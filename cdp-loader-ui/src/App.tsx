import { useEffect, useState, useCallback, useRef } from 'react';
import { api, JobRun, DatabaseHealth, ReconSummary } from './api';
import './App.css';

// ─── Helpers ──────────────────────────────────────────────────────────────────

function isRunning(status: string) { return status === 'STARTED'; }

function fmtNum(n: number | null | undefined) {
  if (n == null) return '—';
  return n.toLocaleString();
}

function fmtDuration(secs: number | null) {
  if (secs == null) return '—';
  if (secs < 60) return `${secs.toFixed(1)}s`;
  const m = Math.floor(secs / 60);
  const s = (secs % 60).toFixed(0).padStart(2, '0');
  return `${m}m ${s}s`;
}

function fmtTs(ts: string | null) {
  if (!ts) return '—';
  return new Date(ts).toLocaleString(undefined, {
    month: 'short', day: 'numeric',
    hour: '2-digit', minute: '2-digit', second: '2-digit',
  });
}

// ─── Badge ────────────────────────────────────────────────────────────────────

function Badge({ status }: { status: string }) {
  const s = status.toUpperCase();
  const dots: Record<string, string> = {
    COMPLETED: '●', STARTED: '◉', FAILED: '✕',
    PASS: '✓', FAIL: '✕', UP: '●', DOWN: '✕', WARNING: '⚠',
  };
  let cls = 'badge badge-default';
  if (s === 'COMPLETED') cls = 'badge badge-completed';
  else if (s === 'STARTED')  cls = 'badge badge-started';
  else if (s === 'FAILED')   cls = 'badge badge-failed';
  else if (s === 'PASS')     cls = 'badge badge-pass';
  else if (s === 'FAIL')     cls = 'badge badge-fail';
  else if (s === 'UP')       cls = 'badge badge-up';
  else if (s === 'DOWN')     cls = 'badge badge-down';
  else if (s === 'WARNING')  cls = 'badge badge-warning';
  return <span className={cls}><span style={{ fontSize: 8 }}>{dots[s] ?? '●'}</span>{status}</span>;
}

// ─── Run card ─────────────────────────────────────────────────────────────────

type RunCardVariant = 'initial' | 'daily' | 'monthly';

function RunCard({ label, run, variant }: { label: string; run: JobRun | undefined; variant: RunCardVariant }) {
  const icons: Record<RunCardVariant, string> = { initial: '⚡', daily: '🔄', monthly: '📊' };
  if (!run) {
    return (
      <div className="run-card">
        <div className={`run-card-accent ${variant}`} />
        <div className="run-card-header">
          <span className="run-card-type">{icons[variant]} {label}</span>
        </div>
        <p className="empty-state" style={{ padding: '8px 0' }}>No run yet</p>
      </div>
    );
  }
  return (
    <div className="run-card">
      <div className={`run-card-accent ${variant}`} />
      <div className="run-card-header">
        <span className="run-card-type">{icons[variant]} {label}</span>
        <Badge status={run.status} />
      </div>
      <div className="run-card-body">
        <div className="run-stat">
          <span className="run-stat-label">Run ID</span>
          <span className="run-stat-value">#{run.runId}</span>
        </div>
        <div className="run-stat">
          <span className="run-stat-label">Duration</span>
          <span className="run-stat-value">{fmtDuration(run.durationSeconds)}</span>
        </div>
        <div className="run-stat">
          <span className="run-stat-label">Read</span>
          <span className="run-stat-value">{fmtNum(run.recordsRead)}</span>
        </div>
        <div className="run-stat">
          <span className="run-stat-label">Processed</span>
          <span className="run-stat-value">{fmtNum(run.recordsInserted)}</span>
        </div>
        <div className="run-stat">
          <span className="run-stat-label">Rejected</span>
          <span className={`run-stat-value${run.recordsRejected > 0 ? ' warned' : ''}`}>
            {fmtNum(run.recordsRejected)}
          </span>
        </div>
        <div className="run-stat">
          <span className="run-stat-label">Started</span>
          <span className="run-stat-value small">{fmtTs(run.startTime)}</span>
        </div>
      </div>
    </div>
  );
}

// ─── History row ──────────────────────────────────────────────────────────────

function HistoryRow({ run }: { run: JobRun }) {
  const typeColors: Record<string, string> = {
    INITIAL: '#818cf8', DAILY: '#22d3ee', MONTHLY: '#10b981',
  };
  const color = typeColors[run.jobType] ?? '#8b95ad';
  return (
    <tr>
      <td className="num" style={{ color: '#8b95ad' }}>#{run.runId}</td>
      <td><span style={{ color, fontWeight: 700, fontSize: 11, letterSpacing: '0.05em' }}>{run.jobType}</span></td>
      <td><Badge status={run.status} /></td>
      <td className="ts-cell">{fmtTs(run.startTime)}</td>
      <td className="ts-cell">{fmtTs(run.endTime)}</td>
      <td className="num">{fmtDuration(run.durationSeconds)}</td>
      <td className="num">{fmtNum(run.recordsRead)}</td>
      <td className="num">{fmtNum(run.recordsInserted)}</td>
      <td className="num">{fmtNum(run.recordsUpdated)}</td>
      <td className={`num${run.recordsRejected > 0 ? ' warned-val' : ''}`}>
        {fmtNum(run.recordsRejected)}
      </td>
    </tr>
  );
}

// ─── Main App ─────────────────────────────────────────────────────────────────

export default function App() {
  const [health, setHealth]           = useState<DatabaseHealth | null>(null);
  const [healthError, setHealthError] = useState<string | null>(null);
  const [summary, setSummary]         = useState<{
    lastInitialRun?: JobRun;
    lastDailyRun?: JobRun;
    lastMonthlyRun?: JobRun;
    reconInitial?: ReconSummary[];
    reconMonthly?: ReconSummary[];
  }>({});
  const [history, setHistory]       = useState<JobRun[]>([]);
  const [launching, setLaunching]   = useState<string | null>(null);
  const [launchError, setLaunchError] = useState<string | null>(null);
  const [confirmInitial, setConfirmInitial] = useState(false);
  const [activeRunIds, setActiveRunIds]     = useState<number[]>([]);
  const pollRef = useRef<ReturnType<typeof setInterval> | null>(null);

  const loadHealth = useCallback(async () => {
    try { const h = await api.getDatabaseHealth(); setHealth(h); setHealthError(null); }
    catch { setHealthError('Health check failed'); }
  }, []);

  const loadSummary = useCallback(async () => {
    try {
      const s = await api.getDashboardSummary();
      setSummary({
        lastInitialRun: s.lastInitialRun && 'runId' in s.lastInitialRun ? s.lastInitialRun as JobRun : undefined,
        lastDailyRun:   s.lastDailyRun   && 'runId' in s.lastDailyRun   ? s.lastDailyRun   as JobRun : undefined,
        lastMonthlyRun: s.lastMonthlyRun && 'runId' in s.lastMonthlyRun ? s.lastMonthlyRun as JobRun : undefined,
        reconInitial: s.reconInitial,
        reconMonthly: s.reconMonthly,
      });
    } catch { /* ignore */ }
  }, []);

  const loadHistory = useCallback(async () => {
    try {
      const r = await api.getJobs(0, 50);
      setHistory(r.runs);
      setActiveRunIds(r.runs.filter(x => isRunning(x.status)).map(x => x.runId));
    } catch { /* ignore */ }
  }, []);

  useEffect(() => {
    if (activeRunIds.length > 0 && !pollRef.current) {
      pollRef.current = setInterval(async () => {
        await loadHistory(); await loadSummary();
        if (activeRunIds.length === 0 && pollRef.current) { clearInterval(pollRef.current); pollRef.current = null; }
      }, 4000);
    } else if (activeRunIds.length === 0 && pollRef.current) {
      clearInterval(pollRef.current); pollRef.current = null;
    }
    return () => { if (pollRef.current) { clearInterval(pollRef.current); pollRef.current = null; } };
  }, [activeRunIds, loadHistory, loadSummary]);

  useEffect(() => { loadHealth(); loadSummary(); loadHistory(); }, [loadHealth, loadSummary, loadHistory]);

  const hasRunning = activeRunIds.length > 0;

  async function launch(type: 'initial' | 'daily' | 'monthly') {
    setLaunchError(null); setLaunching(type);
    try { await api.launchJob(type); await loadHistory(); await loadSummary(); }
    catch (e: unknown) { setLaunchError(e instanceof Error ? e.message : String(e)); }
    finally { setLaunching(null); setConfirmInitial(false); }
  }

  const lastRun = summary.lastDailyRun ?? summary.lastMonthlyRun ?? summary.lastInitialRun;
  const latestReconStatus = (() => {
    const rows = [...(summary.reconMonthly ?? []), ...(summary.reconInitial ?? [])];
    if (rows.length === 0) return null;
    return rows.every(r => r.status === 'PASS') ? 'PASS' : 'FAIL';
  })();
  const hasRecon = (summary.reconInitial?.length ?? 0) + (summary.reconMonthly?.length ?? 0) > 0;

  const bothUp = health?.oracle.status === 'UP' && health?.snowflake.status === 'UP';

  return (
    <div className="app-shell">

      {/* ── Header ── */}
      <header className="app-header">
        <div className="app-header-inner">
          <div className="app-header-left">
            <div className="app-logo">⚡</div>
            <div className="app-title-group">
              <span className="app-title">CDP ETL Dashboard</span>
              <span className="app-subtitle">Snowflake → Oracle Loader</span>
            </div>
          </div>
          <div className="app-header-right">
            {health && <div className={`header-status-dot`} style={bothUp ? {} : { background: '#f43f5e', boxShadow: '0 0 8px #f43f5e', animation: 'none' }} />}
            <span className="app-badge">IBM Bob</span>
          </div>
        </div>
      </header>

      <div className="app-inner">

        {/* ── Summary metrics ── */}
        <div className="metrics-row">
          <div className="metric-chip">
            <div className="metric-chip-icon">📦</div>
            <span className={`metric-chip-num${lastRun && lastRun.recordsInserted === 0 ? ' muted' : ''}`}>
              {lastRun ? fmtNum(lastRun.recordsInserted) : '—'}
            </span>
            <span className="metric-chip-label">Records processed (last run)</span>
          </div>
          <div className="metric-chip">
            <div className="metric-chip-icon">⚠️</div>
            <span className={`metric-chip-num${lastRun && lastRun.recordsRejected > 0 ? ' danger' : ''}`}>
              {lastRun ? fmtNum(lastRun.recordsRejected) : '—'}
            </span>
            <span className="metric-chip-label">Rejected (last run)</span>
          </div>
          <div className="metric-chip">
            <div className="metric-chip-icon">✅</div>
            {latestReconStatus
              ? <><Badge status={latestReconStatus} /><span className="metric-chip-label" style={{ marginTop: 4 }}>Latest reconciliation</span></>
              : <><span className="metric-chip-num muted">—</span><span className="metric-chip-label">Latest reconciliation</span></>
            }
          </div>
        </div>

        {/* ── Connectivity + Job Controls ── */}
        <div className="two-col-grid">

          {/* Connectivity */}
          <div className="card" style={{ margin: 0 }}>
            <p className="section-heading">Database Connectivity</p>
            {healthError && <p style={{ color: '#f43f5e', fontSize: 13, margin: '0 0 10px' }}>{healthError}</p>}
            {health ? (
              <>
                <div className="db-row">
                  <span className={`db-dot ${health.oracle.status === 'UP' ? 'up' : 'down'}`} />
                  <span className="db-icon">🗄️</span>
                  <span className="db-name">Oracle</span>
                  <span className="db-detail">
                    {health.oracle.status === 'UP' ? (health.oracle.database ?? 'connected') : (health.oracle.error ?? 'down')}
                  </span>
                  <span><Badge status={health.oracle.status} /></span>
                </div>
                <div className="db-row">
                  <span className={`db-dot ${health.snowflake.status === 'UP' ? 'up' : 'down'}`} />
                  <span className="db-icon">❄️</span>
                  <span className="db-name">Snowflake</span>
                  <span className="db-detail">
                    {health.snowflake.status === 'UP' ? (health.snowflake.user ?? 'connected') : (health.snowflake.error ?? 'down')}
                  </span>
                  <span><Badge status={health.snowflake.status} /></span>
                </div>
              </>
            ) : !healthError ? (
              <p className="empty-state" style={{ padding: '8px 0' }}>Checking connections…</p>
            ) : null}
            <div style={{ marginTop: 16 }}>
              <button className="btn btn-ghost" onClick={loadHealth}>↻ Refresh</button>
            </div>
          </div>

          {/* Job Controls */}
          <div className="card" style={{ margin: 0 }}>
            <p className="section-heading">Job Controls</p>
            {launchError && (
              <div className="error-banner">
                {launchError.includes('409') ? '⚠ Conflict: ' : '✕ '}
                {launchError.replace(/HTTP 409: /, '').slice(0, 200)}
              </div>
            )}
            {confirmInitial ? (
              <div className="confirm-box">
                <p>⚡ Initial Load will process all Snowflake data. Continue?</p>
                <div className="confirm-box-actions">
                  <button className="btn btn-danger" onClick={() => launch('initial')} disabled={!!launching}>
                    {launching === 'initial' ? 'Launching…' : 'Yes, launch'}
                  </button>
                  <button className="btn btn-ghost" onClick={() => setConfirmInitial(false)}>Cancel</button>
                </div>
              </div>
            ) : (
              <div className="job-controls">
                <button className="btn btn-primary" onClick={() => setConfirmInitial(true)} disabled={hasRunning}>
                  ⚡ Initial Load
                </button>
                <button className="btn btn-primary" style={{ background: 'linear-gradient(135deg, #0891b2, #22d3ee)', color: '#000' }}
                  onClick={() => launch('daily')} disabled={hasRunning || !!launching}>
                  {launching === 'daily' ? 'Launching…' : '🔄 Daily Load'}
                </button>
                <button className="btn btn-primary" style={{ background: 'linear-gradient(135deg, #059669, #10b981)' }}
                  onClick={() => launch('monthly')} disabled={hasRunning || !!launching}>
                  {launching === 'monthly' ? 'Launching…' : '📊 Monthly Load'}
                </button>
              </div>
            )}
            {hasRunning && (
              <p className="poll-notice">
                <span className="poll-icon">↻</span> Job running — polling every 4s
              </p>
            )}
          </div>
        </div>

        {/* ── Latest run cards ── */}
        <p className="section-heading">Latest Job Status</p>
        <div className="run-cards">
          <RunCard label="Initial" run={summary.lastInitialRun} variant="initial" />
          <RunCard label="Daily"   run={summary.lastDailyRun}   variant="daily" />
          <RunCard label="Monthly" run={summary.lastMonthlyRun} variant="monthly" />
        </div>

        {/* ── Job History ── */}
        <div className="card">
          <p className="section-heading" style={{ marginBottom: 16 }}>Job History</p>
          {history.length === 0 ? (
            <p className="empty-state">No job runs yet.</p>
          ) : (
            <div className="table-wrap">
              <table>
                <thead>
                  <tr>
                    <th className="num">Run ID</th>
                    <th>Type</th>
                    <th>Status</th>
                    <th>Started</th>
                    <th>Ended</th>
                    <th className="num">Duration</th>
                    <th className="num">Read</th>
                    <th className="num">Processed</th>
                    <th className="num">Upd</th>
                    <th className="num">Rej</th>
                  </tr>
                </thead>
                <tbody>
                  {history.map(r => <HistoryRow key={r.runId} run={r} />)}
                </tbody>
              </table>
            </div>
          )}
        </div>

        {/* ── Reconciliation ── */}
        {hasRecon && (
          <div className="card">
            <p className="section-heading" style={{ marginBottom: 16 }}>Reconciliation</p>
            {[
              { label: 'Initial', items: summary.reconInitial },
              { label: 'Monthly', items: summary.reconMonthly },
            ].map(({ label, items }) => items && items.length > 0 ? (
              <div key={label} className="recon-section">
                <p className="recon-section-title">{label}</p>
                <div className="table-wrap">
                  <table>
                    <thead>
                      <tr>
                        <th>Entity</th>
                        <th>Metric</th>
                        <th className="num">Source</th>
                        <th className="num">Target</th>
                        <th className="num">Variance</th>
                        <th>Status</th>
                      </tr>
                    </thead>
                    <tbody>
                      {items.map((r, i) => (
                        <tr key={i}>
                          <td>{r.entityName}</td>
                          <td style={{ color: '#8b95ad' }}>{r.reconMetric}</td>
                          <td className="num">{r.sourceValue?.toLocaleString() ?? '—'}</td>
                          <td className="num">{r.targetValue?.toLocaleString() ?? '—'}</td>
                          <td className={`num${r.variance === 0 ? ' variance-zero' : ''}`}>
                            {r.variance?.toLocaleString() ?? '—'}
                          </td>
                          <td><Badge status={r.status} /></td>
                        </tr>
                      ))}
                    </tbody>
                  </table>
                </div>
              </div>
            ) : null)}
          </div>
        )}

      </div>

      <footer className="app-footer">Made with IBM Bob</footer>
    </div>
  );
}
