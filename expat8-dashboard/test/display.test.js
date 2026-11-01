import assert from 'node:assert/strict';
import test from 'node:test';

import { findActiveHref } from '../src/lib/nav.js';
import {
  formatAxisDate,
  formatClock,
  formatCompact,
  formatFullTimestamp,
  formatRelative,
  formatShortDate,
  formatShortDateTime,
} from '../src/lib/datetime.js';
import { humanizeStatus, statusTone } from '../src/lib/status-tone.js';

const NOW = new Date('2026-10-27T10:00:00Z');

test('short dates are compact, UTC and add the year only when it differs', () => {
  assert.equal(formatShortDateTime('2026-10-27T08:00:00Z', NOW), 'Oct 27, 8:00 AM');
  assert.equal(formatShortDateTime('2025-01-03T15:30:00Z', NOW), 'Jan 3, 2025, 3:30 PM');
  assert.equal(formatShortDate('2026-03-09T23:59:00Z', NOW), 'Mar 9');
  assert.equal(formatShortDate(null), '—');
  assert.equal(formatShortDateTime('not a date'), '—');
});

test('full timestamp and clock are UTC', () => {
  assert.equal(formatFullTimestamp('2026-10-27T08:05:09Z'), '2026-10-27 08:05:09 UTC');
  assert.equal(formatClock('2026-10-27T08:05:09Z'), '08:05');
  assert.equal(formatFullTimestamp(undefined), '');
});

test('relative time covers minutes to days and gives up after 30 days', () => {
  assert.equal(formatRelative('2026-10-27T09:59:40Z', NOW), 'just now');
  assert.equal(formatRelative('2026-10-27T09:15:00Z', NOW), '45m ago');
  assert.equal(formatRelative('2026-10-27T08:00:00Z', NOW), '2h ago');
  assert.equal(formatRelative('2026-10-24T10:00:00Z', NOW), '3d ago');
  assert.equal(formatRelative('2026-10-27T12:00:00Z', NOW), 'in 2h');
  assert.equal(formatRelative('2026-08-01T10:00:00Z', NOW), null);
  assert.equal(formatRelative(null, NOW), null);
});

test('chart axis helpers', () => {
  assert.equal(formatAxisDate('2026-10-25'), 'Oct 25');
  assert.equal(formatAxisDate('Grammar'), 'Grammar');
  assert.equal(formatCompact(1200), '1.2K');
  assert.equal(formatCompact(42), '42');
});

test('status tones keep failures and waiting states apart from progress', () => {
  assert.equal(statusTone('processing_failed'), 'danger');
  assert.equal(statusTone('dead_lettered'), 'danger');
  assert.equal(statusTone('rejected'), 'danger');
  assert.equal(statusTone('pending_processing'), 'warning');
  assert.equal(statusTone('pending_review'), 'warning');
  assert.equal(statusTone('processing'), 'info');
  assert.equal(statusTone('processed'), 'success');
  assert.equal(statusTone('published'), 'success');
  assert.equal(statusTone('approved'), 'success');
  assert.equal(statusTone('private'), 'neutral');
  assert.equal(statusTone(null), 'neutral');
  assert.equal(humanizeStatus('pending_processing'), 'Pending processing');
  assert.equal(humanizeStatus(undefined), '—');
});

test('the most specific nav href wins', () => {
  const hrefs = ['/', '/articles', '/articles/new'];
  assert.equal(findActiveHref('/articles/new', hrefs), '/articles/new');
  assert.equal(findActiveHref('/articles/a3', hrefs), '/articles');
  assert.equal(findActiveHref('/', hrefs), '/');
  assert.equal(findActiveHref('/nowhere', hrefs), null);
});
