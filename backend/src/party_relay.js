// Internet party relay: lets phones that are not on the same WiFi play a party game.
//
// The host phone stays authoritative (it runs the game rules); the relay only forwards messages
// between it and its guests, so the game logic lives in one place (mobile lib/src/games/party/).
//
//   host  → relay: {t:'relay_host'} | {t:'relay_host', resume}   (first frame)
//                  {to: guestId, m: message}  {close: guestId}  {t:'relay_end'}
//   relay → host:  {t:'relay_room', code, host_token, guests: [id]}
//                  {from: guestId, open: true}  {from, m: message}  {from, closed: true}
//   guest ↔ relay: plain party messages; the relay assigns the guest id, so guests cannot spoof it.
//
// Rooms live in memory: a backend restart ends the games in progress.

import { randomBytes, randomInt, timingSafeEqual } from 'node:crypto';
import { WebSocketServer } from 'ws';

import { verifyAppCredentialRequest } from './app_credentials.js';
import { InMemoryRateLimiter } from './rate_limit.js';

const HOST_PATH = '/v1/party/host';
const JOIN_PREFIX = '/v1/party/join/';
const CODE_ALPHABET = '0123456789ABCDEFGHJKMNPQRSTVWXYZ'; // Crockford: no I, L, O, U
const CODE_LENGTH = 6;
const PROTOCOL_VERSION = 1;

const DEFAULT_LIMITS = {
  maxRooms: 200,
  maxGuestsPerRoom: 8,
  maxPayloadBytes: 16 * 1024,
  maxMessagesPerSecond: 40,
  hostGraceMs: 30_000,
  firstFrameTimeoutMs: 5_000,
  idleRoomMs: 2 * 60 * 60 * 1000,
  pingIntervalMs: 15_000,
  roomsPerIpPerHour: 20,
  failedJoinsPerIpPer10Min: 30
};

/** Parties are reached by a short code typed by people: tolerate case and look-alike letters. */
export function normalizeRoomCode(raw) {
  return String(raw ?? '')
    .toUpperCase()
    .replace(/[\s-]/g, '')
    .replace(/O/g, '0')
    .replace(/[IL]/g, '1');
}

/**
 * Serves the relay on `server` (the backend's HTTP server) via WebSocket upgrades.
 * Returns `{ close, roomCount }` for shutdown and tests.
 */
export function attachPartyRelay(server, { config, nonceCache, logger = console, limits = {} }) {
  const options = { ...DEFAULT_LIMITS, ...limits };
  const wss = new WebSocketServer({ noServer: true, maxPayload: options.maxPayloadBytes });
  const rooms = new Map();
  const createLimiter = new InMemoryRateLimiter({ windowMs: 60 * 60 * 1000, maxRequests: options.roomsPerIpPerHour });
  const joinFailLimiter = new InMemoryRateLimiter({
    windowMs: 10 * 60 * 1000,
    maxRequests: options.failedJoinsPerIpPer10Min
  });

  server.on('upgrade', (request, socket, head) => {
    handleUpgrade(request, socket, head).catch((error) => {
      logger.warn?.('party_relay.upgrade_failed', { error: error.message });
      refuse(socket, 500);
    });
  });

  async function handleUpgrade(request, socket, head) {
    const url = new URL(request.url, 'http://relay');
    const path = url.pathname;
    const isHost = path === HOST_PATH;
    const code = path.startsWith(JOIN_PREFIX) ? normalizeRoomCode(path.slice(JOIN_PREFIX.length)) : null;
    if (!isHost && !code) {
      return refuse(socket, 404);
    }
    const verified = await verifyAppCredentialRequest({
      method: request.method,
      url,
      headers: request.headers,
      rawBody: Buffer.alloc(0),
      config,
      nonceCache,
      now: new Date()
    });
    if (!verified.ok) {
      return refuse(socket, 401);
    }
    const ip = clientIp(request, config);
    wss.handleUpgrade(request, socket, head, (ws) => {
      guard(ws);
      if (isHost) {
        acceptHost(ws, ip);
      } else {
        acceptGuest(ws, ip, code);
      }
    });
  }

  // ── Hosts ──────────────────────────────────────────────────────────────────

  function acceptHost(ws, ip) {
    const timer = setTimeout(() => ws.close(4000, 'first frame expected'), options.firstFrameTimeoutMs);
    ws.once('message', (data) => {
      clearTimeout(timer);
      const frame = parse(data);
      if (frame?.t !== 'relay_host') {
        return ws.close(4000, 'first frame expected');
      }
      const room = frame.resume ? resumeRoom(ws, frame.resume) : createRoom(ws, ip);
      if (!room) {
        return;
      }
      ws.on('message', (raw) => onHostFrame(room, ws, raw));
      ws.on('close', () => onHostGone(room, ws));
    });
  }

  function createRoom(ws, ip) {
    if (rooms.size >= options.maxRooms || !createLimiter.check(`create:${ip}`).allowed) {
      ws.close(4029, 'too many rooms');
      return null;
    }
    const room = {
      code: newCode(),
      hostToken: randomBytes(24).toString('base64url'),
      host: ws,
      hostTimer: null,
      guests: new Map(),
      nextGuest: 0,
      lastActivityMs: Date.now()
    };
    rooms.set(room.code, room);
    sendRoomInfo(room);
    logger.info?.('party_relay.room_opened', { rooms: rooms.size });
    return room;
  }

  function resumeRoom(ws, token) {
    const room = [...rooms.values()].find((candidate) => sameToken(candidate.hostToken, token));
    if (!room || room.host) {
      ws.close(4404, 'no room');
      return null;
    }
    clearTimeout(room.hostTimer);
    room.host = ws;
    room.lastActivityMs = Date.now();
    sendRoomInfo(room);
    // Guests who arrived while the host was away.
    for (const [id, guest] of room.guests) {
      if (!guest.announced) {
        announce(room, id, guest);
      }
    }
    return room;
  }

  function sendRoomInfo(room) {
    send(room.host, {
      t: 'relay_room',
      code: room.code,
      host_token: room.hostToken,
      guests: [...room.guests].filter(([, guest]) => guest.announced).map(([id]) => id)
    });
  }

  function onHostFrame(room, ws, raw) {
    if (room.host !== ws) {
      return;
    }
    room.lastActivityMs = Date.now();
    const frame = parse(raw);
    if (!frame) {
      return;
    }
    if (frame.t === 'relay_end') {
      return closeRoom(room, 'host_left');
    }
    const target = room.guests.get(frame.to ?? frame.close);
    if (!target) {
      return; // Not one of this room's guests.
    }
    if (frame.close !== undefined) {
      target.ws.close();
    } else if (frame.m && typeof frame.m === 'object') {
      send(target.ws, frame.m);
    }
  }

  function onHostGone(room, ws) {
    if (room.host !== ws || !rooms.has(room.code)) {
      return;
    }
    room.host = null;
    room.hostTimer = setTimeout(() => closeRoom(room, 'host_timeout'), options.hostGraceMs);
  }

  function closeRoom(room, why) {
    if (!rooms.delete(room.code)) {
      return;
    }
    clearTimeout(room.hostTimer);
    for (const guest of room.guests.values()) {
      send(guest.ws, { v: PROTOCOL_VERSION, t: 'reject', reason: 'room_closed' });
      guest.ws.close();
    }
    room.host?.close();
    logger.info?.('party_relay.room_closed', { reason: why, rooms: rooms.size });
  }

  // ── Guests ─────────────────────────────────────────────────────────────────

  function acceptGuest(ws, ip, code) {
    const room = rooms.get(code);
    if (!room) {
      if (!joinFailLimiter.check(`join:${ip}`).allowed) {
        return ws.close(4029, 'too many attempts');
      }
      send(ws, { v: PROTOCOL_VERSION, t: 'reject', reason: 'no_room' });
      return ws.close();
    }
    if (room.guests.size >= options.maxGuestsPerRoom) {
      send(ws, { v: PROTOCOL_VERSION, t: 'reject', reason: 'room_full' });
      return ws.close();
    }
    const id = `g${++room.nextGuest}`;
    const guest = { ws, announced: false };
    room.guests.set(id, guest);
    if (room.host) {
      announce(room, id, guest);
    }
    ws.on('message', (raw) => {
      room.lastActivityMs = Date.now();
      const message = parse(raw);
      if (message && room.host && guest.announced) {
        send(room.host, { from: id, m: message });
      }
    });
    ws.on('close', () => {
      room.guests.delete(id);
      if (guest.announced && room.host) {
        send(room.host, { from: id, closed: true });
      }
    });
  }

  function announce(room, id, guest) {
    guest.announced = true;
    send(room.host, { from: id, open: true });
  }

  // ── Connection hygiene ─────────────────────────────────────────────────────

  function guard(ws) {
    ws.isAlive = true;
    ws.on('pong', () => {
      ws.isAlive = true;
    });
    let windowStart = Date.now();
    let count = 0;
    ws.on('message', () => {
      const now = Date.now();
      if (now - windowStart >= 1000) {
        windowStart = now;
        count = 0;
      }
      if (++count > options.maxMessagesPerSecond) {
        ws.close(4029, 'too many messages');
      }
    });
    ws.on('error', () => ws.terminate());
  }

  const sweeper = setInterval(() => {
    for (const ws of wss.clients) {
      if (!ws.isAlive) {
        ws.terminate();
        continue;
      }
      ws.isAlive = false;
      ws.ping();
    }
    const now = Date.now();
    for (const room of [...rooms.values()]) {
      if (now - room.lastActivityMs > options.idleRoomMs) {
        closeRoom(room, 'idle');
      }
    }
  }, options.pingIntervalMs);
  sweeper.unref?.();

  function newCode() {
    let code;
    do {
      code = Array.from({ length: CODE_LENGTH }, () => CODE_ALPHABET[randomInt(CODE_ALPHABET.length)]).join('');
    } while (rooms.has(code));
    return code;
  }

  return {
    roomCount: () => rooms.size,
    close() {
      clearInterval(sweeper);
      for (const room of [...rooms.values()]) {
        closeRoom(room, 'shutdown');
      }
      wss.close();
    }
  };
}

function parse(raw) {
  try {
    const value = JSON.parse(raw.toString());
    return value && typeof value === 'object' && !Array.isArray(value) ? value : null;
  } catch {
    return null;
  }
}

function send(ws, message) {
  if (ws && ws.readyState === ws.OPEN) {
    ws.send(JSON.stringify(message));
  }
}

function sameToken(expected, given) {
  if (typeof given !== 'string' || given.length !== expected.length) {
    return false;
  }
  return timingSafeEqual(Buffer.from(expected), Buffer.from(given));
}

function refuse(socket, status) {
  const text = { 401: 'Unauthorized', 404: 'Not Found', 500: 'Internal Server Error' }[status] ?? 'Error';
  socket.end(`HTTP/1.1 ${status} ${text}\r\nConnection: close\r\nContent-Length: 0\r\n\r\n`);
}

/**
 * The player's IP for rate limits. Behind Caddy every connection comes from the proxy, so the
 * address it appended to X-Forwarded-For (the last entry; earlier ones are client-supplied) is
 * used — but only when the connection really comes from a trusted proxy (TRUST_PROXY: `true`,
 * a hop count, or comma-separated proxy addresses).
 */
export function clientIp(request, config) {
  const remote = String(request.socket.remoteAddress ?? 'unknown').replace(/^::ffff:/, '');
  const trust = config.trustProxy;
  const forwarded = String(request.headers['x-forwarded-for'] ?? '')
    .split(',')
    .map((part) => part.trim())
    .filter(Boolean);
  if (!trust || forwarded.length === 0) {
    return remote;
  }
  if (typeof trust === 'number') {
    return forwarded[Math.max(0, forwarded.length - trust)] ?? remote;
  }
  const trusted = trust === true || String(trust).split(',').map((ip) => ip.trim()).includes(remote);
  return trusted ? forwarded.at(-1) : remote;
}
