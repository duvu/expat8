import assert from 'node:assert/strict';
import http from 'node:http';
import test from 'node:test';

import { createApp } from '../src/app.js';
import { ShadowingImportFailedError, ShadowingTranscriptUnavailableError } from '../src/shadowing_videos.js';
import { WordStore } from '../src/word_store.js';
import { loadTestConfig, signedFetchOptions } from './support/app_credential_helpers.js';

test('shadowing videos API lists curated items plus only the active learner scope', async () => {
  const store = new WordStore({ seed: false });
  const signedIn = store.registerUser({
    identifier: 'shadowing@example.com',
    password: 'correct-password',
    deviceId: 'signed-device'
  });

  const curated = store.createShadowingVideoEntry({
    resolvedVideo: buildResolvedVideo({ providerVideoId: 'curated0001', title: 'Curated clip' }),
    entryType: 'curated',
    visibility: 'published'
  });
  const anonymous = store.createShadowingVideoEntry({
    deviceId: 'anonymous-device',
    resolvedVideo: buildResolvedVideo({ providerVideoId: 'anonymous01', title: 'Anonymous clip' })
  });
  store.createShadowingVideoEntry({
    deviceId: 'other-device',
    resolvedVideo: buildResolvedVideo({ providerVideoId: 'anonymous02', title: 'Other anonymous clip' })
  });
  const signedEntry = store.createShadowingVideoEntry({
    deviceId: 'signed-device',
    userId: signedIn.user.id,
    resolvedVideo: buildResolvedVideo({ providerVideoId: 'signeduser1', title: 'Signed-in clip' })
  });

  const server = http.createServer(createApp({ store, config: loadTestConfig() }));
  await listen(server);
  try {
    const baseUrl = `http://127.0.0.1:${server.address().port}`;

    const anonymousList = await fetchJson(`${baseUrl}/v1/shadowing/videos?device_id=anonymous-device&limit=10`);
    assert.equal(anonymousList.items[0].id, curated.entry.id);
    assert.deepEqual(
      anonymousList.items.map((item) => item.id).sort(),
      [anonymous.entry.id, curated.entry.id].sort()
    );

    const signedList = await fetchJson(`${baseUrl}/v1/shadowing/videos?device_id=signed-device&limit=10`, {
      headers: {
        authorization: `Bearer ${signedIn.sessionToken}`
      }
    });
    assert.equal(signedList.items[0].id, curated.entry.id);
    assert.deepEqual(
      signedList.items.map((item) => item.id).sort(),
      [curated.entry.id, signedEntry.entry.id].sort()
    );
    assert.ok(!signedList.items.some((item) => item.id === anonymous.entry.id));
  } finally {
    server.close();
  }
});

test('shadowing videos API imports and deduplicates the same normalized learner video', async () => {
  const store = new WordStore({ seed: false });
  const resolver = {
    async resolve() {
      return buildResolvedVideo({
        providerVideoId: 'dedupevideo',
        title: 'Reusable clip',
        sourceUrl: 'https://www.youtube.com/watch?v=dedupevideo'
      });
    }
  };

  const server = http.createServer(createApp({ store, config: loadTestConfig(), shadowingVideoResolver: resolver }));
  await listen(server);
  try {
    const baseUrl = `http://127.0.0.1:${server.address().port}`;
    const createUrl = `${baseUrl}/v1/shadowing/videos`;

    const firstResponse = await fetch(
      createUrl,
      signedFetchOptions(createUrl, {
        method: 'POST',
        headers: { 'content-type': 'application/json' },
        body: JSON.stringify({
          device_id: 'shadow-device',
          source_url: 'https://youtu.be/dedupevideo'
        })
      })
    );
    assert.equal(firstResponse.status, 201);
    const firstBody = await firstResponse.json();

    const secondResponse = await fetch(
      createUrl,
      signedFetchOptions(createUrl, {
        method: 'POST',
        headers: { 'content-type': 'application/json' },
        body: JSON.stringify({
          device_id: 'shadow-device',
          source_url: 'https://www.youtube.com/watch?v=dedupevideo&feature=share'
        })
      })
    );
    assert.equal(secondResponse.status, 200);
    const secondBody = await secondResponse.json();

    assert.equal(secondBody.id, firstBody.id);
    assert.equal(secondBody.youtube_video_id, 'dedupevideo');

    const list = await fetchJson(`${baseUrl}/v1/shadowing/videos?device_id=shadow-device&limit=10`);
    assert.equal(list.items.length, 1);
    assert.equal(list.items[0].id, firstBody.id);
  } finally {
    server.close();
  }
});

test('shadowing videos API rejects imports when transcript is unavailable', async () => {
  const store = new WordStore({ seed: false });
  const resolver = {
    async resolve() {
      throw new ShadowingTranscriptUnavailableError();
    }
  };

  const server = http.createServer(createApp({ store, config: loadTestConfig(), shadowingVideoResolver: resolver }));
  await listen(server);
  try {
    const baseUrl = `http://127.0.0.1:${server.address().port}`;
    const createUrl = `${baseUrl}/v1/shadowing/videos`;
    const response = await fetch(
      createUrl,
      signedFetchOptions(createUrl, {
        method: 'POST',
        headers: { 'content-type': 'application/json' },
        body: JSON.stringify({
          device_id: 'shadow-device',
          source_url: 'https://youtu.be/notranscript'
        })
      })
    );
    assert.equal(response.status, 422);
    assert.deepEqual(await response.json(), { error: 'transcript_unavailable' });

    const list = await fetchJson(`${baseUrl}/v1/shadowing/videos?device_id=shadow-device&limit=10`);
    assert.equal(list.items.length, 0);
  } finally {
    server.close();
  }
});

test('shadowing videos API maps upstream import failures to 502', async () => {
  const store = new WordStore({ seed: false });
  const resolver = {
    async resolve() {
      throw new ShadowingImportFailedError('caption_track_parse_failed');
    }
  };

  const server = http.createServer(createApp({ store, config: loadTestConfig(), shadowingVideoResolver: resolver }));
  await listen(server);
  try {
    const baseUrl = `http://127.0.0.1:${server.address().port}`;
    const createUrl = `${baseUrl}/v1/shadowing/videos`;
    const response = await fetch(
      createUrl,
      signedFetchOptions(createUrl, {
        method: 'POST',
        headers: { 'content-type': 'application/json' },
        body: JSON.stringify({
          device_id: 'shadow-device',
          source_url: 'https://youtu.be/importfailed'
        })
      })
    );
    assert.equal(response.status, 502);
    assert.deepEqual(await response.json(), { error: 'shadowing_import_failed' });
  } finally {
    server.close();
  }
});

test('shadowing videos API returns detail for owners and hides private entries from others', async () => {
  const store = new WordStore({ seed: false });
  const owner = store.registerUser({
    identifier: 'owner@example.com',
    password: 'correct-password',
    deviceId: 'owner-device'
  });
  const otherUser = store.registerUser({
    identifier: 'other@example.com',
    password: 'correct-password',
    deviceId: 'other-device'
  });

  const curated = store.createShadowingVideoEntry({
    resolvedVideo: buildResolvedVideo({ providerVideoId: 'detailcur01', title: 'Curated detail clip' }),
    entryType: 'curated',
    visibility: 'published'
  });
  const privateEntry = store.createShadowingVideoEntry({
    deviceId: 'owner-device',
    userId: owner.user.id,
    resolvedVideo: buildResolvedVideo({ providerVideoId: 'detailsave1', title: 'Private detail clip' })
  });

  const server = http.createServer(createApp({ store, config: loadTestConfig() }));
  await listen(server);
  try {
    const baseUrl = `http://127.0.0.1:${server.address().port}`;

    const ownerDetail = await fetchJson(
      `${baseUrl}/v1/shadowing/videos/${privateEntry.entry.id}?device_id=owner-device`,
      {
        headers: {
          authorization: `Bearer ${owner.sessionToken}`
        }
      }
    );
    assert.equal(ownerDetail.id, privateEntry.entry.id);
    assert.equal(ownerDetail.segments.length, 2);
    assert.deepEqual(ownerDetail.playback_defaults, {
      initial_playback_rate: 1,
      seek_back_ms: 5000
    });

    const otherResponse = await fetch(
      `${baseUrl}/v1/shadowing/videos/${privateEntry.entry.id}?device_id=other-device`,
      signedFetchOptions(`${baseUrl}/v1/shadowing/videos/${privateEntry.entry.id}?device_id=other-device`, {
        headers: {
          authorization: `Bearer ${otherUser.sessionToken}`
        }
      })
    );
    assert.equal(otherResponse.status, 404);
    assert.deepEqual(await otherResponse.json(), { error: 'not_found' });

    const curatedDetail = await fetchJson(`${baseUrl}/v1/shadowing/videos/${curated.entry.id}?device_id=public-device`);
    assert.equal(curatedDetail.id, curated.entry.id);
    assert.equal(curatedDetail.entry_type, 'curated');
    assert.equal(curatedDetail.segments[0].position, 0);
  } finally {
    server.close();
  }
});

function buildResolvedVideo(overrides = {}) {
  return {
    sourceType: 'youtube',
    providerVideoId: 'demo1234567',
    sourceUrl: 'https://www.youtube.com/watch?v=demo1234567',
    title: 'Shadowing demo',
    channelTitle: 'Expat8',
    thumbnailUrl: null,
    durationSeconds: 12,
    transcriptLanguage: 'en',
    transcriptSource: 'youtube_caption_track',
    defaultPlaybackRate: 1,
    defaultSeekBackMs: 5000,
    segments: [
      {
        position: 0,
        startMs: 0,
        endMs: 1800,
        text: 'Welcome to the shadowing demo.'
      },
      {
        position: 1,
        startMs: 1800,
        endMs: 3600,
        text: 'Tap any line to seek playback.'
      }
    ],
    ...overrides
  };
}

async function listen(server) {
  return new Promise((resolve) => server.listen(0, '127.0.0.1', resolve));
}

async function fetchJson(url, options = {}) {
  const response = await fetch(url, signedFetchOptions(url, options));
  if (!response.ok) {
    assert.fail(`${response.status} ${await response.text()}`);
  }
  return response.json();
}
