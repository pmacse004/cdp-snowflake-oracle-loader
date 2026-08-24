# ICA Context Document 17 — Snowflake View Designs and Transformation Layer Assignment

**ICA Document ID:** ICA-17  
**Project:** CDP Snowflake to Oracle Data Loader  
**Version:** 1.1 (Phase 1 Amendment)  
**Status:** Phase 1 — Amended  
**Last Updated:** 2025 (Phase 1 Amendment)

> **Design only — no database objects created or executed in Phase 1.**

---

## 1. Purpose and Layered Responsibility

The ETL pipeline uses three layers of transformation. This document specifies which transformations belong in each layer to avoid redundant calculation and to keep responsibilities clear.

```
┌─────────────────────────────────────────────────────────────────────┐
│  LAYER 1 — Snowflake Views (VW_*)                                   │
│  Responsibility: joins, ranking/selection, set operations,          │
│  date/flag filtering, reference lookups, column aliasing            │
│  NOT responsible for: final validation, PII masking, Oracle types   │
└──────────────────────────────┬──────────────────────────────────────┘
                               │ JDBC read
┌──────────────────────────────▼──────────────────────────────────────┐
│  LAYER 2 — Spring Batch ItemProcessor (Java)                        │
│  Responsibility: type conversion, final validation, PII policy,     │
│  BigDecimal rounding, error isolation, FK resolution to Oracle IDs  │
│  NOT responsible for: joins, aggregations already done in Layer 1   │
└──────────────────────────────┬──────────────────────────────────────┘
                               │ JDBC write
┌──────────────────────────────▼──────────────────────────────────────┐
│  LAYER 3 — Oracle MERGE                                             │
│  Responsibility: idempotent upsert on business key,                 │
│  CREATED_AT/UPDATED_AT stamping, correction-version logic           │
│  NOT responsible for: business calculations already in Layers 1/2   │
└─────────────────────────────────────────────────────────────────────┘
```

---

## 2. VW_DAILY_CUSTOMER_ACCOUNT_EXPORT

### 2.1 Purpose

Provides a single, denormalised row per active energy account joining CUSTOMER, CUSTOMER_CONTACT, ENERGY_ACCOUNT, BILLING_ACCOUNT, SERVICE_PREMISE, METER and REF.CODE_VALUE. The ETL reads this view directly for both initial and daily loads.

### 2.2 Source Tables

| Alias | Source Table | Role |
|-------|-------------|------|
| `c` | `RAW.CUSTOMER` | Root entity |
| `cc` | `RAW.CUSTOMER_CONTACT` | Primary mailing contact (ranked) |
| `ea` | `RAW.ENERGY_ACCOUNT` | Energy account |
| `ba` | `RAW.BILLING_ACCOUNT` | Current billing account (ranked by EFFECTIVE_DATE) |
| `sp` | `RAW.SERVICE_PREMISE` | Current premise (ranked by ENERGY_ACCOUNT_ID) |
| `m` | `RAW.METER` | Current active meter at premise (ranked by INSTALL_DATE) |
| `rc_status` | `REF.CODE_VALUE` | Account-status label lookup (domain `ACCT_STATUS`) |
| `rc_rate` | `REF.CODE_VALUE` | Rate-plan description lookup (domain `RATE_PLAN`) |
| `rc_ctype` | `REF.CODE_VALUE` | Customer-type label lookup (domain `CUST_TYPE`) |

### 2.3 View Design (Snowflake SQL — not yet executed)

```sql
-- VW_DAILY_CUSTOMER_ACCOUNT_EXPORT
-- Design only — Phase 2 will create this view
CREATE OR REPLACE VIEW CDP_DW.CLEAN.VW_DAILY_CUSTOMER_ACCOUNT_EXPORT AS

WITH

-- Rank contact records: PRIMARY mailing contact first; most-recent EFFECTIVE_DATE breaks ties
ranked_contact AS (
  SELECT *,
    ROW_NUMBER() OVER (
      PARTITION BY CUSTOMER_ID
      ORDER BY IS_PRIMARY DESC,
               EFFECTIVE_DATE DESC,
               CONTACT_ID DESC
    ) AS rn
  FROM RAW.CUSTOMER_CONTACT
  WHERE CONTACT_TYPE = 'MAILING'
    AND (EXPIRY_DATE IS NULL OR EXPIRY_DATE >= CURRENT_DATE())
),

-- One current billing account per energy account
-- "Current" = EFFECTIVE_DATE <= today AND (EXPIRY_DATE IS NULL OR > today)
-- Most-recent EFFECTIVE_DATE wins; BILLING_ACCOUNT_ID breaks ties deterministically
ranked_billing AS (
  SELECT *,
    ROW_NUMBER() OVER (
      PARTITION BY ENERGY_ACCOUNT_ID
      ORDER BY EFFECTIVE_DATE DESC, BILLING_ACCOUNT_ID DESC
    ) AS rn
  FROM RAW.BILLING_ACCOUNT
  WHERE EFFECTIVE_DATE <= CURRENT_DATE()
    AND (EXPIRY_DATE IS NULL OR EXPIRY_DATE >= CURRENT_DATE())
),

-- One current active meter per premise
ranked_meter AS (
  SELECT *,
    ROW_NUMBER() OVER (
      PARTITION BY PREMISE_ID
      ORDER BY INSTALL_DATE DESC, METER_ID DESC
    ) AS rn
  FROM RAW.METER
  WHERE ACTIVE_FLAG = 'Y'
    AND (REMOVAL_DATE IS NULL OR REMOVAL_DATE >= CURRENT_DATE())
),

-- Greatest UPDATED_AT across all contributing rows per energy account
-- Used as the composite watermark timestamp for the logical record
max_source_ts AS (
  SELECT
    ea.ENERGY_ACCOUNT_ID,
    GREATEST(
      c.UPDATED_AT,
      COALESCE(cc_inner.UPDATED_AT, '1970-01-01'::TIMESTAMP_NTZ),
      ea.UPDATED_AT,
      COALESCE(ba_inner.UPDATED_AT, '1970-01-01'::TIMESTAMP_NTZ),
      COALESCE(sp_inner.UPDATED_AT, '1970-01-01'::TIMESTAMP_NTZ),
      COALESCE(m_inner.UPDATED_AT,  '1970-01-01'::TIMESTAMP_NTZ)
    ) AS RECORD_EFFECTIVE_TS
  FROM RAW.ENERGY_ACCOUNT ea
  JOIN RAW.CUSTOMER c ON c.CUSTOMER_ID = ea.CUSTOMER_ID
  LEFT JOIN ranked_contact cc_inner ON cc_inner.CUSTOMER_ID = c.CUSTOMER_ID AND cc_inner.rn = 1
  LEFT JOIN ranked_billing ba_inner ON ba_inner.ENERGY_ACCOUNT_ID = ea.ENERGY_ACCOUNT_ID AND ba_inner.rn = 1
  LEFT JOIN RAW.SERVICE_PREMISE sp_inner ON sp_inner.ENERGY_ACCOUNT_ID = ea.ENERGY_ACCOUNT_ID
  LEFT JOIN ranked_meter m_inner ON m_inner.PREMISE_ID = sp_inner.PREMISE_ID AND m_inner.rn = 1
)

SELECT
  -- ── Source identity ──────────────────────────────────────────────
  ea.ENERGY_ACCOUNT_ID,
  c.CUSTOMER_ID,

  -- ── Customer name (Layer 1 join; Layer 2 title-cases) ───────────
  c.FIRST_NAME,
  c.LAST_NAME,
  c.MIDDLE_NAME,
  TRIM(c.FIRST_NAME) || ' ' || TRIM(c.LAST_NAME)              AS FULL_NAME_RAW,

  -- ── Customer classification ──────────────────────────────────────
  c.CUSTOMER_TYPE,
  rc_ctype.CODE_LABEL                                          AS CUSTOMER_TYPE_LABEL,
  c.PREFERRED_LANGUAGE,

  -- ── Account status: from CUSTOMER (primary) and ENERGY_ACCOUNT ──
  c.ACCOUNT_STATUS                                            AS CUST_ACCOUNT_STATUS,
  ea.ACCOUNT_STATUS                                           AS EA_ACCOUNT_STATUS,
  -- Derived: if either is CLOSED/INACTIVE/deleted → combined INACTIVE
  CASE
    WHEN c.DELETED_FLAG = 'Y' OR ea.DELETED_FLAG = 'Y'        THEN 'CLOSED'
    WHEN c.ACCOUNT_STATUS IN ('CLO','CLOSED')                  THEN 'CLOSED'
    WHEN ea.ACCOUNT_STATUS IN ('CLO','CLOSED')                 THEN 'CLOSED'
    WHEN c.ACCOUNT_STATUS IN ('INA','INACTIVE','SUS','DIS')    THEN 'INACTIVE'
    WHEN ea.ACCOUNT_STATUS IN ('INA','INACTIVE','SUS','DIS')   THEN 'INACTIVE'
    WHEN c.ACCOUNT_STATUS IN ('PND','PENDING')                 THEN 'PENDING'
    ELSE                                                            'ACTIVE'
  END                                                         AS COMBINED_STATUS_CODE,
  rc_status.CODE_LABEL                                        AS COMBINED_STATUS_LABEL,

  -- ── Active indicator: 1 if both open and not deleted ────────────
  CASE
    WHEN c.DELETED_FLAG = 'Y' OR ea.DELETED_FLAG = 'Y'        THEN 0
    WHEN ea.END_DATE IS NOT NULL AND ea.END_DATE < CURRENT_DATE() THEN 0
    WHEN c.ACCOUNT_STATUS NOT IN ('ACT','ACTIVE','PND','PENDING') THEN 0
    ELSE 1
  END                                                         AS IS_ACTIVE,

  -- ── Soft-delete sourcing ─────────────────────────────────────────
  c.DELETED_FLAG                                              AS CUST_DELETED_FLAG,
  c.DELETED_AT                                                AS CUST_DELETED_AT,
  ea.DELETED_FLAG                                             AS EA_DELETED_FLAG,
  ea.DELETED_AT                                               AS EA_DELETED_AT,

  -- ── Account dates ────────────────────────────────────────────────
  c.START_DATE                                                AS CUSTOMER_START_DATE,
  c.END_DATE                                                  AS CUSTOMER_END_DATE,
  ea.START_DATE                                               AS ACCOUNT_START_DATE,
  ea.END_DATE                                                 AS ACCOUNT_END_DATE,
  ea.ACCOUNT_NUMBER,
  ea.SERVICE_TYPE,
  ea.RATE_CLASS,
  rc_rate.CODE_LABEL                                          AS RATE_CLASS_DESCRIPTION,

  -- ── Primary contact (mailing) ────────────────────────────────────
  cc.ADDRESS_LINE1,
  cc.ADDRESS_LINE2,
  cc.CITY,
  cc.STATE_CODE,
  cc.ZIP_CODE,
  -- Formatted service address (Layer 1); Layer 2 applies title-case to city
  TRIM(cc.ADDRESS_LINE1)
    || CASE WHEN cc.ADDRESS_LINE2 IS NOT NULL
            THEN ', ' || TRIM(cc.ADDRESS_LINE2)
            ELSE '' END
    || CASE WHEN cc.CITY IS NOT NULL
            THEN ', ' || TRIM(cc.CITY) ELSE '' END
    || CASE WHEN cc.STATE_CODE IS NOT NULL
            THEN ', ' || TRIM(cc.STATE_CODE) ELSE '' END
    || CASE WHEN cc.ZIP_CODE IS NOT NULL
            THEN ' ' || TRIM(cc.ZIP_CODE) ELSE '' END        AS FORMATTED_MAILING_ADDRESS,
  cc.EMAIL_ADDRESS,                     -- Layer 2 normalises to lower-case
  cc.PHONE_NUMBER,                      -- Layer 2 normalises to E.164
  cc.IS_PRIMARY                         AS CONTACT_IS_PRIMARY,
  cc.CONTACT_ID                         AS PRIMARY_CONTACT_ID,

  -- ── Current billing account ──────────────────────────────────────
  ba.BILLING_ACCOUNT_ID,
  ba.BILLING_ACCOUNT_NUMBER,
  ba.BILLING_CYCLE,
  ba.PAYMENT_METHOD,
  ba.PAPERLESS_BILLING,
  ba.EFFECTIVE_DATE                                           AS BILLING_EFFECTIVE_DATE,
  ba.EXPIRY_DATE                                              AS BILLING_EXPIRY_DATE,

  -- ── Current service premise ──────────────────────────────────────
  sp.PREMISE_ID,
  sp.PREMISE_TYPE,
  sp.SERVICE_ADDRESS1,
  sp.SERVICE_ADDRESS2,
  sp.CITY                                                     AS PREMISE_CITY,
  sp.STATE_CODE                                               AS PREMISE_STATE,
  sp.ZIP_CODE                                                 AS PREMISE_ZIP,
  sp.COUNTY,
  sp.GPS_LATITUDE,
  sp.GPS_LONGITUDE,
  sp.DISTRIBUTION_ZONE,
  sp.ACTIVE_FLAG                                              AS PREMISE_ACTIVE_FLAG,

  -- ── Current active meter ─────────────────────────────────────────
  m.METER_ID,
  m.METER_NUMBER,
  m.METER_TYPE,
  m.INSTALL_DATE                                              AS METER_INSTALL_DATE,
  m.MULTIPLIER                                                AS METER_MULTIPLIER,
  m.KWH_DIAL_COUNT,

  -- ── Record lineage timestamp (GREATEST of all contributing UPDATED_AT) ──
  mts.RECORD_EFFECTIVE_TS,

  -- ── Watermark keys per contributing table (for multi-source change detection) ──
  c.UPDATED_AT                                                AS CUST_UPDATED_AT,
  c.CUSTOMER_ID                                               AS CUST_ID_FOR_WM,
  cc.UPDATED_AT                                               AS CONTACT_UPDATED_AT,
  cc.CONTACT_ID                                               AS CONTACT_ID_FOR_WM,
  ea.UPDATED_AT                                               AS EA_UPDATED_AT,
  ea.ENERGY_ACCOUNT_ID                                        AS EA_ID_FOR_WM,
  ba.UPDATED_AT                                               AS BA_UPDATED_AT,
  ba.BILLING_ACCOUNT_ID                                       AS BA_ID_FOR_WM,
  sp.UPDATED_AT                                               AS SP_UPDATED_AT,
  sp.PREMISE_ID                                               AS SP_ID_FOR_WM,
  m.UPDATED_AT                                                AS METER_UPDATED_AT,
  m.METER_ID                                                  AS METER_ID_FOR_WM

FROM RAW.ENERGY_ACCOUNT ea
JOIN RAW.CUSTOMER c
  ON c.CUSTOMER_ID = ea.CUSTOMER_ID
LEFT JOIN ranked_contact cc
  ON cc.CUSTOMER_ID = c.CUSTOMER_ID AND cc.rn = 1
LEFT JOIN ranked_billing ba
  ON ba.ENERGY_ACCOUNT_ID = ea.ENERGY_ACCOUNT_ID AND ba.rn = 1
LEFT JOIN RAW.SERVICE_PREMISE sp
  ON sp.ENERGY_ACCOUNT_ID = ea.ENERGY_ACCOUNT_ID
LEFT JOIN ranked_meter m
  ON m.PREMISE_ID = sp.PREMISE_ID AND m.rn = 1
LEFT JOIN max_source_ts mts
  ON mts.ENERGY_ACCOUNT_ID = ea.ENERGY_ACCOUNT_ID
-- Reference lookups
LEFT JOIN REF.CODE_VALUE rc_status
  ON rc_status.CODE_DOMAIN = 'ACCT_STATUS'
 AND rc_status.CODE_VALUE  = CASE
    WHEN c.DELETED_FLAG = 'Y' OR ea.DELETED_FLAG = 'Y'        THEN 'CLO'
    WHEN c.ACCOUNT_STATUS IN ('CLO','CLOSED')                  THEN 'CLO'
    WHEN ea.ACCOUNT_STATUS IN ('CLO','CLOSED')                 THEN 'CLO'
    WHEN c.ACCOUNT_STATUS IN ('INA','INACTIVE','SUS','DIS')    THEN 'INA'
    WHEN ea.ACCOUNT_STATUS IN ('INA','INACTIVE','SUS','DIS')   THEN 'INA'
    WHEN c.ACCOUNT_STATUS IN ('PND','PENDING')                 THEN 'PND'
    ELSE 'ACT' END
LEFT JOIN REF.CODE_VALUE rc_rate
  ON rc_rate.CODE_DOMAIN = 'RATE_PLAN'
 AND rc_rate.CODE_VALUE  = ea.RATE_CLASS
LEFT JOIN REF.CODE_VALUE rc_ctype
  ON rc_ctype.CODE_DOMAIN = 'CUST_TYPE'
 AND rc_ctype.CODE_VALUE  = c.CUSTOMER_TYPE
;
```

### 2.4 ROW_NUMBER Determinism Rules

| CTE | PARTITION BY | ORDER BY | Tie-break |
|-----|-------------|----------|-----------|
| `ranked_contact` | `CUSTOMER_ID` | `IS_PRIMARY DESC, EFFECTIVE_DATE DESC` | `CONTACT_ID DESC` (highest ID wins) |
| `ranked_billing` | `ENERGY_ACCOUNT_ID` | `EFFECTIVE_DATE DESC` | `BILLING_ACCOUNT_ID DESC` |
| `ranked_meter` | `PREMISE_ID` | `INSTALL_DATE DESC` | `METER_ID DESC` |

All ordering columns are stable non-null values so the result is fully deterministic.

### 2.5 What Each Layer Does for This View

| Layer | Responsibility |
|-------|---------------|
| **Snowflake view** | Joins, ROW_NUMBER ranking, CASE DERIVED status, GREATEST timestamp, formatted address assembly, reference label lookups |
| **Spring Batch Processor** | Title-case names, lower-case + validate email, E.164 phone normalisation, FK resolution to Oracle IDs, BigDecimal type conversion, final VR-* validation, PII redaction for error payloads |
| **Oracle MERGE** | Idempotent upsert on `SOURCE_ENERGY_ACCOUNT_ID`, set `CREATED_AT`/`UPDATED_AT`, apply correction watermark for updates |

---

## 3. VW_MONTHLY_USAGE_BILLING_EXPORT

### 3.1 Purpose

Provides one row per billing record joining MONTHLY_USAGE, ENERGY_ACCOUNT, METER, BILLING_ACCOUNT, SERVICE_PREMISE and REF.CODE_VALUE for rate-plan lookup. Performs all charge calculations in Snowflake using synthetic demonstration rates.

### 3.2 Source Tables

| Alias | Source Table | Role |
|-------|-------------|------|
| `u` | `RAW.MONTHLY_USAGE` | Usage measurement record |
| `m` | `RAW.METER` | Meter attributes (multiplier, type) |
| `ea` | `RAW.ENERGY_ACCOUNT` | Account and rate class |
| `ba` | `RAW.BILLING_ACCOUNT` | Current billing account |
| `sp` | `RAW.SERVICE_PREMISE` | Service location |
| `rc_rate` | `REF.CODE_VALUE` | Rate-plan details (domain `RATE_PLAN`) |
| `rc_read` | `REF.CODE_VALUE` | Read-type label (domain `READ_TYPE`) |

### 3.3 Synthetic Demonstration Rate Structure

> These are **entirely synthetic** demonstration rates. They do not represent any real utility's tariff.

| Rate Plan | Fixed Charge/month (USD) | Energy Rate ($/kWh) | Demand Rate ($/kW) | Tax Rate |
|-----------|--------------------------|--------------------|--------------------|---------|
| `RES-1` | 8.50 | 0.1150 | N/A | 0.080 |
| `RES-2` | 8.50 | 0.0900 (peak) / 0.0700 (off-peak) | N/A | 0.080 |
| `RES-3` | 8.50 | 0.1050 | N/A | 0.080 |
| `COM-1` | 22.00 | 0.1050 | 8.50 | 0.085 |
| `COM-2` | 22.00 | 0.0950 | 9.00 | 0.085 |
| `COM-3` | 15.00 | 0.1100 | N/A | 0.085 |
| `IND-1` | 75.00 | 0.0850 | 12.00 | 0.070 |
| `IND-2` | 60.00 | 0.0750 | 10.00 | 0.070 |
| `SOL-1` | 8.50 | 0.0700 | N/A | 0.080 |

These values are stored in `REF.CODE_VALUE` as JSON-style attributes in `CODE_LABEL` (e.g., `{"fixed":8.50,"energy":0.1150,"demand":null,"tax":0.080}`) and parsed in the view.

### 3.4 Calculation Order and Rounding Rules

All calculations use `NUMBER` arithmetic in Snowflake with explicit `ROUND(..., 2)` at each monetary step.

```
Step 1: ADJUSTED_KWH
        = ROUND( (CURR_METER_READING - PREV_METER_READING) * METER_MULTIPLIER, 6 )
        Note: if CURR > PREV and READ_TYPE = 'A', use calculated value;
              if SOURCE KWH_USAGE differs by > 0.001 kWh, flag as READING_KWH_MISMATCH
        Default: use source KWH_USAGE when meter multiplier = 1.0 (no adjustment)

Step 2: FIXED_CHARGE
        = ROUND( rate_fixed_charge, 2 )
        — from rate-plan table; no KWH dependence

Step 3: ENERGY_CHARGE
        = ROUND( ADJUSTED_KWH * rate_energy_per_kwh, 2 )

Step 4: DEMAND_CHARGE
        = ROUND( PEAK_DEMAND_KW * rate_demand_per_kw, 2 )
          where rate_demand_per_kw IS NOT NULL; else 0.00

Step 5: SUBTOTAL
        = ROUND( FIXED_CHARGE + ENERGY_CHARGE + DEMAND_CHARGE, 2 )

Step 6: TAX_AMOUNT
        = ROUND( SUBTOTAL * rate_tax_rate, 2 )

Step 7: TOTAL_BILLED_AMOUNT
        = ROUND( SUBTOTAL + TAX_AMOUNT, 2 )

Step 8: BILL_TOTAL_VARIANCE
        = SOURCE.TOTAL_BILLED_AMOUNT - TOTAL_BILLED_AMOUNT
          (stored for audit; triggers VAL-USAGE-011 if abs > 0.01)
```

### 3.5 View Design (Snowflake SQL — not yet executed)

```sql
-- VW_MONTHLY_USAGE_BILLING_EXPORT
-- Design only — Phase 2 will create this view
CREATE OR REPLACE VIEW CDP_DW.CLEAN.VW_MONTHLY_USAGE_BILLING_EXPORT AS

WITH

-- Parse synthetic rate attributes from CODE_LABEL JSON field
rate_params AS (
  SELECT
    CODE_VALUE                                                       AS RATE_PLAN,
    TRY_TO_NUMBER(PARSE_JSON(CODE_LABEL):fixed::STRING)             AS FIXED_CHARGE_RATE,
    TRY_TO_NUMBER(PARSE_JSON(CODE_LABEL):energy::STRING)            AS ENERGY_RATE_PER_KWH,
    TRY_TO_NUMBER(PARSE_JSON(CODE_LABEL):demand::STRING)            AS DEMAND_RATE_PER_KW,
    TRY_TO_NUMBER(PARSE_JSON(CODE_LABEL):tax::STRING)               AS TAX_RATE
  FROM REF.CODE_VALUE
  WHERE CODE_DOMAIN = 'RATE_PLAN'
    AND IS_ACTIVE = 'Y'
),

-- One current billing account per energy account (same logic as daily view)
current_billing AS (
  SELECT *,
    ROW_NUMBER() OVER (
      PARTITION BY ENERGY_ACCOUNT_ID
      ORDER BY EFFECTIVE_DATE DESC, BILLING_ACCOUNT_ID DESC
    ) AS rn
  FROM RAW.BILLING_ACCOUNT
)

SELECT
  -- ── Source identity ──────────────────────────────────────────────
  u.USAGE_ID,
  u.ENERGY_ACCOUNT_ID,
  u.PREMISE_ID,
  u.METER_ID,
  ea.CUSTOMER_ID,

  -- ── Billing period ───────────────────────────────────────────────
  u.BILLING_MONTH,
  u.BILL_START_DATE,
  u.BILL_END_DATE,
  -- Billing days derived from dates (source value preserved for comparison)
  DATEDIFF('day', u.BILL_START_DATE, u.BILL_END_DATE) + 1         AS BILLING_DAYS_CALC,
  u.BILLING_DAYS                                                   AS BILLING_DAYS_SOURCE,

  -- ── Meter readings and adjusted usage ────────────────────────────
  u.PREV_METER_READING,
  u.CURR_METER_READING,
  m.MULTIPLIER                                                     AS METER_MULTIPLIER,
  -- Adjusted KWH from meter readings (Step 1)
  ROUND((u.CURR_METER_READING - u.PREV_METER_READING) * m.MULTIPLIER, 6)
                                                                   AS ADJUSTED_KWH,
  u.KWH_USAGE                                                      AS SOURCE_KWH_USAGE,
  -- Mismatch flag if adjusted vs source differ by > 0.001
  CASE
    WHEN ABS(ROUND((u.CURR_METER_READING - u.PREV_METER_READING) * m.MULTIPLIER, 6)
             - u.KWH_USAGE) > 0.001
    THEN 'Y' ELSE 'N'
  END                                                              AS READING_KWH_MISMATCH,
  u.PEAK_DEMAND_KW,
  u.READ_TYPE,
  u.CORRECTION_FLAG,
  u.ORIGINAL_USAGE_ID,

  -- ── Rate plan ────────────────────────────────────────────────────
  ea.RATE_CLASS                                                    AS RATE_PLAN,
  rp.FIXED_CHARGE_RATE,
  rp.ENERGY_RATE_PER_KWH,
  rp.DEMAND_RATE_PER_KW,
  rp.TAX_RATE,

  -- ── Charge calculations (Steps 2-7) ─────────────────────────────
  -- Step 2: Fixed charge
  ROUND(COALESCE(rp.FIXED_CHARGE_RATE, 0), 2)                     AS FIXED_CHARGE,

  -- Step 3: Energy charge
  ROUND(u.KWH_USAGE * COALESCE(rp.ENERGY_RATE_PER_KWH, 0), 2)    AS ENERGY_CHARGE_CALC,

  -- Step 4: Demand charge (0 if no demand rate for this plan)
  ROUND(COALESCE(u.PEAK_DEMAND_KW, 0)
        * COALESCE(rp.DEMAND_RATE_PER_KW, 0), 2)                  AS DEMAND_CHARGE_CALC,

  -- Step 5: Subtotal
  ROUND(
    ROUND(COALESCE(rp.FIXED_CHARGE_RATE, 0), 2)
    + ROUND(u.KWH_USAGE * COALESCE(rp.ENERGY_RATE_PER_KWH, 0), 2)
    + ROUND(COALESCE(u.PEAK_DEMAND_KW, 0) * COALESCE(rp.DEMAND_RATE_PER_KW, 0), 2),
  2)                                                               AS SUBTOTAL_CALC,

  -- Step 6: Tax
  ROUND(
    ROUND(
      ROUND(COALESCE(rp.FIXED_CHARGE_RATE, 0), 2)
      + ROUND(u.KWH_USAGE * COALESCE(rp.ENERGY_RATE_PER_KWH, 0), 2)
      + ROUND(COALESCE(u.PEAK_DEMAND_KW, 0) * COALESCE(rp.DEMAND_RATE_PER_KW, 0), 2),
    2) * COALESCE(rp.TAX_RATE, 0),
  2)                                                               AS TAX_AMOUNT_CALC,

  -- Step 7: Total billed
  ROUND(
    ROUND(
      ROUND(COALESCE(rp.FIXED_CHARGE_RATE, 0), 2)
      + ROUND(u.KWH_USAGE * COALESCE(rp.ENERGY_RATE_PER_KWH, 0), 2)
      + ROUND(COALESCE(u.PEAK_DEMAND_KW, 0) * COALESCE(rp.DEMAND_RATE_PER_KW, 0), 2),
    2)
    * (1 + COALESCE(rp.TAX_RATE, 0)),
  2)                                                               AS TOTAL_BILLED_CALC,

  -- Source values for comparison
  u.ENERGY_CHARGE                                                  AS SOURCE_ENERGY_CHARGE,
  u.TAX_AMOUNT                                                     AS SOURCE_TAX_AMOUNT,
  u.TOTAL_BILLED_AMOUNT                                            AS SOURCE_TOTAL_BILLED,

  -- Step 8: Variance
  ROUND(u.TOTAL_BILLED_AMOUNT - ROUND(
    ROUND(
      ROUND(COALESCE(rp.FIXED_CHARGE_RATE, 0), 2)
      + ROUND(u.KWH_USAGE * COALESCE(rp.ENERGY_RATE_PER_KWH, 0), 2)
      + ROUND(COALESCE(u.PEAK_DEMAND_KW, 0) * COALESCE(rp.DEMAND_RATE_PER_KW, 0), 2),
    2) * (1 + COALESCE(rp.TAX_RATE, 0))
  , 2), 2)                                                         AS BILL_TOTAL_VARIANCE,

  -- ── Usage quality / validation indicators ────────────────────────
  CASE
    WHEN u.KWH_USAGE < 0                             THEN 'FAIL_NEG_KWH'
    WHEN u.PEAK_DEMAND_KW < 0                        THEN 'FAIL_NEG_KW'
    WHEN u.BILL_END_DATE <= u.BILL_START_DATE         THEN 'FAIL_DATE_ORDER'
    WHEN rp.RATE_PLAN IS NULL                         THEN 'FAIL_UNKNOWN_RATE'
    WHEN READING_KWH_MISMATCH = 'Y'                  THEN 'WARN_KWH_MISMATCH'
    ELSE 'PASS'
  END                                                              AS USAGE_QUALITY_STATUS,

  -- ── Watermark fields ─────────────────────────────────────────────
  u.UPDATED_AT                                                     AS USAGE_UPDATED_AT,
  u.USAGE_ID                                                       AS USAGE_ID_FOR_WM,

  -- ── Account and premise context ──────────────────────────────────
  ea.ACCOUNT_NUMBER,
  ea.RATE_CLASS,
  ba.BILLING_ACCOUNT_NUMBER,
  sp.SERVICE_ADDRESS1,
  sp.CITY                                                          AS PREMISE_CITY,
  sp.STATE_CODE                                                    AS PREMISE_STATE,
  m.METER_NUMBER,
  m.METER_TYPE

FROM RAW.MONTHLY_USAGE u
JOIN RAW.ENERGY_ACCOUNT ea
  ON ea.ENERGY_ACCOUNT_ID = u.ENERGY_ACCOUNT_ID
JOIN RAW.METER m
  ON m.METER_ID = u.METER_ID
LEFT JOIN current_billing ba
  ON ba.ENERGY_ACCOUNT_ID = u.ENERGY_ACCOUNT_ID AND ba.rn = 1
LEFT JOIN RAW.SERVICE_PREMISE sp
  ON sp.PREMISE_ID = u.PREMISE_ID
LEFT JOIN rate_params rp
  ON rp.RATE_PLAN = ea.RATE_CLASS
;
```

### 3.6 What Each Layer Does for This View

| Layer | Responsibility |
|-------|---------------|
| **Snowflake view** | All 7 charge-calculation steps, BILLING_DAYS derivation, ADJUSTED_KWH, mismatch flag, USAGE_QUALITY_STATUS, rate-plan parameter lookup, billing account and premise context join |
| **Spring Batch Processor** | BigDecimal conversion and scale enforcement, VR-USAGE-* validation (reject fatal; warn non-fatal), FK resolution to Oracle target IDs, PII redaction for error payloads |
| **Oracle MERGE** | Idempotent upsert on `(ENERGY_ACCOUNT_ID, BILLING_MONTH)` business key; update only if incoming `SOURCE_UPDATED_AT` is newer (correction logic) |

---

## 4. Transformation Layer Summary Matrix

| Transformation | Snowflake Layer 1 | Spring Batch Layer 2 | Oracle Layer 3 |
|---|:---:|:---:|:---:|
| Multi-table join | ✅ | | |
| ROW_NUMBER ranking/selection | ✅ | | |
| Reference-label lookup | ✅ | | |
| CASE WHEN status derivation | ✅ | | |
| GREATEST timestamp derivation | ✅ | | |
| Address formatting (concatenation) | ✅ | | |
| Charge calculations (fixed, energy, demand) | ✅ | | |
| Tax calculation | ✅ | | |
| Billing-days derivation | ✅ | | |
| Adjusted KWH from readings + multiplier | ✅ | | |
| Variance computation (source vs calculated) | ✅ | | |
| Usage quality status flag | ✅ | | |
| Title-case name normalisation | | ✅ | |
| Email lower-case + RFC 5322 validation | | ✅ | |
| Phone E.164 normalisation | | ✅ | |
| BigDecimal scale enforcement | | ✅ | |
| Final VR-* validation and error isolation | | ✅ | |
| FK resolution (source ID → Oracle target ID) | | ✅ | |
| PII redaction from error payloads | | ✅ | |
| Idempotent INSERT/UPDATE (MERGE) | | | ✅ |
| CREATED_AT / UPDATED_AT stamping | | | ✅ |
| Correction watermark check | | | ✅ |
