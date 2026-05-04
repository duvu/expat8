import crypto from 'node:crypto';

export class DuplicateUserError extends Error {
  constructor(identifier) {
    super(`duplicate user identifier: ${identifier}`);
    this.name = 'DuplicateUserError';
  }
}

export class InvalidCredentialsError extends Error {
  constructor() {
    super('invalid user credentials');
    this.name = 'InvalidCredentialsError';
  }
}

export function normalizeUserIdentifier(identifier) {
  return String(identifier ?? '').trim().toLowerCase();
}

export function requireRegistrationInput({ identifier, password }) {
  const normalizedIdentifier = normalizeUserIdentifier(identifier);
  if (!normalizedIdentifier || typeof password !== 'string' || password.length < 8) {
    throw new InvalidCredentialsError();
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
  const leftBuffer = Buffer.from(left);
  const rightBuffer = Buffer.from(right);
  if (leftBuffer.length !== rightBuffer.length) {
    return false;
  }
  return crypto.timingSafeEqual(leftBuffer, rightBuffer);
}
