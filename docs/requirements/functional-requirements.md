# Functional Requirements

**Document ID:** FR-001  
**Project:** CDP Snowflake to Oracle Data Loader  
**Version:** 1.0  
**Status:** Phase 1 — Approved for Architecture  
**Last Updated:** 2025 (Phase 1)

---

## 1. Overview

This document specifies the functional requirements for the CDP Snowflake to Oracle Data Loader. Requirements are grouped by capability area.

---

## 2. Data Extraction (Snowflake)

| ID | Requirement |
|----|-------------|
| FR-EX-01 | The system shall connect to Snowflake using JDBC with RSA key-pair authentication for the service user. |
| FR-EX-02 | The system shall extract customer, contact, energy account, billing account, service premise, meter, monthly usage and reference-data records from Snowflake source tables. |
| FR-EX-03 | For initial load, the system shall extract all eligible source records (no watermark filter). |
| FR-EX-04 | For incremental loads, the system shall extract only records where `UPDATED_AT > last_watermark_ts` OR (`UPDATED_AT = last_watermark_ts` AND `SOURCE_ID > last_watermark_id`). |
| FR-EX-05 | Extraction queries shall be ordered by `(UPDATED_AT ASC, SOURCE_ID ASC)` to ensure deterministic ordering. |
| FR-EX-06 | Extraction shall use a configurable chunk size (default 500 rows per fetch). |
| FR-EX-07 | The system shall log the number of records extracted per entity per job run. |
| FR-EX-08 | Extraction shall not modify source data in Snowflake. |

---

## 3. Data Transformation

| ID | Requirement |
|----|-------------|
| FR-TR-01 | The system shall apply all transformation rules defined in the ICA mapping catalogue before writing to Oracle. |
| FR-TR-02 | Customer names shall be normalised to title case (first and last name independently). |
| FR-TR-03 | Email addresses shall be lower-cased and validated against RFC 5322 format. |
| FR-TR-04 | Phone numbers shall be normalised to E.164 format (+1XXXXXXXXXX for US numbers). |
| FR-TR-05 | Account status codes shall be translated from source code values to target canonical codes per the reference translation table. |
| FR-TR-06 | All technical timestamps shall be converted to UTC before storage. |
| FR-TR-07 | Billing dates shall be stored as Oracle `DATE` with no time component. |
| FR-TR-08 | All monetary and usage values shall be handled as `BigDecimal` in Java and `NUMBER(18,6)` in Oracle. |
| FR-TR-09 | A derived `IS_ACTIVE` flag shall be set based on account status code translation. |
| FR-TR-10 | A derived `INACTIVATION_REASON` shall be populated when a record transitions to inactive or closed status. |
| FR-TR-11 | `BILL_TOTAL_AMOUNT` shall be recalculated as `ENERGY_CHARGE + TAX_AMOUNT` and the difference from the source value recorded if it exceeds $0.01. |

---

## 4. Data Loading (Oracle)

| ID | Requirement |
|----|-------------|
| FR-LD-01 | All target entity writes shall use Oracle `MERGE` statements (upsert on business key). |
| FR-LD-02 | The system shall perform loads in entity dependency order: reference data → customers → contacts → energy accounts → billing accounts → premises → meters → monthly usage. |
| FR-LD-03 | `CREATED_AT` shall be set only on INSERT; `UPDATED_AT` shall be set on both INSERT and UPDATE. |
| FR-LD-04 | Soft-deleted / inactivated records shall have `IS_ACTIVE = 0`, `DELETED_AT` set and `DELETION_REASON` populated; the row must not be physically deleted. |
| FR-LD-05 | The system shall write in configurable chunks; default chunk size is 500 rows per commit. |
| FR-LD-06 | Oracle Flyway migrations shall run at application startup and be idempotent. |
| FR-LD-07 | Spring Batch `JobRepository` tables (`BATCH_*`) shall be stored in the Oracle `CDP_BATCH` schema. |

---

## 5. Initial Load

| ID | Requirement |
|----|-------------|
| FR-IL-01 | An initial load job shall extract and load all entities from Snowflake to Oracle. |
| FR-IL-02 | The initial load shall be triggered manually from the dashboard or via a REST API call. |
| FR-IL-03 | On completion, the initial load shall populate `ETL_WATERMARK` with the maximum `(UPDATED_AT, SOURCE_ID)` seen per entity. |
| FR-IL-04 | Re-running the initial load shall not create duplicate records (idempotent via MERGE). |
| FR-IL-05 | After completion, the initial load shall insert a reconciliation record in `ETL_RECONCILIATION` for each entity. |

---

## 6. Daily Incremental Load

| ID | Requirement |
|----|-------------|
| FR-DI-01 | The daily incremental job shall read the last successful watermark from `ETL_WATERMARK` and extract only changed/new records. |
| FR-DI-02 | The watermark shall advance only after the associated step completes successfully and commits. |
| FR-DI-03 | On failure, the job shall leave the watermark unchanged so it can be safely restarted. |
| FR-DI-04 | The daily load shall handle: new customer records, customer-name updates, contact-information changes, new energy accounts, billing-account-number changes, premise changes, account closures, and soft inactivations. |
| FR-DI-05 | A configurable scheduler (cron expression) shall trigger the daily incremental load automatically. |
| FR-DI-06 | The scheduler shall be viewable and temporarily paused from the dashboard. |

---

## 7. Monthly Usage Load

| ID | Requirement |
|----|-------------|
| FR-MU-01 | The monthly usage job shall extract and load electricity usage and billing records for the target billing month(s). |
| FR-MU-02 | The business key for deduplication shall be `(ENERGY_ACCOUNT_ID, BILLING_MONTH)`. |
| FR-MU-03 | If a record with the same business key already exists and the incoming `UPDATED_AT` is later, the existing record shall be overwritten (correction). |
| FR-MU-04 | If a record with the same business key already exists and the incoming `UPDATED_AT` is equal or earlier, the record shall be skipped and counted as SKIPPED. |
| FR-MU-05 | After load, a reconciliation record shall compare source and target totals for KWH, KW and total billed amount. |

---

## 8. Error Handling

| ID | Requirement |
|----|-------------|
| FR-EH-01 | A record-level error shall not fail the containing step unless the configurable fatal-error threshold (default 5 %) is exceeded. |
| FR-EH-02 | Every rejected record shall be stored in `ETL_RECORD_ERROR` with: job name, run ID, source entity, source record ID, error code, error message, safe payload excerpt, and timestamp. |
| FR-EH-03 | Error codes shall follow the naming convention defined in ICA document 13. |
| FR-EH-04 | PII (names, email, phone) shall not appear in error payloads stored in the database. |
| FR-EH-05 | After the fatal threshold is exceeded, the step shall be marked FAILED and remaining unprocessed records of that step shall not be written. |
| FR-EH-06 | The job framework shall support restart: on re-run, successfully committed steps shall be skipped and failed steps shall resume from the last committed chunk. |

---

## 9. Control Tables

| ID | Requirement |
|----|-------------|
| FR-CT-01 | `ETL_WATERMARK` shall store the last successful `(UPDATED_AT, SOURCE_ID)` watermark per entity and job type. |
| FR-CT-02 | `ETL_JOB_RUN` shall record each job execution with start time, end time, status, records read/inserted/updated/skipped/rejected and watermark values. |
| FR-CT-03 | `ETL_RECORD_ERROR` shall store rejected records as described in FR-EH-02. |
| FR-CT-04 | `ETL_RECONCILIATION` shall store source vs. target record counts and aggregate totals (KWH, KW, billed amount) per entity per job run. |

---

## 10. REST API

| ID | Requirement |
|----|-------------|
| FR-API-01 | `POST /api/v1/jobs/initial-load` — trigger the initial load job. |
| FR-API-02 | `POST /api/v1/jobs/daily-load` — trigger a daily incremental load. |
| FR-API-03 | `POST /api/v1/jobs/monthly-load` — trigger a monthly usage load. |
| FR-API-04 | `GET /api/v1/jobs` — list all job runs with status and summary counts. |
| FR-API-05 | `GET /api/v1/jobs/{runId}` — get detailed job-run information. |
| FR-API-06 | `GET /api/v1/watermarks` — list current watermarks for all entities. |
| FR-API-07 | `GET /api/v1/errors` — list error records with pagination and filtering. |
| FR-API-08 | `GET /api/v1/reconciliation` — list reconciliation records. |
| FR-API-09 | `GET /api/v1/reconciliation/{runId}` — reconciliation detail for a specific run. |
| FR-API-10 | `GET /api/v1/health` — application, Snowflake and Oracle health status. |
| FR-API-11 | `GET /api/v1/mappings` — return the mapping catalogue. |
| FR-API-12 | `GET /api/v1/scheduler` — return scheduler configuration and status. |
| FR-API-13 | `PUT /api/v1/scheduler/pause` — pause automatic scheduling. |
| FR-API-14 | `PUT /api/v1/scheduler/resume` — resume automatic scheduling. |
| FR-API-15 | `GET /api/v1/reports/{runId}/download` — download a run/reconciliation report as CSV or PDF. |

---

## 11. Dashboard

| ID | Requirement |
|----|-------------|
| FR-UI-01 | The dashboard shall allow users to trigger initial, daily and monthly jobs. |
| FR-UI-02 | The dashboard shall display running, successful and failed jobs with record counts and durations. |
| FR-UI-03 | The dashboard shall display previous and current watermarks per entity. |
| FR-UI-04 | The dashboard shall show a job execution history table. |
| FR-UI-05 | The dashboard shall show error records with pagination and ability to view error detail. |
| FR-UI-06 | The dashboard shall show source vs. target record-count reconciliation and aggregate KWH, KW and billed totals. |
| FR-UI-07 | The dashboard shall show active and inactive customer/account counts. |
| FR-UI-08 | The dashboard shall show Snowflake, Oracle and application health indicators. |
| FR-UI-09 | The dashboard shall display the mapping catalogue in a searchable table. |
| FR-UI-10 | The dashboard shall allow downloading a run/reconciliation report. |
| FR-UI-11 | The dashboard shall show scheduler configuration and allow pause/resume. |
| FR-UI-12 | The dashboard shall be responsive and usable on 1280px+ desktop screens. |

---

## 12. Scheduling

| ID | Requirement |
|----|-------------|
| FR-SC-01 | The daily load cron expression shall be configurable via `application.yml`. |
| FR-SC-02 | The monthly load cron expression shall be configurable via `application.yml`. |
| FR-SC-03 | The scheduler shall prevent concurrent runs of the same job type. |
| FR-SC-04 | The scheduler configuration (cron, enabled/disabled, last/next run) shall be exposed via API. |

---

## 13. Health and Observability

| ID | Requirement |
|----|-------------|
| FR-OB-01 | Spring Boot Actuator shall expose `/actuator/health`, `/actuator/info` and `/actuator/metrics`. |
| FR-OB-02 | Custom health indicators shall report Snowflake connectivity and Oracle connectivity. |
| FR-OB-03 | Application logs shall use structured JSON format in production mode and readable format in development mode. |
| FR-OB-04 | Every job run shall be logged with run ID, entity, step, record counts and elapsed time. |
