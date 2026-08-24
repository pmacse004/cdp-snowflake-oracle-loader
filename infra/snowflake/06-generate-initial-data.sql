-- =============================================================================
-- Snowflake Data Generation — Step 6: Generate Initial Dataset
-- =============================================================================
-- Run as: CDP_ADMIN_ROLE
-- Database: CDP_UTIL_DB
-- Warehouse: CDP_LOADER_WH
--
-- PURPOSE
--   Populate all source tables with a synthetic initial dataset of 10,000
--   CUSTOMER rows and realistic related child records.
--
-- ROW COUNT CLARIFICATION
--   "10,000 initial records" = 10,000 CUSTOMER rows specifically.
--   Total rows across all tables will be higher:
--     CUSTOMER             10,000  (exact — from GENERATOR)
--     CUSTOMER_CONTACT    ~20,000  (emails + phones + alternates)
--     ENERGY_ACCOUNT      ~10,500  (10,000 primary + ~500 secondary)
--     BILLING_ACCOUNT     ~10,500  (one per energy account)
--     PREMISE             ~10,500  (one per energy account)
--     METER               ~10,500  (one per premise)
--     MONTHLY_USAGE       ~31,500  (~10,500 active accounts × 3 months)
--
-- SYNTHETIC DATA NOTICE
--   All names, addresses, phone numbers, email addresses and account numbers
--   are completely fictional and obviously synthetic:
--     - Names:  drawn from a fixed 50×50 deterministic pool
--     - Emails: RFC 2606 reserved domains @example.com and @synth.invalid
--     - Phones: NANPA fiction range 555-0100 through 555-0199 ONLY
--     - Addresses: fictional street names with real US state codes
--
-- DEMO_AS_OF_DATE
--   A fixed literal date used for all business dates (billing periods,
--   effective dates, closure dates, installation dates).
--   *** OPERATOR PARAMETER — set once here, same value must appear in 05–10 ***
--   UPDATED_AT and CREATED_AT use CURRENT_TIMESTAMP() so incremental
--   watermarks are real technical timestamps, not demo dates.
--
-- IDEMPOTENCY
--   Each table is guarded with WHERE (SELECT COUNT(*) FROM table) = 0.
--   For restart after partial failure, run 11-reset-demo-data.sql first.
--
-- PREREQUISITE
--   05-seed-reference-data.sql must have been run first.
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
USE WAREHOUSE CDP_LOADER_WH;

-- ---------------------------------------------------------------------------
-- DEMO_AS_OF_DATE — fixed demo anchor date
-- ---------------------------------------------------------------------------
-- *** OPERATOR PARAMETER — must match the value used in scripts 05–10 ***
-- Use the FIRST day of a month (YYYY-MM-01) for clean billing-month boundaries.
-- Business dates (billing periods, effective dates, closure dates,
-- installation dates) reference this value.
-- CREATED_AT and UPDATED_AT remain CURRENT_TIMESTAMP() — real timestamps.
-- ---------------------------------------------------------------------------
SET DEMO_AS_OF_DATE = TO_DATE('2026-06-01');
SELECT $DEMO_AS_OF_DATE AS DEMO_ANCHOR_DATE;
-- Expected output: 2026-06-01

-- Verify REF.CODE_VALUE has data (script 05 must have run)
EXECUTE IMMEDIATE $$
DECLARE
    missing_reference_data EXCEPTION (
        -20003,
        'PREFLIGHT FAILED: REF.CODE_VALUE has fewer than 43 rows — run 05-seed-reference-data.sql first'
    );
    ref_count INTEGER;
BEGIN
    SELECT COUNT(*) INTO :ref_count FROM REF.CODE_VALUE;
    IF (ref_count < 43) THEN
        RAISE missing_reference_data;
    END IF;
    RETURN 'Reference data present — ' || ref_count || ' rows OK';
END;
$$;

-- ===========================================================================
-- GUARD: abort if CUSTOMER already has data (prevents double-load)
-- To re-run from scratch, execute 11-reset-demo-data.sql first.
-- ===========================================================================
EXECUTE IMMEDIATE $$
DECLARE
    customer_table_not_empty EXCEPTION (
        -20004,
        'LOAD GUARD: CUSTOMER table already has data — run 11-reset-demo-data.sql first'
    );
    cust_count INTEGER;
BEGIN
    SELECT COUNT(*) INTO :cust_count FROM CUSTOMER.CUSTOMER;
    IF (cust_count > 0) THEN
        RAISE customer_table_not_empty;
    END IF;
    RETURN 'LOAD GUARD PASSED — CUSTOMER is empty, proceeding with generation';
END;
$$;

-- ===========================================================================
-- NAME AND CITY POOLS
-- Deterministic arrays used to derive synthetic names from row numbers.
-- ===========================================================================

-- First names (50 synthetic entries — will be cycled via MOD)
-- Last names (50 synthetic entries)
-- Cities (20 fictional US city names + real state codes)
-- Street names (30 fictional street names)
-- Street types (10 types)

-- ===========================================================================
-- SCHEMA: CUSTOMER — populate CUSTOMER (10,000 rows)
-- ===========================================================================
USE SCHEMA CUSTOMER;

INSERT INTO CUSTOMER (
    CUSTOMER_ID, FIRST_NAME, LAST_NAME, MIDDLE_NAME,
    CUSTOMER_TYPE, DATE_OF_BIRTH, PREFERRED_LANGUAGE,
    ACCOUNT_STATUS, STATUS_REASON, CREATED_AT, UPDATED_AT
)
SELECT
    'CUST-' || LPAD(ROW_NUMBER() OVER (ORDER BY SEQ4()), 6, '0') AS CUSTOMER_ID,

    -- Synthetic first names cycling through a pool of 50
    CASE MOD(SEQ4(), 50)
        WHEN 0  THEN 'Alexis'   WHEN 1  THEN 'Brandon'  WHEN 2  THEN 'Cassandra'
        WHEN 3  THEN 'Darnell'  WHEN 4  THEN 'Elspeth'  WHEN 5  THEN 'Fitzgerald'
        WHEN 6  THEN 'Gwendolyn'WHEN 7  THEN 'Horatio'  WHEN 8  THEN 'Ingrid'
        WHEN 9  THEN 'Jasper'   WHEN 10 THEN 'Katrina'  WHEN 11 THEN 'Leonidas'
        WHEN 12 THEN 'Marisol'  WHEN 13 THEN 'Nathaniel'WHEN 14 THEN 'Ophelia'
        WHEN 15 THEN 'Percival' WHEN 16 THEN 'Quintessa'WHEN 17 THEN 'Reginald'
        WHEN 18 THEN 'Sylvester'WHEN 19 THEN 'Theodora' WHEN 20 THEN 'Ulysses'
        WHEN 21 THEN 'Valentina'WHEN 22 THEN 'Wentworth'WHEN 23 THEN 'Xanthe'
        WHEN 24 THEN 'Yvonne'   WHEN 25 THEN 'Zachariah'WHEN 26 THEN 'Abernathy'
        WHEN 27 THEN 'Bellamy'  WHEN 28 THEN 'Cornelius'WHEN 29 THEN 'Desdemona'
        WHEN 30 THEN 'Evander'  WHEN 31 THEN 'Fenwick'  WHEN 32 THEN 'Griselda'
        WHEN 33 THEN 'Hildebrand'WHEN 34 THEN 'Isolde'  WHEN 35 THEN 'Jebediah'
        WHEN 36 THEN 'Kestrel'  WHEN 37 THEN 'Lavinia'  WHEN 38 THEN 'Mortimer'
        WHEN 39 THEN 'Niamh'    WHEN 40 THEN 'Oberon'   WHEN 41 THEN 'Peregrine'
        WHEN 42 THEN 'Rosalind' WHEN 43 THEN 'Thaddeus' WHEN 44 THEN 'Ursula'
        WHEN 45 THEN 'Vespera'  WHEN 46 THEN 'Wisteria' WHEN 47 THEN 'Xiomara'
        WHEN 48 THEN 'Yaroslav' ELSE 'Zenobia'
    END AS FIRST_NAME,

    -- Synthetic last names cycling through a pool of 50
    CASE MOD(SEQ4() + 7, 50)
        WHEN 0  THEN 'Ashworth'  WHEN 1  THEN 'Blackstone'WHEN 2  THEN 'Carmichael'
        WHEN 3  THEN 'Dunsworth' WHEN 4  THEN 'Eagleston' WHEN 5  THEN 'Fairweather'
        WHEN 6  THEN 'Goldenrod' WHEN 7  THEN 'Harrington'WHEN 8  THEN 'Ingleborough'
        WHEN 9  THEN 'Jacksworth'WHEN 10 THEN 'Kinderhook'WHEN 11 THEN 'Lampshire'
        WHEN 12 THEN 'Meadowbrook'WHEN 13 THEN 'Norrington'WHEN 14 THEN 'Overbrook'
        WHEN 15 THEN 'Pennington'WHEN 16 THEN 'Quarterfield'WHEN 17 THEN 'Ravenscroft'
        WHEN 18 THEN 'Stonebridge'WHEN 19 THEN 'Throgmorton'WHEN 20 THEN 'Underhill'
        WHEN 21 THEN 'Vanderberg'WHEN 22 THEN 'Whitmore'  WHEN 23 THEN 'Xerxington'
        WHEN 24 THEN 'Yarborough'WHEN 25 THEN 'Zellweger' WHEN 26 THEN 'Ashby'
        WHEN 27 THEN 'Broadmore' WHEN 28 THEN 'Claridge'  WHEN 29 THEN 'Dreadnought'
        WHEN 30 THEN 'Elmswood'  WHEN 31 THEN 'Foxglove'  WHEN 32 THEN 'Greystone'
        WHEN 33 THEN 'Holloway'  WHEN 34 THEN 'Ironbridge' WHEN 35 THEN 'Juniper'
        WHEN 36 THEN 'Kelmore'   WHEN 37 THEN 'Longfellow' WHEN 38 THEN 'Moorgate'
        WHEN 39 THEN 'Northgate' WHEN 40 THEN 'Olmsford'  WHEN 41 THEN 'Primrose'
        WHEN 42 THEN 'Queensbury'WHEN 43 THEN 'Redfield'  WHEN 44 THEN 'Silverstone'
        WHEN 45 THEN 'Thornwood' WHEN 46 THEN 'Upperton'  WHEN 47 THEN 'Valebrook'
        WHEN 48 THEN 'Windermere'ELSE 'Yeomans'
    END AS LAST_NAME,

    -- Middle name for ~30% of customers
    CASE WHEN MOD(SEQ4(), 10) < 3 THEN
        CASE MOD(SEQ4(), 26)
            WHEN 0  THEN 'A' WHEN 1  THEN 'B' WHEN 2  THEN 'C' WHEN 3  THEN 'D'
            WHEN 4  THEN 'E' WHEN 5  THEN 'F' WHEN 6  THEN 'G' WHEN 7  THEN 'H'
            WHEN 8  THEN 'J' WHEN 9  THEN 'K' WHEN 10 THEN 'L' WHEN 11 THEN 'M'
            WHEN 12 THEN 'N' WHEN 13 THEN 'P' WHEN 14 THEN 'R' WHEN 15 THEN 'S'
            WHEN 16 THEN 'T' WHEN 17 THEN 'V' WHEN 18 THEN 'W' WHEN 19 THEN 'A'
            ELSE NULL
        END
    ELSE NULL END AS MIDDLE_NAME,

    -- Customer type distribution: 70% RESIDENTIAL, 20% COMMERCIAL, 10% INDUSTRIAL
    CASE
        WHEN MOD(SEQ4(), 10) < 7 THEN 'RESIDENTIAL'
        WHEN MOD(SEQ4(), 10) < 9 THEN 'COMMERCIAL'
        ELSE 'INDUSTRIAL'
    END AS CUSTOMER_TYPE,

    -- Date of birth only for residential customers (null for commercial/industrial)
    CASE
        WHEN MOD(SEQ4(), 10) < 7
        THEN DATEADD(YEAR, -(25 + MOD(SEQ4(), 55)),
             DATEADD(DAY, MOD(SEQ4(), 365), '1970-01-01'::DATE))
        ELSE NULL
    END AS DATE_OF_BIRTH,

    -- Language: 85% English, 10% Spanish, 5% French
    CASE
        WHEN MOD(SEQ4(), 20) < 17 THEN 'EN'
        WHEN MOD(SEQ4(), 20) < 19 THEN 'ES'
        ELSE 'FR'
    END AS PREFERRED_LANGUAGE,

    -- Account status: 82% ACTIVE, 10% INACTIVE, 5% PENDING, 3% CLOSED
    CASE
        WHEN MOD(SEQ4(), 100) < 82 THEN 'ACTIVE'
        WHEN MOD(SEQ4(), 100) < 92 THEN 'INACTIVE'
        WHEN MOD(SEQ4(), 100) < 97 THEN 'PENDING'
        ELSE 'CLOSED'
    END AS ACCOUNT_STATUS,

    NULL AS STATUS_REASON,

    -- CREATED_AT / UPDATED_AT: technical timestamps, derived from CURRENT_TIMESTAMP()
    -- spread back in time to simulate accounts opened at various points in the past.
    -- Using CURRENT_TIMESTAMP() (not $DEMO_AS_OF_DATE) so watermarks are real
    -- technical values that the incremental ETL watermark mechanism can use.
    DATEADD(DAY, -MOD(SEQ4(), 1095),
        DATEADD(HOUR, -MOD(SEQ4(), 24), CURRENT_TIMESTAMP())) AS CREATED_AT,
    DATEADD(DAY, -MOD(SEQ4(), 365),
        DATEADD(HOUR, -MOD(SEQ4(), 24), CURRENT_TIMESTAMP())) AS UPDATED_AT

FROM TABLE(GENERATOR(ROWCOUNT => 10000))
WHERE (SELECT COUNT(*) FROM CUSTOMER.CUSTOMER) = 0;

-- ===========================================================================
-- SCHEMA: CUSTOMER — CUSTOMER_CONTACT
-- One primary email per customer; primary phone for 80%; secondary email for 20%
-- Emails use @example.com (RFC 2606 reserved) — NOT real addresses
-- Phones use 555-xxxx range — NOT real numbers
-- ===========================================================================

-- Primary email contacts (all 10,000 customers)
INSERT INTO CUSTOMER_CONTACT (
    CONTACT_ID, CUSTOMER_ID, CONTACT_TYPE, CONTACT_VALUE,
    IS_PRIMARY, IS_VERIFIED, EFFECTIVE_DATE, END_DATE, CREATED_AT, UPDATED_AT
)
SELECT
    'CONT-E-' || LPAD(ROW_NUMBER() OVER (ORDER BY c.CUSTOMER_ID), 6, '0'),
    c.CUSTOMER_ID,
    'EMAIL',
    LOWER(c.FIRST_NAME) || '.' || LOWER(c.LAST_NAME) || '.'
        || LPAD(SUBSTRING(c.CUSTOMER_ID, 6, 6), 6, '0')
        || '@example.com',
    TRUE,
    CASE WHEN MOD(HASH(c.CUSTOMER_ID), 10) < 8 THEN TRUE ELSE FALSE END,
    DATEADD(DAY, -DATEDIFF(DAY, c.CREATED_AT::DATE, $DEMO_AS_OF_DATE) + 1, $DEMO_AS_OF_DATE),
    NULL,
    c.CREATED_AT,
    c.UPDATED_AT
FROM CUSTOMER.CUSTOMER c
WHERE (SELECT COUNT(*) FROM CUSTOMER.CUSTOMER_CONTACT WHERE CONTACT_TYPE = 'EMAIL' AND IS_PRIMARY = TRUE) = 0;

-- Primary phone contacts (80% of customers → ~8,000 rows)
-- PHONE RANGE (Issue #13 fix): uses 555-0100 to 555-0199 ONLY.
-- This is the specific 100-number range reserved by NANPA for fictional use.
-- Formula: '555-0' || LPAD(MOD(ABS(HASH(…)), 100), 3, '0')
-- produces 555-0000 through 555-0099, which when written as '555-0' + 3 digits
-- creates 555-0000 … 555-0099.  For the 555-0100-0199 range use base offset:
-- '555-' || LPAD(100 + MOD(ABS(HASH(…)), 100), 4, '0')
-- produces 555-0100 to 555-0199.
INSERT INTO CUSTOMER_CONTACT (
    CONTACT_ID, CUSTOMER_ID, CONTACT_TYPE, CONTACT_VALUE,
    IS_PRIMARY, IS_VERIFIED, EFFECTIVE_DATE, END_DATE, CREATED_AT, UPDATED_AT
)
SELECT
    'CONT-P-' || LPAD(ROW_NUMBER() OVER (ORDER BY c.CUSTOMER_ID), 6, '0'),
    c.CUSTOMER_ID,
    'PHONE',
    -- Restricted to 555-0100 through 555-0199 (NANPA fiction range)
    '555-' || LPAD(100 + MOD(ABS(HASH(c.CUSTOMER_ID)), 100), 4, '0'),
    TRUE,
    CASE WHEN MOD(ABS(HASH(c.CUSTOMER_ID || 'V')), 10) < 7 THEN TRUE ELSE FALSE END,
    DATEADD(DAY, -DATEDIFF(DAY, c.CREATED_AT::DATE, $DEMO_AS_OF_DATE) + 1, $DEMO_AS_OF_DATE),
    NULL,
    c.CREATED_AT,
    c.UPDATED_AT
FROM CUSTOMER.CUSTOMER c
WHERE MOD(ABS(HASH(c.CUSTOMER_ID)), 10) < 8
  AND (SELECT COUNT(*) FROM CUSTOMER.CUSTOMER_CONTACT WHERE CONTACT_TYPE = 'PHONE' AND IS_PRIMARY = TRUE) = 0;

-- Secondary / alternate email contacts (~20% of customers → ~2,000 rows)
INSERT INTO CUSTOMER_CONTACT (
    CONTACT_ID, CUSTOMER_ID, CONTACT_TYPE, CONTACT_VALUE,
    IS_PRIMARY, IS_VERIFIED, EFFECTIVE_DATE, END_DATE, CREATED_AT, UPDATED_AT
)
SELECT
    'CONT-E2-' || LPAD(ROW_NUMBER() OVER (ORDER BY c.CUSTOMER_ID), 6, '0'),
    c.CUSTOMER_ID,
    'EMAIL',
    LOWER(c.LAST_NAME) || '.alt.'
        || LPAD(SUBSTRING(c.CUSTOMER_ID, 6, 6), 6, '0')
        || '@synth.invalid',
    FALSE,
    FALSE,
    DATEADD(DAY, -DATEDIFF(DAY, c.CREATED_AT::DATE, $DEMO_AS_OF_DATE) + 1, $DEMO_AS_OF_DATE),
    NULL,
    c.CREATED_AT,
    c.UPDATED_AT
FROM CUSTOMER.CUSTOMER c
WHERE MOD(ABS(HASH(c.CUSTOMER_ID || 'ALT')), 10) < 2
  AND (SELECT COUNT(*) FROM CUSTOMER.CUSTOMER_CONTACT WHERE IS_PRIMARY = FALSE AND CONTACT_TYPE = 'EMAIL') = 0;

-- ===========================================================================
-- SCHEMA: CUSTOMER — ENERGY_ACCOUNT
-- ~10,000 primary accounts (one per customer)
-- ~500 secondary accounts (5% of customers have a second account)
-- ===========================================================================
INSERT INTO ENERGY_ACCOUNT (
    ENERGY_ACCOUNT_ID, CUSTOMER_ID, ACCOUNT_NUMBER,
    ACCOUNT_STATUS, SERVICE_TYPE, RATE_CLASS, OPEN_DATE, CLOSE_DATE,
    CREATED_AT, UPDATED_AT
)
SELECT
    'EA-' || LPAD(ROW_NUMBER() OVER (ORDER BY c.CUSTOMER_ID), 6, '0') AS ENERGY_ACCOUNT_ID,
    c.CUSTOMER_ID,
    'ACCT-' || LPAD(ROW_NUMBER() OVER (ORDER BY c.CUSTOMER_ID), 8, '0') AS ACCOUNT_NUMBER,
    c.ACCOUNT_STATUS,
    'ELECTRIC',
    CASE
        WHEN c.CUSTOMER_TYPE = 'INDUSTRIAL'  THEN 'LARGE_INDUSTRIAL'
        WHEN c.CUSTOMER_TYPE = 'COMMERCIAL'  THEN
            CASE WHEN MOD(ABS(HASH(c.CUSTOMER_ID)), 2) = 0
                 THEN 'SMALL_COMMERCIAL' ELSE 'MEDIUM_COMMERCIAL' END
        WHEN MOD(ABS(HASH(c.CUSTOMER_ID)), 20) = 0 THEN 'SOLAR_NET'
        ELSE 'RESIDENTIAL'
    END AS RATE_CLASS,
    c.CREATED_AT::DATE AS OPEN_DATE,
    CASE WHEN c.ACCOUNT_STATUS IN ('CLOSED','INACTIVE')
         THEN DATEADD(DAY, -MOD(ABS(HASH(c.CUSTOMER_ID)), 180), $DEMO_AS_OF_DATE::DATE)
         ELSE NULL END AS CLOSE_DATE,
    c.CREATED_AT, c.UPDATED_AT
FROM CUSTOMER.CUSTOMER c
WHERE (SELECT COUNT(*) FROM CUSTOMER.ENERGY_ACCOUNT) = 0;

-- Secondary energy accounts for 5% of active customers
INSERT INTO ENERGY_ACCOUNT (
    ENERGY_ACCOUNT_ID, CUSTOMER_ID, ACCOUNT_NUMBER,
    ACCOUNT_STATUS, SERVICE_TYPE, RATE_CLASS, OPEN_DATE, CLOSE_DATE,
    CREATED_AT, UPDATED_AT
)
SELECT
    'EA-S-' || LPAD(ROW_NUMBER() OVER (ORDER BY c.CUSTOMER_ID), 5, '0'),
    c.CUSTOMER_ID,
    'ACCT-S-' || LPAD(ROW_NUMBER() OVER (ORDER BY c.CUSTOMER_ID), 7, '0'),
    'ACTIVE', 'ELECTRIC', 'RESIDENTIAL',
    -- OPEN_DATE is a business date → $DEMO_AS_OF_DATE
    DATEADD(DAY, -MOD(ABS(HASH(c.CUSTOMER_ID || 'SEC')), 365), $DEMO_AS_OF_DATE::DATE),
    NULL,
    -- CREATED_AT / UPDATED_AT are technical timestamps → CURRENT_TIMESTAMP()
    DATEADD(DAY, -MOD(ABS(HASH(c.CUSTOMER_ID || 'SEC')), 365), CURRENT_TIMESTAMP()),
    CURRENT_TIMESTAMP()
FROM CUSTOMER.CUSTOMER c
WHERE c.ACCOUNT_STATUS = 'ACTIVE'
  AND MOD(ABS(HASH(c.CUSTOMER_ID || 'SEC2')), 20) = 0
  AND (SELECT COUNT(*) FROM CUSTOMER.ENERGY_ACCOUNT WHERE ENERGY_ACCOUNT_ID LIKE 'EA-S-%') = 0;

-- ===========================================================================
-- SCHEMA: CUSTOMER — BILLING_ACCOUNT
-- One billing account per energy account
-- ===========================================================================
INSERT INTO BILLING_ACCOUNT (
    BILLING_ACCOUNT_ID, ENERGY_ACCOUNT_ID, BILLING_ACCOUNT_NBR,
    BILLING_CYCLE, PAYMENT_METHOD, AUTO_PAY_ENROLLED, PAPERLESS_ENROLLED,
    EFFECTIVE_DATE, END_DATE, CREATED_AT, UPDATED_AT
)
SELECT
    'BA-' || LPAD(ROW_NUMBER() OVER (ORDER BY ea.ENERGY_ACCOUNT_ID), 6, '0'),
    ea.ENERGY_ACCOUNT_ID,
    'BILL-' || LPAD(ROW_NUMBER() OVER (ORDER BY ea.ENERGY_ACCOUNT_ID), 8, '0'),
    CASE MOD(ABS(HASH(ea.ENERGY_ACCOUNT_ID || 'BC')), 20)
        WHEN 0 THEN '01' WHEN 1 THEN '02' WHEN 2 THEN '03' WHEN 3 THEN '04'
        WHEN 4 THEN '05' WHEN 5 THEN '06' WHEN 6 THEN '07' WHEN 7 THEN '08'
        WHEN 8 THEN '09' WHEN 9 THEN '10' WHEN 10 THEN '11' WHEN 11 THEN '12'
        WHEN 12 THEN '13' WHEN 13 THEN '14' WHEN 14 THEN '15' WHEN 15 THEN '16'
        WHEN 16 THEN '17' WHEN 17 THEN '18' WHEN 18 THEN '19' ELSE '20'
    END AS BILLING_CYCLE,
    CASE MOD(ABS(HASH(ea.ENERGY_ACCOUNT_ID || 'PM')), 10)
        WHEN 0 THEN 'AUTO_PAY'
        WHEN 1 THEN 'ONLINE'
        ELSE 'PAPER_BILL'
    END AS PAYMENT_METHOD,
    MOD(ABS(HASH(ea.ENERGY_ACCOUNT_ID || 'AP')), 3) = 0 AS AUTO_PAY_ENROLLED,
    MOD(ABS(HASH(ea.ENERGY_ACCOUNT_ID || 'PP')), 4) = 0 AS PAPERLESS_ENROLLED,
    ea.OPEN_DATE AS EFFECTIVE_DATE,
    ea.CLOSE_DATE AS END_DATE,
    ea.CREATED_AT, ea.UPDATED_AT
FROM CUSTOMER.ENERGY_ACCOUNT ea
WHERE (SELECT COUNT(*) FROM CUSTOMER.BILLING_ACCOUNT) = 0;

-- ===========================================================================
-- SCHEMA: SERVICE — PREMISE
-- One premise per energy account
-- Uses fictional street names, real US state codes, synthetic cities
-- ===========================================================================
USE SCHEMA SERVICE;

INSERT INTO PREMISE (
    PREMISE_ID, ENERGY_ACCOUNT_ID,
    ADDRESS_LINE1, ADDRESS_LINE2, CITY, STATE_CODE, ZIP_CODE, COUNTY,
    GEO_LATITUDE, GEO_LONGITUDE, PREMISE_TYPE,
    EFFECTIVE_DATE, END_DATE, CREATED_AT, UPDATED_AT
)
SELECT
    'PREM-' || LPAD(ROW_NUMBER() OVER (ORDER BY ea.ENERGY_ACCOUNT_ID), 6, '0'),
    ea.ENERGY_ACCOUNT_ID,

    -- Synthetic address: number + fictional street name
    CAST(100 + MOD(ABS(HASH(ea.ENERGY_ACCOUNT_ID || 'ST')), 9900) AS VARCHAR)
    || ' '
    || CASE MOD(ABS(HASH(ea.ENERGY_ACCOUNT_ID || 'SN')), 30)
        WHEN 0  THEN 'Sunridge'    WHEN 1  THEN 'Millbrook'   WHEN 2  THEN 'Elmwood'
        WHEN 3  THEN 'Clearwater'  WHEN 4  THEN 'Pinecrest'   WHEN 5  THEN 'Oakdale'
        WHEN 6  THEN 'Mapleleaf'   WHEN 7  THEN 'Birchwood'   WHEN 8  THEN 'Willowbend'
        WHEN 9  THEN 'Cedarbrook'  WHEN 10 THEN 'Riverstone'  WHEN 11 THEN 'Valleyview'
        WHEN 12 THEN 'Crestwood'   WHEN 13 THEN 'Highpoint'   WHEN 14 THEN 'Lakeshore'
        WHEN 15 THEN 'Northbrook'  WHEN 16 THEN 'Southridge'  WHEN 17 THEN 'Eastfield'
        WHEN 18 THEN 'Westmoor'    WHEN 19 THEN 'Foxrun'      WHEN 20 THEN 'Stonegate'
        WHEN 21 THEN 'Meadowlark'  WHEN 22 THEN 'Springwater' WHEN 23 THEN 'Ashbrook'
        WHEN 24 THEN 'Timberline'  WHEN 25 THEN 'Ironwood'    WHEN 26 THEN 'Redwood'
        WHEN 27 THEN 'Goldengrove' WHEN 28 THEN 'Silverbell'  ELSE 'Coppergate'
       END
    || ' '
    || CASE MOD(ABS(HASH(ea.ENERGY_ACCOUNT_ID || 'TY')), 8)
        WHEN 0 THEN 'Dr'  WHEN 1 THEN 'Ave' WHEN 2 THEN 'Blvd'
        WHEN 3 THEN 'Ct'  WHEN 4 THEN 'Ln'  WHEN 5 THEN 'Pl'
        WHEN 6 THEN 'Rd'  ELSE 'Way'
       END AS ADDRESS_LINE1,

    -- Apt/Unit for ~20% of residential
    CASE WHEN MOD(ABS(HASH(ea.ENERGY_ACCOUNT_ID || 'APT')), 5) = 0
         THEN 'Apt ' || CAST(1 + MOD(ABS(HASH(ea.ENERGY_ACCOUNT_ID)), 99) AS VARCHAR)
         ELSE NULL END AS ADDRESS_LINE2,

    -- Synthetic city names
    CASE MOD(ABS(HASH(ea.ENERGY_ACCOUNT_ID || 'CITY')), 20)
        WHEN 0  THEN 'Synthport'    WHEN 1  THEN 'Demoville'    WHEN 2  THEN 'Testburg'
        WHEN 3  THEN 'Faketon'      WHEN 4  THEN 'Sampleton'    WHEN 5  THEN 'Genericburg'
        WHEN 6  THEN 'Placeholder'  WHEN 7  THEN 'Exampleville' WHEN 8  THEN 'Mockridge'
        WHEN 9  THEN 'Simulatia'    WHEN 10 THEN 'Demopolis'    WHEN 11 THEN 'Testfield'
        WHEN 12 THEN 'Synthdale'    WHEN 13 THEN 'Databurg'     WHEN 14 THEN 'Loadville'
        WHEN 15 THEN 'Batchton'     WHEN 16 THEN 'ETLburg'      WHEN 17 THEN 'Pipelinecia'
        WHEN 18 THEN 'Warehouseville'ELSE 'Snowflakeport'
    END AS CITY,

    -- Cycle through 10 US state codes
    CASE MOD(ABS(HASH(ea.ENERGY_ACCOUNT_ID || 'ST2')), 10)
        WHEN 0 THEN 'TX' WHEN 1 THEN 'CA' WHEN 2 THEN 'FL' WHEN 3 THEN 'NY'
        WHEN 4 THEN 'IL' WHEN 5 THEN 'PA' WHEN 6 THEN 'OH' WHEN 7 THEN 'GA'
        WHEN 8 THEN 'NC' ELSE 'MI'
    END AS STATE_CODE,

    -- ZIP: 5-digit synthetic
    LPAD(CAST(10000 + MOD(ABS(HASH(ea.ENERGY_ACCOUNT_ID || 'ZIP')), 89999) AS VARCHAR), 5, '0') AS ZIP_CODE,

    -- County (synthetic)
    CASE MOD(ABS(HASH(ea.ENERGY_ACCOUNT_ID || 'CTY')), 10)
        WHEN 0 THEN 'Synth County'  WHEN 1 THEN 'Demo County'   WHEN 2 THEN 'Test County'
        WHEN 3 THEN 'Sample County' WHEN 4 THEN 'Mock County'   WHEN 5 THEN 'Model County'
        WHEN 6 THEN 'Data County'   WHEN 7 THEN 'Load County'   WHEN 8 THEN 'ETL County'
        ELSE 'Batch County'
    END AS COUNTY,

    -- Synthetic geo coordinates near US geographic center with slight offset
    ROUND(39.5 + (MOD(ABS(HASH(ea.ENERGY_ACCOUNT_ID || 'LAT')), 2000) / 100.0) - 10.0, 6) AS GEO_LATITUDE,
    ROUND(-98.4 + (MOD(ABS(HASH(ea.ENERGY_ACCOUNT_ID || 'LON')), 3000) / 100.0) - 15.0, 6) AS GEO_LONGITUDE,

    -- Premise type aligned to customer type
    CASE
        WHEN ea.RATE_CLASS LIKE '%INDUSTRIAL%' THEN 'INDUSTRIAL'
        WHEN ea.RATE_CLASS LIKE '%COMMERCIAL%' THEN 'COMMERCIAL'
        ELSE 'RESIDENTIAL'
    END AS PREMISE_TYPE,

    ea.OPEN_DATE AS EFFECTIVE_DATE,
    ea.CLOSE_DATE AS END_DATE,
    ea.CREATED_AT,
    ea.UPDATED_AT

FROM CUSTOMER.ENERGY_ACCOUNT ea
WHERE (SELECT COUNT(*) FROM SERVICE.PREMISE) = 0;

-- ===========================================================================
-- SCHEMA: SERVICE — METER
-- One meter per premise
-- ===========================================================================
INSERT INTO METER (
    METER_ID, PREMISE_ID, METER_NUMBER, METER_TYPE,
    MANUFACTURER, MODEL, INSTALL_DATE, REMOVAL_DATE, IS_ACTIVE,
    CREATED_AT, UPDATED_AT
)
SELECT
    'MTR-' || LPAD(ROW_NUMBER() OVER (ORDER BY p.PREMISE_ID), 6, '0'),
    p.PREMISE_ID,
    'M-' || LPAD(ROW_NUMBER() OVER (ORDER BY p.PREMISE_ID), 8, '0'),
    CASE MOD(ABS(HASH(p.PREMISE_ID || 'MT')), 10)
        WHEN 0 THEN 'ANALOG'
        WHEN 1 THEN 'ANALOG'
        WHEN 2 THEN 'DIGITAL'
        WHEN 3 THEN 'DIGITAL'
        ELSE 'AMI'
    END AS METER_TYPE,
    CASE MOD(ABS(HASH(p.PREMISE_ID || 'MFG')), 4)
        WHEN 0 THEN 'SynthMetrics Inc'
        WHEN 1 THEN 'Demopower Corp'
        WHEN 2 THEN 'TestMeter LLC'
        ELSE 'Fakewatt Industries'
    END AS MANUFACTURER,
    'Model-' || CAST(100 + MOD(ABS(HASH(p.PREMISE_ID || 'MDL')), 900) AS VARCHAR) AS MODEL,
    p.EFFECTIVE_DATE AS INSTALL_DATE,
    CASE WHEN p.END_DATE IS NOT NULL
         THEN DATEADD(DAY, MOD(ABS(HASH(p.PREMISE_ID || 'REM')), 30), p.END_DATE)
         ELSE NULL END AS REMOVAL_DATE,
    p.END_DATE IS NULL AS IS_ACTIVE,
    p.CREATED_AT, p.UPDATED_AT
FROM SERVICE.PREMISE p
WHERE (SELECT COUNT(*) FROM SERVICE.METER) = 0;

-- ===========================================================================
-- SCHEMA: BILLING — MONTHLY_USAGE
-- 3 months of historical usage per active energy account
-- Billing months: 3 months ago, 2 months ago, 1 month ago
-- ===========================================================================
USE SCHEMA BILLING;

INSERT INTO MONTHLY_USAGE (
    USAGE_ID, ENERGY_ACCOUNT_ID, PREMISE_ID, METER_ID,
    BILLING_MONTH, BILL_START_DATE, BILL_END_DATE, BILLING_DAYS,
    KWH_USAGE, KWH_ADJUSTED, PEAK_DEMAND_KW,
    PREV_METER_READING, CURR_METER_READING,
    READ_TYPE, RATE_PLAN,
    FIXED_CHARGE, ENERGY_CHARGE, DEMAND_CHARGE,
    SUBTOTAL_CHARGE, TAX_AMOUNT, TOTAL_BILLED,
    IS_CORRECTION, CORRECTION_REASON,
    CREATED_AT, UPDATED_AT
)
WITH months AS (
    SELECT -3 AS MONTH_OFFSET UNION ALL SELECT -2 UNION ALL SELECT -1
),
active_accounts AS (
    SELECT
        ea.ENERGY_ACCOUNT_ID,
        ea.RATE_CLASS,
        p.PREMISE_ID,
        m.METER_ID
    FROM CUSTOMER.ENERGY_ACCOUNT  ea
    JOIN SERVICE.PREMISE           p  ON p.ENERGY_ACCOUNT_ID = ea.ENERGY_ACCOUNT_ID
    JOIN SERVICE.METER             m  ON m.PREMISE_ID        = p.PREMISE_ID
    WHERE ea.ACCOUNT_STATUS = 'ACTIVE'
      AND p.END_DATE IS NULL
      AND m.IS_ACTIVE = TRUE
),
rate_data AS (
    -- Issue #5 fix: read from ATTRIBUTES VARIANT, not from CODE_LABEL
    SELECT
        CODE AS RATE_PLAN_CODE,
        TRY_TO_DECIMAL(ATTRIBUTES['fixed']::STRING,  10, 2) AS FIXED_RATE,
        TRY_TO_DECIMAL(ATTRIBUTES['energy']::STRING, 10, 6) AS ENERGY_RATE,
        TRY_TO_DECIMAL(ATTRIBUTES['demand']::STRING, 10, 6) AS DEMAND_RATE,
        TRY_TO_DECIMAL(ATTRIBUTES['tax']::STRING,    10, 6) AS TAX_RATE
    FROM REF.CODE_VALUE
    WHERE DOMAIN = 'RATE_PLAN' AND IS_ACTIVE = TRUE
),
account_rate AS (
    SELECT
        aa.*,
        CASE aa.RATE_CLASS
            WHEN 'LARGE_INDUSTRIAL'  THEN
                CASE WHEN MOD(ABS(HASH(aa.ENERGY_ACCOUNT_ID)), 2) = 0 THEN 'IND-1' ELSE 'IND-2' END
            WHEN 'MEDIUM_COMMERCIAL' THEN
                CASE WHEN MOD(ABS(HASH(aa.ENERGY_ACCOUNT_ID)), 2) = 0 THEN 'COM-1' ELSE 'COM-2' END
            WHEN 'SMALL_COMMERCIAL'  THEN 'COM-3'
            WHEN 'SOLAR_NET'         THEN 'SOL-1'
            WHEN 'RESIDENTIAL'       THEN
                CASE MOD(ABS(HASH(aa.ENERGY_ACCOUNT_ID)), 3)
                    WHEN 0 THEN 'RES-1' WHEN 1 THEN 'RES-2' ELSE 'RES-3' END
            ELSE 'RES-1'
        END AS RATE_PLAN
    FROM active_accounts aa
)
SELECT
    -- USAGE_ID anchored to $DEMO_AS_OF_DATE for stable billing month string
    'USG-' || ar.ENERGY_ACCOUNT_ID || '-' || TO_CHAR(DATEADD(MONTH, mo.MONTH_OFFSET, $DEMO_AS_OF_DATE::DATE), 'YYYY-MM'),
    ar.ENERGY_ACCOUNT_ID,
    ar.PREMISE_ID,
    ar.METER_ID,

    -- Billing month YYYY-MM — anchored to $DEMO_AS_OF_DATE (already 1st of month)
    TO_CHAR(DATEADD(MONTH, mo.MONTH_OFFSET, $DEMO_AS_OF_DATE::DATE), 'YYYY-MM') AS BILLING_MONTH,

    -- Bill dates (month start / end) — anchored to $DEMO_AS_OF_DATE
    DATEADD(MONTH, mo.MONTH_OFFSET, $DEMO_AS_OF_DATE::DATE)           AS BILL_START_DATE,
    DATEADD(DAY, -1, DATEADD(MONTH, mo.MONTH_OFFSET + 1, $DEMO_AS_OF_DATE::DATE)) AS BILL_END_DATE,
    DATEDIFF(DAY,
        DATEADD(MONTH, mo.MONTH_OFFSET, $DEMO_AS_OF_DATE::DATE),
        DATEADD(DAY, -1, DATEADD(MONTH, mo.MONTH_OFFSET + 1, $DEMO_AS_OF_DATE::DATE))
    ) + 1 AS BILLING_DAYS,

    -- KWH usage: scaled by customer type
    ROUND(
        CASE ar.RATE_CLASS
            WHEN 'LARGE_INDUSTRIAL'  THEN 50000 + MOD(ABS(HASH(ar.ENERGY_ACCOUNT_ID || mo.MONTH_OFFSET::VARCHAR)), 100000)
            WHEN 'MEDIUM_COMMERCIAL' THEN 5000  + MOD(ABS(HASH(ar.ENERGY_ACCOUNT_ID || mo.MONTH_OFFSET::VARCHAR)), 10000)
            WHEN 'SMALL_COMMERCIAL'  THEN 1000  + MOD(ABS(HASH(ar.ENERGY_ACCOUNT_ID || mo.MONTH_OFFSET::VARCHAR)), 3000)
            WHEN 'SOLAR_NET'         THEN 200   + MOD(ABS(HASH(ar.ENERGY_ACCOUNT_ID || mo.MONTH_OFFSET::VARCHAR)), 400)
            ELSE                          200   + MOD(ABS(HASH(ar.ENERGY_ACCOUNT_ID || mo.MONTH_OFFSET::VARCHAR)), 1800)
        END
    ::NUMBER(12,3), 3) AS KWH_USAGE,

    -- KWH adjusted = same as usage for simplicity (±1% variance for some)
    ROUND(
        (CASE ar.RATE_CLASS
            WHEN 'LARGE_INDUSTRIAL'  THEN 50000 + MOD(ABS(HASH(ar.ENERGY_ACCOUNT_ID || mo.MONTH_OFFSET::VARCHAR)), 100000)
            WHEN 'MEDIUM_COMMERCIAL' THEN 5000  + MOD(ABS(HASH(ar.ENERGY_ACCOUNT_ID || mo.MONTH_OFFSET::VARCHAR)), 10000)
            WHEN 'SMALL_COMMERCIAL'  THEN 1000  + MOD(ABS(HASH(ar.ENERGY_ACCOUNT_ID || mo.MONTH_OFFSET::VARCHAR)), 3000)
            WHEN 'SOLAR_NET'         THEN 200   + MOD(ABS(HASH(ar.ENERGY_ACCOUNT_ID || mo.MONTH_OFFSET::VARCHAR)), 400)
            ELSE                          200   + MOD(ABS(HASH(ar.ENERGY_ACCOUNT_ID || mo.MONTH_OFFSET::VARCHAR)), 1800)
        END) * (1.0 + MOD(ABS(HASH(ar.ENERGY_ACCOUNT_ID || 'ADJ')), 20) / 1000.0)
    ::NUMBER(12,3), 3) AS KWH_ADJUSTED,

    -- Peak demand KW (null for residential/solar, calculated for commercial/industrial)
    CASE
        WHEN ar.RATE_CLASS IN ('LARGE_INDUSTRIAL','MEDIUM_COMMERCIAL')
        THEN ROUND(
            CASE ar.RATE_CLASS
                WHEN 'LARGE_INDUSTRIAL'  THEN 100 + MOD(ABS(HASH(ar.ENERGY_ACCOUNT_ID || 'KW')), 400)
                ELSE                           10  + MOD(ABS(HASH(ar.ENERGY_ACCOUNT_ID || 'KW')), 90)
            END::NUMBER(10,3), 3)
        ELSE NULL
    END AS PEAK_DEMAND_KW,

    -- Previous meter reading
    ROUND(
        MOD(ABS(HASH(ar.ENERGY_ACCOUNT_ID || 'PREV' || mo.MONTH_OFFSET::VARCHAR)), 99000)
    ::NUMBER(12,3), 3) AS PREV_METER_READING,

    -- Current meter reading = prev + kwh_usage
    ROUND(
        MOD(ABS(HASH(ar.ENERGY_ACCOUNT_ID || 'PREV' || mo.MONTH_OFFSET::VARCHAR)), 99000)
        + CASE ar.RATE_CLASS
            WHEN 'LARGE_INDUSTRIAL'  THEN 50000 + MOD(ABS(HASH(ar.ENERGY_ACCOUNT_ID || mo.MONTH_OFFSET::VARCHAR)), 100000)
            WHEN 'MEDIUM_COMMERCIAL' THEN 5000  + MOD(ABS(HASH(ar.ENERGY_ACCOUNT_ID || mo.MONTH_OFFSET::VARCHAR)), 10000)
            WHEN 'SMALL_COMMERCIAL'  THEN 1000  + MOD(ABS(HASH(ar.ENERGY_ACCOUNT_ID || mo.MONTH_OFFSET::VARCHAR)), 3000)
            WHEN 'SOLAR_NET'         THEN 200   + MOD(ABS(HASH(ar.ENERGY_ACCOUNT_ID || mo.MONTH_OFFSET::VARCHAR)), 400)
            ELSE                          200   + MOD(ABS(HASH(ar.ENERGY_ACCOUNT_ID || mo.MONTH_OFFSET::VARCHAR)), 1800)
          END
    ::NUMBER(12,3), 3) AS CURR_METER_READING,

    -- Read type: 90% actual, 10% estimated
    CASE WHEN MOD(ABS(HASH(ar.ENERGY_ACCOUNT_ID || 'RT' || mo.MONTH_OFFSET::VARCHAR)), 10) < 9
         THEN 'ACTUAL' ELSE 'ESTIMATED' END AS READ_TYPE,

    ar.RATE_PLAN,

    -- Charges pre-calculated using the same formula as the export view
    -- (so source values match view output for reconciliation validation)
    rd.FIXED_RATE AS FIXED_CHARGE,

    ROUND(
        CASE ar.RATE_CLASS
            WHEN 'LARGE_INDUSTRIAL'  THEN 50000 + MOD(ABS(HASH(ar.ENERGY_ACCOUNT_ID || mo.MONTH_OFFSET::VARCHAR)), 100000)
            WHEN 'MEDIUM_COMMERCIAL' THEN 5000  + MOD(ABS(HASH(ar.ENERGY_ACCOUNT_ID || mo.MONTH_OFFSET::VARCHAR)), 10000)
            WHEN 'SMALL_COMMERCIAL'  THEN 1000  + MOD(ABS(HASH(ar.ENERGY_ACCOUNT_ID || mo.MONTH_OFFSET::VARCHAR)), 3000)
            WHEN 'SOLAR_NET'         THEN 200   + MOD(ABS(HASH(ar.ENERGY_ACCOUNT_ID || mo.MONTH_OFFSET::VARCHAR)), 400)
            ELSE                          200   + MOD(ABS(HASH(ar.ENERGY_ACCOUNT_ID || mo.MONTH_OFFSET::VARCHAR)), 1800)
        END * rd.ENERGY_RATE
    , 2) AS ENERGY_CHARGE,

    -- Demand charge: 0 when demand rate NULL (ICA MU-AC-09)
    CASE
        WHEN ar.RATE_CLASS IN ('LARGE_INDUSTRIAL','MEDIUM_COMMERCIAL') AND rd.DEMAND_RATE IS NOT NULL
        THEN ROUND(
            CASE ar.RATE_CLASS
                WHEN 'LARGE_INDUSTRIAL'  THEN 100 + MOD(ABS(HASH(ar.ENERGY_ACCOUNT_ID || 'KW')), 400)
                ELSE                           10  + MOD(ABS(HASH(ar.ENERGY_ACCOUNT_ID || 'KW')), 90)
            END * rd.DEMAND_RATE
        , 2)
        ELSE 0.00
    END AS DEMAND_CHARGE,

    -- Subtotal
    ROUND(
        rd.FIXED_RATE
        + ROUND(
            CASE ar.RATE_CLASS
                WHEN 'LARGE_INDUSTRIAL'  THEN 50000 + MOD(ABS(HASH(ar.ENERGY_ACCOUNT_ID || mo.MONTH_OFFSET::VARCHAR)), 100000)
                WHEN 'MEDIUM_COMMERCIAL' THEN 5000  + MOD(ABS(HASH(ar.ENERGY_ACCOUNT_ID || mo.MONTH_OFFSET::VARCHAR)), 10000)
                WHEN 'SMALL_COMMERCIAL'  THEN 1000  + MOD(ABS(HASH(ar.ENERGY_ACCOUNT_ID || mo.MONTH_OFFSET::VARCHAR)), 3000)
                WHEN 'SOLAR_NET'         THEN 200   + MOD(ABS(HASH(ar.ENERGY_ACCOUNT_ID || mo.MONTH_OFFSET::VARCHAR)), 400)
                ELSE                          200   + MOD(ABS(HASH(ar.ENERGY_ACCOUNT_ID || mo.MONTH_OFFSET::VARCHAR)), 1800)
            END * rd.ENERGY_RATE
          , 2)
        + CASE
            WHEN ar.RATE_CLASS IN ('LARGE_INDUSTRIAL','MEDIUM_COMMERCIAL') AND rd.DEMAND_RATE IS NOT NULL
            THEN ROUND(
                CASE ar.RATE_CLASS
                    WHEN 'LARGE_INDUSTRIAL' THEN 100 + MOD(ABS(HASH(ar.ENERGY_ACCOUNT_ID || 'KW')), 400)
                    ELSE 10 + MOD(ABS(HASH(ar.ENERGY_ACCOUNT_ID || 'KW')), 90)
                END * rd.DEMAND_RATE
              , 2)
            ELSE 0.00
          END
    , 2) AS SUBTOTAL_CHARGE,

    -- Tax
    ROUND(
        ROUND(
            rd.FIXED_RATE
            + ROUND(
                CASE ar.RATE_CLASS
                    WHEN 'LARGE_INDUSTRIAL'  THEN 50000 + MOD(ABS(HASH(ar.ENERGY_ACCOUNT_ID || mo.MONTH_OFFSET::VARCHAR)), 100000)
                    WHEN 'MEDIUM_COMMERCIAL' THEN 5000  + MOD(ABS(HASH(ar.ENERGY_ACCOUNT_ID || mo.MONTH_OFFSET::VARCHAR)), 10000)
                    WHEN 'SMALL_COMMERCIAL'  THEN 1000  + MOD(ABS(HASH(ar.ENERGY_ACCOUNT_ID || mo.MONTH_OFFSET::VARCHAR)), 3000)
                    WHEN 'SOLAR_NET'         THEN 200   + MOD(ABS(HASH(ar.ENERGY_ACCOUNT_ID || mo.MONTH_OFFSET::VARCHAR)), 400)
                    ELSE                          200   + MOD(ABS(HASH(ar.ENERGY_ACCOUNT_ID || mo.MONTH_OFFSET::VARCHAR)), 1800)
                END * rd.ENERGY_RATE
              , 2)
            + CASE
                WHEN ar.RATE_CLASS IN ('LARGE_INDUSTRIAL','MEDIUM_COMMERCIAL') AND rd.DEMAND_RATE IS NOT NULL
                THEN ROUND(
                    CASE ar.RATE_CLASS
                        WHEN 'LARGE_INDUSTRIAL' THEN 100 + MOD(ABS(HASH(ar.ENERGY_ACCOUNT_ID || 'KW')), 400)
                        ELSE 10 + MOD(ABS(HASH(ar.ENERGY_ACCOUNT_ID || 'KW')), 90)
                    END * rd.DEMAND_RATE
                  , 2)
                ELSE 0.00
              END
        , 2) * rd.TAX_RATE
    , 2) AS TAX_AMOUNT,

    -- Total billed = subtotal + tax (additive)
    ROUND(
        ROUND(
            rd.FIXED_RATE
            + ROUND(
                CASE ar.RATE_CLASS
                    WHEN 'LARGE_INDUSTRIAL'  THEN 50000 + MOD(ABS(HASH(ar.ENERGY_ACCOUNT_ID || mo.MONTH_OFFSET::VARCHAR)), 100000)
                    WHEN 'MEDIUM_COMMERCIAL' THEN 5000  + MOD(ABS(HASH(ar.ENERGY_ACCOUNT_ID || mo.MONTH_OFFSET::VARCHAR)), 10000)
                    WHEN 'SMALL_COMMERCIAL'  THEN 1000  + MOD(ABS(HASH(ar.ENERGY_ACCOUNT_ID || mo.MONTH_OFFSET::VARCHAR)), 3000)
                    WHEN 'SOLAR_NET'         THEN 200   + MOD(ABS(HASH(ar.ENERGY_ACCOUNT_ID || mo.MONTH_OFFSET::VARCHAR)), 400)
                    ELSE                          200   + MOD(ABS(HASH(ar.ENERGY_ACCOUNT_ID || mo.MONTH_OFFSET::VARCHAR)), 1800)
                END * rd.ENERGY_RATE
              , 2)
            + CASE
                WHEN ar.RATE_CLASS IN ('LARGE_INDUSTRIAL','MEDIUM_COMMERCIAL') AND rd.DEMAND_RATE IS NOT NULL
                THEN ROUND(
                    CASE ar.RATE_CLASS
                        WHEN 'LARGE_INDUSTRIAL' THEN 100 + MOD(ABS(HASH(ar.ENERGY_ACCOUNT_ID || 'KW')), 400)
                        ELSE 10 + MOD(ABS(HASH(ar.ENERGY_ACCOUNT_ID || 'KW')), 90)
                    END * rd.DEMAND_RATE
                  , 2)
                ELSE 0.00
              END
        , 2)
        + ROUND(
            ROUND(
                rd.FIXED_RATE
                + ROUND(
                    CASE ar.RATE_CLASS
                        WHEN 'LARGE_INDUSTRIAL'  THEN 50000 + MOD(ABS(HASH(ar.ENERGY_ACCOUNT_ID || mo.MONTH_OFFSET::VARCHAR)), 100000)
                        WHEN 'MEDIUM_COMMERCIAL' THEN 5000  + MOD(ABS(HASH(ar.ENERGY_ACCOUNT_ID || mo.MONTH_OFFSET::VARCHAR)), 10000)
                        WHEN 'SMALL_COMMERCIAL'  THEN 1000  + MOD(ABS(HASH(ar.ENERGY_ACCOUNT_ID || mo.MONTH_OFFSET::VARCHAR)), 3000)
                        WHEN 'SOLAR_NET'         THEN 200   + MOD(ABS(HASH(ar.ENERGY_ACCOUNT_ID || mo.MONTH_OFFSET::VARCHAR)), 400)
                        ELSE                          200   + MOD(ABS(HASH(ar.ENERGY_ACCOUNT_ID || mo.MONTH_OFFSET::VARCHAR)), 1800)
                    END * rd.ENERGY_RATE
                  , 2)
                + CASE
                    WHEN ar.RATE_CLASS IN ('LARGE_INDUSTRIAL','MEDIUM_COMMERCIAL') AND rd.DEMAND_RATE IS NOT NULL
                    THEN ROUND(
                        CASE ar.RATE_CLASS
                            WHEN 'LARGE_INDUSTRIAL' THEN 100 + MOD(ABS(HASH(ar.ENERGY_ACCOUNT_ID || 'KW')), 400)
                            ELSE 10 + MOD(ABS(HASH(ar.ENERGY_ACCOUNT_ID || 'KW')), 90)
                        END * rd.DEMAND_RATE
                      , 2)
                    ELSE 0.00
                  END
            , 2) * rd.TAX_RATE
          , 2)
    , 2) AS TOTAL_BILLED,

    FALSE AS IS_CORRECTION,
    NULL  AS CORRECTION_REASON,
    -- CREATED_AT/UPDATED_AT: technical timestamps spread back in time from now.
    -- MONTH_OFFSET is -3, -2, -1 so these land 3/2/1 months in the past.
    DATEADD(MONTH, mo.MONTH_OFFSET, CURRENT_TIMESTAMP()) AS CREATED_AT,
    DATEADD(MONTH, mo.MONTH_OFFSET, CURRENT_TIMESTAMP()) AS UPDATED_AT

FROM account_rate ar
CROSS JOIN months mo
JOIN rate_data rd ON rd.RATE_PLAN_CODE = ar.RATE_PLAN
WHERE (SELECT COUNT(*) FROM BILLING.MONTHLY_USAGE) = 0;

-- ===========================================================================
-- Final row count verification
-- ===========================================================================
SELECT 'CUSTOMER'          AS TABLE_NAME, COUNT(*) AS ROW_COUNT FROM CUSTOMER.CUSTOMER
UNION ALL SELECT 'CUSTOMER_CONTACT',  COUNT(*) FROM CUSTOMER.CUSTOMER_CONTACT
UNION ALL SELECT 'ENERGY_ACCOUNT',    COUNT(*) FROM CUSTOMER.ENERGY_ACCOUNT
UNION ALL SELECT 'BILLING_ACCOUNT',   COUNT(*) FROM CUSTOMER.BILLING_ACCOUNT
UNION ALL SELECT 'PREMISE',           COUNT(*) FROM SERVICE.PREMISE
UNION ALL SELECT 'METER',             COUNT(*) FROM SERVICE.METER
UNION ALL SELECT 'MONTHLY_USAGE',     COUNT(*) FROM BILLING.MONTHLY_USAGE
ORDER BY TABLE_NAME;
