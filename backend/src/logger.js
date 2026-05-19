const LOG_LEVELS = {
  debug: 10,
  info: 20,
  warn: 30,
  error: 40
};

const REDACTED = '[REDACTED]';
const SENSITIVE_KEY_PATTERN = /pass(word)?|secret|token|authorization|api[_-]?key|credential/i;
const SENSITIVE_VALUE_PATTERN =
  /(Bearer\s+[A-Za-z0-9._~+/=-]+|sk-[A-Za-z0-9_-]+|(?:password|secret|token|api[_-]?key)\s*[:=]\s*[^\s,;]+)/gi;

export function createLogger({
  level = 'info',
  component = 'backend',
  stream = process.stdout,
  redactionEnabled = true,
  bindings = {}
} = {}) {
  const resolvedLevel = normalizeLevel(level);
  const threshold = LOG_LEVELS[resolvedLevel];

  const logger = {
    debug: (event, fields = {}) => emit('debug', event, fields),
    info: (event, fields = {}) => emit('info', event, fields),
    warn: (event, fields = {}) => emit('warn', event, fields),
    error: (event, fields = {}) => emit('error', event, fields),
    child: (childBindings = {}) =>
      createLogger({
        level: resolvedLevel,
        component,
        stream,
        redactionEnabled,
        bindings: { ...bindings, ...sanitizeFields(childBindings, { redactionEnabled }) }
      })
  };

  return logger;

  function emit(levelName, event, fields) {
    if (LOG_LEVELS[levelName] < threshold) {
      return;
    }

    const normalized = normalizeEventAndFields(event, fields);
    const payload = {
      timestamp: new Date().toISOString(),
      level: levelName,
      event: normalized.event,
      component,
      ...bindings,
      ...sanitizeFields(normalized.fields, { redactionEnabled })
    };

    stream.write(`${JSON.stringify(payload)}\n`);
  }
}

function normalizeLevel(level) {
  const candidate = String(level ?? '').toLowerCase();
  if (Object.hasOwn(LOG_LEVELS, candidate)) {
    return candidate;
  }
  return 'info';
}

function normalizeEventAndFields(event, fields) {
  if (typeof event === 'string') {
    return { event, fields: fields ?? {} };
  }
  if (event instanceof Error) {
    return { event: 'error', fields: { error: errorToJson(event), ...(fields ?? {}) } };
  }
  return { event: 'log', fields: { value: event, ...(fields ?? {}) } };
}

export function sanitizeFields(value, { redactionEnabled = true, depth = 0, seen = new WeakSet() } = {}) {
  if (value == null) {
    return value;
  }
  if (depth > 6) {
    return '[TRUNCATED]';
  }
  if (!redactionEnabled) {
    return normalizePrimitive(value);
  }

  if (value instanceof Error) {
    return sanitizeFields(errorToJson(value), { redactionEnabled, depth: depth + 1, seen });
  }

  if (Array.isArray(value)) {
    return value.map((item) => sanitizeFields(item, { redactionEnabled, depth: depth + 1, seen }));
  }

  if (typeof value === 'object') {
    if (seen.has(value)) {
      return '[CIRCULAR]';
    }
    seen.add(value);
    const sanitized = {};
    for (const [key, item] of Object.entries(value)) {
      if (SENSITIVE_KEY_PATTERN.test(key)) {
        sanitized[key] = REDACTED;
        continue;
      }
      sanitized[key] = sanitizeFields(item, { redactionEnabled, depth: depth + 1, seen });
    }
    return sanitized;
  }

  return normalizePrimitive(value);
}

function normalizePrimitive(value) {
  if (typeof value === 'string') {
    return value.replace(SENSITIVE_VALUE_PATTERN, REDACTED);
  }
  if (typeof value === 'bigint') {
    return Number(value);
  }
  return value;
}

function errorToJson(error) {
  return {
    name: error.name,
    message: error.message,
    stack: error.stack
  };
}
