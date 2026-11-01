export type StatusTone = 'success' | 'warning' | 'danger' | 'info' | 'neutral';

export declare function statusTone(status: string | null | undefined): StatusTone;
export declare function humanizeStatus(status: string | null | undefined): string;
