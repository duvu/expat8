import assert from 'node:assert/strict';
import http from 'node:http';
import test from 'node:test';

import { WebSocket } from 'ws';

import { InMemoryNonceCache } from '../src/app_credentials.js';
import { attachPartyRelay, clientIp, normalizeRoomCode } from '../src/party_relay.js';
import { loadTestConfig, signedFetchOptions } from './support/app_credential_helpers.js';

const quiet = { info() {}, warn() {} };

async function startRelay(t, limits = {}) {
  const server = http.createServer((request, response) => response.writeHead(404).end());
  const relay = attachPartyRelay(server, {
    config: loadTestConfig(),
    nonceCache: new InMemoryNonceCache(),
    logger: quiet,
    limits: { pingIntervalMs: 60_000, ...limits }
  });
  await new Promise((resolve) => server.listen(0, '127.0.0.1', resolve));
  t.after(() => {
    relay.close();
    server.close();
  });
  return { relay, base: `ws://127.0.0.1:${server.address().port}` };
}

/** A connected socket that records every JSON message it receives. */
function connect(url, { signed = true } = {}) {
  return new Promise((resolve, reject) => {
    const ws = new WebSocket(url, { headers: signed ? signedFetchOptions(url).headers : {} });
    ws.inbox = [];
    ws.on('message', (data) => ws.inbox.push(JSON.parse(data.toString())));
    ws.on('open', () => resolve(ws));
    ws.on('unexpected-response', (request, response) => reject(new Error(`HTTP ${response.statusCode}`)));
    ws.on('error', reject);
  });
}

/** Resolves with the first received message matching `predicate`. */
async function next(ws, predicate = () => true, timeoutMs = 2000) {
  const end = Date.now() + timeoutMs;
  while (Date.now() < end) {
    const index = ws.inbox.findIndex(predicate);
    if (index >= 0) {
      return ws.inbox.splice(index, 1)[0];
    }
    await new Promise((resolve) => setTimeout(resolve, 10));
  }
  throw new Error('no matching message');
}

const closed = (ws) =>
  ws.readyState === WebSocket.CLOSED ? Promise.resolve() : new Promise((resolve) => ws.once('close', resolve));

async function openRoom(base) {
  const host = await connect(`${base}/v1/party/host`);
  host.send(JSON.stringify({ t: 'relay_host' }));
  const room = await next(host, (m) => m.t === 'relay_room');
  return { host, room };
}

test('relays between a host and its guests, who cannot spoof each other', async (t) => {
  const { base } = await startRelay(t);
  const { host, room } = await openRoom(base);
  assert.match(room.code, /^[0-9A-HJKMNP-TV-Z]{6}$/);
  assert.ok(room.host_token);

  const an = await connect(`${base}/v1/party/join/${room.code.toLowerCase()}`);
  const anOpen = await next(host, (m) => m.open);
  const binh = await connect(`${base}/v1/party/join/${room.code}`);
  const binhOpen = await next(host, (m) => m.open);
  assert.notEqual(anOpen.from, binhOpen.from);

  // A guest message arrives wrapped with the id the relay assigned, whatever it claims.
  an.send(JSON.stringify({ v: 1, t: 'hello', name: 'An', from: binhOpen.from }));
  const hello = await next(host, (m) => m.m?.t === 'hello');
  assert.equal(hello.from, anOpen.from);
  assert.equal(hello.m.name, 'An');

  // Host messages reach only their target; unknown targets are dropped.
  host.send(JSON.stringify({ to: anOpen.from, m: { v: 1, t: 'welcome', player: 'p1' } }));
  host.send(JSON.stringify({ to: 'g999', m: { t: 'lobby' } }));
  assert.equal((await next(an)).t, 'welcome');
  await new Promise((resolve) => setTimeout(resolve, 50));
  assert.equal(binh.inbox.length, 0);

  // A guest leaving is reported; the host ending the room closes it for everyone.
  an.close();
  assert.equal((await next(host, (m) => m.closed)).from, anOpen.from);
  host.send(JSON.stringify({ t: 'relay_end' }));
  assert.equal((await next(binh)).reason, 'room_closed');
  await closed(binh);
});

test('unsigned connections and unknown rooms are refused', async (t) => {
  const { base } = await startRelay(t);
  await assert.rejects(connect(`${base}/v1/party/host`, { signed: false }), /HTTP 401/);
  await assert.rejects(connect(`${base}/v1/other`), /HTTP 404/);
  const lost = await connect(`${base}/v1/party/join/ABC123`);
  assert.equal((await next(lost)).reason, 'no_room');
  await closed(lost);
  assert.equal(normalizeRoomCode(' abc-1o2 '), 'ABC102');
});

test('a host that drops can resume within the grace period; then the room ends', async (t) => {
  const { base, relay } = await startRelay(t, { hostGraceMs: 300 });
  const { host, room } = await openRoom(base);
  const guest = await connect(`${base}/v1/party/join/${room.code}`);
  const open = await next(host, (m) => m.open);

  host.terminate(); // phone lost its connection
  await new Promise((resolve) => setTimeout(resolve, 50));
  const back = await connect(`${base}/v1/party/host`);
  back.send(JSON.stringify({ t: 'relay_host', resume: room.host_token }));
  const resumed = await next(back, (m) => m.t === 'relay_room');
  assert.equal(resumed.code, room.code);
  assert.deepEqual(resumed.guests, [open.from]);
  guest.send(JSON.stringify({ t: 'answer', qid: 'q', choice: 1 }));
  assert.equal((await next(back, (m) => m.m)).m.t, 'answer');

  back.terminate();
  assert.equal((await next(guest, (m) => m.t === 'reject', 2000)).reason, 'room_closed');
  assert.equal(relay.roomCount(), 0);

  const thief = await connect(`${base}/v1/party/host`);
  thief.send(JSON.stringify({ t: 'relay_host', resume: room.host_token }));
  await closed(thief);
});

test('caps: guests per room, rooms per IP, payload size', async (t) => {
  const { base } = await startRelay(t, { maxGuestsPerRoom: 1, roomsPerIpPerHour: 1, maxPayloadBytes: 1024 });
  const { host, room } = await openRoom(base);
  await connect(`${base}/v1/party/join/${room.code}`);
  const extra = await connect(`${base}/v1/party/join/${room.code}`);
  assert.equal((await next(extra)).reason, 'room_full');

  const second = await connect(`${base}/v1/party/host`);
  second.send(JSON.stringify({ t: 'relay_host' }));
  await closed(second);

  host.send('x'.repeat(4096)); // over maxPayload: the relay drops the connection
  await closed(host);
});

test('rate limits key on the address the trusted proxy saw', () => {
  const request = (remoteAddress, forwarded) => ({
    socket: { remoteAddress },
    headers: forwarded ? { 'x-forwarded-for': forwarded } : {}
  });
  const behindCaddy = { trustProxy: '10.113.213.1' };
  assert.equal(clientIp(request('::ffff:10.113.213.1', '6.6.6.6, 1.2.3.4'), behindCaddy), '1.2.3.4');
  assert.equal(clientIp(request('9.9.9.9', '1.2.3.4'), behindCaddy), '9.9.9.9', 'not from the proxy');
  assert.equal(clientIp(request('9.9.9.9', '1.2.3.4'), { trustProxy: false }), '9.9.9.9');
  assert.equal(clientIp(request('10.0.0.1', 'a, b, c'), { trustProxy: 2 }), 'b');
});
