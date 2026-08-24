# ICA Context Document 07 — Validation Rules

**ICA Document ID:** ICA-07  
**Project:** CDP Snowflake to Oracle Data Loader  
**Version:** 1.0  
**Status:** Phase 1 — Approved  
**Last Updated:** 2025 (Phase 1)

---

## 1. Purpose

This document defines all named validation rules referenced in the mapping catalogue (ICA-05). A validation rule specifies what constitutes a valid value, the error code to emit on failure, and the action to take (REJECT record vs. LOG warning and continue).

Validation failures are written to `CDP_CTL.ETL_RECORD_ERROR`.

---

## 2. Validation Rule Table

### 2.1 Flag Validations

| Rule ID | Name | Field(s) | Condition | Error Code | Error Action |
|---------|------|----------|-----------|------------|-------------|
| VR-FLAG-001 | YNFlagCheck | Any Y/N flag column | Value must be `Y` or `N` (case-insensitive) or null | VAL-FLAG-001 | Default to `0`; LOG warning |

---

### 2.2 Code Value Validations

| Rule ID | Name | Field(s) | Condition | Error Code | Error Action |
|---------|------|----------|-----------|------------|-------------|
| VR-CODE-001 | CodeIdNotNull | CODE_ID | Must not be null | VAL-CODE-001 | REJECT |
| VR-CODE-002 | CodeDomainNotBlank | CODE_DOMAIN | Must not be null or blank | VAL-CODE-002 | REJECT |
| VR-CODE-003 | CodeValueNotBlank | CODE_VALUE | Must not be null or blank | VAL-CODE-003 | REJECT |
| VR-CODE-004 | CodeLabelNotBlank | CODE_LABEL | Must not be null or blank | VAL-CODE-004 | REJECT |

---

### 2.3 Customer Validations

| Rule ID | Name | Field(s) | Condition | Error Code | Error Action |
|---------|------|----------|-----------|------------|-------------|
| VR-CUST-001 | CustomerIdNotNull | CUSTOMER_ID | Must not be null | VAL-CUST-001 | REJECT |
| VR-CUST-002 | FirstNameNotBlank | FIRST_NAME | Must not be null or blank after trimming | VAL-CUST-002 | REJECT |
| VR-CUST-003 | LastNameNotBlank | LAST_NAME | Must not be null or blank after trimming | VAL-CUST-003 | REJECT |
| VR-CUST-004 | FullNameDerived | FULL_NAME | Must be non-blank after derivation | VAL-CUST-004 | REJECT |
| VR-CUST-005 | CustomerTypeValid | CUSTOMER_TYPE | Must be one of: RESIDENTIAL, COMMERCIAL, INDUSTRIAL | VAL-CUST-005 | REJECT |
| VR-CUST-006 | AccountStatusValid | ACCOUNT_STATUS | Post-translation must be one of: ACTIVE, INACTIVE, PENDING, CLOSED | VAL-STATUS-001 | REJECT |
| VR-STATUS-001 | AccountStatusTranslatable | ACCOUNT_STATUS | Source code must exist in code-translation table | VAL-STATUS-002 | REJECT |

---

### 2.4 Contact Validations

| Rule ID | Name | Field(s) | Condition | Error Code | Error Action |
|---------|------|----------|-----------|------------|-------------|
| VR-CONT-001 | ContactIdNotNull | CONTACT_ID | Must not be null | VAL-CONT-001 | REJECT |
| VR-CONT-002 | ContactTypeValid | CONTACT_TYPE | Must be one of: MAILING, SERVICE, BILLING, EMAIL, PHONE | VAL-CONT-002 | REJECT |
| VR-CONT-003 | StateCodeValid | STATE_CODE | If present, must be a valid 2-letter US state code | VAL-CONT-003 | LOG warning; do not reject |
| VR-CONT-004 | ZipCodeFormat | ZIP_CODE | If present, must match `^[0-9]{5}(-[0-9]{4})?$` | VAL-CONT-004 | LOG warning; do not reject |
| VR-EMAIL-001 | EmailFormat | EMAIL_ADDRESS | If present, must match RFC 5322 simplified pattern: `^[^@]+@[^@]+\.[^@]+$` | VAL-EMAIL-001 | LOG warning; set EMAIL_ADDRESS to null; do not reject |
| VR-PHONE-001 | PhoneFormat | PHONE_NUMBER | If present, must resolve to a valid 10-digit US number | VAL-PHONE-001 | LOG warning; set PHONE_NUMBER to null; do not reject |

---

### 2.5 Energy Account Validations

| Rule ID | Name | Field(s) | Condition | Error Code | Error Action |
|---------|------|----------|-----------|------------|-------------|
| VR-EA-001 | EnergyAccountIdNotNull | ENERGY_ACCOUNT_ID | Must not be null | VAL-EA-001 | REJECT |
| VR-EA-002 | AccountNumberNotBlank | ACCOUNT_NUMBER | Must not be null or blank | VAL-EA-002 | REJECT |
| VR-EA-003 | EaStatusValid | ACCOUNT_STATUS | Post-translation in ACTIVE, INACTIVE, PENDING, CLOSED | VAL-STATUS-001 | REJECT |
| VR-EA-004 | ServiceTypeValid | SERVICE_TYPE | Must be one of: ELECTRIC, GAS, SOLAR | VAL-EA-004 | REJECT |
| VR-EA-005 | RateClassNotBlank | RATE_CLASS | Must not be null or blank | VAL-EA-005 | REJECT |

---

### 2.6 Billing Account Validations

| Rule ID | Name | Field(s) | Condition | Error Code | Error Action |
|---------|------|----------|-----------|------------|-------------|
| VR-BA-001 | BillingAcctNumNotBlank | BILLING_ACCOUNT_NUMBER | Must not be null or blank | VAL-BA-001 | REJECT |
| VR-BA-002 | BillingCycleValid | BILLING_CYCLE | Must be one of: MONTHLY, BIMONTHLY | VAL-BA-002 | REJECT |

---

### 2.7 Service Premise Validations

| Rule ID | Name | Field(s) | Condition | Error Code | Error Action |
|---------|------|----------|-----------|------------|-------------|
| VR-PREM-001 | PremiseTypeValid | PREMISE_TYPE | Must be one of: RESIDENTIAL, COMMERCIAL, INDUSTRIAL | VAL-PREM-001 | REJECT |
| VR-PREM-002 | Address1NotBlank | SERVICE_ADDRESS1 | Must not be null or blank | VAL-PREM-002 | REJECT |
| VR-PREM-003 | CityNotBlank | CITY | Must not be null or blank | VAL-PREM-003 | REJECT |
| VR-PREM-004 | PremiseStateValid | STATE_CODE | Must be a valid 2-letter US state code | VAL-PREM-004 | REJECT |
| VR-PREM-005 | PremiseZipFormat | ZIP_CODE | Must match `^[0-9]{5}(-[0-9]{4})?$` | VAL-PREM-005 | REJECT |
| VR-PREM-006 | GpsCoordinateRange | GPS_LATITUDE, GPS_LONGITUDE | If present: LAT in [-90, 90], LON in [-180, 180] | VAL-PREM-006 | LOG warning; set to null; do not reject |

---

### 2.8 Meter Validations

| Rule ID | Name | Field(s) | Condition | Error Code | Error Action |
|---------|------|----------|-----------|------------|-------------|
| VR-MTR-001 | MeterNumberNotBlank | METER_NUMBER | Must not be null or blank | VAL-MTR-001 | REJECT |
| VR-MTR-002 | MeterTypeValid | METER_TYPE | Must be one of: ANALOG, DIGITAL, SMART_AMI | VAL-MTR-002 | REJECT |
| VR-MTR-003 | MultiplierPositive | MULTIPLIER | Must be > 0 | VAL-MTR-003 | Default to 1.0000; LOG warning |
| VR-MTR-004 | DialCountPositive | KWH_DIAL_COUNT | Must be > 0 | VAL-MTR-004 | REJECT |

---

### 2.9 Monthly Usage Validations

| Rule ID | Name | Field(s) | Condition | Error Code | Error Action |
|---------|------|----------|-----------|------------|-------------|
| VR-USAGE-001 | BillingMonthFormat | BILLING_MONTH | Must match `^[0-9]{4}-(0[1-9]|1[0-2])$` | VAL-USAGE-001 | REJECT |
| VR-USAGE-002 | BillStartDateNotNull | BILL_START_DATE | Must not be null | VAL-USAGE-002 | REJECT |
| VR-USAGE-003 | BillEndAfterStart | BILL_START_DATE, BILL_END_DATE | BILL_END_DATE must be > BILL_START_DATE | VAL-USAGE-003 | REJECT |
| VR-USAGE-004 | BillingDaysPositive | BILLING_DAYS | Must be > 0 and ≤ 31 | VAL-USAGE-004 | REJECT |
| VR-USAGE-005 | KwhNonNegative | KWH_USAGE | Must be ≥ 0 | VAL-USAGE-005 | REJECT |
| VR-USAGE-006 | KwNonNegative | PEAK_DEMAND_KW | If present, must be ≥ 0 | VAL-USAGE-006 | REJECT |
| VR-USAGE-007 | RatePlanNotBlank | RATE_PLAN | Must not be null or blank | VAL-USAGE-007 | REJECT |
| VR-USAGE-008 | EnergyChargeNotNegative | ENERGY_CHARGE | Must be ≥ 0 | VAL-USAGE-008 | REJECT |
| VR-USAGE-009 | TaxAmountNotNegative | TAX_AMOUNT | Must be ≥ 0 | VAL-USAGE-009 | REJECT |
| VR-USAGE-010 | TotalBilledNotNegative | TOTAL_BILLED_AMOUNT | Must be ≥ 0 | VAL-USAGE-010 | REJECT |
| VR-USAGE-011 | BillTotalConsistency | ENERGY_CHARGE + TAX_AMOUNT vs TOTAL_BILLED_AMOUNT | abs(TOTAL_BILLED_AMOUNT − (ENERGY_CHARGE + TAX_AMOUNT)) ≤ 0.01 | VAL-USAGE-011 | LOG warning; record BILL_TOTAL_VARIANCE; do not reject |
| VR-USAGE-012 | ReadTypeValid | READ_TYPE | Must be `A` or `E` | VAL-USAGE-012 | REJECT |

---

### 2.10 Foreign-Key Validations

| Rule ID | Name | Field(s) | Condition | Error Code | Error Action |
|---------|------|----------|-----------|------------|-------------|
| VR-FK-001 | FkParentExists | Any FK column | Source parent ID must resolve to a target ID in FK cache | VAL-FK-001 | REJECT child record |

---

### 2.11 Date Validations

| Rule ID | Name | Field(s) | Condition | Error Code | Error Action |
|---------|------|----------|-----------|------------|-------------|
| VR-DATE-001 | DateNotNull | Any NOT NULL date | Must not be null | VAL-DATE-001 | REJECT |

---

## 3. Error Code Convention

All error codes follow the pattern: `VAL-{DOMAIN}-{NNN}`

| Prefix | Domain |
|--------|--------|
| VAL-CODE | Code-value table |
| VAL-CUST | Customer |
| VAL-STATUS | Account status |
| VAL-CONT | Contact |
| VAL-EMAIL | Email |
| VAL-PHONE | Phone |
| VAL-EA | Energy account |
| VAL-BA | Billing account |
| VAL-PREM | Service premise |
| VAL-MTR | Meter |
| VAL-USAGE | Monthly usage |
| VAL-FK | Foreign key |
| VAL-DATE | Date |
| VAL-FLAG | Flag fields |

---

## 4. Validation Execution Order

For each record in the processor:

1. Null/not-blank checks on mandatory fields (→ REJECT early)
2. Format and range checks on data fields
3. Code translation / enumeration checks
4. FK resolution check (→ REJECT if parent not found)
5. Business-rule cross-field checks (e.g., bill date range, bill total consistency)
6. Transformation and derivation (TR-* rules)
7. Emit validated + transformed record to writer
