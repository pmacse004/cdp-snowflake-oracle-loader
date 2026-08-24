-- =============================================================================
-- Snowflake Demo Data Reset — Step 11: Reset Demo Data
-- =============================================================================
-- *** DESTRUCTIVE SCRIPT — MANUAL/DEMO USE ONLY ***
-- *** DO NOT EXECUTE IN ANY ENVIRONMENT THAT IS NOT AN ISOLATED DEMO ***
-- =============================================================================
-- Run as: CDP_ADMIN_ROLE
-- Database: CDP_UTIL_DB (verified in-script before any DELETE)
-- Warehouse: CDP_LOADER_WH
--
-- PURPOSE
--   Remove all generated data from source tables so the Phase 3 generation
--   scripts can be re-run from a clean state.
--
-- WHAT THIS SCRIPT DOES
--   - Verifies CURRENT_DATABASE = CDP_UTIL_DB  (abort if wrong)
--   - Verifies CURRENT_ROLE     = CDP_ADMIN_ROLE (abort if wrong)
--   - Deletes all rows from BILLING.MONTHLY_USAGE
--   - Deletes all rows from SERVICE.METER
--   - Deletes all rows from SERVICE.PREMISE
--   - Deletes all rows from CUSTOMER.BILLING_ACCOUNT
--   - Deletes all rows from CUSTOMER.ENERGY_ACCOUNT
--   - Deletes all rows from CUSTOMER.CUSTOMER_CONTACT
--   - Deletes all rows from CUSTOMER.CUSTOMER
--   - Deletes all rows from REF.CODE_VALUE
--   Deletion order is child-to-parent to respect foreign key relationships.
--
-- WHAT THIS SCRIPT DOES NOT DO
--   - Does NOT drop any database, schema, table, view, warehouse, user,
--     role, or RSA key
--   - Does NOT alter any object definition
--   - Does NOT delete Flyway schema history or Spring Batch metadata
--     (those live in Oracle, not Snowflake)
--
-- SAFE-RUN GUARDS
--   The script checks CURRENT_DATABASE and CURRENT_ROLE before proceeding.
--   If either is incorrect the script prints an error and exits.
--   Review the verification output BEFORE confirming any deletion.
--
-- EXECUTION
--   Run interactively in a Snowflake worksheet.
--   Review the verification block output first.
--   Remove the comment markers on each DELETE statement manually
--   after confirming the guards pass.
-- =============================================================================

-- ---------------------------------------------------------------------------
-- PREFLIGHT CHECK — aborts immediately on wrong database or wrong role
-- *** DESTRUCTIVE SCRIPT — must be CDP_ADMIN_ROLE in CDP_UTIL_DB only ***
-- ---------------------------------------------------------------------------
EXECUTE IMMEDIATE $$
DECLARE
    wrong_database EXCEPTION (
        -20001,
        'PREFLIGHT FAILED: expected database CDP_UTIL_DB'
    );
    wrong_role EXCEPTION (
        -20002,
        'PREFLIGHT FAILED: expected role CDP_ADMIN_ROLE'
    );
BEGIN
    IF (CURRENT_DATABASE() <> 'CDP_UTIL_DB') THEN
        RAISE wrong_database;
    END IF;
    IF (CURRENT_ROLE() <> 'CDP_ADMIN_ROLE') THEN
        RAISE wrong_role;
    END IF;
    RETURN 'PREFLIGHT PASS: CDP_UTIL_DB / CDP_ADMIN_ROLE — review row counts before uncommenting any DELETE';
END;
$$;

USE ROLE CDP_ADMIN_ROLE;
USE DATABASE CDP_UTIL_DB;
USE WAREHOUSE CDP_LOADER_WH;

-- Confirm the warehouse is active
SELECT CURRENT_WAREHOUSE() AS ACTIVE_WAREHOUSE;
-- Expected: CDP_LOADER_WH

-- ===========================================================================
-- PRE-DELETION ROW COUNTS (review before proceeding)
-- ===========================================================================
SELECT 'BILLING.MONTHLY_USAGE'     AS TABLE_NAME, COUNT(*) AS ROWS_TO_DELETE FROM BILLING.MONTHLY_USAGE
UNION ALL SELECT 'SERVICE.METER',                  COUNT(*) FROM SERVICE.METER
UNION ALL SELECT 'SERVICE.PREMISE',                COUNT(*) FROM SERVICE.PREMISE
UNION ALL SELECT 'CUSTOMER.BILLING_ACCOUNT',       COUNT(*) FROM CUSTOMER.BILLING_ACCOUNT
UNION ALL SELECT 'CUSTOMER.ENERGY_ACCOUNT',        COUNT(*) FROM CUSTOMER.ENERGY_ACCOUNT
UNION ALL SELECT 'CUSTOMER.CUSTOMER_CONTACT',      COUNT(*) FROM CUSTOMER.CUSTOMER_CONTACT
UNION ALL SELECT 'CUSTOMER.CUSTOMER',              COUNT(*) FROM CUSTOMER.CUSTOMER
UNION ALL SELECT 'REF.CODE_VALUE',                 COUNT(*) FROM REF.CODE_VALUE
ORDER BY TABLE_NAME;

-- ===========================================================================
-- DELETION GUARD — second independent aborting check immediately before DELETEs
-- Independent of the preflight above: if the preflight block is bypassed,
-- this guard still aborts on wrong database or wrong role.
-- ===========================================================================
EXECUTE IMMEDIATE $$
DECLARE
    wrong_database EXCEPTION (
        -20001,
        'DELETION GUARD FAILED: expected database CDP_UTIL_DB'
    );
    wrong_role EXCEPTION (
        -20002,
        'DELETION GUARD FAILED: expected role CDP_ADMIN_ROLE'
    );
BEGIN
    IF (CURRENT_DATABASE() <> 'CDP_UTIL_DB') THEN
        RAISE wrong_database;
    END IF;
    IF (CURRENT_ROLE() <> 'CDP_ADMIN_ROLE') THEN
        RAISE wrong_role;
    END IF;
    RETURN 'DELETION GUARD PASS: CDP_UTIL_DB / CDP_ADMIN_ROLE — safe to uncomment DELETE statements one at a time';
END;
$$;

-- ===========================================================================
-- DELETION BLOCK
-- Both guards above must have passed.
-- Uncomment each DELETE statement one at a time only after both guards pass.
-- ===========================================================================

-- STEP 1: Delete BILLING records (deepest child)
-- DELETE FROM BILLING.MONTHLY_USAGE;

-- STEP 2: Delete SERVICE records
-- DELETE FROM SERVICE.METER;
-- DELETE FROM SERVICE.PREMISE;

-- STEP 3: Delete CUSTOMER records (child-first)
-- DELETE FROM CUSTOMER.BILLING_ACCOUNT;
-- DELETE FROM CUSTOMER.ENERGY_ACCOUNT;
-- DELETE FROM CUSTOMER.CUSTOMER_CONTACT;
-- DELETE FROM CUSTOMER.CUSTOMER;

-- STEP 4: Delete reference data (safe last — no FKs pointing back)
-- DELETE FROM REF.CODE_VALUE;

-- ===========================================================================
-- POST-DELETION VERIFICATION (run after uncommenting and executing DELETEs)
-- ===========================================================================
-- SELECT 'BILLING.MONTHLY_USAGE'     AS TABLE_NAME, COUNT(*) AS REMAINING FROM BILLING.MONTHLY_USAGE
-- UNION ALL SELECT 'SERVICE.METER',                  COUNT(*) FROM SERVICE.METER
-- UNION ALL SELECT 'SERVICE.PREMISE',                COUNT(*) FROM SERVICE.PREMISE
-- UNION ALL SELECT 'CUSTOMER.BILLING_ACCOUNT',       COUNT(*) FROM CUSTOMER.BILLING_ACCOUNT
-- UNION ALL SELECT 'CUSTOMER.ENERGY_ACCOUNT',        COUNT(*) FROM CUSTOMER.ENERGY_ACCOUNT
-- UNION ALL SELECT 'CUSTOMER.CUSTOMER_CONTACT',      COUNT(*) FROM CUSTOMER.CUSTOMER_CONTACT
-- UNION ALL SELECT 'CUSTOMER.CUSTOMER',              COUNT(*) FROM CUSTOMER.CUSTOMER
-- UNION ALL SELECT 'REF.CODE_VALUE',                 COUNT(*) FROM REF.CODE_VALUE
-- ORDER BY TABLE_NAME;
-- All REMAINING counts must = 0 before re-running generation scripts.
