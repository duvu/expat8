import assert from 'node:assert/strict';
import test from 'node:test';

import {
  InvalidRegistrationInputError,
  requireRegistrationInput
} from '../src/user_identity.js';

test('registration input validation uses a registration-specific error', () => {
  assert.throws(
    () => requireRegistrationInput({ identifier: '', password: 'short' }),
    InvalidRegistrationInputError
  );
});
