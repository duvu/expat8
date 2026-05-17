export function formatBytes(bytes) {
  const value = Number(bytes);
  if (!Number.isFinite(value) || value <= 0) {
    return '0 B';
  }

  const units = ['B', 'KB', 'MB', 'GB', 'TB'];
  let size = value;
  let unitIndex = 0;

  while (size >= 1024 && unitIndex < units.length - 1) {
    size /= 1024;
    unitIndex += 1;
  }

  const digits = unitIndex === 0 || size >= 10 ? 0 : 1;
  return `${size.toFixed(digits)} ${units[unitIndex]}`;
}

export function formatDateTime(value) {
  const date = value instanceof Date ? value : new Date(value);
  if (Number.isNaN(date.getTime())) {
    return '—';
  }

  return new Intl.DateTimeFormat(undefined, {
    dateStyle: 'medium',
    timeStyle: 'short'
  }).format(date);
}

export function summarizeLogArchives(archives) {
  const totalBytes = archives.reduce((sum, archive) => sum + Number(archive.size_bytes ?? 0), 0);
  const activeCount = archives.filter((archive) => archive.retention_state === 'active').length;
  const expiredCount = archives.filter((archive) => archive.retention_state === 'expired').length;
  const latestUploadAt = archives[0]?.uploaded_at ?? null;

  return {
    totalBytes,
    activeCount,
    expiredCount,
    latestUploadAt
  };
}

export function filterLogArchives(archives, filters = {}) {
  const query = normalizeText(filters.q ?? '');
  const source = normalizeText(filters.source ?? 'all');
  const state = normalizeText(filters.state ?? 'all');
  const from = parseDateBoundary(filters.from, 'start');
  const to = parseDateBoundary(filters.to, 'end');

  return [...archives]
    .filter((archive) => {
      if (state !== 'all' && normalizeText(archive.retention_state ?? '') !== state) {
        return false;
      }
      if (source !== 'all' && normalizeText(archive.source_label ?? '') !== source) {
        return false;
      }
      const uploadedAt = Date.parse(archive.uploaded_at ?? '');
      if (from != null && uploadedAt < from) {
        return false;
      }
      if (to != null && uploadedAt > to) {
        return false;
      }
      if (!query) {
        return true;
      }
      return [
        archive.id,
        archive.file_name,
        archive.source_app_id,
        archive.source_device_id,
        archive.source_user_id,
        archive.source_label,
        archive.retention_state
      ]
        .filter(Boolean)
        .some((value) => normalizeText(String(value)).includes(query));
    })
    .sort((left, right) => Date.parse(right.uploaded_at ?? '') - Date.parse(left.uploaded_at ?? ''));
}

export function filterLogContentLines(content, filters = {}) {
  const query = normalizeText(filters.q ?? '');
  const level = normalizeText(filters.level ?? 'all');
  const lines = String(content ?? '')
    .split(/\r?\n/)
    .filter((line, index, array) => !(index === array.length - 1 && line === ''))
    .map((text, index) => ({ lineNumber: index + 1, text }));

  const filteredLines = lines.filter((line, index) => {
    if (index < 3) {
      return true;
    }

    if (level !== 'all') {
      const entryLevel = extractLogLevel(line.text);
      if (entryLevel !== level) {
        return false;
      }
    }

    if (!query) {
      return true;
    }

    if (normalizeText(line.text).includes(query)) {
      return true;
    }

    try {
      const parsed = JSON.parse(line.text);
      return JSON.stringify(parsed).toLowerCase().includes(query);
    } catch (_error) {
      return false;
    }
  });

  return {
    lines: filteredLines,
    totalLines: lines.length,
    matchedLines: filteredLines.length
  };
}

function normalizeText(value) {
  return String(value).trim().toLowerCase();
}

function parseDateBoundary(raw, position) {
  if (!raw) {
    return null;
  }

  const date = new Date(raw);
  if (Number.isNaN(date.getTime())) {
    return null;
  }

  if (position === 'start') {
    date.setHours(0, 0, 0, 0);
    return date.getTime();
  }

  date.setHours(23, 59, 59, 999);
  return date.getTime();
}

function extractLogLevel(line) {
  try {
    const parsed = JSON.parse(line);
    return normalizeText(parsed.level ?? '');
  } catch (_error) {
    return '';
  }
}
