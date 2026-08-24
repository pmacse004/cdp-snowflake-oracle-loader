# Solution Architecture

**Document ID:** ARCH-001  
**Project:** CDP Snowflake to Oracle Data Loader  
**Version:** 1.0  
**Status:** Phase 1 — Approved  
**Last Updated:** 2025 (Phase 1)

---

## 1. Architectural Overview

The CDP Snowflake to Oracle Data Loader is a **Spring Boot / Spring Batch** application that extracts synthetic US electric utility customer data from Snowflake and loads it into Oracle Database. An operations dashboard (React / TypeScript) communicates exclusively with a REST API layer; it never connects to either database directly.

```mermaid
graph TD
    subgraph "Source System"
        SF[(Snowflake\nCDP_DW database\nAzure Central India)]
    end

    subgraph "Application Server (localhost / Open Liberty)"
        API[Spring Boot REST API\n:8080]
        BATCH[Spring Batch Engine\nInitial / Daily / Monthly Jobs]
        SCHED[Quartz / Spring Scheduler]
        ACT[Spring Actuator\n/actuator/*]
        FLY[Flyway Migrations]
    end

    subgraph "Target System"
        ORA[(Oracle DB Free 23c\nDocker :1521)]
        ORA_CDP[CDP_APP schema\nBusiness tables]
        ORA_CTL[CDP_CTL schema\nControl tables]
        ORA_BATCH[CDP_BATCH schema\nSpring Batch tables]
    end

    subgraph "Frontend"
        UI[React + Vite\n:5173 dev / :8080 prod]
    end

    subgraph "Governance (Phase 1 docs only)"
        ICA[IBM Consulting Advantage\nContext Studio]
    end

    UI --> API
    API --> BATCH
    API --> ORA_CTL
    SCHED --> BATCH
    BATCH -->|JDBC read| SF
    BATCH -->|MERGE write| ORA_CDP
    BATCH -->|control| ORA_CTL
    BATCH -->|JobRepository| ORA_BATCH
    FLY -->|DDL migrations| ORA
    ACT --> ORA
    ACT --> SF
    ICA -.->|MCP context\n(governance only)| API
```

> **Note:** ICA connectivity via MCP is a future integration. The running application does not connect to ICA.

---

## 2. Component Descriptions

### 2.1 Spring Boot Application

The single deployable unit. Packages the REST API, batch engine, scheduler and Flyway in one fat JAR.

| Component | Technology | Responsibility |
|-----------|-----------|----------------|
| REST Controllers | Spring MVC | Job triggers, status queries, watermark, errors, reconciliation, health, mappings |
| Spring Batch Jobs | Spring Batch 5.x | Initial load, daily incremental, monthly usage pipelines |
| Item Readers | Spring Batch + Snowflake JDBC | Paginated extraction from Snowflake source tables |
| Item Processors | Java 17 | Transformation, validation, enrichment per ICA rules |
| Item Writers | Spring Batch + Oracle JDBC | Oracle MERGE via `OracleItemWriter` / `JdbcBatchItemWriter` |
| Scheduler | Spring `@Scheduled` / Quartz | Cron-triggered daily and monthly jobs |
| Flyway | Flyway 10.x | Version-controlled Oracle schema migrations |
| Actuator | Spring Boot Actuator | Health, info, metrics endpoints |
| Health Indicators | Custom | Snowflake and Oracle connectivity checks |

### 2.2 Snowflake Source

- Account: `LJPNAFI-RW79936` (locator `BM00315`, Azure Central India)
- Database: `CDP_DW` (created in Phase 2)
- Schemas: `RAW` (ingestion tables), `CLEAN` (validated views), `REF` (reference data)
- Warehouse: `CDP_LOADER_WH` (X-Small, dedicated to ETL)
- Service user: `SVC_CDP_LOADER` (key-pair auth, read-only on source objects)

### 2.3 Oracle Target (Docker)

- Image: `container-registry.oracle.com/database/free:latest` (23c)
- Exposed port: `1521`
- Schemas:
  - `CDP_APP` — business target tables (customers, accounts, premises, etc.)
  - `CDP_CTL` — ETL control tables (watermarks, job runs, errors, reconciliation)
  - `CDP_BATCH` — Spring Batch `JobRepository` tables

### 2.4 React Frontend

- Build tool: Vite 5
- Language: TypeScript 5
- Component library: Shadcn/ui (Radix primitives)
- Charts: Recharts
- HTTP client: Axios with typed API client
- Served by Spring Boot in production (static build from `/frontend/dist`)

---

## 3. Deployment Topology

### 3.1 Development (Phase 2–6)

```
localhost
├── Spring Boot fat JAR  (:8080)
│   └── serves /frontend/dist as static resources
├── Oracle DB Free in Docker  (:1521)
├── Vite dev server  (:5173)  [dev only]
└── .env file (git-ignored, holds DB credentials and Snowflake key path)
```

### 3.2 Open Liberty Migration (Phase 7+)

The fat JAR is replaced by deploying the WAR/EAR to Open Liberty:

```
server.xml additions:
  <feature>springBoot-3.0</feature>
  <feature>servlet-6.0</feature>
  <httpEndpoint id="defaultHttpEndpoint" httpPort="9080" httpsPort="9443"/>
  <springBootApplication location="cdp-loader.war"/>
```

No Java code changes are required. Maven packaging switch from `jar` to `war` with a `SpringBootServletInitializer` subclass.

---

## 4. Spring Batch Architecture

### 4.1 Job Hierarchy

```
InitialLoadJob
  ├── Step: loadReferenceData
  ├── Step: loadCustomers
  ├── Step: loadCustomerContacts
  ├── Step: loadEnergyAccounts
  ├── Step: loadBillingAccounts
  ├── Step: loadPremises
  ├── Step: loadMeters
  ├── Step: loadMonthlyUsage
  └── Step: reconcileInitialLoad

DailyIncrementalJob
  ├── Step: extractChangedCustomers
  ├── Step: extractChangedContacts
  ├── Step: extractChangedEnergyAccounts
  ├── Step: extractChangedBillingAccounts
  ├── Step: extractChangedPremises
  ├── Step: extractChangedMeters
  ├── Step: updateWatermarks
  └── Step: reconcileDailyLoad

MonthlyUsageJob
  ├── Step: extractMonthlyUsage
  ├── Step: loadMonthlyUsage
  └── Step: reconcileMonthlyUsage
```

### 4.2 Watermark Strategy

Each entity maintains its own watermark row in `ETL_WATERMARK`:
- `ENTITY_NAME` — e.g., `CUSTOMER`, `ENERGY_ACCOUNT`
- `LAST_WATERMARK_TS` — last successfully processed `UPDATED_AT` 
- `LAST_WATERMARK_ID` — last successfully processed `SOURCE_ID` at that timestamp
- `JOB_TYPE` — `INITIAL`, `DAILY`, `MONTHLY`

Extraction filter: `WHERE UPDATED_AT > :lastTs OR (UPDATED_AT = :lastTs AND SOURCE_ID > :lastId)`  
Order: `ORDER BY UPDATED_AT ASC, SOURCE_ID ASC`

Watermark advances only after the step commits successfully.

### 4.3 Error Handling

```
ItemReader → ItemProcessor → [SkipPolicy] → ItemWriter
                                   ↓ on error
                            ETL_RECORD_ERROR (JDBC direct write)
                                   ↓ count
                            if rejected > threshold%: FAIL step
```

---

## 5. Data Flow Summary

See [`docs/architecture/data-flow.md`](data-flow.md) for full detail.

1. Trigger arrives (REST API or scheduler)
2. Spring Batch job instantiated; `ETL_JOB_RUN` row inserted with status `RUNNING`
3. Reader queries Snowflake using watermark (or full scan for initial)
4. Processor applies ICA transformations and validations
5. Valid records written to Oracle via MERGE; errors written to `ETL_RECORD_ERROR`
6. On successful step commit: watermark updated in `ETL_WATERMARK`
7. On job completion: `ETL_JOB_RUN` updated with final status and counts
8. Reconciliation step writes `ETL_RECONCILIATION` row

---

## 6. Technology Versions

| Technology | Version | Notes |
|-----------|---------|-------|
| Java | 17 (LTS) | Target: OpenJDK 17 |
| Spring Boot | 3.3.x | Includes Spring Batch 5.x |
| Spring Batch | 5.1.x | Included via Spring Boot |
| Maven | 3.9.x | Wrapper included |
| Flyway | 10.x | Oracle-compatible edition |
| Snowflake JDBC | 3.x | `net.snowflake:snowflake-jdbc` |
| Oracle JDBC | 23.x | `com.oracle.database.jdbc:ojdbc11` |
| React | 18.x | |
| TypeScript | 5.x | |
| Vite | 5.x | |
| Node.js | 20 LTS | Frontend build only |
| Docker | 24+ | Oracle container |
| Oracle DB | Free 23c | Development target |
| Shadcn/ui | Latest | Radix + Tailwind |
| Recharts | 2.x | Dashboard charts |

---

## 7. Key Design Decisions

See [`docs/architecture/architecture-decisions.md`](architecture-decisions.md) for full ADRs.

| ADR | Decision |
|-----|----------|
| ADR-01 | Spring Batch over custom scheduler |
| ADR-02 | Oracle MERGE for idempotent upsert |
| ADR-03 | Composite watermark (UPDATED_AT + SOURCE_ID) |
| ADR-04 | Flyway for Oracle schema versioning |
| ADR-05 | Three Oracle schemas (APP / CTL / BATCH) |
| ADR-06 | BigDecimal / NUMBER for all monetary and usage values |
| ADR-07 | Fat JAR with Open Liberty migration path |
| ADR-08 | Snowflake key-pair authentication (no password) |
| ADR-09 | React + Vite for dashboard |
| ADR-10 | ICA as governance authority (not runtime dependency) |
