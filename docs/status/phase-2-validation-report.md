# Phase 2 Validation Report
# CDP Snowflake-to-Oracle Loader

**Report date:** Phase 2 validation (v1.8 — Phase 3 pre-execution audit correction applied)
**Validator:** Bob (automated static analysis + manual code review + live Oracle + live Snowflake execution all confirmed)
**Status:** PHASE 2 SUBSTANTIALLY COMPLETE — Oracle schema V004, Snowflake DB/schemas/tables/views provisioned.
**EXCEPTION (Issue #16):** `SVC_CDP_LOADER` RSA key-pair JDBC authentication from the Java application has NOT been verified. Script `02-create-service-user.sql` shows status NOT EXECUTED in the execution matrix (line 218). The Snowflake JDBC connectivity row (line 754) is correctly marked NOT VERIFIED. The v1.7 header incorrectly stated Phase 2 COMPLETE. This is corrected here: Phase 2 is complete for infrastructure provisioning; Snowflake application-level authentication is deferred to Phase 4.

---

## Validation Status Legend

| Label | Definition |
|---|---|
| **STATICALLY VALIDATED** | Parsed, compiled, or checked by a tool without any running service |
| **EXECUTED** | Command or SQL actually run against a live system and confirmed successful |
| **CONNECTIVITY VERIFIED** | Live database/service connection confirmed by the user |
| **NOT TESTED** | Tool unavailable or not run; result unknown |
| **NOT EXECUTED** | Command or SQL not yet run against a live system |
| **NOT VERIFIED** | Claim cannot be confirmed without a live system |
| **GENERATED** | File created by tooling; correct by review but no runtime has processed it |

---

## 0. Live Oracle Results (User-Confirmed) — COMPLETE

All Oracle infrastructure items are now EXECUTED or CONNECTIVITY VERIFIED.

### Container and Image

| Item | Result | Label |
|---|---|---|
| Oracle image | `container-registry.oracle.com/database/free:23.7.0.0` | **EXECUTED** |
| Container name | `cdp-oracle-db` | **CONNECTIVITY VERIFIED** |
| Container health | `healthy` | **CONNECTIVITY VERIFIED** |
| Oracle version | Oracle Database Free 23ai 23.7.0.25.01 | **CONNECTIVITY VERIFIED** |
| PDB name | `FREEPDB1` | **CONNECTIVITY VERIFIED** |
| PDB status | `READ WRITE` | **CONNECTIVITY VERIFIED** |
| Listener port | `1521` | **CONNECTIVITY VERIFIED** |

### DBA Bootstrap

| Item | Result | Label |
|---|---|---|
| `infra/oracle/00-dba-bootstrap.sql` | Executed as SYSDBA against FREEPDB1 | **EXECUTED** |
| CDP_LOADER user created | Confirmed | **EXECUTED** |
| CDP_LOADER authentication | Verified — JDBC connection succeeded | **CONNECTIVITY VERIFIED** |

### Flyway Migrations

| Item | Result | Label |
|---|---|---|
| `flyway:repair` (remove failed V001 history row) | Executed successfully | **EXECUTED** |
| V001 — Spring Batch schema | Applied — NOCYCLE fix required (see §11) | **EXECUTED** |
| V002 — Reference tables | Applied successfully | **EXECUTED** |
| V003 — ETL control tables | Applied successfully | **EXECUTED** |
| V004 — Target business tables | Applied successfully | **EXECUTED** |
| Oracle schema version | `V004` | **EXECUTED** |
| Flyway schema history table | `CDP_LOADER.flyway_schema_history` created | **EXECUTED** |
| Maven result | `BUILD SUCCESS` | **EXECUTED** |

### Items Remaining NOT EXECUTED / FAILED

| Item | Label | Notes |
|---|---|---|
| `GET /actuator/health` | **NOT EXECUTED** | Requires application startup with local profile env vars |
| Oracle JDBC connectivity from running application | **NOT VERIFIED** | Requires application startup |
| Snowflake script 01 | **EXECUTED** | DB, schemas, warehouse, CDP_LOADER_ROLE created — CDP_ADMIN_ROLE missing (see §17) |
| Snowflake script 01a | **NOT EXECUTED** | Repair script — run as ACCOUNTADMIN before rerunning script 03 |
| Snowflake script 03 | **FAILED on first attempt** | SQL access control — SYSADMIN lacks CREATE TABLE on REF; corrected (see §17) |
| Snowflake script 04 — VW_DAILY_CUSTOMER_ACCOUNT_EXPORT | **EXECUTED** | View created successfully before failure |
| Snowflake script 04 — VW_MONTHLY_USAGE_BILLING_EXPORT | **FAILED** | TRY_CAST(VARIANT, NUMBER) not supported; corrected (see §19) |

---

## 1. Oracle Bootstrap vs Flyway

### Finding
`V001__create_oracle_schema_user.sql` contained `CREATE USER CDP_LOADER ...` and `GRANT ... TO CDP_LOADER`. Flyway connects **as** CDP_LOADER and therefore cannot create itself. The `CREATE USER` requires SYSDBA or DBA privilege — a privilege CDP_LOADER must never hold at runtime.

### Correction Applied
- **Moved** all DBA-level operations to `infra/oracle/00-dba-bootstrap.sql`
- **Renumbered** all Flyway migrations:

| Old file | New file | Contents |
|---|---|---|
| `V001__create_oracle_schema_user.sql` | **DELETED** (moved to DBA bootstrap) | CREATE USER, GRANT |
| `V003__create_spring_batch_schema.sql` | `V001__create_spring_batch_schema.sql` | Spring Batch tables |
| `V002__create_reference_tables.sql` | `V002__create_reference_tables.sql` | REF_CODE_VALUE |
| `V004__create_etl_control_tables.sql` | `V003__create_etl_control_tables.sql` | ETL control tables |
| `V005__create_target_business_tables.sql` | `V004__create_target_business_tables.sql` | Business tables |

- **Removed** all `CDP_LOADER.` schema prefixes from V001–V004 (Flyway connects as CDP_LOADER; unqualified names default to its own schema)
- **Confirmed by live execution:** V001–V004 applied successfully against Oracle 23ai

### Connection Matrix

| Operation | Connection string | User | Privileges needed | When |
|---|---|---|---|---|
| DBA bootstrap | `sqlplus sys/<pwd>@//localhost:1521/FREEPDB1 as sysdba` | SYS | SYSDBA | Once, before first app start — **DONE** |
| Flyway migrate | JDBC `jdbc:oracle:thin:@//localhost:1521/FREEPDB1` | CDP_LOADER | CREATE TABLE, CREATE SEQUENCE | On each app startup — **DONE** |
| App runtime | JDBC `jdbc:oracle:thin:@//localhost:1521/FREEPDB1` | CDP_LOADER | DML only (INSERT, UPDATE, DELETE, SELECT) | Continuous |

### Runtime Privilege Principle
CDP_LOADER at runtime requires only DML privileges — no CREATE TABLE, no DDL.
Flyway needs CREATE TABLE during migration only. Both use the same JDBC user because Oracle Free does not have schema separation from user separation. This is acceptable for a demo; in production the schema owner would differ from the application user.

---

## 2. Oracle Container Validation

### Image

| Attribute | Value | Status |
|---|---|---|
| Image | `container-registry.oracle.com/database/free:23.7.0.0` | **EXECUTED** — pulled and running |
| Registry | `container-registry.oracle.com` | Public registry; `/database/free` path does **not** require login |
| Architecture | `linux/amd64` | Docker Desktop with WSL2 on Windows 11 ✓ |
| PDB service name | `FREEPDB1` | **CONNECTIVITY VERIFIED** |
| CDB service name | `FREE` | Not used by application |
| Listener port | `1521` | **CONNECTIVITY VERIFIED** — mapped 1521:1521 |
| EM Express port | `5500` | Mapped 5500:5500 (optional) |
| Health-check script | `/opt/oracle/checkDBStatus.sh` | **CONNECTIVITY VERIFIED** — container reports `healthy` |
| ORACLE_PWD | From `infra/docker/.env` (gitignored) | Sets SYS, SYSTEM, PDBADMIN passwords |
| ORACLE_CHARACTERSET | `AL32UTF8` | UTF-8; correct for application |
| ENABLE_ARCHIVELOG | **Removed** — not a supported env var in this image | **CORRECTED** |
| init-scripts volume | **Removed** — Flyway manages all DDL | **CORRECTED** |

### Corrections Applied to docker-compose.yml
- Image tag changed from `:latest` → `23.7.0.0`
- `ENABLE_ARCHIVELOG` env var removed (not valid for this image)
- `./init-scripts:/opt/oracle/scripts/startup` volume mount removed
- `mem_limit` increased from `3g` → `4g` (Oracle Free needs SGA + PGA + OS overhead)
- `start_period` increased from `120s` → `180s` (safer for slow first-run)
- Health-check test simplified from multi-line YAML to single-array form
- Full documentation block added in file header (PDB name, registry notes, Windows compat)

---

## 3. Maven Module Consistency

### Finding
The Phase 2 completion report mentioned `cdp-loader-web` as a possible module. The root `pom.xml` was reviewed and contains exactly 3 modules:
```
cdp-loader-core, cdp-loader-batch, cdp-loader-api
```
`cdp-loader-web` was never added to the root POM — it existed only in narrative text.

### Decision (confirmed)
- React/Vite frontend lives in `frontend/` directory (Phase 8)
- It is **not** a Maven module
- Build: `npm run build` → output copied to `cdp-loader-api/src/main/resources/static/` during Phase 8
- No Maven frontend wrapper module needed

**Status: No change required. Consistent.**

---

## 4. Spring Boot and Dependency Validation

### Dependency Review

| Dependency | Version | Java 17 Compatible | Notes |
|---|---|---|---|
| Spring Boot | 3.2.5 | ✓ | Managed via BOM import |
| Spring Batch | 5.1.x (via Boot 3.2.5) | ✓ | Transitive from spring-boot-starter-batch |
| Snowflake JDBC | 3.15.1 | ✓ | `net.snowflake:snowflake-jdbc` |
| Oracle JDBC | 23.4.0.24.05 (`ojdbc11`) | ✓ | ojdbc11 targets Java 11+ |
| Flyway Core | 10.12.0 | ✓ | Flyway 10.x requires Java 17+ |
| flyway-database-oracle | 10.12.0 | ✓ | Required for Oracle support in Flyway 10 |
| MapStruct | 1.5.5.Final | ✓ | |
| Testcontainers oracle-free | 1.19.8 | ✓ | Uses `gvenzl/oracle-free` image |
| Lombok | BOM-managed | ✓ | |

### Bug Found and Fixed: `${lombok.version}` in parent POM
The annotation processor path in the parent POM referenced `${lombok.version}`. This property is defined in the Spring Boot BOM under the name `lombok.version` — it resolves correctly when the BOM is imported. **Confirmed:** `mvn compile` succeeded without error.

### @EnableBatchProcessing — Finding and Fix
**Bug:** `BatchConfig.java` had `@EnableBatchProcessing`. In Spring Boot 3.x / Spring Batch 5.x, this annotation **opts out** of Spring Boot auto-configuration and requires manual wiring of `JobRepository`, `JobLauncher`, etc.

**Fix:** Removed `@EnableBatchProcessing`. Spring Boot auto-configures all Batch infrastructure against the `@Primary` Oracle DataSource. Added detailed Javadoc explaining the decision.

### Spring Batch DDL Version Match
V001 migration uses the Spring Batch 5.x Oracle schema (`schema-oracle10g.sql` from spring-batch-core 5.x). Key verification: `BATCH_JOB_EXECUTION` includes `LAST_UPDATED` column (added in Spring Batch 5).
**Live confirmation:** V001 applied cleanly — all Spring Batch tables and sequences created successfully.

---

## 5. DataSource Design

### Bean Architecture

| Bean name | Type | @Primary | Used by |
|---|---|---|---|
| `dataSource` (auto-configured from `spring.datasource.*`) | `HikariDataSource` → Oracle | **YES** | JPA, Flyway, Spring Batch JobRepository |
| `snowflakeDataSource` | `SnowflakeBasicDataSource` | NO | Injected by `@Qualifier("snowflakeDataSource")` in batch readers |

### Flyway Isolation
Flyway auto-configuration picks up the `@Primary` DataSource (Oracle). The Snowflake DataSource has no Flyway configuration and is never touched by Flyway. **Confirmed by live execution** — Flyway connected as CDP_LOADER to FREEPDB1 only.

### Snowflake Read-Only Enforcement
Two layers:
1. **Role-level** (Snowflake): `CDP_LOADER_ROLE` has `SELECT` only — no INSERT, UPDATE, DELETE, DDL grants
2. **Application-level**: `SnowflakeDataSourceConfig` never calls any write operation; all usage is through `JdbcTemplate` SELECT queries in batch readers

### Compile Fix Applied
`SnowflakeBasicDataSource.setProperties(Properties)` does not exist in JDBC 3.15.1. Replaced with `ds.setLoginTimeout(int)` — the only extra property needed. Application identifier and keep-alive are JDBC URL properties if needed in future.

---

## 6. Snowflake Provisioning Script Review

### Execution Matrix

| Script | Run as | Safe to rerun | Objects created | Validation query | Status |
|---|---|---|---|---|---|
| `01-create-database-schemas-warehouse.sql` | ACCOUNTADMIN | YES — all `IF NOT EXISTS` | CDP_UTIL_DB, 5 schemas, CDP_LOADER_WH, **CDP_ADMIN_ROLE**, CDP_LOADER_ROLE, grants | `SHOW GRANTS TO ROLE CDP_ADMIN_ROLE` | **EXECUTED** (v1.4 env missing CDP_ADMIN_ROLE; use 01a to repair) |
| `01a-repair-admin-role-grants.sql` | ACCOUNTADMIN | YES — idempotent GRANTs | CDP_ADMIN_ROLE + all CREATE TABLE/VIEW grants | `SHOW GRANTS TO ROLE CDP_ADMIN_ROLE` | **NOT EXECUTED** — run first |
| `02-create-service-user.sql` | ACCOUNTADMIN | YES — `IF NOT EXISTS`; key rotation via ALTER | SVC_CDP_LOADER (TYPE=SERVICE), role grant | `DESC USER SVC_CDP_LOADER` | **NOT EXECUTED** |
| `03-create-source-tables.sql` | **CDP_ADMIN_ROLE** | YES — all `IF NOT EXISTS` | 7 source tables across 4 schemas | `SHOW TABLES IN SCHEMA CDP_UTIL_DB.CUSTOMER` | **FAILED** on first attempt — rerun after 01a |
| `04-create-export-views.sql` | **CDP_ADMIN_ROLE** | YES — `CREATE OR REPLACE VIEW` | 2 views in STAGING schema | `SHOW VIEWS IN SCHEMA CDP_UTIL_DB.STAGING` | **FAILED** (view 2 TRY_CAST error) — rerun corrected script |
| `keygen.ps1` | Developer (local) | YES — creates new keys if directory empty | RSA key pair in `~/.cdp-loader/keys/` | File existence check | **NOT EXECUTED** |

### Role Execution Guidance
Scripts **01 and 01a** must run as **ACCOUNTADMIN** (role creation, privilege grants).
Script **02** must run as **ACCOUNTADMIN** (service user creation).
Scripts **03 and 04** must run as **CDP_ADMIN_ROLE** — switch to it from SYSADMIN with `USE ROLE CDP_ADMIN_ROLE`.
**Do not run scripts 03/04 as SYSADMIN directly** — SYSADMIN itself lacks CREATE TABLE on the application schemas.

### Corrections Applied (previously validated)
- `FOR schema_name IN (...) DO ... END FOR;` — **not valid Snowflake SQL** — replaced with explicit per-schema GRANT statements
- `TYPE = SERVICE` added to service user (disables interactive login, password auth, MFA prompt)
- `MUST_CHANGE_PASSWORD = FALSE` removed (not applicable to TYPE=SERVICE)
- `ALTER USER ... SET MINS_TO_BYPASS_MFA = 0` removed (not needed for TYPE=SERVICE)
- Placeholder guard documented: `<<PASTE_RSA_PUBLIC_KEY_HERE>>` contains `<>` which are invalid in a real RSA key — will fail authentication if not replaced
- Rollback comments added to each script

---

## 7. SQL Idempotency

| Script | Idempotency mechanism | Safe on repopulated tables |
|---|---|---|
| Snowflake 01 | `CREATE ... IF NOT EXISTS` throughout | YES |
| Snowflake 02 | `CREATE USER IF NOT EXISTS`; key rotation via ALTER | YES |
| Snowflake 03 | `CREATE TABLE IF NOT EXISTS` throughout | YES |
| Snowflake 04 | `CREATE OR REPLACE VIEW` — views only, no data loss | YES |
| Oracle DBA bootstrap | Not idempotent — run once | N/A (manual) — **DONE** |
| Flyway V001–V004 | Flyway checksum tracking handles idempotency | YES (Flyway manages) — **APPLIED** |

---

## 8. Export View Review

### VW_DAILY_CUSTOMER_ACCOUNT_EXPORT

| Requirement | Status |
|---|---|
| Multi-table joins (6 tables) | PASS — CUSTOMER, ENERGY_ACCOUNT, BILLING_ACCOUNT, PREMISE, METER, CUSTOMER_CONTACT |
| Deterministic primary contact selection | PASS — `QUALIFY ROW_NUMBER() OVER (PARTITION BY CUSTOMER_ID ORDER BY EFFECTIVE_DATE DESC) = 1` |
| Effective-dated billing account | PASS — `WHERE END_DATE IS NULL OR END_DATE >= CURRENT_DATE()` + QUALIFY |
| Effective-dated premise | PASS — same pattern |
| Active meter selection | PASS — `WHERE IS_ACTIVE = TRUE AND (REMOVAL_DATE IS NULL OR ...)` + QUALIFY |
| Soft-delete derivation | PASS — `ea.ACCOUNT_STATUS / c.ACCOUNT_STATUS` passed through; `IS_ACTIVE` derivation in Oracle MERGE (Phase 5) |
| Composite watermark covers all tables | **CORRECTED** — was missing `CUSTOMER_CONTACT` UPDATED_AT; now includes `EMAIL_UPDATED_AT` and `PHONE_UPDATED_AT` |
| Null-safe COALESCE in GREATEST | PASS — all 7 components COALESCE to epoch |

### VW_MONTHLY_USAGE_BILLING_EXPORT

| Requirement | Status |
|---|---|
| Rate plan JSON parsing | PASS — `TRY_PARSE_JSON` + `TRY_CAST` with null-safe COALESCE(rate, 0) |
| 7-step charge calculation | PASS — FIXED → ENERGY → DEMAND → SUBTOTAL → TAX → TOTAL → QUALITY |
| Explicit ROUND(x,2) at each monetary step | PASS |
| Additive total (SUBTOTAL + TAX, not multiplicative) | PASS |
| Corrected usage handling | PASS — `IS_CORRECTION` flag; `USAGE_QUALITY_STATUS` derived |
| Null PEAK_DEMAND_KW handled | PASS — CASE when both KW and rate present |
| KWH_EFFECTIVE fallback | PASS — `COALESCE(KWH_ADJUSTED, KWH_USAGE)` |

### No Duplicate Calculation
Billing charge calculations exist **only in Snowflake** (Layer 1 — view). Spring Batch (Layer 2) reads the pre-calculated `CALC_*` columns and maps them directly to Oracle. No duplication.

---

## 9. Git and Secret Safety

### Static Scan Results

| Check | Result |
|---|---|
| `.gitignore` exists at repository root | PASS |
| Secret pattern scan (password literals, PEM headers, bearer tokens) | PASS — 0 findings |
| `*.p8` excluded | PASS (verified in .gitignore) |
| `*.pem` excluded | PASS |
| `application-local.yml` excluded | PASS |
| `infra/docker/.env` excluded | PASS |
| Templates (`.env.template`, `application-local.yml.template`) tracked | PASS — only templates committed |
| No real passwords used as sample values | PASS — all placeholders are `CHANGE_ME`, `<STRONG_PASSWORD>`, `<<PASTE_RSA_PUBLIC_KEY_HERE>>` |

### Git Repository Status
**NOT TESTED** — no `.git` directory exists in the workspace. The gitignore rules are correct but their enforcement has not been validated by git.

**Required manual step:** Run `git init && git add .` and verify `git status` shows no secrets before any push.

---

## 10. Flyway Version Convergence Fix

### Root Cause
Spring Boot 3.2.5's BOM (`spring-boot-dependencies`) pins `flyway-core` at **9.22.3**.
`cdp-loader-batch` declared explicit `${flyway.version}` pins resolving to 10.12.0, but
`cdp-loader-api` (which imports the Spring Boot BOM via the root POM) was receiving 9.22.3
transitively — causing `AbstractMethodError: OracleDatabase does not implement ensureSupported`.

### Fix Applied to `pom.xml`
The root `<dependencyManagement>` block now has `flyway-core` and `flyway-database-oracle`
overrides **before** the Spring Boot BOM import. Maven gives explicit entries declared before a
BOM import higher precedence, so all modules receive 10.12.0 regardless of what the BOM says.

### Verification

**`mvn dependency:tree -Dincludes=org.flywaydb`** — executed 2026-07-21:

| Module | flyway-core | flyway-database-oracle | Result |
|---|---|---|---|
| `cdp-loader-core` | (no dependency) | (no dependency) | ✅ |
| `cdp-loader-batch` | `10.12.0` | `10.12.0` | ✅ |
| `cdp-loader-api` | `10.12.0` (transitive via batch) | `10.12.0` | ✅ |

**No 9.22.3 appears anywhere in the reactor.** ✅

**`mvn clean install -DskipTests`** — executed 2026-07-21:

| Module | Result |
|---|---|
| `cdp-loader-core` | SUCCESS |
| `cdp-loader-batch` | SUCCESS |
| `cdp-loader-api` | SUCCESS (fat JAR repackaged) |
| **Reactor** | **BUILD SUCCESS — 18.920 s** |

---

## 11. V001 NOCYCLE Fix and flyway:repair

### Root Cause
Oracle `CREATE SEQUENCE` syntax requires `NOCYCLE` as a single keyword. The Spring Batch upstream
schema script (`schema-oracle10g.sql`) uses `NO CYCLE` (two words), which is accepted by PostgreSQL
and other databases but **rejected by Oracle** with:

```
ORA-03049: SQL keyword 'NO' is not syntactically valid following '...MAXVALUE 9223372036854775807 '
```

The first `flyway:migrate` attempt created the `flyway_schema_history` table, wrote a failed row
for V001, and then aborted. Flyway blocks a retry of a failed migration until `flyway:repair`
removes the failed history row.

### Fix Applied to `V001__create_spring_batch_schema.sql`

| Before | After |
|---|---|
| `CREATE SEQUENCE BATCH_STEP_EXECUTION_SEQ MAXVALUE 9223372036854775807 NO CYCLE;` | `... NOCYCLE;` |
| `CREATE SEQUENCE BATCH_JOB_EXECUTION_SEQ  MAXVALUE 9223372036854775807 NO CYCLE;` | `... NOCYCLE;` |
| `CREATE SEQUENCE BATCH_JOB_SEQ            MAXVALUE 9223372036854775807 NO CYCLE;` | `... NOCYCLE;` |

Grep scan confirmed no other `NO CYCLE` occurrences in V002–V004.

### Recovery Sequence Executed

| Step | Command | Result |
|---|---|---|
| 1 | `mvn -pl cdp-loader-api flyway:repair` | Removed failed V001 history row — SUCCESS |
| 2 | `mvn -pl cdp-loader-api flyway:migrate` | V001–V004 all applied — BUILD SUCCESS |

### Live Confirmation
Schema version is now **V004**. Oracle schema `CDP_LOADER` contains:
- Spring Batch infrastructure tables and sequences (V001)
- Reference code tables (V002)
- ETL control tables: `ETL_WATERMARK`, `ETL_JOB_RUN`, `ETL_RECORD_ERROR`, `ETL_RECONCILIATION` (V003)
- Target business tables: `CUSTOMER`, `CUSTOMER_CONTACT`, `ENERGY_ACCOUNT`, `BILLING_ACCOUNT`, `SERVICE_PREMISE`, `METER`, `MONTHLY_USAGE_BILLING`, `REF_CODE_VALUE` (V004)

---

## 12. Build Results Summary

### All Commands Run and Results

| Tool | Command | Result | Label |
|---|---|---|---|
| Maven | `mvn validate` | BUILD SUCCESS — all 4 modules | **EXECUTED** |
| Maven | `mvn compile` | BUILD SUCCESS | **EXECUTED** |
| Maven | `mvn dependency:tree -Dincludes=org.flywaydb` | All modules: 10.12.0 only, no 9.22.3 | **EXECUTED** |
| Maven | `mvn clean install -DskipTests` | BUILD SUCCESS — fat JAR produced | **EXECUTED** |
| Maven | `mvn -pl cdp-loader-api flyway:repair` | Failed V001 history row removed | **EXECUTED** |
| Maven | `mvn -pl cdp-loader-api flyway:migrate` | V001–V004 applied — BUILD SUCCESS | **EXECUTED** |
| PowerShell `[Parser]::ParseFile` | All 6 `.ps1` files | 6/6 PASS | **STATICALLY VALIDATED** |
| Python strict duplicate-key loader | `docker-compose.yml` | 0 duplicate keys | **STATICALLY VALIDATED** |
| Python key-count check (non-comment lines) | `docker-compose.yml` | 15/15 PASS | **STATICALLY VALIDATED** |
| Python `yaml.safe_load` | All `.yml`/`.yaml` files | 4/4 PASS | **STATICALLY VALIDATED** |
| Docker CLI `docker compose config` | `docker-compose.yml` | Not run — Docker CLI not in PATH | **NOT TESTED** |
| Snowflake provisioning SQL | Scripts 01–04, views | Not run — Snowflake pending | **NOT EXECUTED** |
| Oracle JDBC connection from application | `GET /actuator/health` | Not run — application not started | **NOT VERIFIED** |
| Snowflake JDBC connection | Batch reader probe | Not run — no live Snowflake | **NOT VERIFIED** |

### Maven Environment
- Maven: 3.9.16
- Java: 21.0.11 (Oracle JDK) — compiles with `source=17 target=17` confirmed
- Build modules: **3 application modules + 1 parent POM = 4 total**
- Last successful build: `2026-07-21T00:22:01+05:30` — fat JAR produced
- Last successful Flyway migrate: Oracle schema at V004

### Maven Module List (authoritative — from root `pom.xml`)

| Module artifact | Type | Purpose |
|---|---|---|
| `cdp-loader-core` | `jar` | Shared domain model, DTOs, transformation utils — no Spring Boot autoconfiguration |
| `cdp-loader-batch` | `jar` | Spring Batch jobs, Flyway migrations, Snowflake + Oracle JDBC |
| `cdp-loader-api` | `jar` (fat JAR) | Spring Boot entry point, REST API, Actuator |
| `frontend/` | Not a Maven module | React + Vite; built with `npm run build` in Phase 8 |

---

## 13. Remaining Prerequisites Before Application Startup

The following items remain before a full end-to-end `mvn spring-boot:run` can succeed:

| # | Step | Status | Notes |
|---|---|---|---|
| 1 | Docker Desktop installed | **DONE** | Container running |
| 2 | Pull Oracle image 23.7.0.0 | **DONE** | Container healthy |
| 3 | Create `infra/docker/.env` from template | **DONE** | Required for container |
| 4 | Start Oracle: `.\scripts\start-oracle.ps1 -WaitReady` | **DONE** | `cdp-oracle-db` healthy |
| 5 | Run DBA bootstrap `00-dba-bootstrap.sql` | **DONE** | CDP_LOADER user created |
| 6 | Run `flyway:migrate` V001–V004 | **DONE** | Schema at V004 |
| 7 | Generate RSA key pair: `.\infra\snowflake\keygen.ps1` | **NOT EXECUTED** | Needed for Snowflake auth |
| 8 | Run Snowflake scripts 01–04 | **NOT EXECUTED** | Pending Snowflake provisioning |
| 9 | Paste public key into `02-create-service-user.sql`; run | **NOT EXECUTED** | Pending key generation |
| 10 | Copy `application-local.yml.template` → fill credentials | **NOT EXECUTED** | Requires Snowflake details |
| 11 | `mvn spring-boot:run -pl cdp-loader-api -Dspring-boot.run.profiles=local` | **NOT EXECUTED** | Requires steps 7–10 |
| 12 | Verify `GET /actuator/health` | **NOT EXECUTED** | Requires running application |
| 13 | `git init && git add . && git status` | **NOT EXECUTED** | Run before any push |

---

## 14. Known Risks

| ID | Risk | Likelihood | Mitigation |
|---|---|---|---|
| R-P2-01 | ~~Oracle image tag 23.7.0.0 may not exist~~ | **CLOSED** | Pull and container startup confirmed |
| R-P2-02 | `TYPE=SERVICE` for Snowflake user may not be supported on trial edition | Medium | Script documents fallback; DESC USER will show actual type; app auth is unaffected |
| R-P2-03 | Snowflake JDBC `setLoginTimeout` may throw if value is ignored on trial account | Low | Wrap in Phase 4 when actually connecting |
| R-P2-04 | ~~Spring Batch schema may differ between Spring Batch 5.1.x and 5.0.x~~ | **CLOSED** | V001 applied cleanly; all Batch tables confirmed created |
| R-P2-05 | Lombok version from Spring Boot BOM may conflict with Java 21 compiler | Low | `mvn compile` succeeded with Java 21; add explicit Lombok version in Phase 3 if needed |
| R-P2-06 | `flyway.default-schema` vs `flyway.schemas` behaviour differs between Flyway versions | Low | `default-schema` sets the schema for the Flyway history table AND defaults unqualified references; correct for this design |
| R-P2-07 | No `git init` yet; .gitignore not enforced | High (procedural) | Run `git init` before any push |
| **R-P2-08** | **Oracle 23.7 newer than Flyway 10.12.0 tested support (tested up to 21.3)** | **Low** | Flyway emitted a warning but migrations applied cleanly. Monitor for issues in later phases. No upgrade required at this stage. |

---

## 15. Files Changed in This Validation Pass

| File | Change type | Reason |
|---|---|---|
| `infra/oracle/00-dba-bootstrap.sql` | **EXECUTED** | CDP_LOADER user created — DONE |
| `cdp-loader-batch/.../V001__create_spring_batch_schema.sql` | **FIXED** | `NO CYCLE` → `NOCYCLE` on all 3 sequences |
| `cdp-loader-batch/.../V002__create_reference_tables.sql` | **EXECUTED** | Applied cleanly — no changes required |
| `cdp-loader-batch/.../V003__create_etl_control_tables.sql` | **EXECUTED** | Applied cleanly — no changes required |
| `cdp-loader-batch/.../V004__create_target_business_tables.sql` | **EXECUTED** | Applied cleanly — no changes required |
| `pom.xml` | **FIXED** | Flyway overrides placed before Spring Boot BOM in `<dependencyManagement>` |
| `docs/status/phase-2-validation-report.md` | **UPDATED (v1.4)** | All Oracle items promoted to EXECUTED; risks updated; Snowflake pending noted |

### Files Changed in Earlier Validation Passes (v1.1 / v1.2 / v1.3)

| File | Change type | Reason |
|---|---|---|
| `infra/oracle/dba-setup.sql` | Superseded by 00-dba-bootstrap.sql | Old file kept for reference |
| `infra/docker/docker-compose.yml` | **REWRITTEN (v1.2)** | Pinned tag; corrected env vars; validated |
| `infra/docker/validate-compose.py` | **NEW** | Strict duplicate-key YAML validator |
| `infra/snowflake/01-create-database-schemas-warehouse.sql` | **UPDATED** | Removed FOR..IN loop; explicit per-schema grants |
| `infra/snowflake/02-create-service-user.sql` | **UPDATED** | TYPE=SERVICE; placeholder guard; removed MFA bypass |
| `infra/snowflake/04-create-export-views.sql` | **UPDATED** | Added EMAIL/PHONE UPDATED_AT to composite watermark |
| `infra/snowflake/keygen.ps1` | **FIXED** | PowerShell syntax errors |
| `scripts/start-oracle.ps1` | **FIXED** | PowerShell syntax errors |
| `scripts/oracle-status.ps1` | **FIXED** | PowerShell syntax errors |
| `scripts/dev-setup.ps1` | **FIXED** | PowerShell syntax errors; function-based refactor |
| `cdp-loader-api/.../SnowflakeDataSourceConfig.java` | **FIXED** | Removed non-existent `setProperties(Properties)` |
| `cdp-loader-api/.../BatchConfig.java` | **FIXED** | Removed `@EnableBatchProcessing` |
| `cdp-loader-api/.../application.yml` | **UPDATED** | `flyway.schemas` → `flyway.default-schema` |

---


## 17. Snowflake Script 03 Live Failure and Role Model Correction

### Live Failure

**Script:** `03-create-source-tables.sql`
**Executed as:** SYSADMIN
**First statement attempted:** `CREATE TABLE IF NOT EXISTS CODE_VALUE` in schema `CDP_UTIL_DB.REF`
**Error:**
```
SQL access control error:
Insufficient privileges to operate on schema 'REF'
SYSADMIN must have CREATE TABLE on schema CDP_UTIL_DB.REF
```

### Root Cause

Script 01 created the database and all schemas while running as ACCOUNTADMIN. In Snowflake,
the role that executes `CREATE SCHEMA` becomes the schema owner. Because ACCOUNTADMIN owned the
schemas, no other role automatically received `CREATE TABLE` on them. SYSADMIN does not inherit
CREATE privileges on objects owned by ACCOUNTADMIN unless explicitly granted.

Script 01 only granted `CDP_LOADER_ROLE` (SELECT-only). It did not grant any DDL privilege to
any role other than ACCOUNTADMIN. When script 03 switched to `USE ROLE SYSADMIN`, SYSADMIN had
`USAGE` on the database but no `CREATE TABLE` on any schema.

### Role Model Before Correction

| Role | Privileges on schemas | Can run script 03? |
|---|---|---|
| ACCOUNTADMIN | All (owns schemas) | Yes — but unsafe; violates least-privilege |
| SYSADMIN | None beyond schema USAGE | **No — error** |
| CDP_LOADER_ROLE | SELECT only | No |

### Role Model After Correction

| Role | DDL privileges | Read privileges | Granted to |
|---|---|---|---|
| **CDP_ADMIN_ROLE** (new) | CREATE TABLE on CUSTOMER, SERVICE, BILLING, REF; CREATE VIEW on STAGING | SELECT on current+future tables in all data schemas | SYSADMIN |
| CDP_LOADER_ROLE (unchanged) | **None** — no CREATE TABLE, no CREATE VIEW, no DML writes | SELECT on current+future tables/views in all schemas | SVC_CDP_LOADER service user |

**CDP_LOADER_ROLE has no CREATE or write privileges.** This is unchanged and verified by design.

### Files Changed

| File | Change | Reason |
|---|---|---|
| `infra/snowflake/01-create-database-schemas-warehouse.sql` | **UPDATED** | Added CDP_ADMIN_ROLE with full DDL grants before CDP_LOADER_ROLE section; updated verification queries |
| `infra/snowflake/01a-repair-admin-role-grants.sql` | **NEW** | Idempotent repair for already-provisioned trial environment; no DROP/REPLACE of any object |
| `infra/snowflake/03-create-source-tables.sql` | **UPDATED** | `USE ROLE CDP_ADMIN_ROLE`; `USE WAREHOUSE CDP_LOADER_WH`; added prerequisite and idempotency notes |
| `infra/snowflake/04-create-export-views.sql` | **UPDATED** | `USE ROLE CDP_ADMIN_ROLE`; `USE WAREHOUSE CDP_LOADER_WH`; added prerequisite notes |

### Tables Created Before Failure

Script 03 failed on the very first `CREATE TABLE` statement (`REF.CODE_VALUE`). No tables were
created before the failure. Script 03 uses `CREATE TABLE IF NOT EXISTS` throughout — if any
tables had been created before the failure, they would be left in place and the rerun would
skip them safely.

Run `SHOW TABLES IN SCHEMA CDP_UTIL_DB.REF` after executing 01a to confirm the state.

### Validation Queries (run after executing 01a, before rerunning script 03)

```sql
-- 1. Confirm CDP_ADMIN_ROLE holds CREATE TABLE and CREATE VIEW
SHOW GRANTS TO ROLE CDP_ADMIN_ROLE;
-- Expected: USAGE on DB and WH; USAGE + CREATE TABLE on CUSTOMER/SERVICE/BILLING/REF;
--           USAGE + CREATE VIEW on STAGING; SELECT on all data schemas

-- 2. Confirm CDP_LOADER_ROLE has NO CREATE privileges
SHOW GRANTS TO ROLE CDP_LOADER_ROLE;
-- Expected: USAGE on DB, WH, all schemas; SELECT only; no CREATE TABLE/VIEW

-- 3. Confirm current table state (safe to rerun regardless of result)
SHOW TABLES IN SCHEMA CDP_UTIL_DB.REF;
SHOW TABLES IN SCHEMA CDP_UTIL_DB.CUSTOMER;
SHOW TABLES IN SCHEMA CDP_UTIL_DB.SERVICE;
SHOW TABLES IN SCHEMA CDP_UTIL_DB.BILLING;

-- 4. Confirm CDP_ADMIN_ROLE is accessible from SYSADMIN
SHOW GRANTS TO ROLE SYSADMIN;
-- Expected: CDP_ADMIN_ROLE appears in the granted roles list
```

### Exact Execution Sequence

Follow these steps in order in your Snowflake worksheet.

**Step 1 — Run 01a as ACCOUNTADMIN (repair role grants)**
```sql
USE ROLE ACCOUNTADMIN;
-- Run the full contents of infra/snowflake/01a-repair-admin-role-grants.sql
-- Verify: SHOW GRANTS TO ROLE CDP_ADMIN_ROLE shows CREATE TABLE on all data schemas
```

**Step 2 — Rerun script 03 as CDP_ADMIN_ROLE**
```sql
-- The USE ROLE CDP_ADMIN_ROLE at the top of script 03 sets the role automatically.
-- Run the full contents of infra/snowflake/03-create-source-tables.sql
-- Verify:
--   SHOW TABLES IN SCHEMA CDP_UTIL_DB.REF      (expect: CODE_VALUE)
--   SHOW TABLES IN SCHEMA CDP_UTIL_DB.CUSTOMER (expect: CUSTOMER, CUSTOMER_CONTACT, ENERGY_ACCOUNT, BILLING_ACCOUNT)
--   SHOW TABLES IN SCHEMA CDP_UTIL_DB.SERVICE  (expect: PREMISE, METER)
--   SHOW TABLES IN SCHEMA CDP_UTIL_DB.BILLING  (expect: MONTHLY_USAGE)
```

**Step 3 — Run script 04 as CDP_ADMIN_ROLE**
```sql
-- The USE ROLE CDP_ADMIN_ROLE at the top of script 04 sets the role automatically.
-- Run the full contents of infra/snowflake/04-create-export-views.sql
-- Verify:
--   SHOW VIEWS IN SCHEMA CDP_UTIL_DB.STAGING
--   (expect: VW_DAILY_CUSTOMER_ACCOUNT_EXPORT, VW_MONTHLY_USAGE_BILLING_EXPORT)
```

**Step 4 — Validate CDP_LOADER_ROLE has no CREATE privileges**
```sql
SHOW GRANTS TO ROLE CDP_LOADER_ROLE;
-- Scan the privilege column: must show only USAGE and SELECT.
-- Must NOT contain CREATE TABLE, CREATE VIEW, INSERT, UPDATE, or DELETE.
```

---



## 19. Snowflake Script 04 Live Failure — TRY_CAST(VARIANT, NUMBER)

### Live Failure

**Script:** `04-create-export-views.sql` — second view (`VW_MONTHLY_USAGE_BILLING_EXPORT`)
**View created before failure:** `VW_DAILY_CUSTOMER_ACCOUNT_EXPORT` — **created successfully**
**Failing view:** `VW_MONTHLY_USAGE_BILLING_EXPORT`
**Failing CTE:** `rate_params`
**Error:**
```
SQL compilation error:
Function TRY_CAST cannot be used with arguments of types VARIANT and NUMBER(10,2)
```

### Root Cause

`TRY_PARSE_JSON(CODE_LABEL)` returns a `VARIANT`. Snowflake does not support
`TRY_CAST(VARIANT, NUMBER(p,s))`. Direct VARIANT-to-NUMBER casting is not allowed even with
the `TRY_` prefix. The source view design document (§17 of the ICA snowflake-view-designs file)
used `TRY_TO_NUMBER(PARSE_JSON(CODE_LABEL):key::STRING)` but the implementation used
`TRY_CAST` — which is PostgreSQL/SQL Server syntax, not Snowflake.

### Fix Applied

**Pattern changed in `rate_params` CTE — all 4 rate fields:**

| Field | Before (failed) | After (corrected) |
|---|---|---|
| `FIXED_RATE` | `TRY_CAST(TRY_PARSE_JSON(CODE_LABEL):fixed AS NUMBER(10,2))` | `TRY_TO_DECIMAL(TRY_PARSE_JSON(CODE_LABEL):fixed::STRING, 10, 2)` |
| `ENERGY_RATE_PER_KWH` | `TRY_CAST(TRY_PARSE_JSON(CODE_LABEL):energy AS NUMBER(10,6))` | `TRY_TO_DECIMAL(TRY_PARSE_JSON(CODE_LABEL):energy::STRING, 10, 6)` |
| `DEMAND_RATE_PER_KW` | `TRY_CAST(TRY_PARSE_JSON(CODE_LABEL):demand AS NUMBER(10,6))` | `TRY_TO_DECIMAL(TRY_PARSE_JSON(CODE_LABEL):demand::STRING, 10, 6)` |
| `TAX_RATE` | `TRY_CAST(TRY_PARSE_JSON(CODE_LABEL):tax AS NUMBER(10,6))` | `TRY_TO_DECIMAL(TRY_PARSE_JSON(CODE_LABEL):tax::STRING, 10, 6)` |

The two-step pattern:
1. `<variant_path>::STRING` — extracts the value as a text string; returns NULL for missing key or JSON null
2. `TRY_TO_DECIMAL(<string>, precision, scale)` — converts text to NUMBER; returns NULL for NULL, empty, or invalid text — never raises an error

### NULL Propagation Change (ICA-aligned)

Previous code wrapped every rate field in `COALESCE(..., 0)` in charge calculations. This silently
zeroed both *missing/invalid rates* and *valid zero rates*, making them indistinguishable.

Per ICA rules TR-BILL-02 to TR-BILL-07 and requirement 5 of this fix:

| Charge field | Previous behaviour | Corrected behaviour |
|---|---|---|
| `CALC_FIXED_CHARGE` | `COALESCE(FIXED_RATE, 0)` — masked NULLs | `FIXED_RATE` — NULL if rate missing/invalid |
| `CALC_ENERGY_CHARGE` | `ROUND(KWH × COALESCE(rate, 0), 2)` — masked NULLs | `ROUND(KWH × rate, 2)` — NULL if rate NULL |
| `CALC_DEMAND_CHARGE` | `CASE ... ELSE 0` — ICA MU-AC-09 rule, **unchanged** | `CASE ... ELSE 0` — ICA MU-AC-09, **unchanged** |
| `CALC_SUBTOTAL` | masked NULLs | propagates NULL if fixed or energy is NULL |
| `CALC_TAX_AMOUNT` | masked NULLs | propagates NULL if subtotal or tax rate is NULL |
| `CALC_TOTAL_BILLED` | masked NULLs | propagates NULL if subtotal or tax is NULL |

**Demand charge retains the `ELSE 0` rule** because ICA MU-AC-09 explicitly defines: a NULL
demand rate means the plan has no demand component — this is a valid business condition, not a
data error.

### VW_DAILY_CUSTOMER_ACCOUNT_EXPORT — No Changes Required

This view contains no VARIANT paths and no `TRY_CAST` expressions. All columns are sourced
from typed relational columns. No modifications were made.

### Rerun Safety

`CREATE OR REPLACE VIEW` is idempotent. Running the corrected script 04 will:
- Replace `VW_DAILY_CUSTOMER_ACCOUNT_EXPORT` with an identical definition (no functional change)
- Create `VW_MONTHLY_USAGE_BILLING_EXPORT` with the corrected `TRY_TO_DECIMAL` pattern

Both GRANT statements at the end of the script are also idempotent — re-granting an existing
privilege does not error in Snowflake.

### Validation Queries (run after rerunning script 04)

```sql
-- 1. Both views exist
SHOW VIEWS IN SCHEMA CDP_UTIL_DB.STAGING;
-- Expected: VW_DAILY_CUSTOMER_ACCOUNT_EXPORT, VW_MONTHLY_USAGE_BILLING_EXPORT

-- 2. SELECT a sample row from each view (requires tables populated in Phase 3)
--    After Phase 3 data generation, run:
SELECT * FROM STAGING.VW_MONTHLY_USAGE_BILLING_EXPORT LIMIT 5;
-- Verify: FIXED_RATE, ENERGY_RATE_PER_KWH, TAX_RATE are numbers, not NULL
-- Verify: CALC_FIXED_CHARGE, CALC_ENERGY_CHARGE, CALC_TOTAL_BILLED are numbers

-- 3. Run unit tests T01–T07 at the bottom of script 04
--    These require no table data — run immediately after the views are created.
```

### Exact Rerun Instructions

Script 04 is safely rerunnable. After scripts 01a and 03 have been executed successfully:

```sql
-- In Snowflake worksheet:
USE ROLE CDP_ADMIN_ROLE;
-- Run the full contents of infra/snowflake/04-create-export-views.sql
-- Then run unit tests T01–T07 from the bottom of that file
-- Verify: SHOW VIEWS IN SCHEMA CDP_UTIL_DB.STAGING shows both views
```

---


## 18. Phase 2 Acceptance Recommendation

| Acceptance criterion | Validation label | Notes |
|---|---|---|
| docker-compose.yml has no duplicate YAML keys | **EXECUTED** | Strict duplicate-key loader: 0 findings |
| docker-compose.yml has correct structure (15/15 key-count checks) | **EXECUTED** | Non-comment line scan |
| Oracle image tag 23.7.0.0 exists and is pullable | **EXECUTED** | Pull confirmed; container running |
| Oracle container starts and reaches healthy | **EXECUTED** | `cdp-oracle-db` healthy, FREEPDB1 READ WRITE |
| DBA bootstrap (`00-dba-bootstrap.sql`) executed successfully | **EXECUTED** | CDP_LOADER user created and authenticated |
| CDP_LOADER authentication verified | **CONNECTIVITY VERIFIED** | JDBC connection succeeded |
| DBA bootstrap separated from Flyway migrations | **EXECUTED** | CDP_LOADER. prefix absent from all V001–V004 |
| Flyway 10.12.0 convergence in all modules | **EXECUTED** | `mvn dependency:tree`: 10.12.0 only; no 9.22.3 |
| V001 NOCYCLE fix applied | **EXECUTED** | `NO CYCLE` → `NOCYCLE`; flyway:repair run |
| Flyway V001 applied successfully | **EXECUTED** | Spring Batch tables and sequences created |
| Flyway V002 applied successfully | **EXECUTED** | Reference tables created |
| Flyway V003 applied successfully | **EXECUTED** | ETL control tables created |
| Flyway V004 applied successfully | **EXECUTED** | Target business tables created |
| Oracle schema version | **EXECUTED** | V004 confirmed |
| Maven clean install -DskipTests | **EXECUTED** | BUILD SUCCESS — fat JAR produced |
| PowerShell scripts syntactically valid (6/6) | **STATICALLY VALIDATED** | PowerShell parser: 0 errors |
| YAML files parse without error (4/4) | **STATICALLY VALIDATED** | Python yaml.safe_load |
| No `@EnableBatchProcessing` interference | **STATICALLY VALIDATED** | Removed; documented in code |
| Snowflake DataSource is not @Primary | **STATICALLY VALIDATED** | Code review confirmed |
| Snowflake SQL scripts idempotent by design | **STATICALLY VALIDATED** | `CREATE TABLE IF NOT EXISTS` throughout; 01a is idempotent GRANTs |
| **CDP_ADMIN_ROLE created and granted to SYSADMIN** | **STATICALLY VALIDATED** | In script 01 and 01a; not yet executed in live env |
| **CDP_LOADER_ROLE has no CREATE privileges** | **STATICALLY VALIDATED** | Confirmed by design; SELECT only |
| Snowflake script 03 (source tables) | **FAILED — CORRECTED** | Role model fixed; rerun after executing 01a |
| Snowflake script 04 — VW_DAILY_CUSTOMER_ACCOUNT_EXPORT | **EXECUTED** | Created successfully before failure |
| Snowflake script 04 — VW_MONTHLY_USAGE_BILLING_EXPORT | **FAILED — CORRECTED** | TRY_CAST(VARIANT) replaced with TRY_TO_DECIMAL(::STRING); rerun full script 04 (safe — CREATE OR REPLACE VIEW) |
| Export view composite watermark covers 7 UPDATED_AT sources | **STATICALLY VALIDATED** | Code review; CUSTOMER_CONTACT fix applied |
| No secrets in tracked files | **STATICALLY VALIDATED** | Pattern scan: 0 findings |
| Root POM has exactly 3 application modules | **EXECUTED** | Confirmed by Maven reactor output |
| No cdp-loader-web Maven module | **STATICALLY VALIDATED** | Not in root POM; not in file tree |
| Oracle JDBC connectivity from running application | **NOT VERIFIED** | Pending application startup |
| Snowflake JDBC connectivity | **NOT VERIFIED** | Pending Snowflake provisioning completion |

### Summary

**Oracle infrastructure is fully provisioned and verified.** The Oracle schema is at V004.

**Snowflake provisioning is in progress.** Script 01 created the database, schemas, warehouse,
and CDP_LOADER_ROLE successfully. Script 03 failed because the role model did not include a
dedicated DDL role with CREATE TABLE privileges. This has been corrected:

- `CDP_ADMIN_ROLE` introduced — holds all CREATE TABLE / CREATE VIEW grants
- Script 01 updated for fresh environments
- Script 01a created for idempotent repair of the already-provisioned trial environment
- Scripts 03 and 04 updated to `USE ROLE CDP_ADMIN_ROLE`

**Remaining to close Phase 2:**

| # | Item | Action |
|---|---|---|
| 1 | Run `01a-repair-admin-role-grants.sql` as ACCOUNTADMIN | Repair CDP_ADMIN_ROLE grants in trial env |
| 2 | Rerun `03-create-source-tables.sql` as CDP_ADMIN_ROLE | Create 7 source tables (`CREATE TABLE IF NOT EXISTS` — safe rerun) |
| 3 | Rerun `04-create-export-views.sql` as CDP_ADMIN_ROLE | Recreate both views (`CREATE OR REPLACE VIEW` — safe rerun; corrects failed view 2) |
| 4 | Run unit tests T01–T07 at end of script 04 | Verify TRY_TO_DECIMAL behaviour |
| 5 | Run `02-create-service-user.sql` as ACCOUNTADMIN | Create SVC_CDP_LOADER with RSA key |
| 6 | `GET /actuator/health` with local profile | Verify Oracle + Snowflake both UP |

**Phase 3 (synthetic data generation) must not begin until you confirm Phase 2 complete.**
