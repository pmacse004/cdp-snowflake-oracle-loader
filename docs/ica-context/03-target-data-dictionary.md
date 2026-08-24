# ICA Context Document 03 — Target Data Dictionary (Oracle)

**ICA Document ID:** ICA-03  
**Project:** CDP Snowflake to Oracle Data Loader  
**Version:** 1.0  
**Status:** Phase 1 — Approved  
**Last Updated:** 2025 (Phase 1)

> This document is the authoritative data dictionary for Oracle target tables. DDL is implemented by Flyway migrations in Phase 2.

---

## 1. Connection Details

| Property | Value |
|----------|-------|
| Database | Oracle Database Free 23c |
| Host | `localhost` (Docker) |
| Port | `1521` |
| PDB | `FREEPDB1` |
| Business schema | `CDP_APP` |
| Control schema | `CDP_CTL` |
| Batch schema | `CDP_BATCH` |
| Application user | `CDP_LOADER_USER` *(least privilege, to be created Phase 2)* |

---

## 2. CDP_APP Schema

### CDP_APP.REF_CODE_VALUE

| # | Column | Oracle Type | Nullable | PK | UK | Default | Notes |
|---|--------|------------|----------|----|----|---------|-------|
| 1 | CODE_ID | NUMBER(10) | NO | ✓ | | Sequence | Target surrogate |
| 2 | CODE_DOMAIN | VARCHAR2(50) | NO | | ✓ | | |
| 3 | CODE_VALUE | VARCHAR2(30) | NO | | ✓ | | Unique per domain |
| 4 | CODE_LABEL | VARCHAR2(100) | NO | | | | |
| 5 | SORT_ORDER | NUMBER(5) | YES | | | | |
| 6 | IS_ACTIVE | NUMBER(1) | NO | | | 1 | 1=active, 0=inactive |
| 7 | SOURCE_CODE_ID | NUMBER(10) | NO | | | | Snowflake CODE_ID |
| 8 | CREATED_AT | TIMESTAMP | NO | | | SYSTIMESTAMP | UTC |
| 9 | CREATED_BY | VARCHAR2(100) | NO | | | | Job name + run ID |
| 10 | UPDATED_AT | TIMESTAMP | NO | | | SYSTIMESTAMP | UTC |
| 11 | UPDATED_BY | VARCHAR2(100) | NO | | | | Job name + run ID |

### CDP_APP.CUSTOMER

| # | Column | Oracle Type | Nullable | PK | UK | Default | Notes |
|---|--------|------------|----------|----|----|---------|-------|
| 1 | CUSTOMER_ID | NUMBER(15) | NO | ✓ | | Sequence | Target surrogate |
| 2 | SOURCE_CUSTOMER_ID | NUMBER(15) | NO | | ✓ | | Snowflake CUSTOMER_ID |
| 3 | EXTERNAL_REF | VARCHAR2(30) | YES | | | | |
| 4 | FIRST_NAME | VARCHAR2(100) | NO | | | | Title-cased |
| 5 | LAST_NAME | VARCHAR2(100) | NO | | | | Title-cased |
| 6 | MIDDLE_NAME | VARCHAR2(50) | YES | | | | |
| 7 | FULL_NAME | VARCHAR2(255) | NO | | | | Derived: LAST + ', ' + FIRST |
| 8 | CUSTOMER_TYPE | VARCHAR2(20) | NO | | | | RESIDENTIAL / COMMERCIAL / INDUSTRIAL |
| 9 | ACCOUNT_STATUS | VARCHAR2(20) | NO | | | | Canonical: ACTIVE/INACTIVE/PENDING/CLOSED |
| 10 | IS_ACTIVE | NUMBER(1) | NO | | | 1 | Derived from ACCOUNT_STATUS |
| 11 | START_DATE | DATE | NO | | | | No time component |
| 12 | END_DATE | DATE | YES | | | | |
| 13 | PREFERRED_LANGUAGE | VARCHAR2(10) | YES | | | | ISO 639-1 |
| 14 | DELETED_AT | TIMESTAMP | YES | | | | UTC, set on soft delete |
| 15 | DELETION_REASON | VARCHAR2(200) | YES | | | | |
| 16 | CREATED_AT | TIMESTAMP | NO | | | SYSTIMESTAMP | Set on INSERT only |
| 17 | CREATED_BY | VARCHAR2(100) | NO | | | | |
| 18 | UPDATED_AT | TIMESTAMP | NO | | | SYSTIMESTAMP | |
| 19 | UPDATED_BY | VARCHAR2(100) | NO | | | | |

### CDP_APP.CUSTOMER_CONTACT

| # | Column | Oracle Type | Nullable | PK | UK | Notes |
|---|--------|------------|----------|----|----|-------|
| 1 | CONTACT_ID | NUMBER(15) | NO | ✓ | | Target surrogate |
| 2 | SOURCE_CONTACT_ID | NUMBER(15) | NO | | ✓ | Snowflake CONTACT_ID |
| 3 | CUSTOMER_ID | NUMBER(15) | NO | | | FK → CUSTOMER |
| 4 | CONTACT_TYPE | VARCHAR2(20) | NO | | | |
| 5 | ADDRESS_LINE1 | VARCHAR2(200) | YES | | | |
| 6 | ADDRESS_LINE2 | VARCHAR2(100) | YES | | | |
| 7 | CITY | VARCHAR2(100) | YES | | | |
| 8 | STATE_CODE | VARCHAR2(2) | YES | | | |
| 9 | ZIP_CODE | VARCHAR2(10) | YES | | | |
| 10 | EMAIL_ADDRESS | VARCHAR2(255) | YES | | | Lower-cased, RFC 5322 validated |
| 11 | PHONE_NUMBER | VARCHAR2(20) | YES | | | E.164 format |
| 12 | IS_PRIMARY | NUMBER(1) | NO | | | 0/1 |
| 13 | EFFECTIVE_DATE | DATE | NO | | | |
| 14 | EXPIRY_DATE | DATE | YES | | | |
| 15 | CREATED_AT | TIMESTAMP | NO | | | |
| 16 | CREATED_BY | VARCHAR2(100) | NO | | | |
| 17 | UPDATED_AT | TIMESTAMP | NO | | | |
| 18 | UPDATED_BY | VARCHAR2(100) | NO | | | |

### CDP_APP.ENERGY_ACCOUNT

| # | Column | Oracle Type | Nullable | PK | UK | Notes |
|---|--------|------------|----------|----|----|-------|
| 1 | ENERGY_ACCOUNT_ID | NUMBER(15) | NO | ✓ | | Target surrogate |
| 2 | SOURCE_ENERGY_ACCOUNT_ID | NUMBER(15) | NO | | ✓ | Snowflake ID |
| 3 | CUSTOMER_ID | NUMBER(15) | NO | | | FK → CUSTOMER (target ID) |
| 4 | ACCOUNT_NUMBER | VARCHAR2(20) | NO | | | |
| 5 | ACCOUNT_STATUS | VARCHAR2(20) | NO | | | Canonical |
| 6 | IS_ACTIVE | NUMBER(1) | NO | | | Derived |
| 7 | SERVICE_TYPE | VARCHAR2(30) | NO | | | |
| 8 | RATE_CLASS | VARCHAR2(20) | NO | | | |
| 9 | START_DATE | DATE | NO | | | |
| 10 | END_DATE | DATE | YES | | | |
| 11 | DELETED_AT | TIMESTAMP | YES | | | |
| 12 | DELETION_REASON | VARCHAR2(200) | YES | | | |
| 13 | CREATED_AT | TIMESTAMP | NO | | | |
| 14 | CREATED_BY | VARCHAR2(100) | NO | | | |
| 15 | UPDATED_AT | TIMESTAMP | NO | | | |
| 16 | UPDATED_BY | VARCHAR2(100) | NO | | | |

### CDP_APP.BILLING_ACCOUNT

| # | Column | Oracle Type | Nullable | PK | UK | Notes |
|---|--------|------------|----------|----|----|-------|
| 1 | BILLING_ACCOUNT_ID | NUMBER(15) | NO | ✓ | | Target surrogate |
| 2 | SOURCE_BILLING_ACCOUNT_ID | NUMBER(15) | NO | | ✓ | Snowflake ID |
| 3 | ENERGY_ACCOUNT_ID | NUMBER(15) | NO | | | FK → ENERGY_ACCOUNT (target) |
| 4 | BILLING_ACCOUNT_NUMBER | VARCHAR2(30) | NO | | | Sensitive business data |
| 5 | BILLING_CYCLE | VARCHAR2(10) | NO | | | |
| 6 | PAYMENT_METHOD | VARCHAR2(20) | YES | | | |
| 7 | PAPERLESS_BILLING | NUMBER(1) | NO | | | 0/1 |
| 8 | EFFECTIVE_DATE | DATE | NO | | | |
| 9 | EXPIRY_DATE | DATE | YES | | | |
| 10 | CREATED_AT | TIMESTAMP | NO | | | |
| 11 | CREATED_BY | VARCHAR2(100) | NO | | | |
| 12 | UPDATED_AT | TIMESTAMP | NO | | | |
| 13 | UPDATED_BY | VARCHAR2(100) | NO | | | |

### CDP_APP.SERVICE_PREMISE

| # | Column | Oracle Type | Nullable | PK | UK | Notes |
|---|--------|------------|----------|----|----|-------|
| 1 | PREMISE_ID | NUMBER(15) | NO | ✓ | | Target surrogate |
| 2 | SOURCE_PREMISE_ID | NUMBER(15) | NO | | ✓ | Snowflake ID |
| 3 | ENERGY_ACCOUNT_ID | NUMBER(15) | NO | | | FK → ENERGY_ACCOUNT (target) |
| 4 | PREMISE_TYPE | VARCHAR2(20) | NO | | | |
| 5 | SERVICE_ADDRESS1 | VARCHAR2(200) | NO | | | |
| 6 | SERVICE_ADDRESS2 | VARCHAR2(100) | YES | | | |
| 7 | CITY | VARCHAR2(100) | NO | | | |
| 8 | STATE_CODE | VARCHAR2(2) | NO | | | |
| 9 | ZIP_CODE | VARCHAR2(10) | NO | | | |
| 10 | COUNTY | VARCHAR2(100) | YES | | | |
| 11 | GPS_LATITUDE | NUMBER(10,7) | YES | | | |
| 12 | GPS_LONGITUDE | NUMBER(10,7) | YES | | | |
| 13 | DISTRIBUTION_ZONE | VARCHAR2(20) | YES | | | |
| 14 | IS_ACTIVE | NUMBER(1) | NO | | | Mapped from ACTIVE_FLAG Y/N |
| 15 | CREATED_AT | TIMESTAMP | NO | | | |
| 16 | CREATED_BY | VARCHAR2(100) | NO | | | |
| 17 | UPDATED_AT | TIMESTAMP | NO | | | |
| 18 | UPDATED_BY | VARCHAR2(100) | NO | | | |

### CDP_APP.METER

| # | Column | Oracle Type | Nullable | PK | UK | Notes |
|---|--------|------------|----------|----|----|-------|
| 1 | METER_ID | NUMBER(15) | NO | ✓ | | Target surrogate |
| 2 | SOURCE_METER_ID | NUMBER(15) | NO | | ✓ | Snowflake ID |
| 3 | PREMISE_ID | NUMBER(15) | NO | | | FK → SERVICE_PREMISE (target) |
| 4 | METER_NUMBER | VARCHAR2(30) | NO | | | |
| 5 | METER_TYPE | VARCHAR2(20) | NO | | | Canonical code |
| 6 | INSTALL_DATE | DATE | NO | | | |
| 7 | REMOVAL_DATE | DATE | YES | | | |
| 8 | MULTIPLIER | NUMBER(10,4) | NO | | | Default 1.0000 |
| 9 | KWH_DIAL_COUNT | NUMBER(3) | NO | | | |
| 10 | MANUFACTURER | VARCHAR2(50) | YES | | | |
| 11 | MODEL_NUMBER | VARCHAR2(50) | YES | | | |
| 12 | IS_ACTIVE | NUMBER(1) | NO | | | 0/1 |
| 13 | CREATED_AT | TIMESTAMP | NO | | | |
| 14 | CREATED_BY | VARCHAR2(100) | NO | | | |
| 15 | UPDATED_AT | TIMESTAMP | NO | | | |
| 16 | UPDATED_BY | VARCHAR2(100) | NO | | | |

### CDP_APP.MONTHLY_USAGE

| # | Column | Oracle Type | Nullable | PK | UK | Notes |
|---|--------|------------|----------|----|----|-------|
| 1 | USAGE_ID | NUMBER(15) | NO | ✓ | | Target surrogate |
| 2 | SOURCE_USAGE_ID | NUMBER(15) | NO | | ✓ | Snowflake USAGE_ID |
| 3 | ENERGY_ACCOUNT_ID | NUMBER(15) | NO | | | FK → ENERGY_ACCOUNT (target) |
| 4 | PREMISE_ID | NUMBER(15) | NO | | | FK → SERVICE_PREMISE (target) |
| 5 | METER_ID | NUMBER(15) | NO | | | FK → METER (target) |
| 6 | BILLING_MONTH | VARCHAR2(7) | NO | | ✓(biz) | `YYYY-MM` with ENERGY_ACCOUNT_ID |
| 7 | BILL_START_DATE | DATE | NO | | | |
| 8 | BILL_END_DATE | DATE | NO | | | |
| 9 | BILLING_DAYS | NUMBER(3) | NO | | | |
| 10 | KWH_USAGE | NUMBER(12,6) | NO | | | ≥ 0 |
| 11 | PEAK_DEMAND_KW | NUMBER(10,6) | YES | | | ≥ 0 if present |
| 12 | PREV_METER_READING | NUMBER(12,6) | NO | | | |
| 13 | CURR_METER_READING | NUMBER(12,6) | NO | | | |
| 14 | RATE_PLAN | VARCHAR2(20) | NO | | | |
| 15 | ENERGY_CHARGE | NUMBER(15,2) | NO | | | BigDecimal |
| 16 | TAX_AMOUNT | NUMBER(10,2) | NO | | | BigDecimal |
| 17 | TOTAL_BILLED_AMOUNT | NUMBER(15,2) | NO | | | From source |
| 18 | CALCULATED_BILL_TOTAL | NUMBER(15,2) | NO | | | ENERGY_CHARGE + TAX_AMOUNT |
| 19 | BILL_TOTAL_VARIANCE | NUMBER(10,2) | YES | | | Source − calculated |
| 20 | READ_TYPE | VARCHAR2(1) | NO | | | A / E |
| 21 | CORRECTION_FLAG | VARCHAR2(1) | NO | | | N / Y |
| 22 | ORIGINAL_SOURCE_USAGE_ID | NUMBER(15) | YES | | | |
| 23 | SOURCE_UPDATED_AT | TIMESTAMP | NO | | | For correction dedup |
| 24 | CREATED_AT | TIMESTAMP | NO | | | |
| 25 | CREATED_BY | VARCHAR2(100) | NO | | | |
| 26 | UPDATED_AT | TIMESTAMP | NO | | | |
| 27 | UPDATED_BY | VARCHAR2(100) | NO | | | |

---

## 3. CDP_CTL Schema — Summary

See [`docs/data-model/target-data-model.md`](../data-model/target-data-model.md) Section 3 for full ETL_WATERMARK, ETL_JOB_RUN, ETL_RECORD_ERROR, ETL_RECONCILIATION DDL.

---

## 4. Audit Column Convention

All tables include:

| Column | Type | Set on | Value |
|--------|------|--------|-------|
| CREATED_AT | TIMESTAMP | INSERT only | UTC timestamp |
| CREATED_BY | VARCHAR2(100) | INSERT only | `{JobName}/{RunId}` |
| UPDATED_AT | TIMESTAMP | INSERT + UPDATE | UTC timestamp |
| UPDATED_BY | VARCHAR2(100) | INSERT + UPDATE | `{JobName}/{RunId}` |
