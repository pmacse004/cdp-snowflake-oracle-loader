# Architecture Decision Records

**Document ID:** ARCH-004  
**Project:** CDP Snowflake to Oracle Data Loader  
**Version:** 1.0  
**Status:** Phase 1 — Approved  
**Last Updated:** 2025 (Phase 1)

---

## ADR-01: Use Spring Batch as the ETL Framework

**Status:** Accepted

**Context:**  
The application needs to execute multi-step, restartable, chunk-oriented batch jobs with error isolation, skip policies and a persisted job state. Several Java batch frameworks are available.

**Decision:**  
Use **Spring Batch 5.x** (included via Spring Boot 3.x).

**Rationale:**
- Provides `JobRepository` for persisted state — enables restart after failure without re-reading successfully committed chunks.
- Built-in chunk-oriented processing model maps directly to the Extract → Transform → Write pipeline.
- `SkipPolicy` and `RetryPolicy` support error isolation out of the box.
- Spring Boot auto-configuration reduces boilerplate.
- Extensive ecosystem and well-understood by consulting teams.
- Integrates with Spring Scheduler and Quartz for cron triggers.

**Consequences:**
- Spring Batch `BATCH_*` tables must exist in Oracle before first run (Flyway migration).
- Job parameters must be distinct per logical run to avoid duplicate-run protection issues.

---

## ADR-02: Use Oracle MERGE for Idempotent Upsert

**Status:** Accepted

**Context:**  
Records arriving via incremental load may already exist in Oracle (corrections, re-runs). The load must be idempotent.

**Decision:**  
All target entity writes use Oracle **MERGE INTO ... USING ... ON (business_key) WHEN MATCHED THEN UPDATE ... WHEN NOT MATCHED THEN INSERT**.

**Rationale:**
- Single SQL statement handles both insert and update atomically.
- Idempotent by nature: running the same record twice produces the same result.
- Avoids SELECT-before-INSERT race conditions.
- Efficient for bulk operations via `JdbcBatchItemWriter` with a custom SQL provider.

**Consequences:**
- Business keys must be clearly defined for every entity.
- MERGE statements are Oracle-specific; migration to PostgreSQL would require rewrite (acceptable for this Oracle-targeted demo).

---

## ADR-03: Composite Watermark (UPDATED_AT + SOURCE_ID)

**Status:** Accepted

**Context:**  
Watermarks based solely on a timestamp (`UPDATED_AT`) can miss records when multiple records share the same timestamp (e.g., batch updates in Snowflake with millisecond resolution). Using `UPDATED_AT - 1 second` as a safety buffer causes duplicate reprocessing.

**Decision:**  
The watermark is a composite of `(LAST_WATERMARK_TS, LAST_WATERMARK_ID)`.

Extract filter:
```sql
WHERE (UPDATED_AT > :lastTs)
   OR (UPDATED_AT = :lastTs AND SOURCE_ID > :lastId)
ORDER BY UPDATED_AT ASC, SOURCE_ID ASC
```

After a successful commit, advance to the `max(UPDATED_AT, SOURCE_ID)` seen in that chunk.

**Rationale:**
- Handles equal timestamps correctly with zero reprocessing.
- Deterministic ordering enables exact resumption.
- SOURCE_ID is a stable, monotonically increasing surrogate key in Snowflake.

**Consequences:**
- SOURCE_ID must be a stable surrogate that does not change for a given record.
- `ETL_WATERMARK` table stores both `LAST_WATERMARK_TS` and `LAST_WATERMARK_ID`.

---

## ADR-04: Use Flyway for Oracle Schema Versioning

**Status:** Accepted

**Context:**  
The Oracle schema will evolve across phases. Manual DDL is error-prone and non-reproducible.

**Decision:**  
Use **Flyway 10.x** with Oracle-compatible SQL migrations stored in `src/main/resources/db/migration/`.

**Rationale:**
- Industry-standard schema versioning tool.
- Migrations are version-numbered SQL files; Flyway runs only new ones.
- Integrates with Spring Boot auto-configuration (`spring.flyway.*`).
- Supports Oracle-specific DDL (sequences, triggers, synonyms).
- Migrations are tested in CI against a real Oracle instance.

**Consequences:**
- All DDL must go through Flyway migration files; no ad-hoc SQL.
- Migration files are immutable once merged (never edit a deployed migration).

---

## ADR-05: Three Oracle Schemas (APP / CTL / BATCH)

**Status:** Accepted

**Context:**  
Business tables, ETL control tables and Spring Batch framework tables serve different purposes with different access patterns. Mixing them in one schema reduces clarity.

**Decision:**  
Three schemas:
- `CDP_APP` — business target tables (customers, accounts, etc.)
- `CDP_CTL` — ETL control tables (watermarks, job runs, errors, reconciliation)
- `CDP_BATCH` — Spring Batch `JobRepository` tables only

**Rationale:**
- Separation of concerns: DBA can grant read access to `CDP_APP` for reporting without exposing ETL internals.
- Spring Batch tables are created by the framework; isolating them makes upgrades cleaner.
- `CDP_CTL` can be secured independently from business data.

**Consequences:**
- The application user must be granted appropriate privileges on all three schemas.
- Cross-schema queries are needed in reconciliation steps (acceptable in Oracle).

---

## ADR-06: BigDecimal / NUMBER for All Monetary and Usage Values

**Status:** Accepted

**Context:**  
Electric utility billing involves precise financial calculations. IEEE 754 floating-point arithmetic introduces rounding errors that are unacceptable for billing data.

**Decision:**  
- Java: use `java.math.BigDecimal` throughout the processing pipeline.
- Oracle: use `NUMBER(18,6)` for usage values; `NUMBER(15,2)` for monetary values.
- No `float`, `double`, `FLOAT` or `BINARY_DOUBLE` anywhere in the pipeline.

**Rationale:**
- `BigDecimal` provides exact decimal arithmetic.
- Oracle `NUMBER` is an exact decimal type.
- Eliminates floating-point rounding errors in KWH/KW totals and billing amounts.

**Consequences:**
- All arithmetic in processors must use `BigDecimal` operations (`.add()`, `.multiply()`, etc.).
- JDBC `ResultSet` reads use `getBigDecimal()`.

---

## ADR-07: Fat JAR as Primary Target; Open Liberty as Future Option Requiring a Compatibility Spike

**Status:** Accepted (amended)

**Context:**
The demo runs standalone (no app server) for development simplicity. IBM clients may require Open Liberty deployment in production.

**Decision:**
Package as a **Spring Boot fat JAR** as the sole validated deployment target for this demonstration. Open Liberty deployment is acknowledged as a future option but requires a dedicated compatibility spike before it can be claimed.

**Rationale:**
- Fat JAR: simplest possible local execution (`java -jar`); zero external runtime dependencies.
- Spring Boot supports WAR packaging with `SpringBootServletInitializer` in theory, but compatibility with Open Liberty must be verified:
  - Embedded Tomcat exclusion in `pom.xml`
  - Spring Batch `JobRepository` auto-configuration under Open Liberty
  - Flyway Oracle edition behaviour in a managed datasource environment
  - Spring Security filter ordering under the Liberty servlet container
- These have not been tested and will not be tested until Phase 7.

**Consequences:**
- The application is designed and tested as a standalone fat JAR.
- Open Liberty migration is a Phase 7 item that begins with a compatibility spike.
- Claims that "no code changes are required" for Open Liberty are removed until the spike confirms this.
- `server.xml` design will be produced in Phase 7 after the spike.

---

## ADR-08: Snowflake Key-Pair Authentication

**Status:** Accepted

**Context:**  
The Snowflake service user must authenticate securely. Password-based authentication is less secure and passwords must not be stored in config.

**Decision:**  
Use **RSA key-pair authentication** (2048-bit RSA). Private key stored on local filesystem (never in source control), path referenced via environment variable. Public key registered with the Snowflake service user.

**Rationale:**
- Snowflake best-practice for service accounts.
- Eliminates passwords entirely from the application.
- Key rotation is operationally straightforward.
- Supported natively by the Snowflake JDBC driver.

**Consequences:**
- Initial setup requires key generation (PowerShell `New-SelfSignedCertificate` or `openssl`) — documented in Phase 2.
- The private key `.p8` file must be protected by OS file permissions.

---

## ADR-09: React + Vite + Shadcn/ui for Dashboard

**Status:** Accepted

**Context:**  
The operations dashboard needs to be professional, responsive and maintainable. Multiple frontend technology stacks are available.

**Decision:**  
- **React 18** + **TypeScript 5** + **Vite 5**
- **Shadcn/ui** for component primitives (Radix UI + Tailwind CSS)
- **Recharts** for charts and graphs
- **Axios** for API communication with typed client

**Rationale:**
- React + TypeScript: widely used, strong typing, large ecosystem.
- Vite: fast development server, native ES modules, optimised production builds.
- Shadcn/ui: accessible, unstyled Radix primitives + Tailwind; components are copied into the project (no version lock-in).
- Recharts: React-native charting library with straightforward API.
- Production build output is served as static assets by Spring Boot.

**Consequences:**
- Node.js 20 LTS required for frontend build (not required at runtime).
- Tailwind CSS configuration required.
- In production, `npm run build` output goes to `frontend/dist` → Spring Boot serves from `/static`.

---

## ADR-10: ICA as Governance Authority (Not Runtime Dependency)

**Status:** Accepted

**Context:**  
IBM Consulting Advantage (ICA) Context Studio will hold the authoritative mapping catalogue. The question is whether the running application queries ICA at runtime or uses its own copy.

**Decision:**
ICA is the design-time mapping and rule authority. Bob consumes ICA through MCP to generate and maintain code. The running application does not connect to ICA at runtime.

The mapping catalogue YAML (`docs/ica-context/mapping-catalogue.yaml`) is packaged with the application and read at startup for dashboard display. **No runtime Oracle mapping-configuration tables are required** — runtime behaviour is driven solely by compiled Java code, the packaged YAML and Flyway-managed Oracle schemas.

**Rationale:**
- Avoids runtime dependency on an external governance system.
- Mapping rules are stable at deployment time; changes require a code deployment.
- The packaged YAML is a versioned artefact — the dashboard mapping viewer reads it without needing a database table.
- Duplicating mappings into Oracle config tables adds maintenance overhead with no justified runtime benefit for this demonstration.

**Consequences:**
- Mapping changes require updating the catalogue YAML, regenerating/updating Java processor code (which Bob can assist with via ICA MCP context), and deploying.
- The dashboard mapping catalogue view reads `mapping-catalogue.yaml` at startup (classpath resource); no database query needed.
- If a future requirement demands runtime-configurable rules without redeployment, an Oracle `ETL_MAPPING_CONFIG` table could be added at that time.
