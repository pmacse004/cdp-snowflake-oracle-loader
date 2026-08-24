-- =============================================================================
-- Snowflake Provisioning -- Step 1: Database, Schemas, Warehouse, Roles
-- =============================================================================
-- Run as: ACCOUNTADMIN
-- Account: QI79280 (AWS AP_SOUTHEAST_7)
--
-- This script is IDEMPOTENT: CREATE ... IF NOT EXISTS is used throughout.
-- Safe to rerun. Does NOT drop or truncate any existing data.
--
-- Objects created:
--   Database:  CDP_UTIL_DB
--   Schemas:   CUSTOMER, SERVICE, BILLING, REF, STAGING
--   Warehouse: CDP_LOADER_WH  (X-SMALL, auto-suspend 5 min, initially suspended)
--   Roles:
--     CDP_ADMIN_ROLE  -- object-creation role for DDL scripts 03 and 04
--     CDP_LOADER_ROLE -- read-only application role for the ETL service user
--
-- ROLE MODEL SUMMARY
--   CDP_ADMIN_ROLE
--     - Granted to SYSADMIN (administrators inherit it)
--     - USAGE on database, warehouse, all schemas
--     - CREATE TABLE on CUSTOMER, SERVICE, BILLING, REF
--     - CREATE VIEW  on STAGING
--     - Purpose: run scripts 03-create-source-tables.sql and
--                04-create-export-views.sql
--
--   CDP_LOADER_ROLE
--     - Read-only: SELECT on current and future tables/views only
--     - NO CREATE TABLE, CREATE VIEW, INSERT, UPDATE, DELETE
--     - Granted to SVC_CDP_LOADER service user (script 02)
--
-- After this script run 02-create-service-user.sql AS ACCOUNTADMIN.
-- Then run scripts 03 and 04 using CDP_ADMIN_ROLE.
-- =============================================================================

USE ROLE ACCOUNTADMIN;

-- ---------------------------------------------------------------------------
-- 1.  Dedicated database
-- ---------------------------------------------------------------------------
CREATE DATABASE IF NOT EXISTS CDP_UTIL_DB
    DATA_RETENTION_TIME_IN_DAYS = 1
    COMMENT = 'CDP Snowflake-to-Oracle Loader -- synthetic utility source data';

-- ---------------------------------------------------------------------------
-- 2.  Schemas inside CDP_UTIL_DB
-- ---------------------------------------------------------------------------
USE DATABASE CDP_UTIL_DB;

CREATE SCHEMA IF NOT EXISTS CUSTOMER
    COMMENT = 'Customer master, contacts, energy accounts, billing accounts';

CREATE SCHEMA IF NOT EXISTS SERVICE
    COMMENT = 'Service premises and meters';

CREATE SCHEMA IF NOT EXISTS BILLING
    COMMENT = 'Monthly electricity usage and billing records';

CREATE SCHEMA IF NOT EXISTS REF
    COMMENT = 'Reference data: code values, rate plans, status codes';

CREATE SCHEMA IF NOT EXISTS STAGING
    COMMENT = 'ETL export views used by the Spring Batch application';

-- ---------------------------------------------------------------------------
-- 3.  Dedicated ETL warehouse
-- ---------------------------------------------------------------------------
-- X-SMALL is sufficient for the demo (~10,000 customers).
-- Auto-suspend after 5 minutes prevents idle credit usage.
CREATE WAREHOUSE IF NOT EXISTS CDP_LOADER_WH
    WAREHOUSE_SIZE      = 'X-SMALL'
    AUTO_SUSPEND        = 300
    AUTO_RESUME         = TRUE
    INITIALLY_SUSPENDED = TRUE
    STATEMENT_TIMEOUT_IN_SECONDS = 300
    COMMENT = 'CDP ETL loader warehouse -- auto-suspends when idle';

-- ---------------------------------------------------------------------------
-- 4a.  Object administration role (DDL scripts 03 and 04)
--      CDP_ADMIN_ROLE holds CREATE TABLE / CREATE VIEW privileges.
--      It is granted to SYSADMIN so administrators inherit it.
--      It is NOT granted to CDP_LOADER_ROLE.
-- ---------------------------------------------------------------------------
CREATE ROLE IF NOT EXISTS CDP_ADMIN_ROLE
    COMMENT = 'Object-administration role for CDP DDL scripts; granted to SYSADMIN';

-- Administrators can USE CDP_ADMIN_ROLE through SYSADMIN hierarchy.
GRANT ROLE CDP_ADMIN_ROLE TO ROLE SYSADMIN;

-- CDP_ADMIN_ROLE needs the warehouse to execute DDL statements.
GRANT USAGE ON WAREHOUSE CDP_LOADER_WH TO ROLE CDP_ADMIN_ROLE;

-- CDP_ADMIN_ROLE needs USAGE on the database to reference objects inside it.
GRANT USAGE ON DATABASE CDP_UTIL_DB TO ROLE CDP_ADMIN_ROLE;

-- Schema-level: USAGE + CREATE TABLE (all data schemas) + CREATE VIEW (STAGING)
GRANT USAGE        ON SCHEMA CDP_UTIL_DB.CUSTOMER TO ROLE CDP_ADMIN_ROLE;
GRANT CREATE TABLE ON SCHEMA CDP_UTIL_DB.CUSTOMER TO ROLE CDP_ADMIN_ROLE;

GRANT USAGE        ON SCHEMA CDP_UTIL_DB.SERVICE  TO ROLE CDP_ADMIN_ROLE;
GRANT CREATE TABLE ON SCHEMA CDP_UTIL_DB.SERVICE  TO ROLE CDP_ADMIN_ROLE;

GRANT USAGE        ON SCHEMA CDP_UTIL_DB.BILLING  TO ROLE CDP_ADMIN_ROLE;
GRANT CREATE TABLE ON SCHEMA CDP_UTIL_DB.BILLING  TO ROLE CDP_ADMIN_ROLE;

GRANT USAGE        ON SCHEMA CDP_UTIL_DB.REF      TO ROLE CDP_ADMIN_ROLE;
GRANT CREATE TABLE ON SCHEMA CDP_UTIL_DB.REF      TO ROLE CDP_ADMIN_ROLE;

GRANT USAGE        ON SCHEMA CDP_UTIL_DB.STAGING  TO ROLE CDP_ADMIN_ROLE;
GRANT CREATE VIEW  ON SCHEMA CDP_UTIL_DB.STAGING  TO ROLE CDP_ADMIN_ROLE;

-- CDP_ADMIN_ROLE also needs SELECT on all data schemas to define the views
-- in script 04 (views reference tables in CUSTOMER, SERVICE, BILLING, REF).
GRANT SELECT ON ALL    TABLES IN SCHEMA CDP_UTIL_DB.CUSTOMER TO ROLE CDP_ADMIN_ROLE;
GRANT SELECT ON FUTURE TABLES IN SCHEMA CDP_UTIL_DB.CUSTOMER TO ROLE CDP_ADMIN_ROLE;

GRANT SELECT ON ALL    TABLES IN SCHEMA CDP_UTIL_DB.SERVICE  TO ROLE CDP_ADMIN_ROLE;
GRANT SELECT ON FUTURE TABLES IN SCHEMA CDP_UTIL_DB.SERVICE  TO ROLE CDP_ADMIN_ROLE;

GRANT SELECT ON ALL    TABLES IN SCHEMA CDP_UTIL_DB.BILLING  TO ROLE CDP_ADMIN_ROLE;
GRANT SELECT ON FUTURE TABLES IN SCHEMA CDP_UTIL_DB.BILLING  TO ROLE CDP_ADMIN_ROLE;

GRANT SELECT ON ALL    TABLES IN SCHEMA CDP_UTIL_DB.REF      TO ROLE CDP_ADMIN_ROLE;
GRANT SELECT ON FUTURE TABLES IN SCHEMA CDP_UTIL_DB.REF      TO ROLE CDP_ADMIN_ROLE;

-- ---------------------------------------------------------------------------
-- 4b.  Application role (read-only, least-privilege)
--      CDP_LOADER_ROLE is granted to the SVC_CDP_LOADER service user only.
--      It holds NO CREATE TABLE, CREATE VIEW, INSERT, UPDATE, or DELETE.
-- ---------------------------------------------------------------------------
CREATE ROLE IF NOT EXISTS CDP_LOADER_ROLE
    COMMENT = 'Least-privilege read-only role for CDP Snowflake-to-Oracle ETL service user';

-- Make CDP_LOADER_ROLE visible to SYSADMIN for governance/auditing only.
-- This does NOT grant any extra privileges to CDP_LOADER_ROLE.
GRANT ROLE CDP_LOADER_ROLE TO ROLE SYSADMIN;

-- ---------------------------------------------------------------------------
-- 5.  CDP_LOADER_ROLE: warehouse usage
-- ---------------------------------------------------------------------------
GRANT USAGE ON WAREHOUSE CDP_LOADER_WH TO ROLE CDP_LOADER_ROLE;

-- ---------------------------------------------------------------------------
-- 6.  CDP_LOADER_ROLE: database-level privilege
-- ---------------------------------------------------------------------------
GRANT USAGE ON DATABASE CDP_UTIL_DB TO ROLE CDP_LOADER_ROLE;

-- ---------------------------------------------------------------------------
-- 7.  CDP_LOADER_ROLE: schema and object grants
--     SELECT only on current and future tables/views.
--     No INSERT, UPDATE, DELETE, CREATE TABLE, CREATE VIEW, or DDL of any kind.
-- ---------------------------------------------------------------------------

-- CUSTOMER schema
GRANT USAGE  ON SCHEMA CDP_UTIL_DB.CUSTOMER TO ROLE CDP_LOADER_ROLE;
GRANT SELECT ON ALL    TABLES IN SCHEMA CDP_UTIL_DB.CUSTOMER TO ROLE CDP_LOADER_ROLE;
GRANT SELECT ON ALL    VIEWS  IN SCHEMA CDP_UTIL_DB.CUSTOMER TO ROLE CDP_LOADER_ROLE;
GRANT SELECT ON FUTURE TABLES IN SCHEMA CDP_UTIL_DB.CUSTOMER TO ROLE CDP_LOADER_ROLE;
GRANT SELECT ON FUTURE VIEWS  IN SCHEMA CDP_UTIL_DB.CUSTOMER TO ROLE CDP_LOADER_ROLE;

-- SERVICE schema
GRANT USAGE  ON SCHEMA CDP_UTIL_DB.SERVICE TO ROLE CDP_LOADER_ROLE;
GRANT SELECT ON ALL    TABLES IN SCHEMA CDP_UTIL_DB.SERVICE TO ROLE CDP_LOADER_ROLE;
GRANT SELECT ON ALL    VIEWS  IN SCHEMA CDP_UTIL_DB.SERVICE TO ROLE CDP_LOADER_ROLE;
GRANT SELECT ON FUTURE TABLES IN SCHEMA CDP_UTIL_DB.SERVICE TO ROLE CDP_LOADER_ROLE;
GRANT SELECT ON FUTURE VIEWS  IN SCHEMA CDP_UTIL_DB.SERVICE TO ROLE CDP_LOADER_ROLE;

-- BILLING schema
GRANT USAGE  ON SCHEMA CDP_UTIL_DB.BILLING TO ROLE CDP_LOADER_ROLE;
GRANT SELECT ON ALL    TABLES IN SCHEMA CDP_UTIL_DB.BILLING TO ROLE CDP_LOADER_ROLE;
GRANT SELECT ON ALL    VIEWS  IN SCHEMA CDP_UTIL_DB.BILLING TO ROLE CDP_LOADER_ROLE;
GRANT SELECT ON FUTURE TABLES IN SCHEMA CDP_UTIL_DB.BILLING TO ROLE CDP_LOADER_ROLE;
GRANT SELECT ON FUTURE VIEWS  IN SCHEMA CDP_UTIL_DB.BILLING TO ROLE CDP_LOADER_ROLE;

-- REF schema
GRANT USAGE  ON SCHEMA CDP_UTIL_DB.REF TO ROLE CDP_LOADER_ROLE;
GRANT SELECT ON ALL    TABLES IN SCHEMA CDP_UTIL_DB.REF TO ROLE CDP_LOADER_ROLE;
GRANT SELECT ON ALL    VIEWS  IN SCHEMA CDP_UTIL_DB.REF TO ROLE CDP_LOADER_ROLE;
GRANT SELECT ON FUTURE TABLES IN SCHEMA CDP_UTIL_DB.REF TO ROLE CDP_LOADER_ROLE;
GRANT SELECT ON FUTURE VIEWS  IN SCHEMA CDP_UTIL_DB.REF TO ROLE CDP_LOADER_ROLE;

-- STAGING schema (ETL export views only; no tables are created here)
GRANT USAGE  ON SCHEMA CDP_UTIL_DB.STAGING TO ROLE CDP_LOADER_ROLE;
GRANT SELECT ON ALL    VIEWS  IN SCHEMA CDP_UTIL_DB.STAGING TO ROLE CDP_LOADER_ROLE;
GRANT SELECT ON FUTURE VIEWS  IN SCHEMA CDP_UTIL_DB.STAGING TO ROLE CDP_LOADER_ROLE;

-- ---------------------------------------------------------------------------
-- 8.  Verification queries
-- ---------------------------------------------------------------------------
SHOW DATABASES  LIKE 'CDP_UTIL_DB';
SHOW SCHEMAS    IN DATABASE CDP_UTIL_DB;
SHOW WAREHOUSES LIKE 'CDP_LOADER_WH';
SHOW ROLES      LIKE 'CDP_ADMIN_ROLE';
SHOW ROLES      LIKE 'CDP_LOADER_ROLE';
SHOW GRANTS TO ROLE CDP_ADMIN_ROLE;
SHOW GRANTS TO ROLE CDP_LOADER_ROLE;
