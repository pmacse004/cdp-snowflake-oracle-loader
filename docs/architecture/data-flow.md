# Data Flow

**Document ID:** ARCH-002  
**Project:** CDP Snowflake to Oracle Data Loader  
**Version:** 1.0  
**Status:** Phase 1 — Approved  
**Last Updated:** 2025 (Phase 1)

---

## 1. High-Level Data Flow

```mermaid
flowchart LR
    subgraph SF ["Snowflake (Source)"]
        SF_REF[REF schema\nCode tables]
        SF_RAW[RAW schema\nCustomer/Account/\nUsage tables]
    end

    subgraph APP ["Spring Boot Application"]
        direction TB
        TRIG([Trigger\nREST API or Scheduler])
        JOB[Spring Batch Job\nInitial / Daily / Monthly]
        READ[ItemReader\nSnowflake JDBC\nPaginated query]
        PROC[ItemProcessor\nTransform + Validate\nICA rules]
        WRITE[ItemWriter\nOracle JDBC\nMERGE statement]
        ERR_W[ErrorWriter\nOracle JDBC\nETL_RECORD_ERROR]
        RECON[ReconciliationStep\nCompare counts & totals]
        WM[WatermarkManager\nETL_WATERMARK]
    end

    subgraph ORA ["Oracle (Target)"]
        ORA_APP[CDP_APP schema\nBusiness tables]
        ORA_CTL[CDP_CTL schema\nETL_JOB_RUN\nETL_WATERMARK\nETL_RECORD_ERROR\nETL_RECONCILIATION]
        ORA_BATCH[CDP_BATCH schema\nSpring Batch JobRepository]
    end

    subgraph UI ["React Dashboard"]
        DASH[Operations Dashboard\n:5173 dev / :8080 prod]
    end

    DASH -->|REST API calls| TRIG
    TRIG --> JOB
    JOB --> READ
    READ -->|JDBC read| SF_REF
    READ -->|JDBC read| SF_RAW
    READ --> PROC
    PROC -->|valid records| WRITE
    PROC -->|invalid records| ERR_W
    WRITE -->|MERGE| ORA_APP
    ERR_W -->|INSERT| ORA_CTL
    JOB --> WM
    WM -->|read/write watermark| ORA_CTL
    JOB --> RECON
    RECON -->|query counts| ORA_APP
    RECON -->|query counts| SF_RAW
    RECON -->|write result| ORA_CTL
    JOB -->|Job status| ORA_BATCH
    JOB -->|Job run record| ORA_CTL
    DASH -->|GET job runs, errors, recon| ORA_CTL
```

---

## 2. Initial Load Data Flow

```mermaid
sequenceDiagram
    participant U as User/Scheduler
    participant API as REST API
    participant JOB as Spring Batch InitialLoadJob
    participant SF as Snowflake
    participant ORA as Oracle

    U->>API: POST /api/v1/jobs/initial-load
    API->>JOB: launch(JobParameters)
    JOB->>ORA: INSERT ETL_JOB_RUN (status=RUNNING)
    
    loop For each entity in dependency order
        JOB->>SF: SELECT * FROM <entity_table> ORDER BY UPDATED_AT, SOURCE_ID
        SF-->>JOB: page of records (chunk=500)
        JOB->>JOB: Transform + Validate (ICA rules)
        alt Valid records
            JOB->>ORA: MERGE INTO <target_table> (upsert on SOURCE_ID)
        else Invalid records
            JOB->>ORA: INSERT ETL_RECORD_ERROR
        end
        JOB->>ORA: UPDATE ETL_WATERMARK (advance after commit)
    end
    
    JOB->>SF: SELECT COUNT(*), SUM(KWH)... per entity
    JOB->>ORA: SELECT COUNT(*), SUM(KWH)... per entity
    JOB->>ORA: INSERT ETL_RECONCILIATION
    JOB->>ORA: UPDATE ETL_JOB_RUN (status=COMPLETED, counts, end_time)
    API-->>U: 200 OK {runId, status}
```

---

## 3. Daily Incremental Load Data Flow

```mermaid
sequenceDiagram
    participant SCHED as Scheduler
    participant JOB as DailyIncrementalJob
    participant SF as Snowflake
    participant ORA as Oracle

    SCHED->>JOB: trigger (cron)
    JOB->>ORA: SELECT LAST_WATERMARK_TS, LAST_WATERMARK_ID FROM ETL_WATERMARK WHERE ENTITY=X
    JOB->>ORA: INSERT ETL_JOB_RUN (status=RUNNING, prev_watermark)
    
    loop For each entity
        JOB->>SF: SELECT * FROM <entity_table>\nWHERE (UPDATED_AT > :lastTs)\nOR (UPDATED_AT = :lastTs AND SOURCE_ID > :lastId)\nORDER BY UPDATED_AT, SOURCE_ID
        SF-->>JOB: changed records
        JOB->>JOB: Transform + Validate
        alt Valid
            JOB->>ORA: MERGE INTO <target_table>
        else Invalid
            JOB->>ORA: INSERT ETL_RECORD_ERROR
        end
        Note over JOB,ORA: COMMIT chunk
        JOB->>ORA: UPDATE ETL_WATERMARK (new max seen in this chunk)
    end
    
    JOB->>ORA: INSERT ETL_RECONCILIATION
    JOB->>ORA: UPDATE ETL_JOB_RUN (status=COMPLETED)
```

---

## 4. Monthly Usage Load Data Flow

```mermaid
sequenceDiagram
    participant U as User/Scheduler
    participant JOB as MonthlyUsageJob
    participant SF as Snowflake
    participant ORA as Oracle

    U->>JOB: trigger(billingMonth=YYYY-MM)
    JOB->>ORA: INSERT ETL_JOB_RUN
    JOB->>SF: SELECT * FROM MONTHLY_USAGE WHERE BILLING_MONTH = :month ORDER BY UPDATED_AT, ENERGY_ACCOUNT_ID
    SF-->>JOB: usage records

    loop For each usage record
        JOB->>ORA: SELECT UPDATED_AT FROM CDP_USAGE WHERE ENERGY_ACCOUNT_ID=x AND BILLING_MONTH=m
        alt Not exists
            JOB->>ORA: INSERT
        else Incoming is newer
            JOB->>ORA: UPDATE (correction)
        else Incoming is same or older
            Note over JOB: SKIP (count as SKIPPED)
        end
    end
    
    JOB->>SF: SUM(KWH_USAGE, PEAK_DEMAND_KW, TOTAL_BILLED_AMOUNT) for month
    JOB->>ORA: SUM same columns
    JOB->>ORA: INSERT ETL_RECONCILIATION
    JOB->>ORA: UPDATE ETL_JOB_RUN (COMPLETED)
```

---

## 5. Error Record Flow

```mermaid
flowchart TD
    PROC[ItemProcessor] -->|throws validation exception| SKIP[Spring Batch SkipPolicy]
    SKIP -->|record skip count| CNTR[Error Counter]
    SKIP --> ERR_WRITE[Direct JDBC write\nETL_RECORD_ERROR]
    CNTR -->|count > threshold * chunk_size| FAIL[FAIL step]
    CNTR -->|count <= threshold| CONT[Continue processing]
    ERR_WRITE --> DB[(Oracle\nETL_RECORD_ERROR)]
```

**Fields written to `ETL_RECORD_ERROR`:**

| Field | Value |
|-------|-------|
| `JOB_NAME` | e.g., `DailyIncrementalJob` |
| `RUN_ID` | Spring Batch `JobExecution` ID |
| `SOURCE_ENTITY` | e.g., `CUSTOMER` |
| `SOURCE_RECORD_ID` | Source primary key (non-PII) |
| `ERROR_CODE` | Structured code, e.g., `VAL-EMAIL-001` |
| `ERROR_MESSAGE` | Human-readable description |
| `PAYLOAD_EXCERPT` | Non-PII fields only, truncated at 500 chars |
| `OCCURRED_AT` | UTC timestamp |

---

## 6. Watermark Advancement Protocol

```mermaid
stateDiagram-v2
    [*] --> ReadWatermark: Job starts
    ReadWatermark --> Extract: Query Snowflake\nwith watermark filter
    Extract --> Process: Chunk of records
    Process --> Write: Valid records
    Write --> Commit: Oracle COMMIT
    Commit --> AdvanceWatermark: UPDATE ETL_WATERMARK\n(max of chunk)
    AdvanceWatermark --> Extract: More records?
    Extract --> [*]: No more records
    Write --> ErrorTable: Invalid record
    Commit --> FAIL: Commit fails
    FAIL --> [*]: Watermark NOT advanced
```

---

## 7. Reconciliation Flow

After each load job completes, a reconciliation step:

1. Queries Snowflake for source counts and aggregates per entity
2. Queries Oracle `CDP_APP` for target counts and aggregates
3. Computes differences
4. Writes one `ETL_RECONCILIATION` row per entity with:
   - Source count, target count, difference
   - Source KWH sum, target KWH sum (monthly usage only)
   - Source billed total, target billed total (monthly usage only)
   - Pass/fail indicator (`RECON_STATUS`)
5. Updates `ETL_JOB_RUN.RECON_STATUS`

Reconciliation tolerance: ±0 records (exact match required unless errors explain the difference).
