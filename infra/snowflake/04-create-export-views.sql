-- =============================================================================
-- Snowflake Provisioning — Step 4: Export Views (STAGING schema)
-- =============================================================================
-- Run as: CDP_ADMIN_ROLE  (use ACCOUNTADMIN or SYSADMIN to switch to it)
-- Database: CDP_UTIL_DB
-- Schema:   STAGING
-- Warehouse: CDP_LOADER_WH
--
-- PREREQUISITE
--   Script 03-create-source-tables.sql must have been run successfully
--   before this script, as the views reference tables in CUSTOMER, SERVICE,
--   BILLING and REF schemas.
--
-- PURPOSE
--   Create the two ETL export views designed in docs/ica-context/17-snowflake-view-designs.md.
--   These views implement Layer 1 (Snowflake) transformations:
--     - Multi-table joins
--     - Row deduplication (QUALIFY / ROW_NUMBER)
--     - Charge calculations (fixed, energy, demand, tax, total)
--     - Combined name / address fields
--     - GREATEST(…) composite watermark timestamp
--
-- The ETL service user (SVC_CDP_LOADER) has SELECT on STAGING via CDP_LOADER_ROLE.
-- =============================================================================

USE ROLE CDP_ADMIN_ROLE;
USE DATABASE CDP_UTIL_DB;
USE SCHEMA STAGING;
USE WAREHOUSE CDP_LOADER_WH;

-- ===========================================================================
-- VIEW 1: VW_DAILY_CUSTOMER_ACCOUNT_EXPORT
--   Logical dataset for daily incremental customer/account load.
--   Joins: CUSTOMER + CUSTOMER_CONTACT (primary email, primary phone) +
--          ENERGY_ACCOUNT + BILLING_ACCOUNT (current) + PREMISE (current) +
--          METER (active) + REF.CODE_VALUE (ACCT_STATUS, CUST_TYPE)
-- ===========================================================================
CREATE OR REPLACE VIEW STAGING.VW_DAILY_CUSTOMER_ACCOUNT_EXPORT AS
WITH

-- -----------------------------------------------------------------------
-- Primary email per customer
-- -----------------------------------------------------------------------
primary_email AS (
    SELECT
        CUSTOMER_ID,
        CONTACT_VALUE                                          AS EMAIL_ADDRESS,
        IS_VERIFIED                                            AS EMAIL_VERIFIED,
        UPDATED_AT                                             AS EMAIL_UPDATED_AT
    FROM CUSTOMER.CUSTOMER_CONTACT
    WHERE CONTACT_TYPE = 'EMAIL'
      AND IS_PRIMARY    = TRUE
      AND (END_DATE IS NULL OR END_DATE >= CURRENT_DATE())
    QUALIFY ROW_NUMBER() OVER (PARTITION BY CUSTOMER_ID ORDER BY EFFECTIVE_DATE DESC) = 1
),

-- -----------------------------------------------------------------------
-- Primary phone per customer
-- -----------------------------------------------------------------------
primary_phone AS (
    SELECT
        CUSTOMER_ID,
        CONTACT_VALUE                                          AS PHONE_NUMBER,
        UPDATED_AT                                             AS PHONE_UPDATED_AT
    FROM CUSTOMER.CUSTOMER_CONTACT
    WHERE CONTACT_TYPE = 'PHONE'
      AND IS_PRIMARY    = TRUE
      AND (END_DATE IS NULL OR END_DATE >= CURRENT_DATE())
    QUALIFY ROW_NUMBER() OVER (PARTITION BY CUSTOMER_ID ORDER BY EFFECTIVE_DATE DESC) = 1
),

-- -----------------------------------------------------------------------
-- Current billing account per energy account
-- -----------------------------------------------------------------------
current_billing AS (
    SELECT
        ENERGY_ACCOUNT_ID,
        BILLING_ACCOUNT_ID,
        BILLING_ACCOUNT_NBR,
        BILLING_CYCLE,
        PAYMENT_METHOD,
        AUTO_PAY_ENROLLED,
        PAPERLESS_ENROLLED,
        UPDATED_AT                                             AS BA_UPDATED_AT
    FROM CUSTOMER.BILLING_ACCOUNT
    WHERE END_DATE IS NULL OR END_DATE >= CURRENT_DATE()
    QUALIFY ROW_NUMBER() OVER (PARTITION BY ENERGY_ACCOUNT_ID ORDER BY EFFECTIVE_DATE DESC) = 1
),

-- -----------------------------------------------------------------------
-- Current premise per energy account
-- -----------------------------------------------------------------------
current_premise AS (
    SELECT
        ENERGY_ACCOUNT_ID,
        PREMISE_ID,
        ADDRESS_LINE1,
        ADDRESS_LINE2,
        CITY,
        STATE_CODE,
        ZIP_CODE,
        COUNTY,
        GEO_LATITUDE,
        GEO_LONGITUDE,
        PREMISE_TYPE,
        UPDATED_AT                                             AS PREM_UPDATED_AT
    FROM SERVICE.PREMISE
    WHERE END_DATE IS NULL OR END_DATE >= CURRENT_DATE()
    QUALIFY ROW_NUMBER() OVER (PARTITION BY ENERGY_ACCOUNT_ID ORDER BY EFFECTIVE_DATE DESC) = 1
),

-- -----------------------------------------------------------------------
-- Active meter per premise
-- -----------------------------------------------------------------------
active_meter AS (
    SELECT
        PREMISE_ID,
        METER_ID,
        METER_NUMBER,
        METER_TYPE,
        INSTALL_DATE,
        UPDATED_AT                                             AS MTR_UPDATED_AT
    FROM SERVICE.METER
    WHERE IS_ACTIVE = TRUE
      AND (REMOVAL_DATE IS NULL OR REMOVAL_DATE >= CURRENT_DATE())
    QUALIFY ROW_NUMBER() OVER (PARTITION BY PREMISE_ID ORDER BY INSTALL_DATE DESC) = 1
),

-- -----------------------------------------------------------------------
-- Account status label lookup
-- -----------------------------------------------------------------------
acct_status_ref AS (
    SELECT CODE, CODE_LABEL AS ACCT_STATUS_LABEL
    FROM REF.CODE_VALUE
    WHERE DOMAIN = 'ACCT_STATUS'
),

-- -----------------------------------------------------------------------
-- Customer type label lookup
-- -----------------------------------------------------------------------
cust_type_ref AS (
    SELECT CODE, CODE_LABEL AS CUST_TYPE_LABEL
    FROM REF.CODE_VALUE
    WHERE DOMAIN = 'CUST_TYPE'
)

-- -----------------------------------------------------------------------
-- Main select — one row per ENERGY_ACCOUNT
-- -----------------------------------------------------------------------
SELECT
    -- ---- Energy account (root of the export row) ----
    ea.ENERGY_ACCOUNT_ID,
    ea.ACCOUNT_NUMBER,
    ea.ACCOUNT_STATUS,
    ea.SERVICE_TYPE,
    ea.RATE_CLASS,
    ea.OPEN_DATE,
    ea.CLOSE_DATE,

    -- ---- Customer master ----
    c.CUSTOMER_ID,
    c.FIRST_NAME,
    c.LAST_NAME,
    c.MIDDLE_NAME,
    c.NAME_SUFFIX,
    TRIM(UPPER(c.FIRST_NAME) || ' ' ||
         COALESCE(UPPER(c.MIDDLE_NAME) || ' ', '') ||
         UPPER(c.LAST_NAME))                                   AS FULL_NAME_NORMALIZED,
    c.CUSTOMER_TYPE,
    c.PREFERRED_LANGUAGE,
    c.ACCOUNT_STATUS                                           AS CUSTOMER_STATUS,

    -- ---- Contact ----
    pe.EMAIL_ADDRESS,
    pe.EMAIL_VERIFIED,
    pp.PHONE_NUMBER,

    -- ---- Billing account ----
    cb.BILLING_ACCOUNT_ID,
    cb.BILLING_ACCOUNT_NBR,
    cb.BILLING_CYCLE,
    cb.PAYMENT_METHOD,
    cb.AUTO_PAY_ENROLLED,
    cb.PAPERLESS_ENROLLED,

    -- ---- Premise ----
    cp.PREMISE_ID,
    cp.ADDRESS_LINE1,
    cp.ADDRESS_LINE2,
    cp.CITY,
    cp.STATE_CODE,
    cp.ZIP_CODE,
    cp.COUNTY,
    cp.GEO_LATITUDE,
    cp.GEO_LONGITUDE,
    cp.PREMISE_TYPE,
    TRIM(cp.ADDRESS_LINE1 ||
         COALESCE(', ' || cp.ADDRESS_LINE2, '') || ', ' ||
         cp.CITY || ', ' || cp.STATE_CODE || ' ' || cp.ZIP_CODE)
                                                               AS FULL_ADDRESS,

    -- ---- Meter ----
    am.METER_ID,
    am.METER_NUMBER,
    am.METER_TYPE,
    am.INSTALL_DATE,

    -- ---- Reference labels ----
    asr.ACCT_STATUS_LABEL,
    ctr.CUST_TYPE_LABEL,

    -- ---- Composite watermark: max UPDATED_AT across ALL contributing tables ----
    -- Includes CUSTOMER_CONTACT (email + phone) so contact-only changes are detected.
    GREATEST(
        COALESCE(c.UPDATED_AT,          '1970-01-01'::TIMESTAMP_TZ),
        COALESCE(ea.UPDATED_AT,         '1970-01-01'::TIMESTAMP_TZ),
        COALESCE(cb.BA_UPDATED_AT,      '1970-01-01'::TIMESTAMP_TZ),
        COALESCE(cp.PREM_UPDATED_AT,    '1970-01-01'::TIMESTAMP_TZ),
        COALESCE(am.MTR_UPDATED_AT,     '1970-01-01'::TIMESTAMP_TZ),
        COALESCE(pe.EMAIL_UPDATED_AT,   '1970-01-01'::TIMESTAMP_TZ),
        COALESCE(pp.PHONE_UPDATED_AT,   '1970-01-01'::TIMESTAMP_TZ)
    )                                                          AS RECORD_EFFECTIVE_TS

FROM CUSTOMER.ENERGY_ACCOUNT         ea
JOIN CUSTOMER.CUSTOMER                c   ON c.CUSTOMER_ID       = ea.CUSTOMER_ID
LEFT JOIN primary_email               pe  ON pe.CUSTOMER_ID      = c.CUSTOMER_ID
LEFT JOIN primary_phone               pp  ON pp.CUSTOMER_ID      = c.CUSTOMER_ID
LEFT JOIN current_billing             cb  ON cb.ENERGY_ACCOUNT_ID = ea.ENERGY_ACCOUNT_ID
LEFT JOIN current_premise             cp  ON cp.ENERGY_ACCOUNT_ID = ea.ENERGY_ACCOUNT_ID
LEFT JOIN active_meter                am  ON am.PREMISE_ID       = cp.PREMISE_ID
LEFT JOIN acct_status_ref             asr ON asr.CODE            = ea.ACCOUNT_STATUS
LEFT JOIN cust_type_ref               ctr ON ctr.CODE            = c.CUSTOMER_TYPE
;

-- ===========================================================================
-- VIEW 2: VW_MONTHLY_USAGE_BILLING_EXPORT
--   Logical dataset for monthly usage load with charge calculations.
--
-- RATE PARAMETER SOURCE (Issue #1/4 fix)
--   Rate parameters are read from REF.CODE_VALUE.ATTRIBUTES (VARIANT column),
--   NOT from CODE_LABEL.  CODE_LABEL is a human-readable text label only.
--   ATTRIBUTES contains a native Snowflake VARIANT object:
--     {"fixed":8.50,"energy":0.1150,"demand":null,"tax":0.080,"synthetic":true}
--
-- VARIANT PATH ACCESS PATTERN
--   ATTRIBUTES['fixed']::STRING  — extracts field as STRING (NULL if key absent
--                                   or value is JSON null).
--   TRY_TO_DECIMAL(…::STRING, p, s) — converts STRING to NUMBER safely;
--   returns NULL for NULL, empty string, or non-numeric text — never errors.
--   This is the correct pattern; TRY_CAST(VARIANT, NUMBER) is not supported.
--
-- NULL PROPAGATION IN CHARGE CALCULATIONS
--   Per ICA rules TR-BILL-02 to TR-BILL-07:
--   - FIXED_RATE NULL  → CALC_FIXED_CHARGE NULL  (distinguishable from a zero-fixed plan)
--   - ENERGY_RATE NULL → CALC_ENERGY_CHARGE NULL
--   - TAX_RATE NULL    → CALC_TAX_AMOUNT NULL
--   - DEMAND_RATE NULL → CALC_DEMAND_CHARGE = 0  (ICA rule MU-AC-09 explicitly defines 0)
--   CALC_SUBTOTAL and CALC_TOTAL_BILLED propagate NULL if any contributing charge is NULL.
-- ===========================================================================
CREATE OR REPLACE VIEW STAGING.VW_MONTHLY_USAGE_BILLING_EXPORT AS
WITH

-- -----------------------------------------------------------------------
-- Rate plan parameters — ATTRIBUTES VARIANT → typed NUMBER columns
--
-- Source: REF.CODE_VALUE.ATTRIBUTES (VARIANT, populated by 05-seed-reference-data.sql)
-- Access pattern: ATTRIBUTES['key']::STRING  then TRY_TO_DECIMAL for type safety.
--   A missing key or JSON null value both return NULL via ::STRING.
--   TRY_TO_DECIMAL returns NULL for NULL or non-numeric input — never raises an error.
--
-- Using ATTRIBUTES['key'] (bracket notation, valid Snowflake VARIANT path syntax)
-- is preferred over TRY_PARSE_JSON on a VARCHAR column, which would be fragile
-- and type-unsafe.
-- -----------------------------------------------------------------------
rate_params AS (
    SELECT
        CODE                                                          AS RATE_PLAN_CODE,
        CODE_LABEL                                                    AS RATE_PLAN_LABEL,
        ATTRIBUTES                                                    AS RATE_ATTRS,

        -- fixed charge per billing period ($)
        -- ICA TR-BILL-02: missing or invalid → NULL (not defaulted to 0)
        TRY_TO_DECIMAL(
            ATTRIBUTES['fixed']::STRING,
            10, 2
        )                                                             AS FIXED_RATE,

        -- energy rate per kWh ($/kWh, 6 decimal places for precision)
        -- ICA TR-BILL-03: missing or invalid → NULL
        TRY_TO_DECIMAL(
            ATTRIBUTES['energy']::STRING,
            10, 6
        )                                                             AS ENERGY_RATE_PER_KWH,

        -- demand rate per kW ($/kW, 6 decimal places)
        -- ICA MU-AC-09: NULL demand rate is valid — means no demand charge for this plan
        TRY_TO_DECIMAL(
            ATTRIBUTES['demand']::STRING,
            10, 6
        )                                                             AS DEMAND_RATE_PER_KW,

        -- tax rate (fraction, e.g. 0.080 = 8%)
        -- ICA TR-BILL-06: missing or invalid → NULL
        TRY_TO_DECIMAL(
            ATTRIBUTES['tax']::STRING,
            10, 6
        )                                                             AS TAX_RATE

    FROM REF.CODE_VALUE
    WHERE DOMAIN    = 'RATE_PLAN'
      AND IS_ACTIVE = TRUE
)

SELECT
    -- ---- Usage identifiers ----
    u.USAGE_ID,
    u.ENERGY_ACCOUNT_ID,
    u.PREMISE_ID,
    u.METER_ID,
    u.BILLING_MONTH,
    u.BILL_START_DATE,
    u.BILL_END_DATE,
    u.BILLING_DAYS,

    -- ---- Metered quantities ----
    u.KWH_USAGE,
    COALESCE(u.KWH_ADJUSTED, u.KWH_USAGE)                            AS KWH_EFFECTIVE,
    u.PEAK_DEMAND_KW,
    u.PREV_METER_READING,
    u.CURR_METER_READING,
    u.READ_TYPE,

    -- ---- Rate plan (raw rates exposed for validation) ----
    u.RATE_PLAN,
    rp.FIXED_RATE,
    rp.ENERGY_RATE_PER_KWH,
    rp.DEMAND_RATE_PER_KW,
    rp.TAX_RATE,

    -- ---- 7-step charge calculation (Layer 1 — Snowflake) ----
    -- NULL PROPAGATION RULES:
    --   Steps 1, 2, 5, 6: NULL rate → NULL calculated charge (not zero).
    --   Step 3 (demand): NULL rate → 0 per ICA MU-AC-09 (explicit ICA default).
    --   Steps 4, 6: propagate NULL if any addend is NULL.
    --
    -- This makes invalid/missing rates distinguishable from valid zero-rate plans
    -- during Spring Batch reconciliation and error handling.

    -- Step 1: Fixed charge — NULL if rate is missing or invalid
    rp.FIXED_RATE                                                     AS CALC_FIXED_CHARGE,

    -- Step 2: Energy charge = ROUND(KWH_USAGE × energy_rate, 2) — NULL if rate invalid
    ROUND(u.KWH_USAGE * rp.ENERGY_RATE_PER_KWH, 2)                   AS CALC_ENERGY_CHARGE,

    -- Step 3: Demand charge — 0 when no demand rate (ICA MU-AC-09 explicit rule)
    --   NULL demand_rate means the plan has no demand component, not a data error.
    CASE
        WHEN u.PEAK_DEMAND_KW IS NOT NULL AND rp.DEMAND_RATE_PER_KW IS NOT NULL
        THEN ROUND(u.PEAK_DEMAND_KW * rp.DEMAND_RATE_PER_KW, 2)
        ELSE 0
    END                                                               AS CALC_DEMAND_CHARGE,

    -- Step 4: Subtotal = fixed + energy + demand
    --   NULL in fixed or energy propagates NULL to subtotal (distinguishable from valid 0).
    rp.FIXED_RATE
    + ROUND(u.KWH_USAGE * rp.ENERGY_RATE_PER_KWH, 2)
    + CASE
        WHEN u.PEAK_DEMAND_KW IS NOT NULL AND rp.DEMAND_RATE_PER_KW IS NOT NULL
        THEN ROUND(u.PEAK_DEMAND_KW * rp.DEMAND_RATE_PER_KW, 2)
        ELSE 0
      END                                                             AS CALC_SUBTOTAL,

    -- Step 5: Tax = ROUND(subtotal × tax_rate, 2) — NULL if rate or subtotal is NULL
    ROUND(
        (
            rp.FIXED_RATE
            + ROUND(u.KWH_USAGE * rp.ENERGY_RATE_PER_KWH, 2)
            + CASE
                WHEN u.PEAK_DEMAND_KW IS NOT NULL AND rp.DEMAND_RATE_PER_KW IS NOT NULL
                THEN ROUND(u.PEAK_DEMAND_KW * rp.DEMAND_RATE_PER_KW, 2)
                ELSE 0
              END
        ) * rp.TAX_RATE,
        2
    )                                                                 AS CALC_TAX_AMOUNT,

    -- Step 6: Total = subtotal + tax  (additive, not multiplicative)
    --   NULL subtotal or NULL tax propagates NULL to total.
    (
        rp.FIXED_RATE
        + ROUND(u.KWH_USAGE * rp.ENERGY_RATE_PER_KWH, 2)
        + CASE
            WHEN u.PEAK_DEMAND_KW IS NOT NULL AND rp.DEMAND_RATE_PER_KW IS NOT NULL
            THEN ROUND(u.PEAK_DEMAND_KW * rp.DEMAND_RATE_PER_KW, 2)
            ELSE 0
          END
    )
    + ROUND(
        (
            rp.FIXED_RATE
            + ROUND(u.KWH_USAGE * rp.ENERGY_RATE_PER_KWH, 2)
            + CASE
                WHEN u.PEAK_DEMAND_KW IS NOT NULL AND rp.DEMAND_RATE_PER_KW IS NOT NULL
                THEN ROUND(u.PEAK_DEMAND_KW * rp.DEMAND_RATE_PER_KW, 2)
                ELSE 0
              END
        ) * rp.TAX_RATE,
        2
    )                                                                 AS CALC_TOTAL_BILLED,

    -- Step 7: Usage quality flag
    CASE
        WHEN u.READ_TYPE = 'ESTIMATED'   THEN 'ESTIMATED'
        WHEN u.IS_CORRECTION = TRUE      THEN 'CORRECTED'
        ELSE 'ACTUAL'
    END                                                               AS USAGE_QUALITY_STATUS,

    -- ---- Correction flag ----
    u.IS_CORRECTION,
    u.CORRECTION_REASON,

    -- ---- Source watermarks ----
    u.CREATED_AT,
    u.UPDATED_AT

FROM BILLING.MONTHLY_USAGE            u
LEFT JOIN rate_params                  rp  ON rp.RATE_PLAN_CODE = u.RATE_PLAN
;

-- ===========================================================================
-- VIEW 3: VW_DAILY_CUSTOMER_EXPORT
--   Customer-grain export view.  Includes ALL customers regardless of whether
--   they have an energy account.  Used to load the customer master table to
--   Oracle and to detect newly inserted customers (e.g. DC-01 CUST-D1- rows)
--   that have no energy account yet.
--
--   DESIGN RATIONALE
--   VW_DAILY_CUSTOMER_ACCOUNT_EXPORT is account-grain (rooted at ENERGY_ACCOUNT).
--   Customers without energy accounts never appear in that view.
--   This view is customer-grain (rooted at CUSTOMER) so it captures every
--   customer including newly inserted ones awaiting account creation.
--
--   DEDUPLICATION
--   Primary email and primary phone are selected deterministically via
--   QUALIFY ROW_NUMBER() … ORDER BY EFFECTIVE_DATE DESC.
--
--   COMPOSITE WATERMARK
--   RECORD_EFFECTIVE_TS = GREATEST(CUSTOMER.UPDATED_AT, EMAIL_UPDATED_AT,
--                                  PHONE_UPDATED_AT)
--   Advances whenever the customer row or any of their contact rows changes.
-- ===========================================================================
CREATE OR REPLACE VIEW STAGING.VW_DAILY_CUSTOMER_EXPORT AS
WITH

-- -----------------------------------------------------------------------
-- Primary email per customer (same logic as account-grain view)
-- -----------------------------------------------------------------------
primary_email AS (
    SELECT
        CUSTOMER_ID,
        CONTACT_VALUE                                          AS EMAIL_ADDRESS,
        IS_VERIFIED                                            AS EMAIL_VERIFIED,
        UPDATED_AT                                             AS EMAIL_UPDATED_AT
    FROM CUSTOMER.CUSTOMER_CONTACT
    WHERE CONTACT_TYPE = 'EMAIL'
      AND IS_PRIMARY    = TRUE
      AND (END_DATE IS NULL OR END_DATE >= CURRENT_DATE())
    QUALIFY ROW_NUMBER() OVER (PARTITION BY CUSTOMER_ID ORDER BY EFFECTIVE_DATE DESC) = 1
),

-- -----------------------------------------------------------------------
-- Primary phone per customer
-- -----------------------------------------------------------------------
primary_phone AS (
    SELECT
        CUSTOMER_ID,
        CONTACT_VALUE                                          AS PHONE_NUMBER,
        UPDATED_AT                                             AS PHONE_UPDATED_AT
    FROM CUSTOMER.CUSTOMER_CONTACT
    WHERE CONTACT_TYPE = 'PHONE'
      AND IS_PRIMARY    = TRUE
      AND (END_DATE IS NULL OR END_DATE >= CURRENT_DATE())
    QUALIFY ROW_NUMBER() OVER (PARTITION BY CUSTOMER_ID ORDER BY EFFECTIVE_DATE DESC) = 1
),

-- -----------------------------------------------------------------------
-- Customer type label lookup
-- -----------------------------------------------------------------------
cust_type_ref AS (
    SELECT CODE, CODE_LABEL AS CUST_TYPE_LABEL
    FROM REF.CODE_VALUE
    WHERE DOMAIN = 'CUST_TYPE'
),

-- -----------------------------------------------------------------------
-- Account status label lookup
-- -----------------------------------------------------------------------
acct_status_ref AS (
    SELECT CODE, CODE_LABEL AS ACCT_STATUS_LABEL
    FROM REF.CODE_VALUE
    WHERE DOMAIN = 'ACCT_STATUS'
)

-- -----------------------------------------------------------------------
-- Main select — one row per CUSTOMER
-- LEFT JOINs throughout so customers without contacts / ref labels still appear.
-- -----------------------------------------------------------------------
SELECT
    -- ---- Customer master (root of this view) ----
    c.CUSTOMER_ID,
    c.FIRST_NAME,
    c.LAST_NAME,
    c.MIDDLE_NAME,
    c.NAME_SUFFIX,
    TRIM(UPPER(c.FIRST_NAME) || ' ' ||
         COALESCE(UPPER(c.MIDDLE_NAME) || ' ', '') ||
         UPPER(c.LAST_NAME))                                   AS FULL_NAME_NORMALIZED,
    c.CUSTOMER_TYPE,
    c.DATE_OF_BIRTH,
    c.PREFERRED_LANGUAGE,
    c.ACCOUNT_STATUS                                           AS CUSTOMER_STATUS,
    CASE WHEN c.ACCOUNT_STATUS = 'INACTIVE' THEN TRUE
         ELSE FALSE
    END                                                        AS IS_INACTIVE,
    c.STATUS_REASON,

    -- ---- Contact ----
    pe.EMAIL_ADDRESS,
    pe.EMAIL_VERIFIED,
    pp.PHONE_NUMBER,

    -- ---- Reference labels ----
    asr.ACCT_STATUS_LABEL,
    ctr.CUST_TYPE_LABEL,

    -- ---- Source lineage ----
    c.CREATED_AT,
    c.UPDATED_AT,

    -- ---- Composite watermark ----
    GREATEST(
        COALESCE(c.UPDATED_AT,         '1970-01-01'::TIMESTAMP_TZ),
        COALESCE(pe.EMAIL_UPDATED_AT,  '1970-01-01'::TIMESTAMP_TZ),
        COALESCE(pp.PHONE_UPDATED_AT,  '1970-01-01'::TIMESTAMP_TZ)
    )                                                          AS RECORD_EFFECTIVE_TS

FROM CUSTOMER.CUSTOMER                c
LEFT JOIN primary_email                pe  ON pe.CUSTOMER_ID = c.CUSTOMER_ID
LEFT JOIN primary_phone                pp  ON pp.CUSTOMER_ID = c.CUSTOMER_ID
LEFT JOIN acct_status_ref              asr ON asr.CODE        = c.ACCOUNT_STATUS
LEFT JOIN cust_type_ref                ctr ON ctr.CODE        = c.CUSTOMER_TYPE
;

-- ===========================================================================
-- Grant SELECT to the service role
-- ===========================================================================
GRANT SELECT ON VIEW STAGING.VW_DAILY_CUSTOMER_ACCOUNT_EXPORT    TO ROLE CDP_LOADER_ROLE;
GRANT SELECT ON VIEW STAGING.VW_MONTHLY_USAGE_BILLING_EXPORT     TO ROLE CDP_LOADER_ROLE;
GRANT SELECT ON VIEW STAGING.VW_DAILY_CUSTOMER_EXPORT            TO ROLE CDP_LOADER_ROLE;

-- ===========================================================================
-- Verification
-- ===========================================================================
SHOW VIEWS IN SCHEMA CDP_UTIL_DB.STAGING;

-- ===========================================================================
-- UNIT TESTS — TRY_TO_DECIMAL VARIANT extraction
-- ===========================================================================
-- Run these SELECT statements manually in a Snowflake worksheet after the views
-- are created.  They do NOT require any table data.  Each test uses a literal
-- VARIANT value constructed with PARSE_JSON so the conversion behaviour can be
-- verified in isolation.
--
-- Expected results are documented inline.  A NULL result where a number is
-- expected indicates the conversion returned NULL correctly (no error raised).
-- ===========================================================================

-- ---------------------------------------------------------------------------
-- Test 1: Valid numeric value stored as a JSON number literal
--   Input:  {"fixed": 8.50, "energy": 0.1150, "demand": 3.50, "tax": 0.080}
--   Expect: FIXED_RATE=8.50, ENERGY_RATE=0.115000, DEMAND_RATE=3.500000, TAX_RATE=0.080000
-- ---------------------------------------------------------------------------
SELECT
    'T01_valid_number'                                                        AS TEST_CASE,
    TRY_TO_DECIMAL(PARSE_JSON('{"fixed":8.50}'):fixed::STRING,   10, 2)      AS FIXED_RATE,
    TRY_TO_DECIMAL(PARSE_JSON('{"energy":0.1150}'):energy::STRING, 10, 6)    AS ENERGY_RATE,
    TRY_TO_DECIMAL(PARSE_JSON('{"demand":3.50}'):demand::STRING,  10, 6)     AS DEMAND_RATE,
    TRY_TO_DECIMAL(PARSE_JSON('{"tax":0.080}'):tax::STRING,       10, 6)     AS TAX_RATE;
-- Expected: 8.50 | 0.115000 | 3.500000 | 0.080000

-- ---------------------------------------------------------------------------
-- Test 2: Numeric value stored as a JSON string (e.g. "8.50" rather than 8.50)
--   Input:  {"fixed": "8.50"}
--   Expect: FIXED_RATE=8.50  (TRY_TO_DECIMAL handles quoted numeric strings)
-- ---------------------------------------------------------------------------
SELECT
    'T02_quoted_number'                                                       AS TEST_CASE,
    TRY_TO_DECIMAL(PARSE_JSON('{"fixed":"8.50"}'):fixed::STRING, 10, 2)      AS FIXED_RATE;
-- Expected: 8.50

-- ---------------------------------------------------------------------------
-- Test 3: Missing key — key does not exist in the JSON object
--   Input:  {} (empty object)
--   Expect: NULL for all four fields
-- ---------------------------------------------------------------------------
SELECT
    'T03_missing_key'                                                         AS TEST_CASE,
    TRY_TO_DECIMAL(PARSE_JSON('{}'):fixed::STRING,  10, 2)                   AS FIXED_RATE,
    TRY_TO_DECIMAL(PARSE_JSON('{}'):energy::STRING, 10, 6)                   AS ENERGY_RATE,
    TRY_TO_DECIMAL(PARSE_JSON('{}'):demand::STRING, 10, 6)                   AS DEMAND_RATE,
    TRY_TO_DECIMAL(PARSE_JSON('{}'):tax::STRING,    10, 6)                   AS TAX_RATE;
-- Expected: NULL | NULL | NULL | NULL

-- ---------------------------------------------------------------------------
-- Test 4: JSON null literal (key present but value is null)
--   Input:  {"demand": null}
--   Expect: DEMAND_RATE=NULL
--   This is the standard representation for plans without a demand component.
-- ---------------------------------------------------------------------------
SELECT
    'T04_json_null'                                                           AS TEST_CASE,
    TRY_TO_DECIMAL(PARSE_JSON('{"demand":null}'):demand::STRING, 10, 6)      AS DEMAND_RATE;
-- Expected: NULL
-- In the charge calculation CASE, this produces CALC_DEMAND_CHARGE=0 per ICA MU-AC-09.

-- ---------------------------------------------------------------------------
-- Test 5: Invalid non-numeric text — conversion must return NULL, not error
--   Input:  {"fixed": "N/A"}
--   Expect: FIXED_RATE=NULL  (TRY_TO_DECIMAL returns NULL, no exception)
-- ---------------------------------------------------------------------------
SELECT
    'T05_invalid_text'                                                        AS TEST_CASE,
    TRY_TO_DECIMAL(PARSE_JSON('{"fixed":"N/A"}'):fixed::STRING, 10, 2)       AS FIXED_RATE;
-- Expected: NULL  (invalid rate — distinguishable from valid zero)

-- ---------------------------------------------------------------------------
-- Test 6: Negative rate value — returned as-is; application layer must validate
--   Input:  {"energy": -0.05}
--   Expect: ENERGY_RATE=-0.050000
--   Negative rates are NOT silently zeroed. The Spring Batch validation layer
--   (VR-RATE-001) rejects records with negative rate components during load.
--   Returning the raw negative value here allows the error to be detected and
--   reported in ETL_RECORD_ERROR rather than silently corrected.
-- ---------------------------------------------------------------------------
SELECT
    'T06_negative_rate'                                                       AS TEST_CASE,
    TRY_TO_DECIMAL(PARSE_JSON('{"energy":-0.05}'):energy::STRING, 10, 6)     AS ENERGY_RATE;
-- Expected: -0.050000  (not zeroed; downstream validation must flag this)

-- ---------------------------------------------------------------------------
-- Test 7: Full rate-plan object — end-to-end charge calculation verification
--   Input:  KWH_USAGE=500, PEAK_DEMAND_KW=5.0
--           fixed=8.50, energy=0.1150, demand=3.50, tax=0.080
--   Expected calculation:
--     FIXED  = 8.50
--     ENERGY = ROUND(500 × 0.1150, 2) = 57.50
--     DEMAND = ROUND(5.0 × 3.50, 2)  = 17.50
--     SUB    = 8.50 + 57.50 + 17.50  = 83.50
--     TAX    = ROUND(83.50 × 0.080, 2) = 6.68
--     TOTAL  = 83.50 + 6.68           = 90.18
-- ---------------------------------------------------------------------------
SELECT
    'T07_full_calculation'                                                    AS TEST_CASE,
    8.50::NUMBER(10,2)                                                        AS CALC_FIXED,
    ROUND(500 * 0.1150, 2)                                                   AS CALC_ENERGY,
    ROUND(5.0 * 3.50,   2)                                                   AS CALC_DEMAND,
    8.50 + ROUND(500 * 0.1150, 2) + ROUND(5.0 * 3.50, 2)                    AS CALC_SUBTOTAL,
    ROUND((8.50 + ROUND(500*0.1150,2) + ROUND(5.0*3.50,2)) * 0.080, 2)      AS CALC_TAX,
    (8.50 + ROUND(500*0.1150,2) + ROUND(5.0*3.50,2))
        + ROUND((8.50 + ROUND(500*0.1150,2) + ROUND(5.0*3.50,2)) * 0.080, 2)
                                                                              AS CALC_TOTAL;
-- Expected: 8.50 | 57.50 | 17.50 | 83.50 | 6.68 | 90.18
