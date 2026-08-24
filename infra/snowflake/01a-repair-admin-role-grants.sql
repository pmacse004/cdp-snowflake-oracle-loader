-- =============================================================================
-- Snowflake Provisioning — Step 01a: Repair Admin Role Grants
-- =============================================================================
-- Run as: ACCOUNTADMIN
-- Account: LJPNAFI-RW79936 (locator BM00315, Azure Central India)
--
-- PURPOSE
--   One-time repair script for an environment provisioned with script 01
--   before CDP_ADMIN_ROLE was introduced.  Adds the missing role and all
--   required grants without dropping or replacing any existing object.
--
-- SAFE TO RUN BECAUSE:
--   - CREATE ROLE IF NOT EXISTS   -- no-op if the role already exists
--   - GRANT is idempotent         -- re-granting a privilege that already
--                                    exists does NOT error in Snowflake
--   - No DROP, REPLACE, TRUNCATE, DELETE, or ALTER on tables, views,
--     schemas, databases, warehouses, users, or keys
--
-- WHAT THIS SCRIPT DOES:
--   1. Creates CDP_ADMIN_ROLE if not present
--   2. Grants CDP_ADMIN_ROLE to SYSADMIN
--   3. Grants USAGE on warehouse and database to CDP_ADMIN_ROLE
--   4. Grants USAGE + CREATE TABLE on CUSTOMER, SERVICE, BILLING, REF
--   5. Grants USAGE + CREATE VIEW  on STAGING
--   6. Grants SELECT on current and future tables in all data schemas
--      (required so script 04 views can reference source tables)
--   7. Verifies the resulting grants
--
-- EXECUTION ORDER
--   Run this script FIRST (as ACCOUNTADMIN).
--   Then rerun 03-create-source-tables.sql using CDP_ADMIN_ROLE.
--   Then run  04-create-export-views.sql  using CDP_ADMIN_ROLE.
-- =============================================================================

USE ROLE ACCOUNTADMIN;
USE WAREHOUSE COMPUTE_WH;   -- ACCOUNTADMIN's own admin warehouse for DDL

-- ---------------------------------------------------------------------------
-- 1.  Create CDP_ADMIN_ROLE if it does not already exist
-- ---------------------------------------------------------------------------
CREATE ROLE IF NOT EXISTS CDP_ADMIN_ROLE
    COMMENT = 'Object-administration role for CDP DDL scripts; granted to SYSADMIN';

-- ---------------------------------------------------------------------------
-- 2.  Grant CDP_ADMIN_ROLE to SYSADMIN
--     Administrators USE CDP_ADMIN_ROLE through the SYSADMIN hierarchy.
-- ---------------------------------------------------------------------------
GRANT ROLE CDP_ADMIN_ROLE TO ROLE SYSADMIN;

-- ---------------------------------------------------------------------------
-- 3.  Warehouse and database access
-- ---------------------------------------------------------------------------
GRANT USAGE ON WAREHOUSE CDP_LOADER_WH  TO ROLE CDP_ADMIN_ROLE;
GRANT USAGE ON DATABASE  CDP_UTIL_DB    TO ROLE CDP_ADMIN_ROLE;

-- ---------------------------------------------------------------------------
-- 4.  CUSTOMER schema — DDL + SELECT
-- ---------------------------------------------------------------------------
GRANT USAGE        ON SCHEMA CDP_UTIL_DB.CUSTOMER TO ROLE CDP_ADMIN_ROLE;
GRANT CREATE TABLE ON SCHEMA CDP_UTIL_DB.CUSTOMER TO ROLE CDP_ADMIN_ROLE;
GRANT SELECT ON ALL    TABLES IN SCHEMA CDP_UTIL_DB.CUSTOMER TO ROLE CDP_ADMIN_ROLE;
GRANT SELECT ON FUTURE TABLES IN SCHEMA CDP_UTIL_DB.CUSTOMER TO ROLE CDP_ADMIN_ROLE;

-- ---------------------------------------------------------------------------
-- 5.  SERVICE schema — DDL + SELECT
-- ---------------------------------------------------------------------------
GRANT USAGE        ON SCHEMA CDP_UTIL_DB.SERVICE  TO ROLE CDP_ADMIN_ROLE;
GRANT CREATE TABLE ON SCHEMA CDP_UTIL_DB.SERVICE  TO ROLE CDP_ADMIN_ROLE;
GRANT SELECT ON ALL    TABLES IN SCHEMA CDP_UTIL_DB.SERVICE  TO ROLE CDP_ADMIN_ROLE;
GRANT SELECT ON FUTURE TABLES IN SCHEMA CDP_UTIL_DB.SERVICE  TO ROLE CDP_ADMIN_ROLE;

-- ---------------------------------------------------------------------------
-- 6.  BILLING schema — DDL + SELECT
-- ---------------------------------------------------------------------------
GRANT USAGE        ON SCHEMA CDP_UTIL_DB.BILLING  TO ROLE CDP_ADMIN_ROLE;
GRANT CREATE TABLE ON SCHEMA CDP_UTIL_DB.BILLING  TO ROLE CDP_ADMIN_ROLE;
GRANT SELECT ON ALL    TABLES IN SCHEMA CDP_UTIL_DB.BILLING  TO ROLE CDP_ADMIN_ROLE;
GRANT SELECT ON FUTURE TABLES IN SCHEMA CDP_UTIL_DB.BILLING  TO ROLE CDP_ADMIN_ROLE;

-- ---------------------------------------------------------------------------
-- 7.  REF schema — DDL + SELECT
-- ---------------------------------------------------------------------------
GRANT USAGE        ON SCHEMA CDP_UTIL_DB.REF      TO ROLE CDP_ADMIN_ROLE;
GRANT CREATE TABLE ON SCHEMA CDP_UTIL_DB.REF      TO ROLE CDP_ADMIN_ROLE;
GRANT SELECT ON ALL    TABLES IN SCHEMA CDP_UTIL_DB.REF      TO ROLE CDP_ADMIN_ROLE;
GRANT SELECT ON FUTURE TABLES IN SCHEMA CDP_UTIL_DB.REF      TO ROLE CDP_ADMIN_ROLE;

-- ---------------------------------------------------------------------------
-- 8.  STAGING schema — CREATE VIEW only (no tables are created here)
-- ---------------------------------------------------------------------------
GRANT USAGE       ON SCHEMA CDP_UTIL_DB.STAGING   TO ROLE CDP_ADMIN_ROLE;
GRANT CREATE VIEW ON SCHEMA CDP_UTIL_DB.STAGING   TO ROLE CDP_ADMIN_ROLE;

-- ---------------------------------------------------------------------------
-- 9.  Verification
--     Run each SHOW statement and confirm the expected privileges appear.
-- ---------------------------------------------------------------------------

-- 9a. All grants held by CDP_ADMIN_ROLE
SHOW GRANTS TO ROLE CDP_ADMIN_ROLE;

-- 9b. Confirm CDP_ADMIN_ROLE appears in SYSADMIN's granted roles
SHOW GRANTS TO ROLE SYSADMIN;

-- 9c. All grants held by CDP_LOADER_ROLE (confirm: no CREATE TABLE, no CREATE VIEW)
SHOW GRANTS TO ROLE CDP_LOADER_ROLE;

-- 9d. Tables already present (safe: CREATE TABLE IF NOT EXISTS in script 03
--     means any tables created before the failure do NOT need to be dropped)
SHOW TABLES IN SCHEMA CDP_UTIL_DB.REF;
SHOW TABLES IN SCHEMA CDP_UTIL_DB.CUSTOMER;
SHOW TABLES IN SCHEMA CDP_UTIL_DB.SERVICE;
SHOW TABLES IN SCHEMA CDP_UTIL_DB.BILLING;
