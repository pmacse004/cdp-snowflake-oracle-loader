# CDP Snowflake-to-Oracle Loader

ETL pipeline: reads synthetic US electric utility data from Snowflake and loads it into Oracle using Spring Batch. Includes a React dashboard for monitoring and triggering jobs.

---

## Quick Start

### 1. Prerequisites

| Requirement | Version |
|-------------|---------|
| Java | 17 |
| Maven | 3.8+ |
| Node.js | 18+ |
| Oracle 23ai Free | 23.7 running on `localhost:1521/FREEPDB1` |
| Snowflake account | `LJPNAFI-RW79936` with provisioned service user |

Flyway migrations V001–V004 must already be applied to Oracle (CDP_LOADER schema).

---

### 2. Set Environment Variables

Copy the template and fill in your values:

```powershell
Copy-Item scripts\set-local-env.template.ps1 scripts\set-local-env.ps1
# Edit scripts\set-local-env.ps1 with your Oracle password and Snowflake key path
. .\scripts\set-local-env.ps1
```

Required variables:

```
CDP_ORACLE_JDBC_URL            = jdbc:oracle:thin:@//localhost:1521/FREEPDB1
CDP_ORACLE_USERNAME            = CDP_LOADER
CDP_ORACLE_PASSWORD            = <your Oracle password>

CDP_SNOWFLAKE_ACCOUNT          = LJPNAFI-RW79936
CDP_SNOWFLAKE_USER             = SVC_CDP_LOADER
CDP_SNOWFLAKE_ROLE             = CDP_LOADER_ROLE
CDP_SNOWFLAKE_WAREHOUSE        = CDP_LOADER_WH
CDP_SNOWFLAKE_DATABASE         = CDP_UTIL_DB
CDP_SNOWFLAKE_PRIVATE_KEY_PATH = C:\Users\AlthafPM\.cdp-loader\keys\snowflake_rsa_key.p8
```

---

### 3. Build the Backend

```powershell
mvn clean package -DskipTests
```

JAR output: `cdp-loader-api/target/cdp-loader-api-0.1.0-SNAPSHOT.jar`

---

### 4. Run Unit Tests (No Live Credentials Required)

```powershell
mvn test -pl cdp-loader-core,cdp-loader-api -DskipITs
```

Expected: **44 tests pass, 0 failures**.

---

### 5. Start the Backend

```powershell
. .\scripts\set-local-env.ps1     # set environment variables
.\scripts\start-backend.ps1       # starts on port 8080
```

Or manually:
```powershell
java -jar cdp-loader-api\target\cdp-loader-api-0.1.0-SNAPSHOT.jar
```

Endpoints:
- API: `http://localhost:8080`
- Swagger UI: `http://localhost:8080/swagger-ui.html`
- Health: `http://localhost:8080/api/health/databases`

---

### 6. Start the Frontend Dashboard

```powershell
.\scripts\start-frontend.ps1      # starts on port 5173
```

Or manually:
```powershell
cd cdp-loader-ui
npm install
npm run dev
```

Dashboard: `http://localhost:5173`

---

### 7. Verify Connectivity

```powershell
# With backend running:
curl http://localhost:8080/api/health/databases
```

Expected:
```json
{
  "oracle":    { "status": "UP",   "database": "Oracle 23ai" },
  "snowflake": { "status": "UP",   "user": "SVC_CDP_LOADER", "role": "CDP_LOADER_ROLE" }
}
```

---

## End-to-End Demo Sequence

### Step 1 — Initial Load

Loads all current Snowflake data into Oracle. Parents before children.

```bash
POST http://localhost:8080/api/jobs/initial
```

Response:
```json
{ "runId": 1, "jobName": "INITIAL_LOAD_JOB", "status": "STARTED", "submittedAt": "..." }
```

Monitor progress:
```bash
GET http://localhost:8080/api/jobs/1
GET http://localhost:8080/api/jobs/1/errors
```

Expected after completion:
- `TGT_CUSTOMER`: ~500+ rows
- `TGT_ENERGY_ACCOUNT`: ~500+ rows
- `TGT_MONTHLY_USAGE`: ~1,864 rows (two June cohorts)
- `ETL_RECORD_ERROR`: 2 rows — `USG-INVK-*` (negative KW) and `USG-INVD-*` (bill end before start)

---

### Step 2 — Simulate Daily Changes

In Snowflake (run as CDP_ADMIN_ROLE):
```sql
-- Run infra/snowflake/12-simulate-demo-daily-run.sql
```

This inserts:
- 5 new customers (CUST-D12-001..005)
- 5 new energy accounts (EA-D12-001..005)
- Updates 5 existing customer STATUS_REASON fields

---

### Step 3 — Daily Incremental Load

```bash
POST http://localhost:8080/api/jobs/daily
```

Expected:
- Only new/changed records since the initial load watermark
- ~10 new rows loaded (5 new customers + 5 accounts)
- Watermarks advance to the new maximum RECORD_EFFECTIVE_TS

---

### Step 4 — Simulate Monthly Usage Changes

In Snowflake (run as CDP_ADMIN_ROLE):
```sql
-- Run infra/snowflake/13-simulate-demo-monthly-run.sql
```

This inserts 10 new July 2024 usage rows (USG-D13-EA000001..010).

---

### Step 5 — Monthly Usage Load

```bash
POST http://localhost:8080/api/jobs/monthly
```

Expected:
- 10 new TGT_MONTHLY_USAGE rows for billing month 2024-07
- ETL_RECONCILIATION populated with source/target counts
- Monthly watermark advances

---

### Step 6 — View in Dashboard

Open `http://localhost:5173` to see:
- Database connectivity indicators
- All three job run histories
- Read/insert/update/reject counts
- Reconciliation summary

---

## API Reference

| Method | Endpoint | Description |
|--------|----------|-------------|
| POST | `/api/jobs/initial` | Launch initial load (202 or 409) |
| POST | `/api/jobs/daily` | Launch daily incremental load |
| POST | `/api/jobs/monthly` | Launch monthly usage load |
| GET | `/api/jobs` | Paginated job history |
| GET | `/api/jobs/{runId}` | Single job run details |
| GET | `/api/jobs/{runId}/errors` | Rejection records for a run |
| GET | `/api/health/databases` | Oracle + Snowflake health check |
| GET | `/api/dashboard/summary` | Overview panel data |
| GET | `/api/reconciliation/latest` | Latest reconciliation results |

---

## Known Warnings and Limitations

| Category | Details |
|----------|---------|
| **1,864 June rows** | Two 932-row cohorts in Snowflake — treated as normal demo data, not errors |
| **4 meter-pair warnings** | Synthetic data has 4 accounts with two potential meter candidates — view selects most recent, no data loss |
| **2 intentional rejection records** | `USG-INVK-*` (negative KW) and `USG-INVD-*` (bill end before start) — always rejected to ETL_RECORD_ERROR |
| **ETL_JOB_RUN status `STARTED`** | The schema CHECK constraint uses STARTED (not RUNNING). Docs use STARTING/RUNNING/COMPLETED — the actual value stored is STARTED/COMPLETED/FAILED. |
| **Watermark DAILY vs INITIAL** | Watermark JOB_TYPE CHECK constraint only allows INITIAL, DAILY, MONTHLY. Matches implementation. |
| **No BATCH_* recreation** | `spring.batch.jdbc.initialize-schema=never` — relies on Flyway V001 already applied |
| **Hibernate ddl-auto=none** | JPA is present for Spring Batch; no entity auto-schema generation |

---

## ICA / MCP Context

See [`docs/ica-mcp-setup-guide.md`](docs/ica-mcp-setup-guide.md) for instructions to load ICA context into IBM Bob via MCP for design-time retrieval of mapping rules and transformation logic.

See [`docs/ica-mcp-validation.md`](docs/ica-mcp-validation.md) for the full ICA rule → Java file → test traceability matrix.

**The running application has no ICA or MCP dependency at runtime.**

---

## Tests Requiring Manual Execution (MANUAL/PENDING)

The following tests require live Oracle + Snowflake credentials and cannot run in automated CI:

1. **Live connectivity** — start backend, `GET /api/health/databases`, confirm both UP
2. **Initial load end-to-end** — `POST /api/jobs/initial`, verify TGT_CUSTOMER + TGT_MONTHLY_USAGE counts
3. **Intentional rejection** — confirm `USG-INVK-*` and `USG-INVD-*` in ETL_RECORD_ERROR
4. **Daily incremental** — run script 12, `POST /api/jobs/daily`, confirm only delta rows loaded
5. **Monthly usage load** — run script 13, `POST /api/jobs/monthly`, confirm July rows in TGT_MONTHLY_USAGE
6. **Watermark advancement** — confirm ETL_WATERMARK timestamps advance correctly
7. **Job concurrency** — launch two jobs simultaneously, confirm 409 on second
8. **Idempotency** — re-run initial load, confirm no duplicates
9. **Flyway validate** — `mvn flyway:validate` against live Oracle confirms V001–V004 unchanged
10. **Frontend live test** — open dashboard, trigger all three jobs, observe polling and status updates

---

## Project Structure

```
├── cdp-loader-core/          Domain models, validators, exceptions (no Spring)
├── cdp-loader-batch/         Spring Batch jobs, readers, processors, writers, repositories
├── cdp-loader-api/           Spring Boot app, REST controllers, application.yml
├── cdp-loader-ui/            React/TypeScript dashboard (Vite)
├── infra/
│   ├── oracle/               DBA bootstrap SQL
│   └── snowflake/            Provisioning scripts 01-13
├── docs/
│   ├── ica-context/          ICA mapping documents + importable context bundle
│   ├── ica-mcp-setup-guide.md
│   └── ica-mcp-validation.md
└── scripts/                  PowerShell run/test scripts
```

---

*Made with IBM Bob*
