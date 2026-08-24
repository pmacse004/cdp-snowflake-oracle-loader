# Non-Functional Requirements

**Document ID:** NFR-001  
**Project:** CDP Snowflake to Oracle Data Loader  
**Version:** 1.0  
**Status:** Phase 1 — Approved for Architecture  
**Last Updated:** 2025 (Phase 1)

---

## 1. Performance

| ID | Requirement | Target |
|----|-------------|--------|
| NFR-P-01 | Initial load throughput | ≥ 5,000 customer records/minute end-to-end on dev hardware |
| NFR-P-02 | Daily incremental load — 1,000 changed records | Complete within 5 minutes |
| NFR-P-03 | Monthly usage load — 1,000 records | Complete within 3 minutes |
| NFR-P-04 | REST API response time (non-streaming) | ≤ 500 ms at p95 |
| NFR-P-05 | Dashboard initial page load | ≤ 3 seconds on local network |
| NFR-P-06 | Scalability target | Design must support ~1 million customers without redesign (chunk size, partitioned tables, Snowflake pagination) |

---

## 2. Reliability and Availability

| ID | Requirement |
|----|-------------|
| NFR-R-01 | A failed step shall leave the watermark unchanged, enabling safe restart. |
| NFR-R-02 | Re-running any load type shall produce the same target state as running it once (idempotency). |
| NFR-R-03 | A single bad record shall not abort the step unless the fatal-error threshold is exceeded. |
| NFR-R-04 | The fatal-error threshold shall be configurable (default: 5 % of records in a chunk). |
| NFR-R-05 | Spring Batch shall manage job state in Oracle so restarts survive application restarts. |

---

## 3. Scalability

| ID | Requirement |
|----|-------------|
| NFR-S-01 | Batch chunk size shall be configurable; default 500 rows. |
| NFR-S-02 | Oracle target tables shall include a `PARTITION_KEY` design column for future LIST/RANGE partitioning by utility region or billing month without schema redesign. |
| NFR-S-03 | Snowflake extraction queries shall use `LIMIT`/`OFFSET` or cursor-based pagination so memory consumption does not grow with table size. |
| NFR-S-04 | JDBC fetch size shall be configurable; default 500 rows. |
| NFR-S-05 | The application shall not require more than 2 GB heap for the 10,000-customer demo workload. |

---

## 4. Security

| ID | Requirement |
|----|-------------|
| NFR-SEC-01 | No password, private key, token or secret shall appear in source control. |
| NFR-SEC-02 | Snowflake connection shall use RSA key-pair authentication (no password). |
| NFR-SEC-03 | Oracle credentials shall be supplied via environment variables or a `.env` file excluded by `.gitignore`. |
| NFR-SEC-04 | The Snowflake service user shall be a dedicated least-privilege account (`SVC_CDP_LOADER`) with read-only access to source objects. |
| NFR-SEC-05 | PII (customer names, email addresses, phone numbers) shall not appear in application logs. |
| NFR-SEC-06 | Error payloads stored in `ETL_RECORD_ERROR` shall contain only non-PII identifiers and structured error information. |
| NFR-SEC-07 | The REST API shall be protected by at minimum HTTP Basic authentication in dev mode; OAuth 2.0 token-based auth shall be the target for production. |
| NFR-SEC-08 | HTTPS shall be used for all external API and dashboard traffic in non-local environments. |

---

## 5. Maintainability

| ID | Requirement |
|----|-------------|
| NFR-M-01 | Oracle schema changes shall be managed exclusively by Flyway migration scripts; no ad-hoc DDL. |
| NFR-M-02 | All transformation and validation logic shall be implemented in named, unit-testable Java classes or static methods. |
| NFR-M-03 | Mapping rules shall be traceable to ICA mapping IDs in code comments and/or annotations. |
| NFR-M-04 | Configuration (chunk size, cron, thresholds, DB URLs) shall be externalised in `application.yml`; no hard-coded values in Java. |
| NFR-M-05 | The codebase shall follow standard Maven directory conventions and Java naming conventions. |
| NFR-M-06 | All public APIs shall be documented with OpenAPI / Swagger annotations. |

---

## 6. Testability

| ID | Requirement |
|----|-------------|
| NFR-T-01 | Unit test coverage for transformation and validation logic shall be ≥ 80 %. |
| NFR-T-02 | Spring Batch integration tests shall use an embedded H2 database for `JobRepository`; a separate Oracle integration test profile shall target a real Oracle instance. |
| NFR-T-03 | REST API tests shall use Spring's `MockMvc` framework. |
| NFR-T-04 | Frontend component tests shall use Vitest and React Testing Library. |
| NFR-T-05 | End-to-end tests shall cover: initial load, daily incremental, monthly usage, error threshold, restart and reconciliation scenarios. |
| NFR-T-06 | A performance test shall verify throughput with at least 10,000 customers. |
| NFR-T-07 | Test reports (Surefire XML + HTML, JaCoCo coverage) shall be generated on every build. |

---

## 7. Observability and Operations

| ID | Requirement |
|----|-------------|
| NFR-O-01 | All log messages shall include a correlation ID (job run ID) for traceability. |
| NFR-O-02 | Application shall expose `/actuator/health` (liveness + readiness), `/actuator/info` and `/actuator/metrics`. |
| NFR-O-03 | Custom health indicators for Snowflake and Oracle connectivity shall be included. |
| NFR-O-04 | Batch job metrics (records read, written, skipped, elapsed time) shall be written to `ETL_JOB_RUN` at step completion. |
| NFR-O-05 | Application shall start within 60 seconds on the development machine. |

---

## 8. Portability

| ID | Requirement |
|----|-------------|
| NFR-PO-01 | The application shall run as a standalone Spring Boot fat JAR without an external application server. |
| NFR-PO-02 | The application shall be deployable to Open Liberty with minimal changes (add `server.xml`, no code changes). |
| NFR-PO-03 | Docker Compose shall manage the Oracle database instance; a single `docker compose up` command shall start Oracle. |
| NFR-PO-04 | All shell automation shall be provided as PowerShell scripts compatible with Windows 11 + PowerShell 7. |

---

## 9. Data Integrity

| ID | Requirement |
|----|-------------|
| NFR-DI-01 | All Oracle writes shall occur within transactions; a chunk failure shall roll back only the failed chunk. |
| NFR-DI-02 | Referential integrity shall be enforced in Oracle via foreign-key constraints on all child tables. |
| NFR-DI-03 | All target tables shall have non-nullable `CREATED_AT` and `UPDATED_AT` audit columns. |
| NFR-DI-04 | Reconciliation figures shall be written to `ETL_RECONCILIATION` before the job completes. |
| NFR-DI-05 | `BigDecimal` scale shall be set to 6 for usage values and 2 for monetary values throughout the processing pipeline. |

---

## 10. Compliance

| ID | Requirement |
|----|-------------|
| NFR-C-01 | Demonstration data must be entirely synthetic; no real customer PII or proprietary data. |
| NFR-C-02 | The solution design must not reproduce any real utility's proprietary database schema. |
| NFR-C-03 | ICA Context Studio is the authoritative source of mapping and transformation governance; the running application shall not connect to ICA at runtime. |
