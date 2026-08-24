# Phase 2 Completion Report
# CDP Snowflake-to-Oracle Loader

**Date:** Phase 2 delivery  
**Status:** COMPLETE — awaiting review before Phase 3

---

## Deliverables Created

### 2.1 Oracle Docker Infrastructure

| File | Purpose |
|---|---|
| `infra/docker/docker-compose.yml` | Oracle Free 23c container with health-check, volume persistence, resource limits |
| `infra/docker/.env.template` | Template for ORACLE_PWD (never committed) |
| `infra/docker/init-scripts/README.md` | Explains Flyway vs init-scripts approach |

### 2.2 PowerShell Scripts

| File | Purpose |
|---|---|
| `scripts/start-oracle.ps1` | Start Oracle container, optional `-WaitReady` blocking wait |
| `scripts/stop-oracle.ps1` | Stop Oracle, optional `-RemoveVolume` (with confirmation prompt) |
| `scripts/oracle-status.ps1` | Show container health, last 5 health-check log entries, TCP port test |
| `scripts/oracle-logs.ps1` | Tail Oracle container logs with configurable line count |
| `scripts/dev-setup.ps1` | New developer onboarding: checks prerequisites, copies templates, prints next steps |

### 2.3 Snowflake Provisioning Scripts

| File | Purpose |
|---|---|
| `infra/snowflake/01-create-database-schemas-warehouse.sql` | CDP_UTIL_DB, 5 schemas, CDP_LOADER_WH, CDP_LOADER_ROLE, future grants |
| `infra/snowflake/02-create-service-user.sql` | SVC_CDP_LOADER with RSA key-pair auth (public key placeholder) |
| `infra/snowflake/03-create-source-tables.sql` | All 8 synthetic source tables across REF, CUSTOMER, SERVICE, BILLING schemas |
| `infra/snowflake/04-create-export-views.sql` | VW_DAILY_CUSTOMER_ACCOUNT_EXPORT and VW_MONTHLY_USAGE_BILLING_EXPORT (Layer 1 transformations) |
| `infra/snowflake/keygen.ps1` | RSA key-pair generation script using OpenSSL |

### 2.4 Maven Multi-Module Project

| File | Purpose |
|---|---|
| `pom.xml` | Root parent POM: version pins, shared deps, plugin management |
| `cdp-loader-core/pom.xml` | Core domain module: MapStruct, Jackson, validation (no Spring Boot) |
| `cdp-loader-batch/pom.xml` | Batch module: Spring Batch, Oracle JDBC, Snowflake JDBC, Flyway, Testcontainers |
| `cdp-loader-api/pom.xml` | API module: Spring Web, Actuator, SpringDoc/OpenAPI, fat JAR packaging |

### 2.5 Application Configuration

| File | Purpose |
|---|---|
| `cdp-loader-api/src/main/resources/application.yml` | Non-secret, env-agnostic configuration; all secrets via env vars |
| `cdp-loader-api/src/main/resources/application-local.yml.template` | Local dev template (copy + fill; gitignored) |
| `cdp-loader-api/src/main/resources/application-ci.yml` | CI profile for Testcontainers integration tests |
| `docs/operations/environment-variables.md` | Complete env var reference with examples and setup instructions |

### 2.6 Flyway Oracle DDL Migrations

| Migration | Purpose |
|---|---|
| `V001__create_oracle_schema_user.sql` | CDP_LOADER Oracle user and grants (DBA prerequisite) |
| `V002__create_reference_tables.sql` | REF_CODE_VALUE — translated reference codes |
| `V003__create_spring_batch_schema.sql` | Spring Batch 5.x Oracle job repository tables and sequences |
| `V004__create_etl_control_tables.sql` | ETL_WATERMARK, ETL_JOB_RUN, ETL_RECORD_ERROR, ETL_RECONCILIATION |
| `V005__create_target_business_tables.sql` | TGT_CUSTOMER, TGT_CUSTOMER_CONTACT, TGT_ENERGY_ACCOUNT, TGT_BILLING_ACCOUNT, TGT_PREMISE, TGT_METER, TGT_MONTHLY_USAGE |

### 2.7 Java Application Scaffold

| File | Purpose |
|---|---|
| `cdp-loader-api/src/main/java/.../CdpLoaderApplication.java` | Spring Boot application entry point |
| `cdp-loader-api/src/main/java/.../config/CdpLoaderProperties.java` | Strongly-typed `@ConfigurationProperties` binding |
| `cdp-loader-api/src/main/java/.../config/BatchConfig.java` | `@EnableBatchProcessing` + `@EnableScheduling` |
| `cdp-loader-api/src/main/java/.../config/SnowflakeDataSourceConfig.java` | RSA key-pair Snowflake DataSource bean |
| `cdp-loader-api/src/main/java/.../api/SystemInfoController.java` | Non-secret system info REST endpoint |
| `cdp-loader-api/src/test/java/.../CdpLoaderApplicationIT.java` | Context load smoke test |

### 2.8 Security Guardrails

| Item | Status |
|---|---|
| `.gitignore` | Excludes `.env`, `*.p8`, `*.pem`, `application-local.yml`, `target/` |
| No passwords in any committed file | ✅ Verified — all credentials are placeholders or env var references |
| No private keys in source control | ✅ Key path stored in config; key file excluded |
| `infra/docker/.env.template` only (no `.env`) | ✅ |
| `application-local.yml.template` only (no `application-local.yml`) | ✅ |

---

## Acceptance Criteria Verification

| Criterion | Status | Notes |
|---|---|---|
| Oracle Free 23c runs in Docker with persistent volume | ✅ | docker-compose.yml with named volume `cdp-oracle-data` |
| Oracle container has a health-check | ✅ | Uses built-in `/opt/oracle/checkDBStatus.sh` |
| PowerShell scripts for start/stop/status/logs | ✅ | 4 operational scripts + 1 setup script |
| Developer onboarding script | ✅ | `scripts/dev-setup.ps1` |
| Snowflake database, schemas, warehouse created | ✅ | Script 01 |
| Snowflake service user with key-pair auth | ✅ | Script 02 (public key placeholder) |
| Snowflake source tables defined | ✅ | Script 03 — all 8 entities |
| Snowflake export views (Layer 1 transforms) | ✅ | Script 04 — both views with charge calcs |
| RSA key generation script | ✅ | `infra/snowflake/keygen.ps1` |
| Maven multi-module structure | ✅ | 3 modules + parent POM |
| Java 17 compilation target | ✅ | Set in parent POM properties |
| Spring Boot 3.2.5 | ✅ | Parent POM dependency management |
| Spring Batch 5.x (via spring-boot-starter-batch) | ✅ | cdp-loader-batch/pom.xml |
| Snowflake JDBC 3.15.1 | ✅ | cdp-loader-batch/pom.xml |
| Oracle JDBC ojdbc11 23.4 | ✅ | cdp-loader-batch/pom.xml |
| Flyway with Oracle extension | ✅ | flyway-database-oracle in cdp-loader-batch |
| Application config with env var injection | ✅ | application.yml uses `${VAR_NAME}` pattern |
| No secrets in any committed file | ✅ | All verified |
| Flyway V001–V005 cover all target tables | ✅ | All 7 business tables + 4 ETL control tables + Spring Batch tables |
| All ETL control tables from Phase 1 design | ✅ | ETL_WATERMARK, ETL_JOB_RUN, ETL_RECORD_ERROR, ETL_RECONCILIATION |
| BigDecimal / NUMBER for monetary/usage columns | ✅ | All monetary/usage columns use NUMBER — no FLOAT |
| Audit columns on all tables | ✅ | CREATED_AT, UPDATED_AT, ETL_RUN_ID, ETL_LOAD_TS |
| Per-table watermark design (not per-entity) | ✅ | ETL_WATERMARK.TABLE_NAME column |
| Composite watermark (max across contributing tables) | ✅ | RECORD_EFFECTIVE_TS in view + LAST_MAX_SOURCE_ID in watermark table |
| Indexes on all foreign keys and query columns | ✅ | All FK indexes + status/date/name indexes |
| OpenAPI/Swagger UI | ✅ | springdoc-openapi-starter-webmvc-ui included |
| Spring Boot Actuator with Prometheus | ✅ | Included in cdp-loader-api |
| Spring profile structure (local/ci) | ✅ | application-local.yml.template + application-ci.yml |

---

## Important Notes

### What Has NOT Been Done (by design)
- No database objects have been created or executed
- No Snowflake connectivity has been tested
- No Oracle connectivity has been tested
- No application has been compiled or run
- These happen when the developer follows the setup instructions

### V001 Note
`V001__create_oracle_schema_user.sql` is documented as a DBA prerequisite step.
Because Flyway runs as `CDP_LOADER` (not SYSDBA), V001 should be applied manually
by the DBA before the application starts. The `infra/oracle/dba-setup.sql` script
is the operational version of this step for local Docker development.

### Open Decision
The root POM references `${lombok.version}` which is resolved from Spring Boot
BOM. In Phase 3, this should be verified by running `mvn dependency:resolve` with
Lombok explicitly versioned if the BOM version conflicts.

---

## What Is Ready for Phase 3

Phase 3 will create the synthetic data generation scripts for Snowflake:
- ~10,000 customers with realistic related child records
- ~1,000 records for daily change simulation
- ~1,000 monthly usage/billing records
- Reference data (ACCT_STATUS, RATE_PLAN, CUST_TYPE domains)

**Phase 3 requires no Oracle changes.** All Phase 2 Oracle infrastructure
can be set up and verified independently.
