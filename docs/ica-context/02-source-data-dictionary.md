# ICA Context Document 02 — Source Data Dictionary (Snowflake)

**ICA Document ID:** ICA-02  
**Project:** CDP Snowflake to Oracle Data Loader  
**Version:** 1.0  
**Status:** Phase 1 — Approved  
**Last Updated:** 2025 (Phase 1)

> This document is the authoritative source dictionary for Snowflake source objects extracted by the CDP Loader.  
> All data is synthetic. Connectivity has not been tested in Phase 1.

---

## 1. Connection Details

| Property | Value |
|----------|-------|
| Account identifier | `LJPNAFI-RW79936` |
| Account locator | `BM00315` |
| Region | AZURE_CENTRALINDIA |
| Database | `CDP_DW` *(to be created Phase 2)* |
| ETL Warehouse | `CDP_LOADER_WH` *(X-Small, to be created Phase 2)* |
| ETL Role | `CDP_LOADER_ROLE` *(read-only, to be created Phase 2)* |
| Service User | `SVC_CDP_LOADER` *(key-pair auth, to be created Phase 2)* |

---

## 2. Schema: REF

### REF.CODE_VALUE

**Purpose:** Centralised code/reference table shared across all entities.
**Load frequency:** Initial + daily incremental (changes rare).
**Extraction source:** `CDP_UTIL_DB.REF.CODE_VALUE`

> **Schema note (Phase 3 audit — Issue #1):** The `ATTRIBUTES` VARIANT column was added by script `03a-add-reference-attributes.sql` to `REF.CODE_VALUE`. `CODE_LABEL` is a human-readable text label ONLY. Structured rate parameters (fixed charge, energy rate, demand rate, tax rate) are stored in `ATTRIBUTES` as a native Snowflake VARIANT object. Script `04-create-export-views.sql` reads `ATTRIBUTES['fixed']::STRING` etc. using bracket notation, not `TRY_PARSE_JSON(CODE_LABEL)`.

| # | Column | Snowflake Type | Nullable | PK | UK | Sample Value | Business Term |
|---|--------|---------------|----------|----|----|-------------|---------------|
| 1 | CODE_VALUE_ID | NUMBER(10,0) | NO | ✓ | | 1001 | — |
| 2 | DOMAIN | VARCHAR(50) | NO | | ✓ | `ACCT_STATUS` | Code Domain |
| 3 | CODE | VARCHAR(30) | NO | | ✓ | `ACTIVE` | Code Value |
| 4 | CODE_LABEL | VARCHAR(500) | NO | | | `Active` | Human-readable label ONLY (never JSON) |
| 5 | ATTRIBUTES | VARIANT | YES | | | `{"fixed":8.50,"energy":0.115,"demand":null,"tax":0.08,"synthetic":true}` | Structured rate parameters (RATE_PLAN rows only; NULL for all other domains) |
| 6 | DESCRIPTION | VARCHAR(500) | YES | | | `[SYNTHETIC] fixed $8.50/mo…` | Descriptive notes |
| 7 | DISPLAY_ORDER | NUMBER(5,0) | YES | | | 10 | — |
| 8 | IS_ACTIVE | BOOLEAN | NO | | | `TRUE` | — |
| 9 | CREATED_AT | TIMESTAMP_TZ | NO | | | `2025-06-01T00:00:00+00:00` | — |
| 10 | UPDATED_AT | TIMESTAMP_TZ | NO | | | `2025-06-01T00:00:00+00:00` | Watermark column |

**ATTRIBUTES VARIANT structure (RATE_PLAN domain rows only):**

```json
{
  "fixed":     8.50,
  "energy":    0.115000,
  "demand":    null,
  "tax":       0.080000,
  "synthetic": true
}
```

Access pattern in Snowflake SQL: `ATTRIBUTES['fixed']::STRING` → then `TRY_TO_DECIMAL(…, 10, 2)`.

---

## 3. Schema: RAW

### RAW.CUSTOMER

**Purpose:** Master customer record.  
**Load frequency:** Initial + daily incremental.  
**Extraction source:** `CDP_DW.RAW.CUSTOMER` or view `CDP_DW.CLEAN.V_CUSTOMER`  
**PII columns:** FIRST_NAME, LAST_NAME, MIDDLE_NAME

| # | Column | Snowflake Type | Nullable | PK | Notes |
|---|--------|---------------|----------|----|-------|
| 1 | CUSTOMER_ID | NUMBER(15,0) | NO | ✓ | Stable surrogate; never reused |
| 2 | EXTERNAL_REF | VARCHAR(30) | YES | | Optional upstream ref |
| 3 | FIRST_NAME | VARCHAR(100) | NO | | **PII** |
| 4 | LAST_NAME | VARCHAR(100) | NO | | **PII** |
| 5 | MIDDLE_NAME | VARCHAR(50) | YES | | **PII** |
| 6 | CUSTOMER_TYPE | VARCHAR(20) | NO | | `RESIDENTIAL` / `COMMERCIAL` / `INDUSTRIAL` |
| 7 | ACCOUNT_STATUS | VARCHAR(20) | NO | | Source codes: `ACT`, `INA`, `PND`, `CLO` |
| 8 | START_DATE | DATE | NO | | Customer relationship start |
| 9 | END_DATE | DATE | YES | | Customer relationship end |
| 10 | PREFERRED_LANGUAGE | VARCHAR(10) | YES | | ISO 639-1 |
| 11 | CREATED_AT | TIMESTAMP_NTZ | NO | | UTC |
| 12 | UPDATED_AT | TIMESTAMP_NTZ | NO | | **Watermark column** |
| 13 | DELETED_FLAG | VARCHAR(1) | NO | | `N` / `Y` |
| 14 | DELETED_AT | TIMESTAMP_NTZ | YES | | UTC soft-delete time |

### RAW.CUSTOMER_CONTACT

**PII columns:** ADDRESS_LINE1, ADDRESS_LINE2, CITY, EMAIL_ADDRESS, PHONE_NUMBER

| # | Column | Snowflake Type | Nullable | PK | Notes |
|---|--------|---------------|----------|----|-------|
| 1 | CONTACT_ID | NUMBER(15,0) | NO | ✓ | |
| 2 | CUSTOMER_ID | NUMBER(15,0) | NO | | FK → CUSTOMER |
| 3 | CONTACT_TYPE | VARCHAR(20) | NO | | `MAILING`, `SERVICE`, `BILLING`, `EMAIL`, `PHONE` |
| 4 | ADDRESS_LINE1 | VARCHAR(200) | YES | | **PII** |
| 5 | ADDRESS_LINE2 | VARCHAR(100) | YES | | **PII** |
| 6 | CITY | VARCHAR(100) | YES | | **PII** |
| 7 | STATE_CODE | VARCHAR(2) | YES | | US 2-letter state |
| 8 | ZIP_CODE | VARCHAR(10) | YES | | US ZIP or ZIP+4 |
| 9 | EMAIL_ADDRESS | VARCHAR(255) | YES | | **PII** — mixed case |
| 10 | PHONE_NUMBER | VARCHAR(30) | YES | | **PII** — various formats |
| 11 | IS_PRIMARY | VARCHAR(1) | NO | | `Y` / `N` |
| 12 | EFFECTIVE_DATE | DATE | NO | | |
| 13 | EXPIRY_DATE | DATE | YES | | |
| 14 | CREATED_AT | TIMESTAMP_NTZ | NO | | UTC |
| 15 | UPDATED_AT | TIMESTAMP_NTZ | NO | | **Watermark column** |

### RAW.ENERGY_ACCOUNT

| # | Column | Snowflake Type | Nullable | PK | Notes |
|---|--------|---------------|----------|----|-------|
| 1 | ENERGY_ACCOUNT_ID | NUMBER(15,0) | NO | ✓ | |
| 2 | CUSTOMER_ID | NUMBER(15,0) | NO | | FK → CUSTOMER |
| 3 | ACCOUNT_NUMBER | VARCHAR(20) | NO | | Business account number |
| 4 | ACCOUNT_STATUS | VARCHAR(20) | NO | | Source codes: `ACT`, `INA`, `PND`, `CLO` |
| 5 | SERVICE_TYPE | VARCHAR(30) | NO | | `ELECTRIC` for this demo |
| 6 | RATE_CLASS | VARCHAR(20) | NO | | Tariff code e.g., `RES-1`, `COM-2` |
| 7 | START_DATE | DATE | NO | | Account open date |
| 8 | END_DATE | DATE | YES | | Account close date |
| 9 | CREATED_AT | TIMESTAMP_NTZ | NO | | UTC |
| 10 | UPDATED_AT | TIMESTAMP_NTZ | NO | | **Watermark column** |
| 11 | DELETED_FLAG | VARCHAR(1) | NO | | `N` / `Y` |
| 12 | DELETED_AT | TIMESTAMP_NTZ | YES | | UTC |

### RAW.BILLING_ACCOUNT

| # | Column | Snowflake Type | Nullable | PK | Notes |
|---|--------|---------------|----------|----|-------|
| 1 | BILLING_ACCOUNT_ID | NUMBER(15,0) | NO | ✓ | |
| 2 | ENERGY_ACCOUNT_ID | NUMBER(15,0) | NO | | FK → ENERGY_ACCOUNT |
| 3 | BILLING_ACCOUNT_NUMBER | VARCHAR(30) | NO | | **Sensitive business** |
| 4 | BILLING_CYCLE | VARCHAR(10) | NO | | `MONTHLY` / `BIMONTHLY` |
| 5 | PAYMENT_METHOD | VARCHAR(20) | YES | | `AUTO_PAY`, `MAIL`, `ONLINE` |
| 6 | PAPERLESS_BILLING | VARCHAR(1) | NO | | `Y` / `N` |
| 7 | EFFECTIVE_DATE | DATE | NO | | |
| 8 | EXPIRY_DATE | DATE | YES | | |
| 9 | CREATED_AT | TIMESTAMP_NTZ | NO | | UTC |
| 10 | UPDATED_AT | TIMESTAMP_NTZ | NO | | **Watermark column** |

### RAW.SERVICE_PREMISE

| # | Column | Snowflake Type | Nullable | PK | Notes |
|---|--------|---------------|----------|----|-------|
| 1 | PREMISE_ID | NUMBER(15,0) | NO | ✓ | |
| 2 | ENERGY_ACCOUNT_ID | NUMBER(15,0) | NO | | FK → ENERGY_ACCOUNT |
| 3 | PREMISE_TYPE | VARCHAR(20) | NO | | `RESIDENTIAL`, `COMMERCIAL`, `INDUSTRIAL` |
| 4 | SERVICE_ADDRESS1 | VARCHAR(200) | NO | | |
| 5 | SERVICE_ADDRESS2 | VARCHAR(100) | YES | | |
| 6 | CITY | VARCHAR(100) | NO | | |
| 7 | STATE_CODE | VARCHAR(2) | NO | | US state |
| 8 | ZIP_CODE | VARCHAR(10) | NO | | |
| 9 | COUNTY | VARCHAR(100) | YES | | |
| 10 | GPS_LATITUDE | NUMBER(10,7) | YES | | Decimal degrees |
| 11 | GPS_LONGITUDE | NUMBER(10,7) | YES | | Decimal degrees |
| 12 | DISTRIBUTION_ZONE | VARCHAR(20) | YES | | Grid zone code |
| 13 | ACTIVE_FLAG | VARCHAR(1) | NO | | `Y` / `N` |
| 14 | CREATED_AT | TIMESTAMP_NTZ | NO | | UTC |
| 15 | UPDATED_AT | TIMESTAMP_NTZ | NO | | **Watermark column** |

### RAW.METER

| # | Column | Snowflake Type | Nullable | PK | Notes |
|---|--------|---------------|----------|----|-------|
| 1 | METER_ID | NUMBER(15,0) | NO | ✓ | |
| 2 | PREMISE_ID | NUMBER(15,0) | NO | | FK → SERVICE_PREMISE |
| 3 | METER_NUMBER | VARCHAR(30) | NO | | Physical serial number |
| 4 | METER_TYPE | VARCHAR(20) | NO | | `ANALOG`, `DIGITAL`, `SMART_AMI` |
| 5 | INSTALL_DATE | DATE | NO | | |
| 6 | REMOVAL_DATE | DATE | YES | | |
| 7 | MULTIPLIER | NUMBER(10,4) | NO | | Default 1.0000 |
| 8 | KWH_DIAL_COUNT | NUMBER(3,0) | NO | | Number of register dials |
| 9 | MANUFACTURER | VARCHAR(50) | YES | | |
| 10 | MODEL_NUMBER | VARCHAR(50) | YES | | |
| 11 | ACTIVE_FLAG | VARCHAR(1) | NO | | `Y` / `N` |
| 12 | CREATED_AT | TIMESTAMP_NTZ | NO | | UTC |
| 13 | UPDATED_AT | TIMESTAMP_NTZ | NO | | **Watermark column** |

### RAW.MONTHLY_USAGE

| # | Column | Snowflake Type | Nullable | PK | Notes |
|---|--------|---------------|----------|----|-------|
| 1 | USAGE_ID | NUMBER(15,0) | NO | ✓ | |
| 2 | ENERGY_ACCOUNT_ID | NUMBER(15,0) | NO | | FK |
| 3 | PREMISE_ID | NUMBER(15,0) | NO | | FK |
| 4 | METER_ID | NUMBER(15,0) | NO | | FK |
| 5 | BILLING_MONTH | VARCHAR(7) | NO | | `YYYY-MM` |
| 6 | BILL_START_DATE | DATE | NO | | |
| 7 | BILL_END_DATE | DATE | NO | | |
| 8 | BILLING_DAYS | NUMBER(3,0) | NO | | |
| 9 | KWH_USAGE | NUMBER(12,3) | NO | | Non-negative |
| 10 | PEAK_DEMAND_KW | NUMBER(10,3) | YES | | Non-negative |
| 11 | PREV_METER_READING | NUMBER(12,3) | NO | | |
| 12 | CURR_METER_READING | NUMBER(12,3) | NO | | |
| 13 | RATE_PLAN | VARCHAR(20) | NO | | |
| 14 | ENERGY_CHARGE | NUMBER(12,2) | NO | | USD |
| 15 | TAX_AMOUNT | NUMBER(10,2) | NO | | USD |
| 16 | TOTAL_BILLED_AMOUNT | NUMBER(12,2) | NO | | USD |
| 17 | READ_TYPE | VARCHAR(1) | NO | | `A` / `E` |
| 18 | CORRECTION_FLAG | VARCHAR(1) | NO | | `N` / `Y` |
| 19 | ORIGINAL_USAGE_ID | NUMBER(15,0) | YES | | FK to original |
| 20 | CREATED_AT | TIMESTAMP_NTZ | NO | | UTC |
| 21 | UPDATED_AT | TIMESTAMP_NTZ | NO | | **Watermark column** |

---

## 4. Extraction Queries

All extraction is performed by the ETL using the `CDP_LOADER_ROLE` on the `CDP_DW` database. Queries follow the pattern:

```sql
-- Initial load (no watermark filter)
SELECT * FROM CDP_DW.RAW.<TABLE>
ORDER BY UPDATED_AT ASC, <PK> ASC;

-- Incremental load
SELECT * FROM CDP_DW.RAW.<TABLE>
WHERE (UPDATED_AT > ?)
   OR (UPDATED_AT = ? AND <PK> > ?)
ORDER BY UPDATED_AT ASC, <PK> ASC
LIMIT ?;
```

> Note: Snowflake does not enforce FK constraints. Referential integrity is validated during transformation.
