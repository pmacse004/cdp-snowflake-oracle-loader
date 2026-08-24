# Environment Variables Reference
# CDP Snowflake-to-Oracle Loader

## Overview

The application uses environment variables for all secrets and
environment-specific values. No passwords, tokens or private keys are stored
in source control.

---

## Variable Name Conventions

| Prefix | Scope |
|---|---|
| `ORACLE_PWD` | Oracle container admin password — used by Docker Compose **only** |
| `CDP_ORACLE_*` | Oracle connection for the Spring Boot application |
| `CDP_SF_*` | Snowflake connection |

> **Important: Docker Compose `.env` isolation**
>
> `infra/docker/.env` is loaded by `docker compose` when starting the Oracle
> container. It is **not** automatically inherited by a separately launched
> Maven or Spring Boot process on the host.
>
> `ORACLE_PWD` sets the SYS/SYSTEM/PDBADMIN password for the Oracle container.
> It is **not** the CDP_LOADER application password.
>
> The Spring Boot application reads `CDP_ORACLE_PASSWORD` from the host
> environment or from `application-local.yml`. You must set it separately.

---

## Required Environment Variables

### Oracle Application Connection

| Variable | Description | Example |
|---|---|---|
| `CDP_ORACLE_JDBC_URL` | Oracle JDBC connection URL | `jdbc:oracle:thin:@//localhost:1521/FREEPDB1` |
| `CDP_ORACLE_USERNAME` | Oracle schema/user name | `CDP_LOADER` |
| `CDP_ORACLE_PASSWORD` | CDP_LOADER user password — set during DBA bootstrap | *(set interactively, never stored in source control)* |

### Snowflake

| Variable | Description | Example |
|---|---|---|
| `CDP_SF_ACCOUNT` | Snowflake account identifier | `QI79280` |
| `CDP_SF_USER` | Snowflake service user login name | `SVC_CDP_LOADER` |
| `CDP_SF_WAREHOUSE` | Snowflake warehouse name | `CDP_LOADER_WH` |
| `CDP_SF_DATABASE` | Snowflake source database | `CDP_UTIL_DB` |
| `CDP_SF_ROLE` | Snowflake role for the service user | `CDP_LOADER_ROLE` |
| `CDP_SF_PRIVATE_KEY_PATH` | **Absolute path** to the RSA PKCS#8 private key file | `C:\Users\you\.cdp-loader\keys\snowflake_rsa_key.p8` |

> **Security note:** The private key file path is not a secret, but the file
> it points to is. Ensure the key file has restricted file-system permissions.
> See `infra/snowflake/keygen.ps1` to generate the key pair.

### Docker Compose Only (not read by Spring Boot)

| Variable | Description | Where set |
|---|---|---|
| `ORACLE_PWD` | Oracle container SYS/SYSTEM/PDBADMIN password | `infra/docker/.env` only |

---

## Optional Variables (with defaults)

| Variable | Default | Description |
|---|---|---|
| `CDP_DAILY_LOAD_CRON` | `0 0 2 * * ?` | Cron expression for daily load |
| `CDP_DAILY_LOAD_SCHEDULE_ENABLED` | `false` | Set `true` to enable cron scheduling |
| `CDP_MONTHLY_LOAD_CRON` | `0 0 3 1 * ?` | Cron expression for monthly load |
| `CDP_MONTHLY_LOAD_SCHEDULE_ENABLED` | `false` | Set `true` to enable cron scheduling |

---

## Setting Variables for Local Development

### Option A — application-local.yml (recommended for IDE)

1. Copy `cdp-loader-api/src/main/resources/application-local.yml.template`
   to `cdp-loader-api/src/main/resources/application-local.yml`
2. Set `spring.datasource.password: "${CDP_ORACLE_PASSWORD}"` and supply
   `CDP_ORACLE_PASSWORD` as an OS environment variable, **or** set the
   password inline in the gitignored local file
3. Activate Spring profile `local` in your IDE run configuration

### Option B — PowerShell session variables

```powershell
$env:CDP_ORACLE_JDBC_URL   = "jdbc:oracle:thin:@//localhost:1521/FREEPDB1"
$env:CDP_ORACLE_USERNAME   = "CDP_LOADER"
$env:CDP_ORACLE_PASSWORD   = "YourStrongPassword"   # same value entered during bootstrap
$env:CDP_SF_ACCOUNT        = "QI79280"
$env:CDP_SF_USER           = "SVC_CDP_LOADER"
$env:CDP_SF_WAREHOUSE      = "CDP_LOADER_WH"
$env:CDP_SF_DATABASE       = "CDP_UTIL_DB"
$env:CDP_SF_ROLE           = "CDP_LOADER_ROLE"
$env:CDP_SF_PRIVATE_KEY_PATH = "C:\Users\you\.cdp-loader\keys\snowflake_rsa_key.p8"
```

> Set these in the **same PowerShell session** that runs `mvn spring-boot:run`.
> They are not shared across sessions or processes.

### Option C — project-root .env file with IDE plugin

Use the EnvFile plugin for IntelliJ IDEA or the `.env` support in VS Code.
Create a `.env` file in the **project root** (not in `infra/docker/`).
This file is `.gitignore`d:

```
CDP_ORACLE_JDBC_URL=jdbc:oracle:thin:@//localhost:1521/FREEPDB1
CDP_ORACLE_USERNAME=CDP_LOADER
CDP_ORACLE_PASSWORD=YourStrongPassword
CDP_SF_ACCOUNT=QI79280
CDP_SF_USER=SVC_CDP_LOADER
CDP_SF_WAREHOUSE=CDP_LOADER_WH
CDP_SF_DATABASE=CDP_UTIL_DB
CDP_SF_ROLE=CDP_LOADER_ROLE
CDP_SF_PRIVATE_KEY_PATH=C:\Users\you\.cdp-loader\keys\snowflake_rsa_key.p8
```

> This is **separate** from `infra/docker/.env` which is only for Docker Compose.

---

## Running the Application

```powershell
# 1. Start Oracle container (already running if you followed setup)
.\scripts\start-oracle.ps1 -WaitReady

# 2. Set application environment variables in this shell session
#    (or use application-local.yml instead)
$env:CDP_ORACLE_JDBC_URL = "jdbc:oracle:thin:@//localhost:1521/FREEPDB1"
$env:CDP_ORACLE_USERNAME = "CDP_LOADER"
$env:CDP_ORACLE_PASSWORD = "YourStrongPassword"

# 3. Run with the local profile
mvn spring-boot:run -pl cdp-loader-api -Dspring-boot.run.profiles=local
```

Or build and run the fat JAR:

```powershell
mvn clean package -DskipTests
java -Dspring.profiles.active=local `
     -DCDP_ORACLE_JDBC_URL="jdbc:oracle:thin:@//localhost:1521/FREEPDB1" `
     -DCDP_ORACLE_USERNAME="CDP_LOADER" `
     -DCDP_ORACLE_PASSWORD="YourStrongPassword" `
     -jar cdp-loader-api/target/cdp-loader-api-0.1.0-SNAPSHOT.jar
```

---

## CI/CD

In CI pipelines (GitHub Actions, Jenkins, etc.), inject variables as masked
pipeline secrets. Reference them using the pipeline's secret injection syntax.
Never print secret variable values in pipeline logs.

Variable names in CI must match the names above exactly:
`CDP_ORACLE_JDBC_URL`, `CDP_ORACLE_USERNAME`, `CDP_ORACLE_PASSWORD`, etc.
