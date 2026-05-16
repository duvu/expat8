import crypto from 'node:crypto';

export class DuplicateUserError extends Error {
  constructor(identifier) {
    super(`duplicate user identifier: ${identifier}`);
    this.name = 'DuplicateUserError';
  }
}

export class InvalidCredentialsError extends Error {
  constructor({ reason = null } = {}) {
    super('invalid user credentials');
    this.name = 'InvalidCredentialsError';
    this.reason = reason;
  }
}

export class InvalidRegistrationInputError extends Error {
  constructor() {
    super('invalid registration input');
    this.name = 'InvalidRegistrationInputError';
  }
}

export function normalizeUserIdentifier(identifier) {
  return String(identifier ?? '').trim().toLowerCase();
}

export function requireRegistrationInput({ identifier, password }) {
  const normalizedIdentifier = normalizeUserIdentifier(identifier);
  if (!normalizedIdentifier || typeof password !== 'string' || password.length < 8) {
    throw new InvalidRegistrationInputError();
  }
  return {
    identifier: normalizedIdentifier,
    password
  };
}

export function createPasswordHash(password, salt = crypto.randomBytes(16).toString('base64url')) {
  const hash = crypto.scryptSync(password, salt, 32).toString('base64url');
  return `scrypt:${salt}:${hash}`;
}

export function verifyPassword(password, storedHash) {
  const [algorithm, salt, expectedHash] = String(storedHash).split(':');
  if (algorithm !== 'scrypt' || !salt || !expectedHash) {
    return false;
  }
  const actualHash = crypto.scryptSync(password, salt, 32).toString('base64url');
  return timingSafeEqual(actualHash, expectedHash);
}

export function createSessionToken() {
  return `session_${crypto.randomBytes(32).toString('base64url')}`;
}

export function hashSessionToken(token) {
  return crypto.createHash('sha256').update(token).digest('base64url');
}

function timingSafeEqual(left, right) {
  // Hash both operands to a fixed-length digest before comparing.
  // This removes the length-check branch that would leak whether the
  // operand lengths matched, preserving constant-time semantics.
  const hash = (v) => crypto.createHash('sha256').update(v).digest();
  return crypto.timingSafeEqual(hash(left), hash(right));
}
