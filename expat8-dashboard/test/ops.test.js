import assert from 'node:assert/strict';
import test from 'node:test';

import { isSidebarLinkActive } from '../src/lib/nav.js';
import {
  filterLogArchives,
  filterLogContentLines,
  formatBytes,
  summarizeLogArchives,
} from '../src/lib/ops.js';

test('sidebar active link covers nested ops routes', () => {
  assert.equal(isSidebarLinkActive('/ops', '/ops'), true);
  assert.equal(isSidebarLinkActive('/ops/logs', '/ops'), true);
  assert.equal(isSidebarLinkActive('/review', '/ops'), false);
});

test('formats archive sizes and summary counts', () => {
  assert.equal(formatBytes(0), '0 B');
  assert.equal(formatBytes(1024), '1.0 KB');

  const summary = summarizeLogArchives([
    { size_bytes: 512, retention_state: 'active', uploaded_at: '2026-05-05T00:00:00Z' },
    { size_bytes: 2048, retention_state: 'expired', uploaded_at: '2026-05-04T00:00:00Z' },
  ]);

  assert.equal(summary.totalBytes, 2560);
  assert.equal(summary.activeCount, 1);
  assert.equal(summary.expiredCount, 1);
});

test('filters archives by text, source, and state', () => {
  const archives = filterLogArchives([
    {
      id: 'a1',
      file_name: 'app.log',
      source_label: 'mobile',
      retention_state: 'active',
      uploaded_at: '2026-05-05T10:00:00.000Z',
      source_app_id: 'app-mobile',
      source_device_id: 'device-1',
      source_user_id: 'user-1',
    },
    {
      id: 'a2',
      file_name: 'ops.log',
      source_label: 'mobile',
      retention_state: 'expired',
      uploaded_at: '2026-05-04T10:00:00.000Z',
      source_app_id: 'app-mobile',
      source_device_id: 'device-2',
      source_user_id: 'user-2',
    },
  ], {
    q: 'device-1',
    state: 'active',
  });

  assert.deepEqual(archives.map((archive) => archive.id), ['a1']);
});

test('filters log content lines by level and text', () => {
  const result = filterLogContentLines([
    '# header',
    '# second header',
    '# third header',
    '{"level":"info","message":"ready"}',
    '{"level":"error","message":"failed to upload"}',
  ].join('\n'), {
    q: 'failed',
    level: 'error',
  });

  assert.equal(result.totalLines, 5);
  assert.equal(result.matchedLines, 4);
  assert.equal(result.lines.at(-1)?.text.includes('failed to upload'), true);
});
