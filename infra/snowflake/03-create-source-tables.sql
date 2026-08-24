-- =============================================================================
-- Snowflake Provisioning — Step 3: Source Table DDL
-- =============================================================================
-- Run as: CDP_ADMIN_ROLE  (use ACCOUNTADMIN or SYSADMIN to switch to it)
-- Database: CDP_UTIL_DB
-- Warehouse: CDP_LOADER_WH
--
-- PREREQUISITE
--   Script 01a-repair-admin-role-grants.sql (or a fresh run of script 01)
--   must have been executed as ACCOUNTADMIN before this script is run.
--   CDP_ADMIN_ROLE must hold CREATE TABLE on each target schema.
--
-- PURPOSE
--   Define the synthetic source tables that the ETL pipeline reads from.
--   Column names, data types and constraints match the Phase 1 source data model.
--
-- IMPORTANT — ATTRIBUTES VARIANT column on CODE_VALUE
--   CODE_LABEL is a human-readable label ONLY (e.g. 'Residential Standard').
--   Machine-readable structured parameters (rate plan rates, etc.) are stored
--   in ATTRIBUTES VARIANT, e.g. {"fixed":8.50,"energy":0.115,"demand":null,
--   "tax":0.080,"synthetic":true}.
--   Do NOT store JSON in CODE_LABEL — this violates the ICA data dictionary.
--   If this script was previously executed without ATTRIBUTES, run
--   03a-add-reference-attributes.sql to add the column idempotently.
--
-- IDEMPOTENCY
--   Every CREATE TABLE uses IF NOT EXISTS.
--   Safe to rerun after a partial failure — no tables are dropped or replaced.
--   Any tables that were created before a prior failure are left in place.
--
-- NOTE
--   These tables are populated by the data-generation scripts in Phase 3.
--   The ETL service user has SELECT-only access via CDP_LOADER_ROLE.
-- =============================================================================

-- ---------------------------------------------------------------------------
-- PREFLIGHT CHECK: verify database and role before any DDL
-- ---------------------------------------------------------------------------
SELECT
    IFF(CURRENT_DATABASE() = 'CDP_UTIL_DB',    'OK', 'ERROR: wrong database — expected CDP_UTIL_DB') AS DB_CHECK,
    IFF(CURRENT_ROLE()     = 'CDP_ADMIN_ROLE', 'OK', 'ERROR: wrong role — use CDP_ADMIN_ROLE')       AS ROLE_CHECK,
    CURRENT_DATABASE()  AS ACTIVE_DATABASE,
    CURRENT_ROLE()      AS ACTIVE_ROLE,
    CURRENT_TIMESTAMP() AS RUN_AT;
-- Stop if either check shows ERROR.

USE ROLE CDP_ADMIN_ROLE;
USE DATABASE CDP_UTIL_DB;
USE WAREHOUSE CDP_LOADER_WH;

-- ===========================================================================
-- SCHEMA: REF  (reference / code values — must exist before FK-dependent tables)
-- ===========================================================================

USE SCHEMA REF;

-- Reference code values (rate plans, account status, customer type, etc.)
--
-- Column design (Issue #1 fix):
--   CODE_LABEL  VARCHAR(500) — human-readable label ONLY
--   ATTRIBUTES  VARIANT      — machine-readable structured parameters
--                              (rate plan rates, etc.)  NULL for non-rate codes.
--   The ATTRIBUTES VARIANT column provides native Snowflake path access:
--     ATTRIBUTES['fixed']::STRING
--   without requiring TRY_PARSE_JSON on every query.
CREATE TABLE IF NOT EXISTS CODE_VALUE (
    CODE_VALUE_ID       NUMBER(10,0)    NOT NULL    AUTOINCREMENT PRIMARY KEY,
    DOMAIN              VARCHAR(50)     NOT NULL,   -- e.g. ACCT_STATUS, RATE_PLAN, CUST_TYPE
    CODE                VARCHAR(30)     NOT NULL,
    CODE_LABEL          VARCHAR(500)    NOT NULL,   -- human-readable label ONLY (not JSON)
    ATTRIBUTES          VARIANT,                    -- structured machine-readable params (nullable)
    DESCRIPTION         VARCHAR(500),
    DISPLAY_ORDER       NUMBER(5,0)     DEFAULT 0,
    IS_ACTIVE           BOOLEAN         DEFAULT TRUE,
    CREATED_AT          TIMESTAMP_TZ    DEFAULT CURRENT_TIMESTAMP(),
    UPDATED_AT          TIMESTAMP_TZ    DEFAULT CURRENT_TIMESTAMP(),
    CONSTRAINT uq_cv_domain_code UNIQUE (DOMAIN, CODE)
);

-- ===========================================================================
-- SCHEMA: CUSTOMER
-- ===========================================================================

USE SCHEMA CUSTOMER;

-- Customer master
CREATE TABLE IF NOT EXISTS CUSTOMER (
    CUSTOMER_ID         VARCHAR(20)     NOT NULL    PRIMARY KEY,  -- e.g. CUST-000001
    FIRST_NAME          VARCHAR(100)    NOT NULL,
    LAST_NAME           VARCHAR(100)    NOT NULL,
    MIDDLE_NAME         VARCHAR(100),
    NAME_SUFFIX         VARCHAR(20),
    CUSTOMER_TYPE       VARCHAR(30)     NOT NULL,   -- RESIDENTIAL / COMMERCIAL / INDUSTRIAL
    DATE_OF_BIRTH       DATE,                       -- residential only; may be NULL
    SSN_LAST4           VARCHAR(4),                 -- last 4 digits only; masked in exports
    TAX_ID              VARCHAR(20),                -- commercial/industrial
    PREFERRED_LANGUAGE  VARCHAR(10)     DEFAULT 'EN',
    ACCOUNT_STATUS      VARCHAR(30)     NOT NULL,   -- ACTIVE / INACTIVE / SUSPENDED / PENDING
    STATUS_REASON       VARCHAR(100),
    CREATED_AT          TIMESTAMP_TZ    DEFAULT CURRENT_TIMESTAMP(),
    UPDATED_AT          TIMESTAMP_TZ    DEFAULT CURRENT_TIMESTAMP()
);

-- Customer contact information (one customer → many contacts)
CREATE TABLE IF NOT EXISTS CUSTOMER_CONTACT (
    CONTACT_ID          VARCHAR(20)     NOT NULL    PRIMARY KEY,  -- e.g. CONT-000001
    CUSTOMER_ID         VARCHAR(20)     NOT NULL    REFERENCES CUSTOMER(CUSTOMER_ID),
    CONTACT_TYPE        VARCHAR(30)     NOT NULL,   -- EMAIL / PHONE / MAILING_ADDRESS
    CONTACT_VALUE       VARCHAR(500)    NOT NULL,   -- actual email, phone number or address
    IS_PRIMARY          BOOLEAN         DEFAULT FALSE,
    IS_VERIFIED         BOOLEAN         DEFAULT FALSE,
    EFFECTIVE_DATE      DATE            NOT NULL,
    END_DATE            DATE,
    CREATED_AT          TIMESTAMP_TZ    DEFAULT CURRENT_TIMESTAMP(),
    UPDATED_AT          TIMESTAMP_TZ    DEFAULT CURRENT_TIMESTAMP()
);

-- Energy / service accounts
CREATE TABLE IF NOT EXISTS ENERGY_ACCOUNT (
    ENERGY_ACCOUNT_ID   VARCHAR(20)     NOT NULL    PRIMARY KEY,  -- e.g. EA-000001
    CUSTOMER_ID         VARCHAR(20)     NOT NULL    REFERENCES CUSTOMER(CUSTOMER_ID),
    ACCOUNT_NUMBER      VARCHAR(30)     NOT NULL    UNIQUE,       -- customer-facing number
    ACCOUNT_STATUS      VARCHAR(30)     NOT NULL,
    SERVICE_TYPE        VARCHAR(30)     DEFAULT 'ELECTRIC',
    RATE_CLASS          VARCHAR(30)     NOT NULL,   -- RESIDENTIAL / SMALL_COMMERCIAL / etc.
    OPEN_DATE           DATE            NOT NULL,
    CLOSE_DATE          DATE,
    CREATED_AT          TIMESTAMP_TZ    DEFAULT CURRENT_TIMESTAMP(),
    UPDATED_AT          TIMESTAMP_TZ    DEFAULT CURRENT_TIMESTAMP()
);

-- Billing accounts (one energy account → one billing account at a time)
CREATE TABLE IF NOT EXISTS BILLING_ACCOUNT (
    BILLING_ACCOUNT_ID  VARCHAR(20)     NOT NULL    PRIMARY KEY,  -- e.g. BA-000001
    ENERGY_ACCOUNT_ID   VARCHAR(20)     NOT NULL    REFERENCES ENERGY_ACCOUNT(ENERGY_ACCOUNT_ID),
    BILLING_ACCOUNT_NBR VARCHAR(30)     NOT NULL,
    BILLING_CYCLE       VARCHAR(10)     NOT NULL,   -- e.g. 01 … 20
    PAYMENT_METHOD      VARCHAR(30)     DEFAULT 'PAPER_BILL',
    AUTO_PAY_ENROLLED   BOOLEAN         DEFAULT FALSE,
    PAPERLESS_ENROLLED  BOOLEAN         DEFAULT FALSE,
    EFFECTIVE_DATE      DATE            NOT NULL,
    END_DATE            DATE,
    CREATED_AT          TIMESTAMP_TZ    DEFAULT CURRENT_TIMESTAMP(),
    UPDATED_AT          TIMESTAMP_TZ    DEFAULT CURRENT_TIMESTAMP()
);

-- ===========================================================================
-- SCHEMA: SERVICE
-- ===========================================================================

USE SCHEMA SERVICE;

-- Service premises (physical location where electricity is delivered)
CREATE TABLE IF NOT EXISTS PREMISE (
    PREMISE_ID          VARCHAR(20)     NOT NULL    PRIMARY KEY,  -- e.g. PREM-000001
    ENERGY_ACCOUNT_ID   VARCHAR(20)     NOT NULL,   -- FK to CUSTOMER.ENERGY_ACCOUNT
    ADDRESS_LINE1       VARCHAR(200)    NOT NULL,
    ADDRESS_LINE2       VARCHAR(200),
    CITY                VARCHAR(100)    NOT NULL,
    STATE_CODE          VARCHAR(2)      NOT NULL,   -- US 2-letter state code
    ZIP_CODE            VARCHAR(10)     NOT NULL,
    COUNTY              VARCHAR(100),
    GEO_LATITUDE        NUMBER(10,6),
    GEO_LONGITUDE       NUMBER(11,6),
    PREMISE_TYPE        VARCHAR(30),                -- RESIDENTIAL / COMMERCIAL
    EFFECTIVE_DATE      DATE            NOT NULL,
    END_DATE            DATE,
    CREATED_AT          TIMESTAMP_TZ    DEFAULT CURRENT_TIMESTAMP(),
    UPDATED_AT          TIMESTAMP_TZ    DEFAULT CURRENT_TIMESTAMP()
);

-- Meters installed at premises
CREATE TABLE IF NOT EXISTS METER (
    METER_ID            VARCHAR(20)     NOT NULL    PRIMARY KEY,  -- e.g. MTR-000001
    PREMISE_ID          VARCHAR(20)     NOT NULL    REFERENCES SERVICE.PREMISE(PREMISE_ID),
    METER_NUMBER        VARCHAR(30)     NOT NULL    UNIQUE,
    METER_TYPE          VARCHAR(30)     DEFAULT 'ANALOG',    -- ANALOG / SMART / AMI
    MANUFACTURER        VARCHAR(100),
    MODEL               VARCHAR(100),
    INSTALL_DATE        DATE            NOT NULL,
    REMOVAL_DATE        DATE,
    IS_ACTIVE           BOOLEAN         DEFAULT TRUE,
    CREATED_AT          TIMESTAMP_TZ    DEFAULT CURRENT_TIMESTAMP(),
    UPDATED_AT          TIMESTAMP_TZ    DEFAULT CURRENT_TIMESTAMP()
);

-- ===========================================================================
-- SCHEMA: BILLING
-- ===========================================================================

USE SCHEMA BILLING;

-- Monthly electricity usage and billing
CREATE TABLE IF NOT EXISTS MONTHLY_USAGE (
    USAGE_ID            VARCHAR(30)     NOT NULL    PRIMARY KEY,  -- e.g. USG-2024-01-EA000001
    ENERGY_ACCOUNT_ID   VARCHAR(20)     NOT NULL,
    PREMISE_ID          VARCHAR(20)     NOT NULL,
    METER_ID            VARCHAR(20)     NOT NULL,
    BILLING_MONTH       VARCHAR(7)      NOT NULL,   -- YYYY-MM  (business-key component)
    BILL_START_DATE     DATE            NOT NULL,
    BILL_END_DATE       DATE            NOT NULL,
    BILLING_DAYS        NUMBER(3,0)     NOT NULL,
    KWH_USAGE           NUMBER(12,3)    NOT NULL,   -- total consumption
    KWH_ADJUSTED        NUMBER(12,3),               -- after loss factors
    PEAK_DEMAND_KW      NUMBER(10,3),
    PREV_METER_READING  NUMBER(12,3),
    CURR_METER_READING  NUMBER(12,3),
    READ_TYPE           VARCHAR(10)     DEFAULT 'ACTUAL',  -- ACTUAL / ESTIMATED
    RATE_PLAN           VARCHAR(30)     NOT NULL,   -- FK to REF.CODE_VALUE(DOMAIN=RATE_PLAN)
    FIXED_CHARGE        NUMBER(10,2),
    ENERGY_CHARGE       NUMBER(10,2),
    DEMAND_CHARGE       NUMBER(10,2),
    SUBTOTAL_CHARGE     NUMBER(10,2),
    TAX_AMOUNT          NUMBER(10,2),
    TOTAL_BILLED        NUMBER(10,2),
    IS_CORRECTION       BOOLEAN         DEFAULT FALSE,
    CORRECTION_REASON   VARCHAR(200),
    CREATED_AT          TIMESTAMP_TZ    DEFAULT CURRENT_TIMESTAMP(),
    UPDATED_AT          TIMESTAMP_TZ    DEFAULT CURRENT_TIMESTAMP(),
    CONSTRAINT uq_usage_ea_month UNIQUE (ENERGY_ACCOUNT_ID, BILLING_MONTH)
);

-- ===========================================================================
-- Verification
-- ===========================================================================
SHOW TABLES IN SCHEMA CDP_UTIL_DB.REF;
SHOW TABLES IN SCHEMA CDP_UTIL_DB.CUSTOMER;
SHOW TABLES IN SCHEMA CDP_UTIL_DB.SERVICE;
SHOW TABLES IN SCHEMA CDP_UTIL_DB.BILLING;
