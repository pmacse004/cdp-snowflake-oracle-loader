-- =============================================================================
-- 00-dba-bootstrap.sql  --  Oracle DBA Bootstrap  (MANUAL, run ONCE per PDB)
-- =============================================================================
--
-- PURPOSE
--   Create the CDP_LOADER schema owner in FREEPDB1 before Flyway runs.
--   Flyway connects as CDP_LOADER and can only create objects it owns.
--   CREATE USER requires SYSDBA privilege and must run outside Flyway.
--
-- DEMO PRIVILEGE NOTE
--   In this demo CDP_LOADER is both the Flyway schema owner and the
--   application runtime user.  It therefore retains DDL privileges at
--   runtime.  This is acceptable for a single-developer demonstration.
--   A production design should separate:
--     CDP_SCHEMA_OWNER  --  holds objects, runs Flyway (DDL only)
--     CDP_APP_USER      --  application login, DML only (SELECT/INSERT/
--                           UPDATE/DELETE plus EXECUTE on packages)
--
-- RUN ORDER
--   Step 0  (this file, DBA)    : creates CDP_LOADER in FREEPDB1
--   Step 1  (Flyway V001)       : Spring Batch tables
--   Step 2  (Flyway V002)       : REF_CODE_VALUE
--   Step 3  (Flyway V003)       : ETL control tables
--   Step 4  (Flyway V004)       : Target business tables
--
-- HOW TO EXECUTE  (see exact commands at end of this file)
--   1. docker cp infra/oracle/00-dba-bootstrap.sql cdp-oracle-db:/tmp/
--   2. docker exec -it cdp-oracle-db sqlplus / as sysdba
--   3. At SQL*Plus prompt: @/tmp/00-dba-bootstrap.sql
--   4. Enter CDP_LOADER password when prompted (input is hidden, not echoed)
--
-- CONNECTION MATRIX
--   DBA bootstrap (this file)  :  OS auth  /  as sysdba  ->  CDB$ROOT  then ALTER SESSION to FREEPDB1
--   Flyway migrate              :  CDP_LOADER  /  CDP_ORACLE_PASSWORD  ->  FREEPDB1
--   Application runtime         :  CDP_LOADER  /  CDP_ORACLE_PASSWORD  ->  FREEPDB1
--
-- SECURITY
--   No password is stored in this file.
--   The password is entered interactively with HIDE (not echoed to screen).
--   SET VERIFY OFF prevents SQL*Plus from printing old/new substitution lines
--   that could expose the password in terminal output or log files.
--   SET ECHO OFF prevents the IDENTIFIED BY line from being echoed.
--   UNDEFINE clears the substitution variable after use.
--   The password value is quoted ("&cdp_loader_password") to support mixed
--   case and most special characters. The chosen password must NOT contain
--   a double-quote (") character, as that would break the quoting.
--   This file contains no secret values and is safe to track in source control.
-- =============================================================================

-- ---------------------------------------------------------------------------
-- SQL*Plus session settings
-- These must appear before any substitution variable is expanded.
-- ---------------------------------------------------------------------------
SET VERIFY OFF
SET ECHO OFF
SET FEEDBACK ON
WHENEVER SQLERROR EXIT SQL.SQLCODE

-- ---------------------------------------------------------------------------
-- STEP 1: Confirm we are connected via OS authentication
-- ---------------------------------------------------------------------------
SELECT SYS_CONTEXT('USERENV','SESSION_USER')          AS SESSION_USER,
       SYS_CONTEXT('USERENV','AUTHENTICATION_METHOD') AS AUTH_METHOD,
       SYS_CONTEXT('USERENV','CON_NAME')              AS CURRENT_CONTAINER
FROM DUAL;
-- Expected: SESSION_USER=SYS, AUTH_METHOD=OS, CON_NAME=CDB$ROOT

-- ---------------------------------------------------------------------------
-- STEP 2: Switch to FREEPDB1
-- ---------------------------------------------------------------------------
ALTER SESSION SET CONTAINER = FREEPDB1;

-- Confirm container switch
SELECT SYS_CONTEXT('USERENV', 'CON_NAME') AS CURRENT_CONTAINER FROM DUAL;
-- Expected value: FREEPDB1
-- If this does not show FREEPDB1, stop and investigate before continuing.

-- ---------------------------------------------------------------------------
-- STEP 3: Prompt for CDP_LOADER password (hidden input -- not echoed)
-- ---------------------------------------------------------------------------
-- SQL*Plus ACCEPT reads input without displaying it on screen.
-- The &cdp_loader_password variable is only held in the current SQL*Plus
-- session memory and is undefined (cleared) at the end of this script.
-- ---------------------------------------------------------------------------
ACCEPT cdp_loader_password CHAR PROMPT 'Enter new CDP_LOADER password: ' HIDE

-- ---------------------------------------------------------------------------
-- STEP 4: Create CDP_LOADER schema/user
-- ---------------------------------------------------------------------------
-- Password policy (Oracle Free 23c default):
--   Minimum 8 characters, must contain uppercase, lowercase and digit.
-- The password is quoted to preserve mixed case and allow most special
-- characters. The double-quote character (") is NOT permitted in the
-- password because it is used as the SQL identifier delimiter here.
-- ---------------------------------------------------------------------------
CREATE USER CDP_LOADER
    IDENTIFIED BY "&cdp_loader_password"
    DEFAULT TABLESPACE   USERS
    TEMPORARY TABLESPACE TEMP
    QUOTA UNLIMITED ON   USERS;

-- ---------------------------------------------------------------------------
-- STEP 5: Grant minimum required privileges
-- ---------------------------------------------------------------------------
-- Privileges are derived from actual Flyway migration DDL (V001-V004).
-- Migrations use: CREATE TABLE, CREATE SEQUENCE, CREATE INDEX.
-- CREATE INDEX does not need a separate privilege (index owner = table owner).
-- GENERATED ALWAYS AS IDENTITY requires CREATE SEQUENCE.
-- No VIEWs, PROCEDUREs, TRIGGERs, or TYPEs exist in current migrations.
-- CONNECT role is intentionally excluded -- it is just CREATE SESSION anyway.
-- RESOURCE role is intentionally excluded -- it grants unnecessary privileges
-- such as CREATE CLUSTER, CREATE OPERATOR, CREATE INDEXTYPE.
-- ---------------------------------------------------------------------------
GRANT CREATE SESSION  TO CDP_LOADER;
GRANT CREATE TABLE    TO CDP_LOADER;
GRANT CREATE SEQUENCE TO CDP_LOADER;

-- Flyway also needs to read the data dictionary for migration state tracking.
-- These system views are accessible via CREATE SESSION -- no extra grants.

-- ---------------------------------------------------------------------------
-- STEP 6: Clear the password from session memory
-- ---------------------------------------------------------------------------
UNDEFINE cdp_loader_password

-- ---------------------------------------------------------------------------
-- STEP 7: Verification
-- ---------------------------------------------------------------------------
-- Confirm user exists, is OPEN, and is in FREEPDB1.
SELECT USERNAME,
       ACCOUNT_STATUS,
       DEFAULT_TABLESPACE,
       PROFILE
FROM   DBA_USERS
WHERE  USERNAME = 'CDP_LOADER';

-- Confirm no unexpected roles were granted.
SELECT GRANTED_ROLE, ADMIN_OPTION, DEFAULT_ROLE
FROM   DBA_ROLE_PRIVS
WHERE  GRANTEE = 'CDP_LOADER';
-- Expected: no rows (no roles granted -- only direct system privileges)

-- Confirm exactly the three required system privileges were granted.
SELECT PRIVILEGE, ADMIN_OPTION
FROM   DBA_SYS_PRIVS
WHERE  GRANTEE = 'CDP_LOADER'
ORDER BY PRIVILEGE;
-- Expected rows (exactly):
--   CREATE SEQUENCE   NO
--   CREATE SESSION    NO
--   CREATE TABLE      NO

-- Confirm tablespace quota.
SELECT TABLESPACE_NAME, MAX_BYTES
FROM   DBA_TS_QUOTAS
WHERE  USERNAME = 'CDP_LOADER';
-- Expected: USERS  -1  (-1 means UNLIMITED)

-- =============================================================================
-- EXECUTION COMMANDS (run these in PowerShell -- copy/paste one line at a time)
-- =============================================================================
--
--   Step A: Copy this script into the running Oracle container
--     docker cp infra/oracle/00-dba-bootstrap.sql cdp-oracle-db:/tmp/00-dba-bootstrap.sql
--
--   Step B: Open SQL*Plus inside the container using OS authentication
--     docker exec -it cdp-oracle-db sqlplus / as sysdba
--
--   Step C: At the SQL*Plus prompt, run the script
--     @/tmp/00-dba-bootstrap.sql
--
--   Step D: When prompted "Enter new CDP_LOADER password: " type a strong
--     password and press Enter.  Input is NOT echoed to the screen.
--     Choose a password that does NOT contain a double-quote (") character.
--
--     After the script exits SQL*Plus, load the password into your PowerShell
--     session interactively WITHOUT writing it to command history:
--
--       $env:CDP_ORACLE_PASSWORD = [System.Net.NetworkCredential]::new(
--           '', (Read-Host -AsSecureString 'CDP_ORACLE_PASSWORD')
--       ).Password
--
--     The Spring Boot application reads CDP_ORACLE_PASSWORD from the host
--     environment or from the gitignored application-local.yml.
--     application-local.yml should contain only the placeholder:
--       spring.datasource.password: "${CDP_ORACLE_PASSWORD}"
--     The actual value must never appear in that file.
--
--     infra/docker/.env contains ORACLE_PWD only (the SYS/SYSTEM/PDBADMIN
--     container password).  Do NOT add CDP_ORACLE_PASSWORD to that file.
--
--     Do NOT write the password in chat, in PowerShell history, in any
--     tracked file, or in any unencrypted note.
--
--   Step E: Verify the output matches the expected values in STEP 7 above.
--
--   Step F: Exit SQL*Plus
--     EXIT
--
-- =============================================================================
-- ROLLBACK (if you need to start over)
-- =============================================================================
--   Connect as SYSDBA, switch to FREEPDB1, then:
--     ALTER SESSION SET CONTAINER = FREEPDB1;
--     DROP USER CDP_LOADER CASCADE;
-- =============================================================================
