# Security Design

**Document ID:** ARCH-003  
**Project:** CDP Snowflake to Oracle Data Loader  
**Version:** 1.0  
**Status:** Phase 1 — Approved  
**Last Updated:** 2025 (Phase 1)

---

## 1. Security Principles

1. **Zero secrets in source control** — no passwords, tokens, private keys or connection strings ever committed.
2. **Least privilege** — every system actor has the minimum permissions required for its function.
3. **PII protection** — customer PII must not appear in logs or error tables.
4. **Defence in depth** — credentials, network, authentication and authorization are each independently secured.
5. **Auditability** — all load events, errors and data changes are recorded with timestamps and actor identity.

---

## 2. Credential Management

### 2.1 Environment Variables

All secrets are supplied at runtime via environment variables or a `.env` file. The `.env` file is listed in `.gitignore` and must never be committed.

A `.env.template` file (no real values) is provided in source control:

```dotenv
# .env.template — copy to .env and fill in values
# NEVER commit .env to source control

# Oracle
ORACLE_JDBC_URL=jdbc:oracle:thin:@localhost:1521/FREEPDB1
ORACLE_USERNAME=<placeholder>
ORACLE_PASSWORD=<placeholder>

# Snowflake
SNOWFLAKE_ACCOUNT=LJPNAFI-RW79936
SNOWFLAKE_USER=SVC_CDP_LOADER
SNOWFLAKE_PRIVATE_KEY_PATH=<absolute-path-to-rsa_key.p8>
SNOWFLAKE_PRIVATE_KEY_PASSPHRASE=<placeholder-or-empty-if-unencrypted>
SNOWFLAKE_WAREHOUSE=CDP_LOADER_WH
SNOWFLAKE_DATABASE=CDP_DW
SNOWFLAKE_ROLE=CDP_LOADER_ROLE

# Application
APP_API_USERNAME=<placeholder>
APP_API_PASSWORD=<placeholder>
```

### 2.2 Spring Boot Configuration

`application.yml` references environment variables exclusively:

```yaml
spring:
  datasource:
    url: ${ORACLE_JDBC_URL}
    username: ${ORACLE_USERNAME}
    password: ${ORACLE_PASSWORD}

snowflake:
  account: ${SNOWFLAKE_ACCOUNT}
  user: ${SNOWFLAKE_USER}
  private-key-path: ${SNOWFLAKE_PRIVATE_KEY_PATH}
  private-key-passphrase: ${SNOWFLAKE_PRIVATE_KEY_PASSPHRASE:}
  warehouse: ${SNOWFLAKE_WAREHOUSE}
  database: ${SNOWFLAKE_DATABASE}
  role: ${SNOWFLAKE_ROLE}
```

### 2.3 Private Key Storage

- The Snowflake RSA private key (`.p8` format) is stored on the developer's local filesystem only.
- The file path is referenced via `SNOWFLAKE_PRIVATE_KEY_PATH` environment variable.
- The key file must have restrictive file-system permissions (owner read-only).
- The key passphrase (if used) is in the environment variable `SNOWFLAKE_PRIVATE_KEY_PASSPHRASE`.
- **Private key material is never stored in the database, application properties, or source control.**

---

## 3. Snowflake Security

### 3.1 Service User

| Attribute | Value |
|-----------|-------|
| Username | `SVC_CDP_LOADER` |
| Authentication | RSA key-pair (2048-bit minimum) |
| Role | `CDP_LOADER_ROLE` (dedicated, minimal privileges) |
| Login disabled | Password login disabled |
| Network policy | Restrict to dev-machine IP (optional, Phase 2) |

### 3.2 Role Privileges (Minimum Required)

```sql
-- Phase 2 provisioning — not executed in Phase 1
GRANT USAGE ON WAREHOUSE CDP_LOADER_WH TO ROLE CDP_LOADER_ROLE;
GRANT USAGE ON DATABASE CDP_DW TO ROLE CDP_LOADER_ROLE;
GRANT USAGE ON SCHEMA CDP_DW.RAW TO ROLE CDP_LOADER_ROLE;
GRANT USAGE ON SCHEMA CDP_DW.CLEAN TO ROLE CDP_LOADER_ROLE;
GRANT USAGE ON SCHEMA CDP_DW.REF TO ROLE CDP_LOADER_ROLE;
GRANT SELECT ON ALL TABLES IN SCHEMA CDP_DW.RAW TO ROLE CDP_LOADER_ROLE;
GRANT SELECT ON ALL TABLES IN SCHEMA CDP_DW.CLEAN TO ROLE CDP_LOADER_ROLE;
GRANT SELECT ON ALL TABLES IN SCHEMA CDP_DW.REF TO ROLE CDP_LOADER_ROLE;
-- No INSERT / UPDATE / DELETE / DROP granted
```

### 3.3 Human Administrator

The current Snowflake human administrator account is not embedded in any application configuration. Administrative operations use the Snowflake web UI or SnowSQL with personal credentials.

---

## 4. Oracle Security

### 4.1 Application Schema Users

| Schema | Purpose | Privileges |
|--------|---------|------------|
| `CDP_APP` | Business target tables | SELECT, INSERT, UPDATE, DELETE on own tables |
| `CDP_CTL` | ETL control tables | SELECT, INSERT, UPDATE, DELETE on own tables |
| `CDP_BATCH` | Spring Batch JobRepository | SELECT, INSERT, UPDATE, DELETE on own tables |

The application connects with a single Oracle user (`CDP_LOADER_USER`) that has been granted the minimum required privileges on the above schemas. The SYS/SYSTEM password is never used by the application.

### 4.2 Oracle Docker Container

- Oracle Database Free 23c in Docker
- The `ORACLE_PWD` Docker environment variable sets the SYS/SYSTEM password during initial container startup only
- Subsequent application connections use `CDP_LOADER_USER`
- The Oracle container is not exposed on a public network interface in development

---

## 5. REST API Security

### 5.1 Development Mode

HTTP Basic Authentication secured by Spring Security:
- Credentials supplied via environment variables `APP_API_USERNAME` and `APP_API_PASSWORD`
- All endpoints (except `/actuator/health`) require authentication
- CORS restricted to `http://localhost:5173` in development

### 5.2 Production / Open Liberty Target

- OAuth 2.0 Bearer Token (JWT) via an external IdP
- All endpoints require a valid bearer token
- HTTPS only (TLS 1.2+)
- CORS restricted to the deployed frontend origin

---

## 6. PII Handling

| Data element | Classification | Logging policy | Error table policy |
|-------------|---------------|----------------|-------------------|
| Customer full name | PII | Never log | Never store |
| Email address | PII | Never log | Never store |
| Phone number | PII | Never log | Never store |
| Mailing address | PII | Never log | Never store |
| Customer source ID | Non-PII identifier | Log permitted | Store permitted |
| Energy account ID | Non-PII identifier | Log permitted | Store permitted |
| Billing account number | Sensitive business data | Never log | Never store |
| KWH/KW usage | Business data | Log aggregates only | Store permitted |
| Error codes and messages | Operational | Log permitted | Store permitted |

**Implementation:** The `ItemProcessor` redacts PII fields before constructing `ETL_RECORD_ERROR` payloads. Logging frameworks must use masking patterns for email and phone fields.

---

## 7. Audit Trail

All business tables and control tables include:

| Column | Purpose |
|--------|---------|
| `CREATED_AT` | UTC timestamp of first insert |
| `CREATED_BY` | Job name + run ID that created the record |
| `UPDATED_AT` | UTC timestamp of last update |
| `UPDATED_BY` | Job name + run ID that last updated the record |

`ETL_JOB_RUN` records every execution with:
- Job name, Spring Batch run ID
- Triggered by (MANUAL / SCHEDULER)
- Start and end timestamps (UTC)
- Status (RUNNING, COMPLETED, FAILED, STOPPED)
- Record counts (read, inserted, updated, skipped, rejected)
- Watermark values (before and after)

---

## 8. Secret Scanning

- A `.gitignore` rule excludes `.env`, `*.p8`, `*.pem`, `*.key`, `*secret*`, `*credential*`
- Phase 2 will add a pre-commit hook (PowerShell script) to detect common secret patterns before commit
- GitHub / GitLab secret scanning should be enabled on the repository

---

## 9. Network Security Summary

| Connection | Protocol | Authentication | Encryption |
|-----------|---------|----------------|-----------|
| App → Snowflake | HTTPS / Snowflake JDBC | RSA key-pair | TLS (Snowflake enforced) |
| App → Oracle (Docker) | TCP/1521 | Username/password | None (localhost only) |
| App → Oracle (Prod) | TCP/1521 | Username/password | TLS (Oracle NET) |
| Browser → App REST API | HTTP (dev) / HTTPS (prod) | HTTP Basic / JWT | HTTPS in prod |
| Browser → Vite dev | HTTP | None | localhost only |
