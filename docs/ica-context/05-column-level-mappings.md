# ICA Context Document 05 — Column-Level Mappings

**ICA Document ID:** ICA-05  
**Project:** CDP Snowflake to Oracle Data Loader  
**Version:** 1.0  
**Status:** Phase 1 — Approved  
**Last Updated:** 2025 (Phase 1)

> This is the master column-level mapping catalogue. Every mapping has a stable unique ID (CM-NNN).  
> The machine-readable version is at `docs/ica-context/mapping-catalogue.yaml`.  
> Load frequency codes: **I** = Initial only, **D** = Daily incremental, **M** = Monthly usage, **I+D** = Initial and daily.

---

## Entity: REF_CODE_VALUE (EM-01)

> **Phase 3 audit amendment (Issue #1/12):** Added CM-004a for `ATTRIBUTES` VARIANT column. `CODE_LABEL` (CM-004) is a human-readable label ONLY — never contains JSON. Rate parameters are sourced from `ATTRIBUTES` (CM-004a) for RATE_PLAN rows. Column names corrected to match actual DDL (DOMAIN, CODE, CODE_VALUE_ID).

| Map ID | Source Table | Source Column | Src Type | Target Table | Target Column | Tgt Type | Transform Rule | Validation Rule | Default | Mandatory | Biz Key | Freq |
|--------|-------------|--------------|----------|-------------|--------------|----------|----------------|----------------|---------|-----------|---------|------|
| CM-001 | REF.CODE_VALUE | CODE_VALUE_ID | NUMBER(10) | REF_CODE_VALUE | SOURCE_CODE_ID | NUMBER(10) | Direct | VR-CODE-001 | — | Y | — | I+D |
| CM-002 | REF.CODE_VALUE | DOMAIN | VARCHAR(50) | REF_CODE_VALUE | CODE_DOMAIN | VARCHAR2(50) | Direct | VR-CODE-002 | — | Y | Y | I+D |
| CM-003 | REF.CODE_VALUE | CODE | VARCHAR(30) | REF_CODE_VALUE | CODE_VALUE | VARCHAR2(30) | Direct | VR-CODE-003 | — | Y | Y | I+D |
| CM-004 | REF.CODE_VALUE | CODE_LABEL | VARCHAR(500) | REF_CODE_VALUE | CODE_LABEL | VARCHAR2(500) | Direct — human-readable text only; never JSON | VR-CODE-004 | — | Y | N | I+D |
| CM-004a | REF.CODE_VALUE | ATTRIBUTES | VARIANT | REF_CODE_VALUE | ATTRIBUTES_JSON | CLOB | Extract and pass through as JSON string for RATE_PLAN rows; NULL for all other domains | VR-CODE-005: NULL allowed for non-RATE_PLAN rows; RATE_PLAN rows must have non-null fixed, energy, tax keys | NULL | N | N | I+D |
| CM-005 | REF.CODE_VALUE | DISPLAY_ORDER | NUMBER(5) | REF_CODE_VALUE | SORT_ORDER | NUMBER(5) | Direct | None | NULL | N | N | I+D |
| CM-006 | REF.CODE_VALUE | IS_ACTIVE | BOOLEAN | REF_CODE_VALUE | IS_ACTIVE | NUMBER(1) | TR-01: TRUE→1, FALSE→0 | VR-FLAG-001 | 1 | Y | N | I+D |
| CM-007 | — | — | — | REF_CODE_VALUE | CODE_ID | NUMBER(10) | Sequence: SEQ_REF_CODE_VALUE.NEXTVAL (INSERT only) | — | Sequence | Y | N | I+D |
| CM-008 | — | — | — | REF_CODE_VALUE | CREATED_AT | TIMESTAMP | TR-AUD-01: SYSTIMESTAMP (INSERT only) | — | SYSTIMESTAMP | Y | N | I+D |
| CM-009 | — | — | — | REF_CODE_VALUE | CREATED_BY | VARCHAR2(100) | TR-AUD-02: '{JobName}/{RunId}' | — | — | Y | N | I+D |
| CM-010 | — | — | — | REF_CODE_VALUE | UPDATED_AT | TIMESTAMP | TR-AUD-03: SYSTIMESTAMP | — | SYSTIMESTAMP | Y | N | I+D |
| CM-011 | — | — | — | REF_CODE_VALUE | UPDATED_BY | VARCHAR2(100) | TR-AUD-04: '{JobName}/{RunId}' | — | — | Y | N | I+D |

---

## Entity: CUSTOMER (EM-02)

| Map ID | Source Table | Source Column | Src Type | Target Table | Target Column | Tgt Type | Transform Rule | Validation Rule | Default | Mandatory | Biz Key | Freq |
|--------|-------------|--------------|----------|-------------|--------------|----------|----------------|----------------|---------|-----------|---------|------|
| CM-020 | RAW.CUSTOMER | CUSTOMER_ID | NUMBER(15) | CUSTOMER | SOURCE_CUSTOMER_ID | NUMBER(15) | Direct | VR-CUST-001 | — | Y | Y | I+D |
| CM-021 | RAW.CUSTOMER | EXTERNAL_REF | VARCHAR(30) | CUSTOMER | EXTERNAL_REF | VARCHAR2(30) | Direct | None | NULL | N | N | I+D |
| CM-022 | RAW.CUSTOMER | FIRST_NAME | VARCHAR(100) | CUSTOMER | FIRST_NAME | VARCHAR2(100) | TR-02: TitleCase | VR-CUST-002 | — | Y | N | I+D |
| CM-023 | RAW.CUSTOMER | LAST_NAME | VARCHAR(100) | CUSTOMER | LAST_NAME | VARCHAR2(100) | TR-02: TitleCase | VR-CUST-003 | — | Y | N | I+D |
| CM-024 | RAW.CUSTOMER | MIDDLE_NAME | VARCHAR(50) | CUSTOMER | MIDDLE_NAME | VARCHAR2(50) | TR-02: TitleCase | None | NULL | N | N | I+D |
| CM-025 | RAW.CUSTOMER | FIRST_NAME + LAST_NAME | VARCHAR | CUSTOMER | FULL_NAME | VARCHAR2(255) | TR-03: LAST_NAME + ', ' + FIRST_NAME | VR-CUST-004 | — | Y | N | I+D |
| CM-026 | RAW.CUSTOMER | CUSTOMER_TYPE | VARCHAR(20) | CUSTOMER | CUSTOMER_TYPE | VARCHAR2(20) | TR-08: Uppercase trim | VR-CUST-005 | — | Y | N | I+D |
| CM-027 | RAW.CUSTOMER | ACCOUNT_STATUS | VARCHAR(20) | CUSTOMER | ACCOUNT_STATUS | VARCHAR2(20) | TR-05: Code translate | VR-CUST-006 | — | Y | N | I+D |
| CM-028 | RAW.CUSTOMER | ACCOUNT_STATUS | VARCHAR(20) | CUSTOMER | IS_ACTIVE | NUMBER(1) | TR-04: ACTIVE→1, else 0 | — | 1 | Y | N | I+D |
| CM-029 | RAW.CUSTOMER | START_DATE | DATE | CUSTOMER | START_DATE | DATE | TR-DATE-01: Date only | VR-DATE-001 | — | Y | N | I+D |
| CM-030 | RAW.CUSTOMER | END_DATE | DATE | CUSTOMER | END_DATE | DATE | TR-DATE-01 | None | NULL | N | N | I+D |
| CM-031 | RAW.CUSTOMER | PREFERRED_LANGUAGE | VARCHAR(10) | CUSTOMER | PREFERRED_LANGUAGE | VARCHAR2(10) | Lowercase trim | None | NULL | N | N | I+D |
| CM-032 | RAW.CUSTOMER | DELETED_AT | TIMESTAMP_NTZ | CUSTOMER | DELETED_AT | TIMESTAMP | TR-TS-01: UTC normalize | None | NULL | N | N | I+D |
| CM-033 | RAW.CUSTOMER | DELETED_FLAG | VARCHAR(1) | CUSTOMER | DELETION_REASON | VARCHAR2(200) | TR-06: if Y then 'SOURCE_DELETED' | — | NULL | N | N | I+D |
| CM-034 | — | — | — | CUSTOMER | CUSTOMER_ID | NUMBER(15) | Sequence (INSERT only) | — | Sequence | Y | N | I+D |
| CM-035 | — | — | — | CUSTOMER | CREATED_AT | TIMESTAMP | TR-AUD-01 | — | SYSTIMESTAMP | Y | N | I+D |
| CM-036 | — | — | — | CUSTOMER | CREATED_BY | VARCHAR2(100) | TR-AUD-02 | — | — | Y | N | I+D |
| CM-037 | — | — | — | CUSTOMER | UPDATED_AT | TIMESTAMP | TR-AUD-03 | — | SYSTIMESTAMP | Y | N | I+D |
| CM-038 | — | — | — | CUSTOMER | UPDATED_BY | VARCHAR2(100) | TR-AUD-04 | — | — | Y | N | I+D |

---

## Entity: CUSTOMER_CONTACT (EM-03)

| Map ID | Source Table | Source Column | Src Type | Target Table | Target Column | Tgt Type | Transform Rule | Validation Rule | Default | Mandatory | Biz Key | Freq |
|--------|-------------|--------------|----------|-------------|--------------|----------|----------------|----------------|---------|-----------|---------|------|
| CM-040 | RAW.CUSTOMER_CONTACT | CONTACT_ID | NUMBER(15) | CUSTOMER_CONTACT | SOURCE_CONTACT_ID | NUMBER(15) | Direct | VR-CONT-001 | — | Y | Y | I+D |
| CM-041 | RAW.CUSTOMER_CONTACT | CUSTOMER_ID | NUMBER(15) | CUSTOMER_CONTACT | CUSTOMER_ID | NUMBER(15) | TR-FK-01: Lookup CUSTOMER by SOURCE_CUSTOMER_ID | VR-FK-001 | — | Y | N | I+D |
| CM-042 | RAW.CUSTOMER_CONTACT | CONTACT_TYPE | VARCHAR(20) | CUSTOMER_CONTACT | CONTACT_TYPE | VARCHAR2(20) | Uppercase trim | VR-CONT-002 | — | Y | N | I+D |
| CM-043 | RAW.CUSTOMER_CONTACT | ADDRESS_LINE1 | VARCHAR(200) | CUSTOMER_CONTACT | ADDRESS_LINE1 | VARCHAR2(200) | Direct | None | NULL | N | N | I+D |
| CM-044 | RAW.CUSTOMER_CONTACT | ADDRESS_LINE2 | VARCHAR(100) | CUSTOMER_CONTACT | ADDRESS_LINE2 | VARCHAR2(100) | Direct | None | NULL | N | N | I+D |
| CM-045 | RAW.CUSTOMER_CONTACT | CITY | VARCHAR(100) | CUSTOMER_CONTACT | CITY | VARCHAR2(100) | TR-02: TitleCase | None | NULL | N | N | I+D |
| CM-046 | RAW.CUSTOMER_CONTACT | STATE_CODE | VARCHAR(2) | CUSTOMER_CONTACT | STATE_CODE | VARCHAR2(2) | Uppercase trim | VR-CONT-003 | NULL | N | N | I+D |
| CM-047 | RAW.CUSTOMER_CONTACT | ZIP_CODE | VARCHAR(10) | CUSTOMER_CONTACT | ZIP_CODE | VARCHAR2(10) | Direct | VR-CONT-004 | NULL | N | N | I+D |
| CM-048 | RAW.CUSTOMER_CONTACT | EMAIL_ADDRESS | VARCHAR(255) | CUSTOMER_CONTACT | EMAIL_ADDRESS | VARCHAR2(255) | TR-06: Lowercase | VR-EMAIL-001 | NULL | N | N | I+D |
| CM-049 | RAW.CUSTOMER_CONTACT | PHONE_NUMBER | VARCHAR(30) | CUSTOMER_CONTACT | PHONE_NUMBER | VARCHAR2(20) | TR-07: E.164 normalize | VR-PHONE-001 | NULL | N | N | I+D |
| CM-050 | RAW.CUSTOMER_CONTACT | IS_PRIMARY | VARCHAR(1) | CUSTOMER_CONTACT | IS_PRIMARY | NUMBER(1) | TR-01: Y→1, N→0 | VR-FLAG-001 | 0 | Y | N | I+D |
| CM-051 | RAW.CUSTOMER_CONTACT | EFFECTIVE_DATE | DATE | CUSTOMER_CONTACT | EFFECTIVE_DATE | DATE | TR-DATE-01 | VR-DATE-001 | — | Y | N | I+D |
| CM-052 | RAW.CUSTOMER_CONTACT | EXPIRY_DATE | DATE | CUSTOMER_CONTACT | EXPIRY_DATE | DATE | TR-DATE-01 | None | NULL | N | N | I+D |

---

## Entity: ENERGY_ACCOUNT (EM-04)

| Map ID | Source Table | Source Column | Src Type | Target Table | Target Column | Tgt Type | Transform Rule | Validation Rule | Default | Mandatory | Biz Key | Freq |
|--------|-------------|--------------|----------|-------------|--------------|----------|----------------|----------------|---------|-----------|---------|------|
| CM-060 | RAW.ENERGY_ACCOUNT | ENERGY_ACCOUNT_ID | NUMBER(15) | ENERGY_ACCOUNT | SOURCE_ENERGY_ACCOUNT_ID | NUMBER(15) | Direct | VR-EA-001 | — | Y | Y | I+D |
| CM-061 | RAW.ENERGY_ACCOUNT | CUSTOMER_ID | NUMBER(15) | ENERGY_ACCOUNT | CUSTOMER_ID | NUMBER(15) | TR-FK-01: Lookup | VR-FK-001 | — | Y | N | I+D |
| CM-062 | RAW.ENERGY_ACCOUNT | ACCOUNT_NUMBER | VARCHAR(20) | ENERGY_ACCOUNT | ACCOUNT_NUMBER | VARCHAR2(20) | Direct | VR-EA-002 | — | Y | N | I+D |
| CM-063 | RAW.ENERGY_ACCOUNT | ACCOUNT_STATUS | VARCHAR(20) | ENERGY_ACCOUNT | ACCOUNT_STATUS | VARCHAR2(20) | TR-05: Code translate | VR-EA-003 | — | Y | N | I+D |
| CM-064 | RAW.ENERGY_ACCOUNT | ACCOUNT_STATUS | VARCHAR(20) | ENERGY_ACCOUNT | IS_ACTIVE | NUMBER(1) | TR-04 | — | 1 | Y | N | I+D |
| CM-065 | RAW.ENERGY_ACCOUNT | SERVICE_TYPE | VARCHAR(30) | ENERGY_ACCOUNT | SERVICE_TYPE | VARCHAR2(30) | Uppercase trim | VR-EA-004 | — | Y | N | I+D |
| CM-066 | RAW.ENERGY_ACCOUNT | RATE_CLASS | VARCHAR(20) | ENERGY_ACCOUNT | RATE_CLASS | VARCHAR2(20) | Uppercase trim | VR-EA-005 | — | Y | N | I+D |
| CM-067 | RAW.ENERGY_ACCOUNT | START_DATE | DATE | ENERGY_ACCOUNT | START_DATE | DATE | TR-DATE-01 | VR-DATE-001 | — | Y | N | I+D |
| CM-068 | RAW.ENERGY_ACCOUNT | END_DATE | DATE | ENERGY_ACCOUNT | END_DATE | DATE | TR-DATE-01 | None | NULL | N | N | I+D |
| CM-069 | RAW.ENERGY_ACCOUNT | DELETED_FLAG | VARCHAR(1) | ENERGY_ACCOUNT | IS_ACTIVE | NUMBER(1) | TR-09: if Y then 0 | — | — | — | N | I+D |
| CM-070 | RAW.ENERGY_ACCOUNT | DELETED_AT | TIMESTAMP_NTZ | ENERGY_ACCOUNT | DELETED_AT | TIMESTAMP | TR-TS-01 | None | NULL | N | N | I+D |

---

## Entity: BILLING_ACCOUNT (EM-05)

| Map ID | Source Table | Source Column | Src Type | Target Table | Target Column | Tgt Type | Transform Rule | Validation Rule | Default | Mandatory | Biz Key | Freq |
|--------|-------------|--------------|----------|-------------|--------------|----------|----------------|----------------|---------|-----------|---------|------|
| CM-080 | RAW.BILLING_ACCOUNT | BILLING_ACCOUNT_ID | NUMBER(15) | BILLING_ACCOUNT | SOURCE_BILLING_ACCOUNT_ID | NUMBER(15) | Direct | — | — | Y | Y | I+D |
| CM-081 | RAW.BILLING_ACCOUNT | ENERGY_ACCOUNT_ID | NUMBER(15) | BILLING_ACCOUNT | ENERGY_ACCOUNT_ID | NUMBER(15) | TR-FK-01: Lookup | VR-FK-001 | — | Y | N | I+D |
| CM-082 | RAW.BILLING_ACCOUNT | BILLING_ACCOUNT_NUMBER | VARCHAR(30) | BILLING_ACCOUNT | BILLING_ACCOUNT_NUMBER | VARCHAR2(30) | Direct | VR-BA-001 | — | Y | N | I+D |
| CM-083 | RAW.BILLING_ACCOUNT | BILLING_CYCLE | VARCHAR(10) | BILLING_ACCOUNT | BILLING_CYCLE | VARCHAR2(10) | Uppercase trim | VR-BA-002 | — | Y | N | I+D |
| CM-084 | RAW.BILLING_ACCOUNT | PAYMENT_METHOD | VARCHAR(20) | BILLING_ACCOUNT | PAYMENT_METHOD | VARCHAR2(20) | Uppercase trim | None | NULL | N | N | I+D |
| CM-085 | RAW.BILLING_ACCOUNT | PAPERLESS_BILLING | VARCHAR(1) | BILLING_ACCOUNT | PAPERLESS_BILLING | NUMBER(1) | TR-01: Y→1, N→0 | VR-FLAG-001 | 0 | Y | N | I+D |
| CM-086 | RAW.BILLING_ACCOUNT | EFFECTIVE_DATE | DATE | BILLING_ACCOUNT | EFFECTIVE_DATE | DATE | TR-DATE-01 | VR-DATE-001 | — | Y | N | I+D |
| CM-087 | RAW.BILLING_ACCOUNT | EXPIRY_DATE | DATE | BILLING_ACCOUNT | EXPIRY_DATE | DATE | TR-DATE-01 | None | NULL | N | N | I+D |

---

## Entity: SERVICE_PREMISE (EM-06)

| Map ID | Source Table | Source Column | Src Type | Target Table | Target Column | Tgt Type | Transform Rule | Validation Rule | Default | Mandatory | Biz Key | Freq |
|--------|-------------|--------------|----------|-------------|--------------|----------|----------------|----------------|---------|-----------|---------|------|
| CM-090 | RAW.SERVICE_PREMISE | PREMISE_ID | NUMBER(15) | SERVICE_PREMISE | SOURCE_PREMISE_ID | NUMBER(15) | Direct | — | — | Y | Y | I+D |
| CM-091 | RAW.SERVICE_PREMISE | ENERGY_ACCOUNT_ID | NUMBER(15) | SERVICE_PREMISE | ENERGY_ACCOUNT_ID | NUMBER(15) | TR-FK-01 | VR-FK-001 | — | Y | N | I+D |
| CM-092 | RAW.SERVICE_PREMISE | PREMISE_TYPE | VARCHAR(20) | SERVICE_PREMISE | PREMISE_TYPE | VARCHAR2(20) | Uppercase trim | VR-PREM-001 | — | Y | N | I+D |
| CM-093 | RAW.SERVICE_PREMISE | SERVICE_ADDRESS1 | VARCHAR(200) | SERVICE_PREMISE | SERVICE_ADDRESS1 | VARCHAR2(200) | Direct | VR-PREM-002 | — | Y | N | I+D |
| CM-094 | RAW.SERVICE_PREMISE | SERVICE_ADDRESS2 | VARCHAR(100) | SERVICE_PREMISE | SERVICE_ADDRESS2 | VARCHAR2(100) | Direct | None | NULL | N | N | I+D |
| CM-095 | RAW.SERVICE_PREMISE | CITY | VARCHAR(100) | SERVICE_PREMISE | CITY | VARCHAR2(100) | TR-02: TitleCase | VR-PREM-003 | — | Y | N | I+D |
| CM-096 | RAW.SERVICE_PREMISE | STATE_CODE | VARCHAR(2) | SERVICE_PREMISE | STATE_CODE | VARCHAR2(2) | Uppercase trim | VR-PREM-004 | — | Y | N | I+D |
| CM-097 | RAW.SERVICE_PREMISE | ZIP_CODE | VARCHAR(10) | SERVICE_PREMISE | ZIP_CODE | VARCHAR2(10) | Direct | VR-PREM-005 | — | Y | N | I+D |
| CM-098 | RAW.SERVICE_PREMISE | COUNTY | VARCHAR(100) | SERVICE_PREMISE | COUNTY | VARCHAR2(100) | TR-02: TitleCase | None | NULL | N | N | I+D |
| CM-099 | RAW.SERVICE_PREMISE | GPS_LATITUDE | NUMBER(10,7) | SERVICE_PREMISE | GPS_LATITUDE | NUMBER(10,7) | Direct | VR-PREM-006 | NULL | N | N | I+D |
| CM-100 | RAW.SERVICE_PREMISE | GPS_LONGITUDE | NUMBER(10,7) | SERVICE_PREMISE | GPS_LONGITUDE | NUMBER(10,7) | Direct | VR-PREM-006 | NULL | N | N | I+D |
| CM-101 | RAW.SERVICE_PREMISE | DISTRIBUTION_ZONE | VARCHAR(20) | SERVICE_PREMISE | DISTRIBUTION_ZONE | VARCHAR2(20) | Uppercase trim | None | NULL | N | N | I+D |
| CM-102 | RAW.SERVICE_PREMISE | ACTIVE_FLAG | VARCHAR(1) | SERVICE_PREMISE | IS_ACTIVE | NUMBER(1) | TR-01: Y→1, N→0 | VR-FLAG-001 | 1 | Y | N | I+D |

---

## Entity: METER (EM-07)

| Map ID | Source Table | Source Column | Src Type | Target Table | Target Column | Tgt Type | Transform Rule | Validation Rule | Default | Mandatory | Biz Key | Freq |
|--------|-------------|--------------|----------|-------------|--------------|----------|----------------|----------------|---------|-----------|---------|------|
| CM-110 | RAW.METER | METER_ID | NUMBER(15) | METER | SOURCE_METER_ID | NUMBER(15) | Direct | — | — | Y | Y | I+D |
| CM-111 | RAW.METER | PREMISE_ID | NUMBER(15) | METER | PREMISE_ID | NUMBER(15) | TR-FK-01 | VR-FK-001 | — | Y | N | I+D |
| CM-112 | RAW.METER | METER_NUMBER | VARCHAR(30) | METER | METER_NUMBER | VARCHAR2(30) | Direct | VR-MTR-001 | — | Y | N | I+D |
| CM-113 | RAW.METER | METER_TYPE | VARCHAR(20) | METER | METER_TYPE | VARCHAR2(20) | Uppercase trim | VR-MTR-002 | — | Y | N | I+D |
| CM-114 | RAW.METER | INSTALL_DATE | DATE | METER | INSTALL_DATE | DATE | TR-DATE-01 | VR-DATE-001 | — | Y | N | I+D |
| CM-115 | RAW.METER | REMOVAL_DATE | DATE | METER | REMOVAL_DATE | DATE | TR-DATE-01 | None | NULL | N | N | I+D |
| CM-116 | RAW.METER | MULTIPLIER | NUMBER(10,4) | METER | MULTIPLIER | NUMBER(10,4) | Direct | VR-MTR-003 | 1.0000 | Y | N | I+D |
| CM-117 | RAW.METER | KWH_DIAL_COUNT | NUMBER(3) | METER | KWH_DIAL_COUNT | NUMBER(3) | Direct | VR-MTR-004 | — | Y | N | I+D |
| CM-118 | RAW.METER | MANUFACTURER | VARCHAR(50) | METER | MANUFACTURER | VARCHAR2(50) | Direct | None | NULL | N | N | I+D |
| CM-119 | RAW.METER | MODEL_NUMBER | VARCHAR(50) | METER | MODEL_NUMBER | VARCHAR2(50) | Direct | None | NULL | N | N | I+D |
| CM-120 | RAW.METER | ACTIVE_FLAG | VARCHAR(1) | METER | IS_ACTIVE | NUMBER(1) | TR-01: Y→1, N→0 | VR-FLAG-001 | 1 | Y | N | I+D |

---

## Entity: MONTHLY_USAGE (EM-08)

| Map ID | Source Table | Source Column | Src Type | Target Table | Target Column | Tgt Type | Transform Rule | Validation Rule | Default | Mandatory | Biz Key | Freq |
|--------|-------------|--------------|----------|-------------|--------------|----------|----------------|----------------|---------|-----------|---------|------|
| CM-130 | RAW.MONTHLY_USAGE | USAGE_ID | NUMBER(15) | MONTHLY_USAGE | SOURCE_USAGE_ID | NUMBER(15) | Direct | — | — | Y | — | M |
| CM-131 | RAW.MONTHLY_USAGE | ENERGY_ACCOUNT_ID | NUMBER(15) | MONTHLY_USAGE | ENERGY_ACCOUNT_ID | NUMBER(15) | TR-FK-01 | VR-FK-001 | — | Y | Y | M |
| CM-132 | RAW.MONTHLY_USAGE | PREMISE_ID | NUMBER(15) | MONTHLY_USAGE | PREMISE_ID | NUMBER(15) | TR-FK-01 | VR-FK-001 | — | Y | N | M |
| CM-133 | RAW.MONTHLY_USAGE | METER_ID | NUMBER(15) | MONTHLY_USAGE | METER_ID | NUMBER(15) | TR-FK-01 | VR-FK-001 | — | Y | N | M |
| CM-134 | RAW.MONTHLY_USAGE | BILLING_MONTH | VARCHAR(7) | MONTHLY_USAGE | BILLING_MONTH | VARCHAR2(7) | Direct | VR-USAGE-001 | — | Y | Y | M |
| CM-135 | RAW.MONTHLY_USAGE | BILL_START_DATE | DATE | MONTHLY_USAGE | BILL_START_DATE | DATE | TR-DATE-01 | VR-USAGE-002 | — | Y | N | M |
| CM-136 | RAW.MONTHLY_USAGE | BILL_END_DATE | DATE | MONTHLY_USAGE | BILL_END_DATE | DATE | TR-DATE-01 | VR-USAGE-003 | — | Y | N | M |
| CM-137 | RAW.MONTHLY_USAGE | BILLING_DAYS | NUMBER(3) | MONTHLY_USAGE | BILLING_DAYS | NUMBER(3) | Direct | VR-USAGE-004 | — | Y | N | M |
| CM-138 | RAW.MONTHLY_USAGE | KWH_USAGE | NUMBER(12,3) | MONTHLY_USAGE | KWH_USAGE | NUMBER(12,6) | TR-DEC-01: BigDecimal scale 6 | VR-USAGE-005 | — | Y | N | M |
| CM-139 | RAW.MONTHLY_USAGE | PEAK_DEMAND_KW | NUMBER(10,3) | MONTHLY_USAGE | PEAK_DEMAND_KW | NUMBER(10,6) | TR-DEC-01 | VR-USAGE-006 | NULL | N | N | M |
| CM-140 | RAW.MONTHLY_USAGE | PREV_METER_READING | NUMBER(12,3) | MONTHLY_USAGE | PREV_METER_READING | NUMBER(12,6) | TR-DEC-01 | — | — | Y | N | M |
| CM-141 | RAW.MONTHLY_USAGE | CURR_METER_READING | NUMBER(12,3) | MONTHLY_USAGE | CURR_METER_READING | NUMBER(12,6) | TR-DEC-01 | — | — | Y | N | M |
| CM-142 | RAW.MONTHLY_USAGE | RATE_PLAN | VARCHAR(20) | MONTHLY_USAGE | RATE_PLAN | VARCHAR2(20) | Uppercase trim | VR-USAGE-007 | — | Y | N | M |
| CM-143 | RAW.MONTHLY_USAGE | ENERGY_CHARGE | NUMBER(12,2) | MONTHLY_USAGE | ENERGY_CHARGE | NUMBER(15,2) | TR-DEC-02: BigDecimal scale 2 | VR-USAGE-008 | — | Y | N | M |
| CM-144 | RAW.MONTHLY_USAGE | TAX_AMOUNT | NUMBER(10,2) | MONTHLY_USAGE | TAX_AMOUNT | NUMBER(10,2) | TR-DEC-02 | VR-USAGE-009 | — | Y | N | M |
| CM-145 | RAW.MONTHLY_USAGE | TOTAL_BILLED_AMOUNT | NUMBER(12,2) | MONTHLY_USAGE | TOTAL_BILLED_AMOUNT | NUMBER(15,2) | TR-DEC-02 | VR-USAGE-010 | — | Y | N | M |
| CM-146 | — | ENERGY_CHARGE + TAX_AMOUNT | — | MONTHLY_USAGE | CALCULATED_BILL_TOTAL | NUMBER(15,2) | TR-10: BigDecimal add | VR-USAGE-011 | — | Y | N | M |
| CM-147 | — | TOTAL_BILLED_AMOUNT − CALCULATED | — | MONTHLY_USAGE | BILL_TOTAL_VARIANCE | NUMBER(10,2) | TR-11: abs diff | None | NULL | N | N | M |
| CM-148 | RAW.MONTHLY_USAGE | READ_TYPE | VARCHAR(1) | MONTHLY_USAGE | READ_TYPE | VARCHAR2(1) | Uppercase | VR-USAGE-012 | — | Y | N | M |
| CM-149 | RAW.MONTHLY_USAGE | CORRECTION_FLAG | VARCHAR(1) | MONTHLY_USAGE | CORRECTION_FLAG | VARCHAR2(1) | Uppercase | VR-FLAG-001 | 'N' | Y | N | M |
| CM-150 | RAW.MONTHLY_USAGE | ORIGINAL_USAGE_ID | NUMBER(15) | MONTHLY_USAGE | ORIGINAL_SOURCE_USAGE_ID | NUMBER(15) | Direct | None | NULL | N | N | M |
| CM-151 | RAW.MONTHLY_USAGE | UPDATED_AT | TIMESTAMP_NTZ | MONTHLY_USAGE | SOURCE_UPDATED_AT | TIMESTAMP | TR-TS-01 | — | — | Y | N | M |
