const API = import.meta.env.VITE_API_BASE_URL || '';

export interface JobRun {
  runId: number;
  jobName: string;
  jobType: string;
  status: string;
  startTime: string | null;
  endTime: string | null;
  durationSeconds: number | null;
  recordsRead: number;
  recordsInserted: number;
  recordsUpdated: number;
  recordsSkipped: number;
  recordsRejected: number;
  errorSummary: string | null;
  watermarkBefore: string | null;
  watermarkAfter: string | null;
}

export interface LaunchResult {
  runId: number;
  jobName: string;
  status: string;
  submittedAt: string;
}

export interface DatabaseHealth {
  oracle: { status: string; database?: string; error?: string };
  snowflake: { status: string; user?: string; role?: string; warehouse?: string; error?: string };
}

export interface ReconSummary {
  entityName: string;
  reconMetric: string;
  sourceValue: number | null;
  targetValue: number | null;
  variance: number | null;
  status: string;
}

async function request<T>(url: string, options?: RequestInit): Promise<T> {
  const res = await fetch(API + url, options);
  if (!res.ok) {
    const body = await res.text();
    throw new Error(`HTTP ${res.status}: ${body}`);
  }
  return res.json() as Promise<T>;
}

export const api = {
  launchJob: (type: 'initial' | 'daily' | 'monthly') =>
    request<LaunchResult>(`/api/jobs/${type}`, { method: 'POST' }),

  getJobs: (page = 0, size = 20) =>
    request<{ runs: JobRun[]; page: number; size: number }>(`/api/jobs?page=${page}&size=${size}`),

  getJob: (runId: number) =>
    request<JobRun>(`/api/jobs/${runId}`),

  getErrors: (runId: number, page = 0, size = 50) =>
    request<{ errors: unknown[]; totalCount: number }>(`/api/jobs/${runId}/errors?page=${page}&size=${size}`),

  getDatabaseHealth: () =>
    request<DatabaseHealth>('/api/health/databases'),

  getDashboardSummary: () =>
    request<{ lastInitialRun: JobRun | Record<string, never>; lastDailyRun: JobRun | Record<string, never>; lastMonthlyRun: JobRun | Record<string, never>; reconInitial: ReconSummary[]; reconMonthly: ReconSummary[] }>('/api/dashboard/summary'),

  getReconciliation: () =>
    request<{ initial: ReconSummary[]; monthly: ReconSummary[] }>('/api/reconciliation/latest'),
};
