# Source Data Model — Snowflake

**Document ID:** DM-001  
**Project:** CDP Snowflake to Oracle Data Loader  
**Version:** 1.0  
**Status:** Phase 1 — Approved  
**Last Updated:** 2025 (Phase 1)

> **All entities and data are synthetic.** No real utility customer data, proprietary schemas or confidential information is represented.

---

## 1. Snowflake Database Overview

| Property | Value |
|----------|-------|
| Account | `LJPNAFI-RW79936` |
| Account locator | `BM00315` |
| Region | AZURE_CENTRALINDIA |
| Database | `CDP_DW` (to be created in Phase 2) |
| Schemas | `RAW`, `CLEAN`, `REF` |
| Warehouse (ETL) | `CDP_LOADER_WH` (X-Small) |

### Schema Purposes

| Schema | Purpose |
|--------|---------|
| `RAW` | Raw ingestion tables; source records as-landed with `CREATED_AT` and `UPDATED_AT` system columns |
| `CLEAN` | Validated views over `RAW` tables; used as extraction source by the ETL |
| `REF` | Reference / code-value tables shared across entities |

---

## 2. Source Tables

### 2.1 REF.CODE_VALUE

Shared reference/code-value table.

| Column | Type | Nullable | Description |
|--------|------|----------|-------------|
| `CODE_ID` | NUMBER(10) | NO | Surrogate PK |
| `CODE_DOMAIN` | VARCHAR(50) | NO | Category, e.g., `ACCT_STATUS`, `METER_TYPE` |
| `CODE_VALUE` | VARCHAR(30) | NO | Source code value |
| `CODE_LABEL` | VARCHAR(100) | NO | Human-readable label |
| `SORT_ORDER` | NUMBER(5) | YES | Display order |
| `IS_ACTIVE` | VARCHAR(1) | NO | `Y` / `N` |
| `CREATED_AT` | TIMESTAMP_NTZ | NO | UTC creation timestamp |
| `UPDATED_AT` | TIMESTAMP_NTZ | NO | UTC last-update timestamp |

**Unique constraint:** `(CODE_DOMAIN, CODE_VALUE)`

---

### 2.2 RAW.CUSTOMER

Master customer record.

| Column | Type | Nullable | Description |
|--------|------|----------|-------------|
| `CUSTOMER_ID` | NUMBER(15) | NO | Synthetic surrogate PK (stable) |
| `EXTERNAL_REF` | VARCHAR(30) | YES | Optional upstream reference |
| `FIRST_NAME` | VARCHAR(100) | NO | PII — customer first name |
| `LAST_NAME` | VARCHAR(100) | NO | PII — customer last name |
| `MIDDLE_NAME` | VARCHAR(50) | YES | PII — middle name |
| `CUSTOMER_TYPE` | VARCHAR(20) | NO | `RESIDENTIAL` / `COMMERCIAL` / `INDUSTRIAL` |
| `ACCOUNT_STATUS` | VARCHAR(20) | NO | Source status code — see REF.CODE_VALUE domain `ACCT_STATUS` |
| `START_DATE` | DATE | NO | Customer relationship start date |
| `END_DATE` | DATE | YES | Customer relationship end date (null = active) |
| `PREFERRED_LANGUAGE` | VARCHAR(10) | YES | ISO 639-1 language code |
| `CREATED_AT` | TIMESTAMP_NTZ | NO | UTC creation timestamp |
| `UPDATED_AT` | TIMESTAMP_NTZ | NO | UTC last-update timestamp |
| `DELETED_FLAG` | VARCHAR(1) | NO | `N` = active, `Y` = soft deleted |
| `DELETED_AT` | TIMESTAMP_NTZ | YES | UTC soft-delete timestamp |

---

### 2.3 RAW.CUSTOMER_CONTACT

Customer contact information. One-to-many with CUSTOMER.

| Column | Type | Nullable | Description |
|--------|------|----------|-------------|
| `CONTACT_ID` | NUMBER(15) | NO | Surrogate PK |
| `CUSTOMER_ID` | NUMBER(15) | NO | FK → CUSTOMER.CUSTOMER_ID |
| `CONTACT_TYPE` | VARCHAR(20) | NO | `MAILING`, `SERVICE`, `BILLING`, `EMAIL`, `PHONE` |
| `ADDRESS_LINE1` | VARCHAR(200) | YES | PII — street address line 1 |
| `ADDRESS_LINE2` | VARCHAR(100) | YES | PII — street address line 2 |
| `CITY` | VARCHAR(100) | YES | PII — city |
| `STATE_CODE` | VARCHAR(2) | YES | US state abbreviation |
| `ZIP_CODE` | VARCHAR(10) | YES | US ZIP / ZIP+4 |
| `EMAIL_ADDRESS` | VARCHAR(255) | YES | PII — email address |
| `PHONE_NUMBER` | VARCHAR(30) | YES | PII — phone number (various formats) |
| `IS_PRIMARY` | VARCHAR(1) | NO | `Y` = primary contact of this type |
| `EFFECTIVE_DATE` | DATE | NO | Contact validity start |
| `EXPIRY_DATE` | DATE | YES | Contact validity end (null = current) |
| `CREATED_AT` | TIMESTAMP_NTZ | NO | UTC |
| `UPDATED_AT` | TIMESTAMP_NTZ | NO | UTC |

---

### 2.4 RAW.ENERGY_ACCOUNT

Energy / service account. Each account belongs to one customer.

| Column | Type | Nullable | Description |
|--------|------|----------|-------------|
| `ENERGY_ACCOUNT_ID` | NUMBER(15) | NO | Surrogate PK |
| `CUSTOMER_ID` | NUMBER(15) | NO | FK → CUSTOMER.CUSTOMER_ID |
| `ACCOUNT_NUMBER` | VARCHAR(20) | NO | Business-facing account number |
| `ACCOUNT_STATUS` | VARCHAR(20) | NO | `ACTIVE`, `INACTIVE`, `PENDING`, `CLOSED` |
| `SERVICE_TYPE` | VARCHAR(30) | NO | `ELECTRIC`, `GAS`, `SOLAR` (demo uses ELECTRIC) |
| `RATE_CLASS` | VARCHAR(20) | NO | Tariff/rate class code |
| `START_DATE` | DATE | NO | Account open date |
| `END_DATE` | DATE | YES | Account close date |
| `CREATED_AT` | TIMESTAMP_NTZ | NO | UTC |
| `UPDATED_AT` | TIMESTAMP_NTZ | NO | UTC |
| `DELETED_FLAG` | VARCHAR(1) | NO | Soft-delete flag |
| `DELETED_AT` | TIMESTAMP_NTZ | YES | Soft-delete timestamp |

---

### 2.5 RAW.BILLING_ACCOUNT

Billing account (financial relationship). Linked to one energy account.

| Column | Type | Nullable | Description |
|--------|------|----------|-------------|
| `BILLING_ACCOUNT_ID` | NUMBER(15) | NO | Surrogate PK |
| `ENERGY_ACCOUNT_ID` | NUMBER(15) | NO | FK → ENERGY_ACCOUNT |
| `BILLING_ACCOUNT_NUMBER` | VARCHAR(30) | NO | Sensitive business — billing account number |
| `BILLING_CYCLE` | VARCHAR(10) | NO | `MONTHLY` / `BIMONTHLY` |
| `PAYMENT_METHOD` | VARCHAR(20) | YES | `AUTO_PAY`, `MAIL`, `ONLINE` |
| `PAPERLESS_BILLING` | VARCHAR(1) | NO | `Y` / `N` |
| `EFFECTIVE_DATE` | DATE | NO | Effective from |
| `EXPIRY_DATE` | DATE | YES | Effective to (null = current) |
| `CREATED_AT` | TIMESTAMP_NTZ | NO | UTC |
| `UPDATED_AT` | TIMESTAMP_NTZ | NO | UTC |

---

### 2.6 RAW.SERVICE_PREMISE

Physical service location.

| Column | Type | Nullable | Description |
|--------|------|----------|-------------|
| `PREMISE_ID` | NUMBER(15) | NO | Surrogate PK |
| `ENERGY_ACCOUNT_ID` | NUMBER(15) | NO | FK → ENERGY_ACCOUNT |
| `PREMISE_TYPE` | VARCHAR(20) | NO | `RESIDENTIAL`, `COMMERCIAL`, `INDUSTRIAL` |
| `SERVICE_ADDRESS1` | VARCHAR(200) | NO | Street address |
| `SERVICE_ADDRESS2` | VARCHAR(100) | YES | Suite / apt |
| `CITY` | VARCHAR(100) | NO | City |
| `STATE_CODE` | VARCHAR(2) | NO | US state |
| `ZIP_CODE` | VARCHAR(10) | NO | ZIP |
| `COUNTY` | VARCHAR(100) | YES | County |
| `GPS_LATITUDE` | NUMBER(10,7) | YES | Lat (decimal degrees) |
| `GPS_LONGITUDE` | NUMBER(10,7) | YES | Long (decimal degrees) |
| `DISTRIBUTION_ZONE` | VARCHAR(20) | YES | Grid zone code |
| `ACTIVE_FLAG` | VARCHAR(1) | NO | `Y` / `N` |
| `CREATED_AT` | TIMESTAMP_NTZ | NO | UTC |
| `UPDATED_AT` | TIMESTAMP_NTZ | NO | UTC |

---

### 2.7 RAW.METER

Meter installed at a service premise.

| Column | Type | Nullable | Description |
|--------|------|----------|-------------|
| `METER_ID` | NUMBER(15) | NO | Surrogate PK |
| `PREMISE_ID` | NUMBER(15) | NO | FK → SERVICE_PREMISE |
| `METER_NUMBER` | VARCHAR(30) | NO | Physical meter serial number |
| `METER_TYPE` | VARCHAR(20) | NO | `ANALOG`, `DIGITAL`, `SMART_AMI` |
| `INSTALL_DATE` | DATE | NO | Installation date |
| `REMOVAL_DATE` | DATE | YES | Removal date (null = installed) |
| `MULTIPLIER` | NUMBER(10,4) | NO | Meter multiplier (default 1.0000) |
| `KWH_DIAL_COUNT` | NUMBER(3) | NO | Number of KWH register dials |
| `MANUFACTURER` | VARCHAR(50) | YES | Meter manufacturer |
| `MODEL_NUMBER` | VARCHAR(50) | YES | Meter model |
| `ACTIVE_FLAG` | VARCHAR(1) | NO | `Y` / `N` |
| `CREATED_AT` | TIMESTAMP_NTZ | NO | UTC |
| `UPDATED_AT` | TIMESTAMP_NTZ | NO | UTC |

---

### 2.8 RAW.MONTHLY_USAGE

Monthly electricity usage and billing record.

| Column | Type | Nullable | Description |
|--------|------|----------|-------------|
| `USAGE_ID` | NUMBER(15) | NO | Surrogate PK |
| `ENERGY_ACCOUNT_ID` | NUMBER(15) | NO | FK → ENERGY_ACCOUNT |
| `PREMISE_ID` | NUMBER(15) | NO | FK → SERVICE_PREMISE |
| `METER_ID` | NUMBER(15) | NO | FK → METER |
| `BILLING_MONTH` | VARCHAR(7) | NO | `YYYY-MM` format |
| `BILL_START_DATE` | DATE | NO | Billing period start |
| `BILL_END_DATE` | DATE | NO | Billing period end |
| `BILLING_DAYS` | NUMBER(3) | NO | Number of days in billing period |
| `KWH_USAGE` | NUMBER(12,3) | NO | Energy consumption in kWh |
| `PEAK_DEMAND_KW` | NUMBER(10,3) | YES | Peak demand in kW |
| `PREV_METER_READING` | NUMBER(12,3) | NO | Previous meter reading |
| `CURR_METER_READING` | NUMBER(12,3) | NO | Current meter reading |
| `RATE_PLAN` | VARCHAR(20) | NO | Applied rate plan code |
| `ENERGY_CHARGE` | NUMBER(12,2) | NO | Energy charge in USD |
| `TAX_AMOUNT` | NUMBER(10,2) | NO | Tax in USD |
| `TOTAL_BILLED_AMOUNT` | NUMBER(12,2) | NO | Total bill in USD |
| `READ_TYPE` | VARCHAR(1) | NO | `A` = actual, `E` = estimated |
| `CORRECTION_FLAG` | VARCHAR(1) | NO | `N` = original, `Y` = corrected |
| `ORIGINAL_USAGE_ID` | NUMBER(15) | YES | FK to original USAGE_ID if correction |
| `CREATED_AT` | TIMESTAMP_NTZ | NO | UTC |
| `UPDATED_AT` | TIMESTAMP_NTZ | NO | UTC |

---

## 3. Source Volumes (Synthetic Target)

| Entity | Initial rows | Daily delta | Monthly delta |
|--------|-------------|-------------|---------------|
| CODE_VALUE | ~200 | ~5 | — |
| CUSTOMER | ~10,000 | ~300 | — |
| CUSTOMER_CONTACT | ~12,000 | ~200 | — |
| ENERGY_ACCOUNT | ~11,000 | ~200 | — |
| BILLING_ACCOUNT | ~11,000 | ~150 | — |
| SERVICE_PREMISE | ~11,000 | ~100 | — |
| METER | ~11,500 | ~50 | — |
| MONTHLY_USAGE | ~110,000 (12 months) | — | ~1,000 |

---

## 4. Source Constraints and Indexes (Snowflake)

Snowflake does not enforce traditional FK constraints at query time, but logical relationships are documented:

| Relationship | Cardinality |
|-------------|-------------|
| CUSTOMER → CUSTOMER_CONTACT | 1:N |
| CUSTOMER → ENERGY_ACCOUNT | 1:N |
| ENERGY_ACCOUNT → BILLING_ACCOUNT | 1:1 (current) |
| ENERGY_ACCOUNT → SERVICE_PREMISE | 1:1 (current) |
| SERVICE_PREMISE → METER | 1:N (one active at a time) |
| ENERGY_ACCOUNT → MONTHLY_USAGE | 1:N |
| METER → MONTHLY_USAGE | 1:N |

All source tables include a clustered micro-partition on `(UPDATED_AT)` to support watermark-based incremental extraction.
