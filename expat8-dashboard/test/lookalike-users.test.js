import assert from 'node:assert/strict';
import test from 'node:test';

import { editDistanceIsOne, findLookalikes, lookalikeReason } from '../src/lib/lookalike-users.js';

test('editDistanceIsOne covers substitution, insertion and deletion only', () => {
  assert.equal(editDistanceIsOne('gmail.com', 'gmal.com'), true);
  assert.equal(editDistanceIsOne('gmal.com', 'gmail.com'), true);
  assert.equal(editDistanceIsOne('abcd', 'abxd'), true);
  assert.equal(editDistanceIsOne('abcd', 'abcde'), true);
  assert.equal(editDistanceIsOne('abcd', 'abcd'), false);
  assert.equal(editDistanceIsOne('abcd', 'axyd'), false);
  assert.equal(editDistanceIsOne('abcd', 'abcdef'), false);
  assert.equal(editDistanceIsOne('ab', 'ba'), false);
});

test('lookalikeReason flags same local part and one-character slips between emails', () => {
  assert.equal(lookalikeReason('hoaivubk@gmail.com', 'hoaivubk@gmal.com'), 'same_local_part');
  assert.equal(lookalikeReason('hoaivubk@gmail.com', 'hoaivubk@yahoo.com'), 'same_local_part');
  assert.equal(lookalikeReason('nguyen.an@gmail.com', 'nguyen.am@gmail.com'), 'one_character_apart');
  assert.equal(lookalikeReason('a@gmail.com', 'a@yahoo.com'), null, 'short local parts are too generic');
  assert.equal(lookalikeReason('anna@gmail.com', 'bella@gmail.com'), null);
  assert.equal(lookalikeReason('anna@gmail.com', 'anna@gmail.com'), null);
});

test('non-email identifiers are never compared', () => {
  assert.equal(lookalikeReason('0912345678', '0912345679'), null);
  assert.equal(lookalikeReason('learner01', 'learner02'), null);
  assert.equal(lookalikeReason('learner01', 'learner01@gmail.com'), null);
});

test('findLookalikes maps both accounts of a pair and ignores everyone else', () => {
  const users = [
    { id: 'u1', identifier: 'Hoaivubk@gmail.com' },
    { id: 'u2', identifier: 'hoaivubk@gmal.com' },
    { id: 'u3', identifier: 'someone@example.com' },
    { id: 'u4', identifier: '0912345678' },
  ];
  const result = findLookalikes(users);
  assert.deepEqual([...result.keys()].sort(), ['u1', 'u2']);
  assert.deepEqual(result.get('u1'), ['hoaivubk@gmal.com']);
  assert.deepEqual(result.get('u2'), ['Hoaivubk@gmail.com']);
  assert.equal(findLookalikes([]).size, 0);
});
