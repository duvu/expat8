import assert from 'node:assert/strict';
import test from 'node:test';

import { createLogger, sanitizeFields } from '../src/logger.js';

test('emits structured json logs with required fields', () => {
  const chunks = [];
  const logger = createLogger({
    level: 'info',
    component: 'test',
    stream: { write: (line) => chunks.push(line) }
  });

  logger.info('request_started', { method: 'POST', path: '/v1/learning/cards' });

  assert.equal(chunks.length, 1);
  const parsed = JSON.parse(chunks[0]);
  assert.equal(parsed.level, 'info');
  assert.equal(parsed.event, 'request_started');
  assert.equal(parsed.component, 'test');
  assert.equal(parsed.method, 'POST');
  assert.equal(parsed.path, '/v1/learning/cards');
  assert.ok(typeof parsed.timestamp === 'string');
});

test('redacts sensitive keys and sensitive bearer values', () => {
  const sanitized = sanitizeFields({
    password: 'plain',
    nested: {
      app_secret: 'abc',
      authorization: 'Bearer token-value',
      note: 'token is Bearer hello-world'
    }
  });

  assert.equal(sanitized.password, '[REDACTED]');
  assert.equal(sanitized.nested.app_secret, '[REDACTED]');
  assert.equal(sanitized.nested.authorization, '[REDACTED]');
  assert.equal(sanitized.nested.note.includes('[REDACTED]'), true);
});

test('suppresses logs below configured level', () => {
  const chunks = [];
  const logger = createLogger({
    level: 'warn',
    component: 'test',
    stream: { write: (line) => chunks.push(line) }
  });

  logger.info('info_event', {});
  logger.warn('warn_event', {});

  assert.equal(chunks.length, 1);
  const parsed = JSON.parse(chunks[0]);
  assert.equal(parsed.event, 'warn_event');
});
