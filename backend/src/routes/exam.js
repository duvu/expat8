import express from 'express';

const EXAM_PASS_THRESHOLD = 0.7;
const EXAM_SESSION_TTL_MS = 2 * 60 * 60 * 1000; // 2 hours
const CERTIFICATE_DISCLAIMER =
  'This is an internal Expat8 completion certificate. It does not represent an official CEFR or HSK examination result.';

export function createExamRouter({ store }) {
  const router = express.Router();

  // GET /v1/exam/topics?language=<lang>
  // Returns distinct topics from the user's studied words for the given language.
  router.get(
    '/topics',
    asyncHandler(async (request, response) => {
      const userSession = await resolveRequiredUserSession({ request, response, store });
      if (!userSession) {
        return;
      }
      const language = request.query.language ?? 'en';
      const topics = await store.examTopics({ userId: userSession.user.id, language });
      return response.json({ topics });
    })
  );

  // POST /v1/exam/start
  // Generates a new exam session with MCQ questions.
  router.post(
    '/start',
    asyncHandler(async (request, response) => {
      const userSession = await resolveRequiredUserSession({ request, response, store });
      if (!userSession) {
        return;
      }
      const body = request.body ?? {};
      const topic = typeof body.topic === 'string' ? body.topic.trim() : null;
      const language = typeof body.language === 'string' ? body.language.trim() : 'en';
      if (!topic) {
        return response.status(400).json({ error: 'bad_request', message: 'topic is required' });
      }
      const result = await store.startExamSession({
        userId: userSession.user.id,
        topic,
        language,
        now: new Date().toISOString(),
        sessionTtlMs: EXAM_SESSION_TTL_MS
      });
      if (result.error === 'INSUFFICIENT_WORDS') {
        return response.status(422).json({
          error: 'INSUFFICIENT_WORDS',
          message: `Not enough studied words for topic "${topic}" in language "${language}". Found ${result.found}, need at least 5.`
        });
      }
      return response.status(201).json(result);
    })
  );

  // POST /v1/exam/submit
  // Submits answers for an exam session and scores it.
  router.post(
    '/submit',
    asyncHandler(async (request, response) => {
      const userSession = await resolveRequiredUserSession({ request, response, store });
      if (!userSession) {
        return;
      }
      const body = request.body ?? {};
      const sessionId = typeof body.session_id === 'string' ? body.session_id : null;
      const answers = Array.isArray(body.answers) ? body.answers : null;
      if (!sessionId || !answers) {
        return response.status(400).json({ error: 'bad_request', message: 'session_id and answers are required' });
      }
      const result = await store.submitExamSession({
        sessionId,
        userId: userSession.user.id,
        answers,
        now: new Date().toISOString(),
        passPct: EXAM_PASS_THRESHOLD * 100,
        disclaimer: CERTIFICATE_DISCLAIMER
      });
      if (result.error === 'NOT_FOUND') {
        return response.status(404).json({ error: 'not_found' });
      }
      if (result.error === 'ALREADY_SUBMITTED') {
        return response.status(409).json({ error: 'ALREADY_SUBMITTED', message: 'Exam session already submitted.' });
      }
      if (result.error === 'SESSION_EXPIRED') {
        return response.status(410).json({ error: 'SESSION_EXPIRED', message: 'Exam session has expired.' });
      }
      if (result.error === 'ANSWER_COUNT_MISMATCH') {
        return response.status(422).json({
          error: 'ANSWER_COUNT_MISMATCH',
          message: `Expected ${result.expected} answers, got ${result.received}.`
        });
      }
      return response.json(result);
    })
  );

  // GET /v1/exam/results?page=1&limit=20
  // Returns the authenticated user's exam attempt history (newest first).
  router.get(
    '/results',
    asyncHandler(async (request, response) => {
      const userSession = await resolveRequiredUserSession({ request, response, store });
      if (!userSession) {
        return;
      }
      const page = Math.max(1, Number.parseInt(request.query.page ?? '1', 10) || 1);
      const limit = Math.max(1, Math.min(100, Number.parseInt(request.query.limit ?? '20', 10) || 20));
      const result = await store.getExamResults({ userId: userSession.user.id, page, limit });
      return response.json(result);
    })
  );

  // GET /v1/exam/certificate/:id  (PUBLIC — mounted separately in app.js)
  // Returns a certificate record without PII.
  router.get(
    '/certificate/:id',
    asyncHandler(async (request, response) => {
      const cert = await store.getExamCertificate({ id: request.params.id });
      if (!cert) {
        return response.status(404).json({ error: 'not_found' });
      }
      return response.json(cert);
    })
  );

  return router;
}

// ─── helpers ────────────────────────────────────────────────────────────────

function asyncHandler(handler) {
  return (request, response, next) => {
    Promise.resolve(handler(request, response, next)).catch(next);
  };
}

async function resolveRequiredUserSession({ request, response, store }) {
  const token = bearerToken(request);
  if (!token) {
    response.status(401).json({ error: 'invalid_session' });
    return null;
  }
  const session = await store.resolveUserSession({ sessionToken: token });
  if (!session) {
    response.status(401).json({ error: 'invalid_session' });
    return null;
  }
  return session;
}

function bearerToken(request) {
  const authorization = request.get('authorization') ?? '';
  const [scheme, token] = authorization.split(/\s+/);
  return scheme?.toLowerCase() === 'bearer' && token ? token : null;
}
