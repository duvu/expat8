type DateInput = string | number | Date | null | undefined;

export declare function formatShortDate(value: DateInput, now?: Date): string;
export declare function formatShortDateTime(value: DateInput, now?: Date): string;
export declare function formatFullTimestamp(value: DateInput): string;
export declare function formatClock(value: DateInput): string;
export declare function formatRelative(value: DateInput, now?: Date): string | null;
export declare function formatAxisDate(value: string | number): string;
export declare function formatCompact(value: number | string): string;
export declare function formatNumber(value: number | string): string;
