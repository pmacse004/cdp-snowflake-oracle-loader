# Repository Structure

**Document ID:** PROJ-001  
**Project:** CDP Snowflake to Oracle Data Loader  
**Version:** 1.0  
**Status:** Phase 1 — Proposed  
**Last Updated:** 2025 (Phase 1)

---

## Proposed Final Repository Layout

```
cdp-snowflake-oracle-loader/
│
├── README.md                                # Project overview and quick start
├── .env.template                            # Environment variable template (no secrets)
├── .gitignore                               # Excludes .env, *.p8, *.key, target/, node_modules/
├── docker-compose.yml                       # Oracle DB Free container
│
├── docs/                                    # All documentation
│   ├── requirements/
│   │   ├── business-requirements.md
│   │   ├── functional-requirements.md
│   │   └── non-functional-requirements.md
│   ├── architecture/
│   │   ├── solution-architecture.md
│   │   ├── data-flow.md
│   │   ├── security-design.md
│   │   └── architecture-decisions.md
│   ├── data-model/
│   │   ├── source-data-model.md
│   │   ├── target-data-model.md
│   │   └── entity-relationships.md
│   ├── ica-context/
│   │   ├── 01-business-glossary.md
│   │   ├── 02-source-data-dictionary.md
│   │   ├── 03-target-data-dictionary.md
│   │   ├── 04-entity-level-mappings.md
│   │   ├── 05-column-level-mappings.md
│   │   ├── 06-transformation-rules.md
│   │   ├── 07-validation-rules.md
│   │   ├── 08-reference-code-translations.md
│   │   ├── 09-incremental-loading-watermark-rules.md
│   │   ├── 10-initial-load-rules.md
│   │   ├── 11-daily-load-rules.md
│   │   ├── 12-monthly-usage-rules.md
│   │   ├── 13-error-handling-rules.md
│   │   ├── 14-reconciliation-rules.md
│   │   ├── 15-security-sensitive-data.md
│   │   ├── 16-nonfunctional-scalability.md
│   │   ├── mapping-catalogue.yaml           # Machine-readable mapping catalogue
│   │   └── mapping-catalogue.md             # Human-readable mapping catalogue
│   └── project/
│       ├── repository-structure.md          # This file
│       ├── implementation-backlog.md
│       └── assumptions-risks-decisions.md
│
├── scripts/                                 # PowerShell automation scripts
│   ├── snowflake/
│   │   ├── 01-create-warehouse.sql          # Snowflake provisioning SQL (not yet created)
│   │   ├── 02-create-database-schemas.sql
│   │   ├── 03-create-role-user.sql
│   │   ├── 04-grant-privileges.sql
│   │   ├── 05-generate-data.sql             # Synthetic data generation
│   │   └── provision-snowflake.ps1          # PowerShell wrapper
│   ├── oracle/
│   │   ├── create-schemas-users.sql         # Oracle user/schema creation
│   │   └── provision-oracle.ps1
│   └── db/
│       └── migrate.ps1                      # Run Flyway migrations
│
├── backend/                                 # Spring Boot application (Maven)
│   ├── pom.xml
│   ├── mvnw                                 # Maven wrapper
│   ├── mvnw.cmd
│   ├── src/
│   │   ├── main/
│   │   │   ├── java/
│   │   │   │   └── com/cdp/loader/
│   │   │   │       ├── CdpLoaderApplication.java
│   │   │   │       ├── config/
│   │   │   │       │   ├── BatchConfig.java           # Spring Batch job/step beans
│   │   │   │       │   ├── DatabaseConfig.java        # DataSource beans (Snowflake + Oracle)
│   │   │   │       │   ├── FlywayConfig.java
│   │   │   │       │   └── SecurityConfig.java
│   │   │   │       ├── batch/
│   │   │   │       │   ├── job/
│   │   │   │       │   │   ├── InitialLoadJob.java
│   │   │   │       │   │   ├── DailyIncrementalJob.java
│   │   │   │       │   │   └── MonthlyUsageJob.java
│   │   │   │       │   ├── reader/
│   │   │   │       │   │   ├── SnowflakeCustomerReader.java
│   │   │   │       │   │   ├── SnowflakeEnergyAccountReader.java
│   │   │   │       │   │   └── ...
│   │   │   │       │   ├── processor/
│   │   │   │       │   │   ├── CustomerProcessor.java
│   │   │   │       │   │   ├── CustomerContactProcessor.java
│   │   │   │       │   │   └── ...
│   │   │   │       │   ├── writer/
│   │   │   │       │   │   ├── CustomerWriter.java
│   │   │   │       │   │   └── ...
│   │   │   │       │   └── listener/
│   │   │   │       │       ├── JobRunListener.java
│   │   │   │       │       └── WatermarkStepListener.java
│   │   │   │       ├── transform/
│   │   │   │       │   ├── FlagTransformer.java       # TR-01
│   │   │   │       │   ├── NameTransformer.java       # TR-02, TR-03
│   │   │   │       │   ├── StatusTransformer.java     # TR-04, TR-05
│   │   │   │       │   ├── ContactTransformer.java    # TR-06, TR-07
│   │   │   │       │   ├── BillingTransformer.java    # TR-10, TR-11
│   │   │   │       │   ├── DateTransformer.java       # TR-DATE-01, TR-TS-01
│   │   │   │       │   └── DecimalTransformer.java    # TR-DEC-01, TR-DEC-02
│   │   │   │       ├── validation/
│   │   │   │       │   ├── CustomerValidator.java
│   │   │   │       │   ├── ContactValidator.java
│   │   │   │       │   ├── UsageValidator.java
│   │   │   │       │   └── ...
│   │   │   │       ├── fk/
│   │   │   │       │   ├── FkResolutionService.java   # TR-FK-01
│   │   │   │       │   └── FkCache.java
│   │   │   │       ├── watermark/
│   │   │   │       │   ├── WatermarkService.java
│   │   │   │       │   └── WatermarkRepository.java
│   │   │   │       ├── model/
│   │   │   │       │   ├── source/                    # Snowflake row POJOs
│   │   │   │       │   │   ├── SourceCustomer.java
│   │   │   │       │   │   └── ...
│   │   │   │       │   └── target/                    # Oracle target POJOs
│   │   │   │       │       ├── TargetCustomer.java
│   │   │   │       │       └── ...
│   │   │   │       ├── repository/
│   │   │   │       │   ├── JobRunRepository.java
│   │   │   │       │   ├── RecordErrorRepository.java
│   │   │   │       │   └── ReconciliationRepository.java
│   │   │   │       ├── service/
│   │   │   │       │   ├── JobLaunchService.java
│   │   │   │       │   ├── ReconciliationService.java
│   │   │   │       │   └── MappingCatalogueService.java
│   │   │   │       ├── api/
│   │   │   │       │   ├── JobController.java         # FR-API-01 to 15
│   │   │   │       │   ├── WatermarkController.java
│   │   │   │       │   ├── ErrorController.java
│   │   │   │       │   ├── ReconciliationController.java
│   │   │   │       │   ├── SchedulerController.java
│   │   │   │       │   └── MappingController.java
│   │   │   │       ├── scheduler/
│   │   │   │       │   └── BatchScheduler.java
│   │   │   │       └── health/
│   │   │   │           ├── SnowflakeHealthIndicator.java
│   │   │   │           └── OracleHealthIndicator.java
│   │   │   └── resources/
│   │   │       ├── application.yml
│   │   │       ├── application-dev.yml
│   │   │       ├── application-prod.yml
│   │   │       ├── static/                            # React build output (Phase 5)
│   │   │       └── db/
│   │   │           └── migration/
│   │   │               ├── V1__create_cdp_app_schema.sql
│   │   │               ├── V2__create_cdp_ctl_schema.sql
│   │   │               ├── V3__create_indexes.sql
│   │   │               ├── V4__seed_watermarks.sql
│   │   │               └── V5__seed_reference_data.sql
│   │   └── test/
│   │       └── java/com/cdp/loader/
│   │           ├── transform/
│   │           │   ├── NameTransformerTest.java
│   │           │   ├── StatusTransformerTest.java
│   │           │   ├── ContactTransformerTest.java
│   │           │   └── BillingTransformerTest.java
│   │           ├── validation/
│   │           │   ├── CustomerValidatorTest.java
│   │           │   └── UsageValidatorTest.java
│   │           ├── batch/
│   │           │   ├── InitialLoadJobTest.java
│   │           │   ├── DailyLoadJobTest.java
│   │           │   └── MonthlyUsageJobTest.java
│   │           ├── api/
│   │           │   ├── JobControllerTest.java
│   │           │   └── ReconciliationControllerTest.java
│   │           └── integration/
│   │               ├── FullInitialLoadIT.java
│   │               └── WatermarkBoundaryIT.java
│
├── frontend/                                # React/TypeScript dashboard
│   ├── package.json
│   ├── vite.config.ts
│   ├── tsconfig.json
│   ├── tailwind.config.ts
│   ├── index.html
│   ├── public/
│   └── src/
│       ├── main.tsx
│       ├── App.tsx
│       ├── api/
│       │   ├── client.ts                   # Axios typed API client
│       │   ├── jobs.ts
│       │   ├── watermarks.ts
│       │   ├── errors.ts
│       │   ├── reconciliation.ts
│       │   └── health.ts
│       ├── components/
│       │   ├── dashboard/
│       │   │   ├── JobControlPanel.tsx
│       │   │   ├── JobRunHistory.tsx
│       │   │   ├── WatermarkDisplay.tsx
│       │   │   ├── KpiCards.tsx
│       │   │   └── ReconciliationSummary.tsx
│       │   ├── charts/
│       │   │   ├── RecordCountChart.tsx
│       │   │   └── ThroughputChart.tsx
│       │   ├── errors/
│       │   │   └── ErrorTable.tsx
│       │   └── common/
│       │       ├── StatusBadge.tsx
│       │       └── HealthIndicator.tsx
│       ├── pages/
│       │   ├── Dashboard.tsx
│       │   ├── Jobs.tsx
│       │   ├── Errors.tsx
│       │   ├── Reconciliation.tsx
│       │   ├── Mappings.tsx
│       │   └── Health.tsx
│       └── tests/
│           ├── JobControlPanel.test.tsx
│           └── ReconciliationSummary.test.tsx
│
└── e2e/                                     # End-to-end tests (Phase 6)
    ├── playwright.config.ts
    └── tests/
        ├── initial-load.spec.ts
        ├── daily-load.spec.ts
        └── monthly-usage.spec.ts
```

---

## File Count by Phase

| Phase | New Files / Directories |
|-------|------------------------|
| Phase 1 (current) | 33 documentation files |
| Phase 2 | ~15 (docker-compose, scripts, pom.xml scaffold, .env.template) |
| Phase 3 | ~5 (data generator SQL scripts) |
| Phase 4 | ~60 (Java source: jobs, readers, processors, writers, transformers, validators) |
| Phase 5 | ~40 (REST controllers, React components, pages) |
| Phase 6 | ~20 (test files) |
| Phase 7 | ~10 (Open Liberty server.xml, hardening scripts) |

---

## Conventions

| Convention | Rule |
|-----------|------|
| Java packages | `com.cdp.loader.*` |
| Java class names | PascalCase; suffix by role (Reader, Processor, Writer, Transformer, Validator, Controller, Service, Repository) |
| Test class names | Mirror source class + `Test` or `IT` suffix (IT = integration test) |
| SQL migrations | `V{n}__{description}.sql` — Flyway naming convention |
| React components | PascalCase `.tsx` files |
| API endpoints | `/api/v1/{resource}` |
| Environment variables | SCREAMING_SNAKE_CASE |
