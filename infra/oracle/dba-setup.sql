-- =============================================================================
-- Oracle DBA Setup Script — Run ONCE before Flyway migrations
-- =============================================================================
-- Context: Connected as SYSDBA or SYSTEM to Oracle Free 23c FREEPDB1
--
-- This script is the ONLY place the CDP_LOADER password should appear.
-- It must be run by a DBA on the local Docker instance.
-- Do NOT commit the filled-in password version to source control.
--
-- After this script, Flyway V001 will run but will find CDP_LOADER already
-- exists (Flyway V001 is idempotent for the user creation via IF NOT EXISTS
-- logic if needed, or DBA can skip V001).
--
-- For Docker Oracle Free: the simplest approach is to run this script
-- via sqlplus inside the container, then let Flyway manage tables.
-- =============================================================================

-- Connect to FREEPDB1 first:
--   docker exec -it cdp-oracle-db sqlplus system/<ORACLE_PWD>@//localhost:1521/FREEPDB1

-- ---------------------------------------------------------------------------
-- 1. Create CDP_LOADER schema/user
-- ---------------------------------------------------------------------------
CREATE USER CDP_LOADER
    IDENTIFIED BY "<STRONG_PASSWORD_HERE>"    -- ← change before running
    DEFAULT TABLESPACE USERS
    TEMPORARY TABLESPACE TEMP
    QUOTA UNLIMITED ON USERS;

-- ---------------------------------------------------------------------------
-- 2. Grants
-- ---------------------------------------------------------------------------
GRANT CONNECT, RESOURCE         TO CDP_LOADER;
GRANT CREATE SESSION             TO CDP_LOADER;
GRANT CREATE TABLE               TO CDP_LOADER;
GRANT CREATE SEQUENCE            TO CDP_LOADER;
GRANT CREATE VIEW                TO CDP_LOADER;
GRANT CREATE PROCEDURE           TO CDP_LOADER;
GRANT CREATE TYPE                TO CDP_LOADER;
GRANT SELECT ANY SEQUENCE        TO CDP_LOADER;

-- ---------------------------------------------------------------------------
-- 3. Verify
-- ---------------------------------------------------------------------------
SELECT USERNAME, ACCOUNT_STATUS FROM DBA_USERS WHERE USERNAME = 'CDP_LOADER';
