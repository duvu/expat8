import assert from 'node:assert/strict';
import test from 'node:test';

import {
  createPasswordHash,
  createPasswordHashSync,
  InvalidRegistrationInputError,
  requireRegistrationInput,
  verifyPassword
} from '../src/user_identity.js';

test('registration input validation uses a registration-specific error', () => {
  assert.throws(() => requireRegistrationInput({ identifier: '', password: 'short' }), InvalidRegistrationInputError);
});

test('password hash functions are async and remain compatible', async () => {
  const password = 'correct-horse-battery-staple';
  const asyncHash = await createPasswordHash(password);
  const syncHash = createPasswordHashSync(password, 'fixed-salt-2026');

  assert.equal(await verifyPassword(password, asyncHash), true);
  assert.equal(await verifyPassword('wrong', asyncHash), false);
  assert.equal(await verifyPassword(password, syncHash), true);
  assert.equal(await verifyPassword(password, 'scrypt:fixed-salt-2026:tampered'), false);
});
