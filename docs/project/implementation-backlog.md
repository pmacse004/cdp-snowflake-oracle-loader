# Implementation Backlog — Phase-by-Phase with Acceptance Criteria

**Document ID:** PROJ-002  
**Project:** CDP Snowflake to Oracle Data Loader  
**Version:** 1.0  
**Status:** Phase 1 — Approved  
**Last Updated:** 2025 (Phase 1)

---

## How to Read This Backlog

Each item has:
- **ID** — stable backlog item ID (format: `P{phase}-{nn}`)
- **Title** — short description
- **Acceptance Criteria** — measurable conditions for "done"
- **Phase** — delivery phase
- **Priority** — must-have (M) or should-have (S) or nice-to-have (N)

---

## Phase 2 — Infrastructure & Schema Provisioning

| ID | Title | Priority | Acceptance Criteria |
|----|-------|----------|---------------------|
| P2-01 | Docker Compose file for Oracle Database Free 23c | M | `docker compose up -d oracle` starts Oracle; `docker ps` shows healthy container; port 1521 accessible on localhost |
| P2-02 | Snowflake provisioning script: warehouse, database, schemas | M | `CDP_LOADER_WH` warehouse created; `CDP_DW` database with `RAW`, `CLEAN`, `REF` schemas created via SnowSQL or Snowflake UI |
| P2-03 | Snowflake provisioning script: role and service user | M | `CDP_LOADER_ROLE` and `SVC_CDP_LOADER` created; service user has no password; public key registered |
| P2-04 | Snowflake provisioning script: privilege grants | M | `CDP_LOADER_ROLE` can SELECT on all RAW, CLEAN, REF tables; cannot INSERT/UPDATE/DELETE |
| P2-05 | RSA key-pair generation PowerShell script | M | Script generates 2048-bit RSA key; private key saved as `.p8`; public key displayed for Snowflake registration; no secrets in source control |
| P2-06 | Spring Boot Maven project scaffold (pom.xml, main class) | M | `./mvnw clean package` produces a fat JAR without errors; `java -jar` starts the application on port 8080 |
| P2-07 | `application.yml` with all configuration externalised | M | All credentials reference `${ENV_VAR}` expressions; no hard-coded values; app fails fast with clear message if required env vars missing |
| P2-08 | `.env.template` with all required variables documented | M | File contains all variable names with placeholder values and comments; no real values |
| P2-09 | `.gitignore` covering secrets, IDE files, build output | M | `.env`, `*.p8`, `*.pem`, `target/`, `node_modules/`, `*.key` excluded |
| P2-10 | Oracle user and schema creation script | M | `CDP_LOADER_USER`, `CDP_APP`, `CDP_CTL`, `CDP_BATCH` schemas created; user granted appropriate privileges |
| P2-11 | Flyway migration V1: CDP_APP business tables | M | `./mvnw flyway:migrate` creates all 8 business tables with correct DDL, sequences and unique constraints |
| P2-12 | Flyway migration V2: CDP_CTL control tables | M | ETL_WATERMARK, ETL_JOB_RUN, ETL_RECORD_ERROR, ETL_RECONCILIATION tables created |
| P2-13 | Flyway migration V3: indexes | M | All documented indexes created; EXPLAIN PLAN on watermark filter query uses index |
| P2-14 | Flyway migration V4: seed ETL_WATERMARK rows | M | 16 seed rows (8 entities × 2 job types) inserted with epoch-zero watermarks |
| P2-15 | PowerShell `migrate.ps1` helper script | S | Script runs Flyway migrations against local Oracle; shows success/failure |
| P2-16 | Spring Actuator `/actuator/health` returns UP | M | `GET /actuator/health` returns `{"status":"UP"}` when Oracle is reachable |

---

## Phase 3 — Synthetic Data Generation

| ID | Title | Priority | Acceptance Criteria |
|----|-------|----------|---------------------|
| P3-01 | Snowflake seed script: REF.CODE_VALUE (~200 rows) | M | All required code domains and values inserted; account status translation values present |
| P3-02 | Snowflake data generator: ~10,000 CUSTOMER rows | M | 10,000± rows in RAW.CUSTOMER; mix of RESIDENTIAL/COMMERCIAL/INDUSTRIAL; realistic name variety; no real PII |
| P3-03 | Snowflake data generator: CUSTOMER_CONTACT rows | M | ~1.2 per customer; email in mixed case; phone in various formats; valid and invalid records mixed for testing |
| P3-04 | Snowflake data generator: ENERGY_ACCOUNT rows | M | ~1.1 per customer; mix of statuses |
| P3-05 | Snowflake data generator: BILLING_ACCOUNT, SERVICE_PREMISE, METER rows | M | FK relationships correct; at least 500 inactive/closed accounts; at least 50 soft-deleted records |
| P3-06 | Snowflake data generator: MONTHLY_USAGE rows (12 months) | M | ~1,000 per billing month × 12 months ≈ 12,000 rows; realistic KWH (50–2000), energy charge and tax amounts; non-negative values; some correction records |
| P3-07 | Daily change simulation script | S | Script inserts/updates ~1,000 records across entities with a future UPDATED_AT to simulate a day's changes |
| P3-08 | Data quality verification queries | M | Snowflake SQL queries confirm referential integrity, count ratios and absence of NULL in mandatory columns |

---

## Phase 4 — Core ETL Pipeline (Spring Batch)

| ID | Title | Priority | Acceptance Criteria |
|----|-------|----------|---------------------|
| P4-01 | Snowflake JDBC DataSource bean | M | Application connects to Snowflake using key-pair auth; `SnowflakeHealthIndicator` returns UP |
| P4-02 | Oracle JDBC DataSource bean | M | Application connects to Oracle; `OracleHealthIndicator` returns UP |
| P4-03 | Spring Batch JobRepository in Oracle CDP_BATCH schema | M | `BATCH_JOB_INSTANCE`, `BATCH_JOB_EXECUTION`, `BATCH_STEP_EXECUTION` tables created and populated by Spring Boot auto-config |
| P4-04 | Transformation classes (all TR-* rules) | M | Unit tests pass for all transformer classes (TR-01 through TR-DEC-02); 100% branch coverage on transformation logic |
| P4-05 | Validation classes (all VR-* rules) | M | Unit tests pass for all validator classes; edge cases covered (null, empty, boundary values) |
| P4-06 | FK Resolution Service and Cache | M | `FkResolutionService.resolve()` returns correct target ID for known source IDs; throws `FkResolutionException` for unknown IDs |
| P4-07 | Watermark Service | M | `WatermarkService.readWatermark()` returns epoch zero for uninitialised entity; `advanceWatermark()` updates ETL_WATERMARK within the same transaction |
| P4-08 | InitialLoadJob — all 8 entities | M | `POST /api/v1/jobs/initial-load` loads all entities; all ~10,000 customers in Oracle; all reconciliation rows PASS |
| P4-09 | DailyIncrementalJob — all entity types | M | Daily load detects and loads only changed records since last watermark; re-run produces no extra rows |
| P4-10 | MonthlyUsageJob — dedup and correction | M | Monthly load for a billing month: new records inserted; corrections update existing; stale records skipped |
| P4-11 | Error handling: SkipPolicy and ETL_RECORD_ERROR | M | Invalid record rejected with correct error code; valid records in same chunk committed; ETL_RECORD_ERROR row written with no PII |
| P4-12 | Fatal error threshold enforcement | M | When rejected count > threshold%, step fails; ETL_JOB_RUN status = FAILED; watermark unchanged |
| P4-13 | ETL_JOB_RUN lifecycle management | M | RUN_ID created on job start; counts (read/inserted/updated/skipped/rejected) accurate; end_time and status set on completion |
| P4-14 | Reconciliation step (all 3 job types) | M | ETL_RECONCILIATION row written after each job; RECON_STATUS = PASS for clean loads |
| P4-15 | Scheduler (daily + monthly cron) | S | Cron triggers daily load at configured time; scheduler prevents concurrent runs; status visible via `/api/v1/scheduler` |
| P4-16 | Soft delete handling | M | Customer with DELETED_FLAG=Y loads as IS_ACTIVE=0; DELETED_AT and DELETION_REASON set; no physical delete |
| P4-17 | Re-run / restart test | M | Kill application mid-job; restart; job resumes from last committed watermark; no duplicate rows; all data correct |

---

## Phase 5 — REST API and Dashboard

| ID | Title | Priority | Acceptance Criteria |
|----|-------|----------|---------------------|
| P5-01 | `JobController` — trigger and status endpoints | M | All FR-API-01 to FR-API-05 endpoints return correct JSON; HTTP 409 if job already running |
| P5-02 | `WatermarkController` | M | FR-API-06 returns current watermarks for all 8 entities |
| P5-03 | `ErrorController` with pagination | M | FR-API-07 returns paginated error records; filter by entity and date range |
| P5-04 | `ReconciliationController` | M | FR-API-08/09 returns reconciliation records per run |
| P5-05 | `HealthController` (augments Actuator) | M | FR-API-10 returns application, Snowflake and Oracle health in single response |
| P5-06 | `MappingController` | S | FR-API-11 returns mapping catalogue from YAML |
| P5-07 | `SchedulerController` | S | FR-API-12/13/14 expose scheduler status; pause/resume work |
| P5-08 | Report download endpoint | S | FR-API-15 returns CSV report for a run with reconciliation details |
| P5-09 | Spring Security (HTTP Basic for dev) | M | All endpoints except /actuator/health require auth; 401 on missing credentials |
| P5-10 | OpenAPI / Swagger documentation | S | `GET /swagger-ui.html` shows all endpoints with descriptions |
| P5-11 | React project scaffold (Vite + TypeScript) | M | `npm run dev` starts on port 5173; `npm run build` produces dist/ |
| P5-12 | Typed Axios API client | M | All API calls typed with TypeScript interfaces |
| P5-13 | Job Control Panel component | M | Trigger initial/daily/monthly jobs from dashboard; shows running spinner and success/failure |
| P5-14 | Job Run History table | M | Shows last 20 runs with status, counts, duration |
| P5-15 | Watermark display component | M | Shows current watermarks for all entities |
| P5-16 | KPI cards (customer/account counts) | M | Shows active/inactive customers and energy accounts |
| P5-17 | Record count chart (Recharts) | S | Bar chart: read vs inserted vs updated vs rejected per run |
| P5-18 | Reconciliation summary | M | Source vs target counts; KWH/KW/billed totals; PASS/FAIL badges |
| P5-19 | Error records table with pagination | M | Shows last 100 errors; expandable error detail (no PII) |
| P5-20 | Health indicators (Snowflake + Oracle) | M | Green/red badges; tooltip with latency |
| P5-21 | Scheduler panel | S | Shows cron, last/next run, enabled/disabled; pause/resume buttons |
| P5-22 | Mapping catalogue viewer | S | Searchable table of CM-* mappings with transform rule and example |
| P5-23 | Report download button | S | Downloads current run reconciliation as CSV |
| P5-24 | React build served by Spring Boot | M | `npm run build`; copy to `src/main/resources/static`; `GET /` returns dashboard |

---

## Phase 6 — Testing & Quality

| ID | Title | Priority | Acceptance Criteria |
|----|-------|----------|---------------------|
| P6-01 | Unit test coverage ≥ 80% for transformation/validation classes | M | JaCoCo report shows ≥ 80% line and branch coverage on `transform/` and `validation/` packages |
| P6-02 | Spring Batch integration tests (H2 in-memory JobRepository) | M | InitialLoadJobTest, DailyLoadJobTest, MonthlyUsageJobTest pass without a real Oracle instance |
| P6-03 | Oracle integration tests (real Oracle instance) | S | `mvn test -Pintegration-oracle` runs against local Oracle; all tests pass |
| P6-04 | MockMvc REST API tests | M | All controller endpoints have test coverage; 200/400/409 response codes verified |
| P6-05 | Transformation edge-case tests | M | Tests cover: null inputs, empty strings, boundary dates, maximum/minimum numbers, special-character names |
| P6-06 | Watermark boundary tests | M | Test: records exactly AT watermark timestamp; records with same timestamp and different IDs; epoch-zero start |
| P6-07 | Correction / deduplication tests | M | Test: insert → same key + newer UPDATED_AT (correction); same key + older UPDATED_AT (skip) |
| P6-08 | Fatal threshold test | M | Set threshold to 10%; inject 11% invalid records; verify step FAILED; watermark unchanged; valid records committed |
| P6-09 | Restart test | M | Start job; kill mid-step; restart; verify correct final state; no duplicates |
| P6-10 | Soft delete test | M | Source record with DELETED_FLAG=Y loaded as IS_ACTIVE=0 with DELETED_AT and DELETION_REASON |
| P6-11 | Reconciliation test | M | After load: source count = target count + rejected count; KWH/billed totals match within tolerance |
| P6-12 | Performance test (10,000 customers) | M | Initial load of 10,000 customers + all child records completes in ≤ 20 minutes; daily load of 1,000 changes in ≤ 5 minutes |
| P6-13 | React component tests (Vitest + Testing Library) | S | JobControlPanel, ReconciliationSummary, ErrorTable render correctly with mock data |
| P6-14 | End-to-end test: initial load flow (Playwright) | S | Browser navigates to dashboard; triggers initial load; waits for COMPLETED status; verifies KPI counts |
| P6-15 | End-to-end test: daily load flow | S | Triggers daily load; verifies at least 1 inserted/updated record |
| P6-16 | Automated test reports | M | Surefire XML + HTML reports generated on `mvn test`; JaCoCo coverage report at `target/site/jacoco` |

---

## Phase 7 — Hardening & Operationalisation

| ID | Title | Priority | Acceptance Criteria |
|----|-------|----------|---------------------|
| P7-01 | Open Liberty `server.xml` and packaging documentation | S | `mvn -Pliberty package` produces WAR; `server.xml` documented; deployment instructions in docs/ |
| P7-02 | Pre-commit secret-scanning PowerShell hook | M | Script detects common patterns (password=, key=, -----BEGIN) before git commit; CI pipeline check |
| P7-03 | Security review of all API responses | M | No schema details, stack traces or PII in any API error response |
| P7-04 | Full demo script and walkthrough | M | Written script covering all dashboard views; presenter can demo without live debugging |
| P7-05 | PowerShell end-to-end setup script | S | Single `setup.ps1` starts Oracle, applies Flyway, generates data, starts app — for fresh demo environment |
| P7-06 | Performance tuning documentation | S | Document chunk size, fetch size and heap recommendations for demo and scale-up scenarios |
| P7-07 | `BILLING_ACCOUNT_NUMBER` PII review | M | Decision documented: treat as PII-equivalent in production; current demo applies same safeguards |
| P7-08 | Dashboard production build and CORS configuration | M | Frontend built and served by Spring Boot; CORS restricted to production origin |

---

## Milestone Summary

| Milestone | Completion Criteria |
|-----------|---------------------|
| Phase 1 complete | All 33 documents written; architecture reviewed and approved by stakeholder |
| Phase 2 complete | Oracle runs in Docker; Snowflake provisioned; Spring Boot starts and connects to both databases; Actuator health shows UP |
| Phase 3 complete | ~10,000 synthetic customers in Snowflake with all child records; daily change script produces ~1,000 changes |
| Phase 4 complete | All 3 job types run successfully; reconciliation PASS; restart works; error isolation works |
| Phase 5 complete | All REST endpoints pass tests; dashboard shows job status, watermarks, errors and reconciliation |
| Phase 6 complete | ≥ 80% test coverage; performance test passes; all edge cases covered |
| Phase 7 complete | Demo-ready; Open Liberty documented; security hardened; demo script written |
