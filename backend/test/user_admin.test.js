import assert from 'node:assert/strict';
import http from 'node:http';
import test from 'node:test';

import { createApp } from '../src/app.js';
import { suggestIdentifierFix } from '../src/domain/identifier_typos.js';
import { deletionConfirmed, generateTemporaryPassword, resolveResetPassword } from '../src/domain/user_admin.js';
import { createPasswordHashSync } from '../src/user_identity.js';
import { WordStore } from '../src/word_store.js';
import { loadTestConfig, signedFetchOptions } from './support/app_credential_helpers.js';

const ADMIN = { 'content-type': 'application/json', 'x-expat8-admin-token': 'admin-token' };
const JSON_HEADERS = { 'content-type': 'application/json' };

async function startApp(t, store = new WordStore({ seed: false })) {
  const server = http.createServer(
    createApp({ store, generationService: null, config: loadTestConfig({ ADMIN_API_TOKENS: 'admin-token' }) })
  );
  await new Promise((resolve) => server.listen(0, '127.0.0.1', resolve));
  t.after(() => server.close());
  const base = `http://127.0.0.1:${server.address().port}`;
  const call = (path, method, { headers = ADMIN, body } = {}) =>
    fetch(`${base}${path}`, signedFetchOptions(`${base}${path}`, { method, headers, ...(body ? { body: JSON.stringify(body) } : {}) }));
  return { store, call };
}

test('typo domains of big providers are detected, real domains and non-emails are not', () => {
  for (const [typo, fixed] of [
    ['a@gmal.com', 'a@gmail.com'],
    ['a@gmial.com', 'a@gmail.com'],
    ['a@gmail.con', 'a@gmail.com'],
    ['a@gmil.com', 'a@gmail.com'],
    ['a@gnail.com', 'a@gmail.com'],
    ['a@hotmial.com', 'a@hotmail.com'],
    ['a@hotmal.com', 'a@hotmail.com'],
    ['a@yaho.com', 'a@yahoo.com'],
    ['a@yahooo.com', 'a@yahoo.com'],
    ['a@outlok.com', 'a@outlook.com'],
    ['a@iclould.com', 'a@icloud.com'],
    ['first.last+tag@gmal.com', 'first.last+tag@gmail.com']
  ]) {
    assert.equal(suggestIdentifierFix(typo), fixed, typo);
  }
  for (const fine of [
    'a@gmail.com', 'a@yahoo.com', 'a@hotmail.com', 'a@outlook.com', 'a@icloud.com', 'a@yahoo.com.vn',
    'a@gmal.vn', 'a@mygmal.com', 'a@sub.gmal.com', 'gmal.com', '@gmal.com', 'a@b@gmal.com',
    '0912345678', '+84912345678', 'gmal', 'user_gmal.com', '', null
  ]) {
    assert.equal(suggestIdentifierFix(fine), null, String(fine));
  }
});

test('registration rejects typo domains with a suggestion while sign-in of an existing account still works', async (t) => {
  const { store, call } = await startApp(t);
  // An account created before the guard existed.
  const legacy = {
    id: 'user_legacy', identifier: 'old@gmal.com', display_name: null,
    password_hash: createPasswordHashSync('legacy password'), created_at: 'x', updated_at: 'x'
  };
  store.usersById.set(legacy.id, legacy);
  store.usersByIdentifier.set(legacy.identifier, legacy);

  const rejected = await call('/v1/users/register', 'POST', {
    headers: JSON_HEADERS, body: { identifier: ' New@GMAL.com ', password: 'long enough pw' }
  });
  assert.equal(rejected.status, 400);
  assert.deepEqual(await rejected.json(), { error: 'bad_request', reason: 'identifier_domain_typo', suggestion: 'new@gmail.com' });
  assert.equal(store.usersByIdentifier.has('new@gmal.com'), false);

  const accepted = await call('/v1/users/register', 'POST', {
    headers: JSON_HEADERS, body: { identifier: '0912345678', password: 'long enough pw' }
  });
  assert.equal(accepted.status, 201);
  const plain = await call('/v1/users/register', 'POST', { headers: JSON_HEADERS, body: { identifier: 'x', password: 'short' } });
  assert.deepEqual(await plain.json(), { error: 'bad_request' });

  const signIn = await call('/v1/users/sign-in', 'POST', {
    headers: JSON_HEADERS, body: { identifier: 'old@gmal.com', password: 'legacy password' }
  });
  assert.equal(signIn.status, 200);
});

test('reset password rules: generated passwords are strong, supplied ones validated', () => {
  const generated = resolveResetPassword(undefined);
  assert.equal(generated.generated, true);
  assert.ok(generated.password.length >= 12);
  assert.match(generated.password, /^[A-HJ-NP-Za-km-z2-9]+$/, 'no ambiguous characters');
  assert.notEqual(generateTemporaryPassword(), generateTemporaryPassword());
  assert.deepEqual(resolveResetPassword('long enough'), { password: 'long enough', generated: false });
  assert.equal(resolveResetPassword('short'), null);
  assert.equal(resolveResetPassword(12345678), null);
  assert.equal(deletionConfirmed({ identifier: 'a@b.com' }, ' A@B.com '), true);
  assert.equal(deletionConfirmed({ identifier: 'a@b.com' }, 'a@b.co'), false);
  assert.equal(deletionConfirmed({ identifier: 'a@b.com' }, undefined), false);
});

test('admin user endpoints require the admin token', async (t) => {
  const { call } = await startApp(t);
  const noToken = { 'content-type': 'application/json' };
  assert.equal((await call('/v1/admin/users/user_x/reset-password', 'POST', { headers: noToken, body: {} })).status, 403);
  assert.equal((await call('/v1/admin/users/user_x', 'DELETE', { headers: noToken, body: { confirm: 'x' } })).status, 403);
});

test('admin reset-password revokes sessions and returns the temporary password once', async (t) => {
  const { store, call } = await startApp(t);
  const { user, sessionToken } = store.registerUser({ identifier: 'learner@example.com', password: 'old password 1', deviceId: 'dev1' });

  const generated = await call(`/v1/admin/users/${user.id}/reset-password`, 'POST', { body: {} });
  assert.equal(generated.status, 200);
  const body = await generated.json();
  assert.equal(body.user_id, user.id);
  assert.equal(body.identifier, 'learner@example.com');
  assert.ok(body.temporary_password.length >= 12);
  assert.equal(store.resolveUserSession({ sessionToken }), null, 'old sessions are revoked');
  assert.throws(() => store.createUserSession({ identifier: 'learner@example.com', password: 'old password 1' }));
  assert.equal(store.createUserSession({ identifier: 'learner@example.com', password: body.temporary_password }).user.id, user.id);

  const chosen = await call(`/v1/admin/users/${user.id}/reset-password`, 'POST', { body: { new_password: 'my own new password' } });
  const chosenBody = await chosen.json();
  assert.equal(chosenBody.temporary_password, undefined);
  assert.equal(store.createUserSession({ identifier: 'learner@example.com', password: 'my own new password' }).user.id, user.id);

  const tooShort = await call(`/v1/admin/users/${user.id}/reset-password`, 'POST', { body: { new_password: 'short' } });
  assert.equal(tooShort.status, 400);
  assert.equal((await call('/v1/admin/users/user_missing/reset-password', 'POST', { body: {} })).status, 404);
});

test('admin delete requires the identifier and removes the account data', async (t) => {
  const { store, call } = await startApp(t);
  const target = store.registerUser({ identifier: 'target@example.com', password: 'password one', deviceId: 'dev_t' });
  const other = store.registerUser({ identifier: 'other@example.com', password: 'password two', deviceId: 'dev_o' });
  const word = store.insertWord({ term: 'alpha', language: 'en', meaning_vi: 'm', difficulty: 'A1' }).word;
  for (const [userId, deviceId] of [[target.user.id, 'dev_t'], [other.user.id, 'dev_o'], [null, 'dev_t']]) {
    store.recordStudyEvent({
      deviceId, userId,
      event: { client_event_id: `evt_${userId}_${deviceId}`, server_word_id: word.id, rating: 'easy', occurred_at: '2026-05-04T10:30:00.000Z' }
    });
  }
  store.recordGameRounds({ deviceId: 'dev_t', userId: target.user.id, rounds: [{ client_round_id: 'r1', game: 'word_blaster', mode: 'classic', language: 'en', score: 5, correct_count: 1, answered_count: 1, best_combo: 1, wave: 1, duration_ms: 100, completed_at: '2026-05-04T10:30:00.000Z' }] });
  store.replaceCachedWordIds({ deviceId: 'dev_t', userId: target.user.id, wordIds: [word.id] });
  const article = store.createArticle({ userId: target.user.id, title: 't', language: 'en', rawText: 'hello' });
  store.createPassage({ title: 'p', language: 'en', rawText: 'text', ownerUserId: target.user.id });

  const base = `/v1/admin/users/${target.user.id}`;
  const missing = await call(base, 'DELETE', { body: {} });
  assert.equal(missing.status, 400);
  assert.deepEqual(await missing.json(), { error: 'confirmation_required' });
  assert.equal((await call(base, 'DELETE', { body: { confirm: 'other@example.com' } })).status, 400);
  assert.equal(store.usersById.has(target.user.id), true);
  assert.equal((await call('/v1/admin/users/user_missing', 'DELETE', { body: { confirm: 'x' } })).status, 404);

  const deleted = await call(`${base}?confirm=${encodeURIComponent('Target@Example.com')}`, 'DELETE');
  assert.equal(deleted.status, 200);
  const body = await deleted.json();
  assert.equal(body.identifier, 'target@example.com');
  assert.equal(body.deleted.user, 1);
  assert.equal(body.deleted.sessions, 1);
  assert.equal(body.deleted.study_events, 2, 'own event plus the anonymous one on the device');
  assert.equal(body.deleted.game_rounds, 1);
  assert.equal(body.deleted.cached_words, 1);
  assert.equal(body.deleted.articles, 1);
  assert.equal(body.deleted.memorization_content, 1);

  assert.equal(store.usersById.has(target.user.id), false);
  assert.equal(store.usersByIdentifier.has('target@example.com'), false);
  assert.equal(store.resolveUserSession({ sessionToken: target.sessionToken }), null);
  assert.equal(store.articlesById.has(article.id), false);
  assert.equal(store.memorizationPassagesById.size, 0);
  assert.equal(store.cachedWordIdsByOwner.has(`user:${target.user.id}`), false);
  assert.equal(store.studyEventsByClientId.size, 1);
  assert.equal([...store.studyEventsByClientId.values()][0].user_id, other.user.id);
  assert.equal(store.usersById.has(other.user.id), true);
  assert.equal(store.words.has(word.id), true);
});
