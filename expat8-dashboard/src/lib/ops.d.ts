import type { LogArchiveRecord } from './ops-data';

export type LogContentLine = {
  lineNumber: number;
  text: string;
};

export type LogContentFilterResult = {
  lines: LogContentLine[];
  totalLines: number;
  matchedLines: number;
};

export declare function formatBytes(bytes: number | string | null | undefined): string;
export declare function formatDateTime(value: string | number | Date | null | undefined): string;
export declare function summarizeLogArchives(archives: LogArchiveRecord[]): {
  totalBytes: number;
  activeCount: number;
  expiredCount: number;
  latestUploadAt: string | null;
};
export declare function filterLogArchives(
  archives: LogArchiveRecord[],
  filters?: {
    q?: string;
    source?: string;
    state?: string;
    from?: string;
    to?: string;
  }
): LogArchiveRecord[];
export declare function filterLogContentLines(
  content: string,
  filters?: {
    q?: string;
    level?: string;
  }
): LogContentFilterResult;
