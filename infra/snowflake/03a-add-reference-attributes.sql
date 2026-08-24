-- =============================================================================
-- Snowflake Provisioning — Step 3a: Add ATTRIBUTES Column to CODE_VALUE
-- =============================================================================
-- Run as: CDP_ADMIN_ROLE
-- Database: CDP_UTIL_DB
-- Warehouse: CDP_LOADER_WH
--
-- PURPOSE
--   Script 03-create-source-tables.sql was executed BEFORE the ATTRIBUTES
--   VARIANT column was designed.  This repair script adds the column
--   idempotently using ALTER TABLE ... ADD COLUMN IF NOT EXISTS, which is
--   safe to run on a table that already has data or on a fresh database
--   (where 03 has been updated to include ATTRIBUTES and IF NOT EXISTS
--   prevents duplicate-column errors).
--
-- DESIGN DECISION (Issue #1 — ATTRIBUTES/CODE_LABEL split)
--   CODE_LABEL  VARCHAR(500) — human-readable label ONLY.
--                               Example: 'Residential Standard'
--   ATTRIBUTES  VARIANT      — machine-readable structured parameters.
--                               Example: {"fixed":8.50,"energy":0.1150,
--                                         "demand":null,"tax":0.0800,
--                                         "synthetic":true}
--   Mixing JSON into a VARCHAR column that is declared as a human label
--   causes ambiguity when parsing and violates the ICA data dictionary.
--   The VARIANT column gives Snowflake native VARIANT path access
--   (rp.ATTRIBUTES['fixed']::STRING) without TRY_PARSE_JSON overhead.
--
-- IDEMPOTENCY
--   ALTER TABLE ... ADD COLUMN IF NOT EXISTS — no error if column exists.
--   Safe to run on a live table with data; existing rows receive NULL for
--   the new column until 05-seed-reference-data.sql populates it.
--
-- PREREQUISITE
--   Script 03-create-source-tables.sql must have been executed first.
--
-- EXECUTION ORDER
--   Run AFTER script 03 (if 03 was executed without ATTRIBUTES).
--   Run BEFORE script 05 (which populates ATTRIBUTES values).
-- =============================================================================

-- ---------------------------------------------------------------------------
-- PREFLIGHT — aborts immediately on wrong database or role
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
    RETURN 'PREFLIGHT PASS: CDP_UTIL_DB / CDP_ADMIN_ROLE';
END;
$$;

USE ROLE CDP_ADMIN_ROLE;
USE DATABASE CDP_UTIL_DB;
USE SCHEMA REF;
USE WAREHOUSE CDP_LOADER_WH;

-- ---------------------------------------------------------------------------
-- ADD ATTRIBUTES VARIANT column (idempotent — IF NOT EXISTS)
-- ---------------------------------------------------------------------------
ALTER TABLE REF.CODE_VALUE
    ADD COLUMN IF NOT EXISTS ATTRIBUTES VARIANT;

-- ---------------------------------------------------------------------------
-- Verify the column now exists
-- ---------------------------------------------------------------------------
SELECT COLUMN_NAME, DATA_TYPE, IS_NULLABLE
FROM INFORMATION_SCHEMA.COLUMNS
WHERE TABLE_SCHEMA  = 'REF'
  AND TABLE_NAME    = 'CODE_VALUE'
  AND COLUMN_NAME   = 'ATTRIBUTES';
-- Expected: 1 row — ATTRIBUTES | VARIANT | YES

-- ---------------------------------------------------------------------------
-- Show the final column list for REF.CODE_VALUE
-- ---------------------------------------------------------------------------
SELECT COLUMN_NAME, ORDINAL_POSITION, DATA_TYPE, CHARACTER_MAXIMUM_LENGTH, IS_NULLABLE
FROM INFORMATION_SCHEMA.COLUMNS
WHERE TABLE_SCHEMA = 'REF'
  AND TABLE_NAME   = 'CODE_VALUE'
ORDER BY ORDINAL_POSITION;
-- Expected columns (in order):
--   CODE_VALUE_ID, DOMAIN, CODE, CODE_LABEL, ATTRIBUTES, DESCRIPTION,
--   DISPLAY_ORDER, IS_ACTIVE, CREATED_AT, UPDATED_AT
-- (ATTRIBUTES may appear at end if added via ALTER — position is immaterial)
