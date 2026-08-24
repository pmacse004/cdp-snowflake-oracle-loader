# ICA Context Document 15 — Security and Sensitive Data Handling

**ICA Document ID:** ICA-15  
**Project:** CDP Snowflake to Oracle Data Loader  
**Version:** 1.0  
**Status:** Phase 1 — Approved  
**Last Updated:** 2025 (Phase 1)

---

## 1. Purpose

This document defines the authoritative security and sensitive-data-handling rules for the CDP Snowflake to Oracle Data Loader. These rules apply throughout the data pipeline, logging, error handling, API layer and dashboard.

---

## 2. Data Classification

| Classification | Definition | Examples in this project |
|---------------|------------|--------------------------|
| PII (Personally Identifiable Information) | Data that can be used to identify a specific individual | FIRST_NAME, LAST_NAME, MIDDLE_NAME, FULL_NAME, EMAIL_ADDRESS, PHONE_NUMBER, ADDRESS_LINE1, ADDRESS_LINE2 |
| Sensitive Business Data | Non-PII data that is commercially sensitive | BILLING_ACCOUNT_NUMBER |
| Operational Identifiers | Non-PII surrogate keys and codes | CUSTOMER_ID, ENERGY_ACCOUNT_ID, ACCOUNT_NUMBER, ERROR_CODE |
| Non-sensitive Business Data | All other business attributes | ACCOUNT_STATUS, KWH_USAGE, BILLING_MONTH, RATE_PLAN |
| Technical Data | ETL control data | Watermarks, job run IDs, error codes, counts |

---

## 3. PII Rules

| Rule ID | Rule |
|---------|------|
| SEC-PII-01 | PII fields (FIRST_NAME, LAST_NAME, MIDDLE_NAME, EMAIL_ADDRESS, PHONE_NUMBER, ADDRESS_LINE1, ADDRESS_LINE2) must never appear in application logs. |
| SEC-PII-02 | PII fields must not appear in the `PAYLOAD_EXCERPT` column of `ETL_RECORD_ERROR`. |
| SEC-PII-03 | Log masking patterns must be configured in the logging framework (Logback/Log4j2) for email and phone patterns. |
| SEC-PII-04 | Spring Batch skip/failure logging must use only the non-PII source record ID. |
| SEC-PII-05 | BILLING_ACCOUNT_NUMBER must not appear in application logs or error payloads. |
| SEC-PII-06 | The REST API must not expose PII in error responses. |
| SEC-PII-07 | PII may exist in the Oracle `CDP_APP` target tables (it is the purpose of the loader to store it there); access to these tables is controlled by Oracle grants. |

---

## 4. Credential Management

| Rule ID | Rule |
|---------|------|
| SEC-CRED-01 | No password, private key, access token or secret may be stored in source control (Git repository). |
| SEC-CRED-02 | The `.env` file is listed in `.gitignore` and must never be committed. |
| SEC-CRED-03 | The Snowflake private key file (`.p8`) must be stored only on the developer's local filesystem or a secrets manager in production. |
| SEC-CRED-04 | The Snowflake service user `SVC_CDP_LOADER` must authenticate exclusively with RSA key-pair. Password login must be disabled in Snowflake. |
| SEC-CRED-05 | The Oracle application user `CDP_LOADER_USER` connects with a password supplied via environment variable only. |
| SEC-CRED-06 | The `.env.template` file in source control contains only placeholder values and comments. |
| SEC-CRED-07 | Application configuration (`application.yml`) must reference only environment variable expressions: `${VARIABLE_NAME}`. |

---

## 5. Snowflake Least-Privilege

| Rule ID | Rule |
|---------|------|
| SEC-SF-01 | `SVC_CDP_LOADER` is granted only SELECT on the required source schemas (`CDP_DW.RAW`, `CDP_DW.CLEAN`, `CDP_DW.REF`). |
| SEC-SF-02 | No INSERT, UPDATE, DELETE, DROP or CREATE is granted to `SVC_CDP_LOADER`. |
| SEC-SF-03 | `SVC_CDP_LOADER` is assigned to `CDP_LOADER_ROLE` only; it must not have the SYSADMIN or ACCOUNTADMIN role. |
| SEC-SF-04 | The warehouse `CDP_LOADER_WH` is accessible only to `CDP_LOADER_ROLE`. |
| SEC-SF-05 | The human administrator's Snowflake username must not appear in any application configuration file. |

---

## 6. Oracle Least-Privilege

| Rule ID | Rule |
|---------|------|
| SEC-ORA-01 | `CDP_LOADER_USER` is granted SELECT, INSERT, UPDATE, DELETE on `CDP_APP`, `CDP_CTL` and `CDP_BATCH` tables only. |
| SEC-ORA-02 | `CDP_LOADER_USER` is NOT granted DBA, CREATE TABLE, CREATE INDEX, DROP TABLE or any DDL privilege. |
| SEC-ORA-03 | DDL is executed exclusively by Flyway using a separate migration user (or SYS equivalent during initial setup). |
| SEC-ORA-04 | In the development Docker environment, the Oracle `SYSTEM` password is set via Docker environment variable and is not stored in application code. |

---

## 7. API Security

| Rule ID | Rule |
|---------|------|
| SEC-API-01 | All REST API endpoints (except `/actuator/health`) require authentication. |
| SEC-API-02 | Development mode: HTTP Basic Authentication over localhost only. Credentials from environment variables. |
| SEC-API-03 | Production mode: OAuth 2.0 Bearer Token (JWT). |
| SEC-API-04 | CORS is restricted to the known frontend origin. |
| SEC-API-05 | HTTPS is required for all non-localhost connections. |
| SEC-API-06 | API responses must not expose raw Oracle or Snowflake error messages that could reveal schema or connection details. |

---

## 8. Logging Rules

| Rule ID | Rule |
|---------|------|
| SEC-LOG-01 | Log level: INFO for normal operation; DEBUG for development only (never in production). |
| SEC-LOG-02 | Structured JSON logging in production; human-readable in development. |
| SEC-LOG-03 | Every log line includes: timestamp (UTC), log level, job run ID (correlation), class name, message. |
| SEC-LOG-04 | PII values must never be interpolated into log messages. Use placeholders: `"Processing record ID: {}"` not `"Processing customer: John Smith"`. |
| SEC-LOG-05 | Log aggregates (counts, watermarks, durations) are encouraged; individual record data logging is restricted. |

---

## 9. Data in Transit

| Rule ID | Rule |
|---------|------|
| SEC-TLS-01 | All Snowflake JDBC connections use TLS (enforced by Snowflake). |
| SEC-TLS-02 | Oracle JDBC connections use TLS in non-localhost environments. |
| SEC-TLS-03 | All browser-to-API traffic uses HTTPS in non-localhost environments. |

---

## 10. Secret Scanning and Prevention

| Rule ID | Rule |
|---------|------|
| SEC-SCAN-01 | `.gitignore` excludes: `.env`, `*.p8`, `*.pem`, `*.key`, `*secret*`, `*private*`, `*password*`, `*credential*`. |
| SEC-SCAN-02 | A pre-commit PowerShell script (Phase 2) checks for common secret patterns before allowing commits. |
| SEC-SCAN-03 | Repository-level secret scanning (GitHub/GitLab) must be enabled. |

---

## 11. Demo Data Note

All source and target data in this demonstration is synthetic. No real customer PII, real utility proprietary data or real billing information is loaded. The PII handling rules above are implemented to demonstrate production-grade practices for actual deployments.
