# Mapping Catalogue — Human Readable

**Document ID:** ICA-05-HR  
**Project:** CDP Snowflake to Oracle Data Loader  
**Version:** 1.0  
**Status:** Phase 1 — Approved  
**Last Updated:** 2025 (Phase 1)

> This is the human-readable version of the mapping catalogue.  
> The machine-readable version is at `mapping-catalogue.yaml`.  
> The detailed column-level table is at `05-column-level-mappings.md`.

---

## Overview

| Total Mappings | Entities | Load Types | Active Version |
|---|---|---|---|
| 152 (CM-001 to CM-151 + audit columns) | 8 | Initial, Daily, Monthly | 1.0 |

---

## Entity Summary

| Entity Map ID | Source Object | Target Table | Business Key | Mappings | Load Type |
|---|---|---|---|---|---|
| EM-01 | `CDP_DW.REF.CODE_VALUE` | `CDP_APP.REF_CODE_VALUE` | (CODE_DOMAIN, CODE_VALUE) | CM-001 to CM-011 | I+D |
| EM-02 | `CDP_DW.RAW.CUSTOMER` | `CDP_APP.CUSTOMER` | SOURCE_CUSTOMER_ID | CM-020 to CM-038 | I+D |
| EM-03 | `CDP_DW.RAW.CUSTOMER_CONTACT` | `CDP_APP.CUSTOMER_CONTACT` | SOURCE_CONTACT_ID | CM-040 to CM-055 | I+D |
| EM-04 | `CDP_DW.RAW.ENERGY_ACCOUNT` | `CDP_APP.ENERGY_ACCOUNT` | SOURCE_ENERGY_ACCOUNT_ID | CM-060 to CM-075 | I+D |
| EM-05 | `CDP_DW.RAW.BILLING_ACCOUNT` | `CDP_APP.BILLING_ACCOUNT` | SOURCE_BILLING_ACCOUNT_ID | CM-080 to CM-090 | I+D |
| EM-06 | `CDP_DW.RAW.SERVICE_PREMISE` | `CDP_APP.SERVICE_PREMISE` | SOURCE_PREMISE_ID | CM-090 to CM-105 | I+D |
| EM-07 | `CDP_DW.RAW.METER` | `CDP_APP.METER` | SOURCE_METER_ID | CM-110 to CM-125 | I+D |
| EM-08 | `CDP_DW.RAW.MONTHLY_USAGE` | `CDP_APP.MONTHLY_USAGE` | (ENERGY_ACCOUNT_ID, BILLING_MONTH) | CM-130 to CM-151 | M |

---

## Transformation Rules Summary

### Snowflake Layer 1 Rules (executed in the view)

| Rule ID | Name | Description |
|---------|------|-------------|
| TR-JOIN-01..07 | Join rules | INNER/LEFT JOINs across 8 source tables; see ICA-06 and ICA-17 |
| TR-RANK-01 | PrimaryMailingContactSelector | ROW_NUMBER: IS_PRIMARY DESC, EFFECTIVE_DATE DESC, CONTACT_ID DESC |
| TR-RANK-02 | CurrentBillingAccountSelector | ROW_NUMBER: EFFECTIVE_DATE DESC, BILLING_ACCOUNT_ID DESC |
| TR-RANK-03 | CurrentActiveMeterSelector | ROW_NUMBER: INSTALL_DATE DESC, METER_ID DESC |
| TR-COMB-01 | CombinedAccountStatusDeriver | CASE across CUSTOMER + ENERGY_ACCOUNT status; priority CLOSED > INACTIVE > PENDING > ACTIVE |
| TR-COND-01 | MultiSourceIsActiveDeriver | 1 if no deleted/closed/end-dated condition; else 0 |
| TR-ADDR-01 | FormattedMailingAddressAssembler | Null-guarded concatenation of address components |
| TR-TS-GREATEST-01 | RecordEffectiveTsDeriver | GREATEST of all 6 contributing UPDATED_AT values |
| TR-BILL-01 | AdjustedKwhCalculator | ROUND((CURR_READING − PREV_READING) × MULTIPLIER, 6) |
| TR-BILL-02 | FixedChargeExtractor | ROUND(rate.fixed, 2) |
| TR-BILL-03 | EnergyChargeCalculator | ROUND(KWH × energy_rate, 2) |
| TR-BILL-04 | DemandChargeCalculator | ROUND(KW × demand_rate, 2); 0 if no demand rate |
| TR-BILL-05 | SubtotalCalculator | ROUND(FIXED + ENERGY + DEMAND, 2) |
| TR-BILL-06 | TaxCalculator | ROUND(SUBTOTAL × tax_rate, 2) |
| TR-BILL-07 | TotalBilledCalculator | ROUND(SUBTOTAL + TAX, 2) |

### Spring Batch Layer 2 Rules (executed in Java processor)

| Rule ID | Name | Description |
|---------|------|-------------|
| TR-01 | YNToIntFlag | Y→1, N→0 |
| TR-02 | TitleCaseNormalizer | Title-case all name fields |
| TR-03 | FullNameDeriver | LAST_NAME + ', ' + FIRST_NAME (title-cased) |
| TR-05 | AccountStatusTranslator | ACT/INA/PND/CLO → ACTIVE/INACTIVE/PENDING/CLOSED |
| TR-06 | EmailNormalizer | Lowercase + trim + RFC 5322 validate |
| TR-07 | PhoneNormalizer | E.164 (+1XXXXXXXXXX) |
| TR-08 | SoftDeleteTransformer | IS_ACTIVE=0, DELETED_AT, DELETION_REASON |
| TR-FK-01 | SourceToTargetFkResolver | Source ID → Oracle target ID via cache |
| TR-DATE-01 | DateOnlyExtractor | Snowflake DATE → Oracle DATE |
| TR-TS-01 | UtcTimestampNormalizer | TIMESTAMP_NTZ → Oracle TIMESTAMP UTC |
| TR-DEC-01 | UsageDecimalNormalizer | NUMBER → BigDecimal scale 6, HALF_EVEN |
| TR-DEC-02 | MonetaryDecimalNormalizer | NUMBER → BigDecimal scale 2, HALF_EVEN |

### Oracle Layer 3 Rules (audit stamping in MERGE)

| Rule ID | Name | Description |
|---------|------|-------------|
| TR-AUD-01 | CREATED_AT setter | INSERT only — SYSTIMESTAMP UTC |
| TR-AUD-02 | CREATED_BY setter | INSERT only — {JobName}/{RunId} |
| TR-AUD-03 | UPDATED_AT setter | INSERT + UPDATE — SYSTIMESTAMP UTC |
| TR-AUD-04 | UPDATED_BY setter | INSERT + UPDATE — {JobName}/{RunId} |

---

## Validation Rules Summary

| Rule ID | Field(s) | Action on Failure |
|---------|----------|-------------------|
| VR-CODE-001 to 004 | CODE_ID, CODE_DOMAIN, CODE_VALUE, CODE_LABEL | REJECT |
| VR-CUST-001 to 006 | CUSTOMER_ID, FIRST_NAME, LAST_NAME, FULL_NAME, CUSTOMER_TYPE, ACCOUNT_STATUS | REJECT |
| VR-STATUS-001 | ACCOUNT_STATUS translation | REJECT |
| VR-CONT-001, 002 | CONTACT_ID, CONTACT_TYPE | REJECT |
| VR-CONT-003, 004 | STATE_CODE, ZIP_CODE | WARN (no reject) |
| VR-EMAIL-001 | EMAIL_ADDRESS | WARN; null field |
| VR-PHONE-001 | PHONE_NUMBER | WARN; null field |
| VR-EA-001 to 005 | EA mandatory fields | REJECT |
| VR-BA-001, 002 | BA mandatory fields | REJECT |
| VR-PREM-001 to 005 | Premise mandatory fields | REJECT |
| VR-PREM-006 | GPS coordinates | WARN; null field |
| VR-MTR-001 to 004 | Meter mandatory fields | REJECT |
| VR-USAGE-001 to 012 | Usage fields | REJECT (except VR-USAGE-011 = WARN) |
| VR-FK-001 | Any FK | REJECT |
| VR-DATE-001 | NOT NULL dates | REJECT |
| VR-FLAG-001 | Any Y/N flag | WARN; default 0 |

---

## Key Design Showcase Transformations

This catalogue demonstrates the following transformation types explicitly required:

| Category | Example(s) |
|----------|-----------|
| **Direct mappings** | CM-001 CODE_ID → SOURCE_CODE_ID; CM-021 EXTERNAL_REF → EXTERNAL_REF |
| **Renamed columns** | CM-001 CODE_ID → SOURCE_CODE_ID; CM-020 CUSTOMER_ID → SOURCE_CUSTOMER_ID |
| **Datatype conversions** | CM-138 NUMBER(12,3) → NUMBER(12,6); CM-006 VARCHAR(1) → NUMBER(1) |
| **Name normalisation** | CM-022 TR-02 TitleCase on FIRST_NAME; CM-023 TR-02 on LAST_NAME |
| **Email validation** | CM-048 TR-06 + VR-EMAIL-001 |
| **Phone validation** | CM-049 TR-07 + VR-PHONE-001 to E.164 |
| **Default values** | CM-116 MULTIPLIER default 1.0000; CM-050 IS_PRIMARY default 0 |
| **Code translations** | CM-027 TR-05 ACT→ACTIVE; CLO→CLOSED |
| **Deduplication** | MU-DEDUP-01 to 05 on (ENERGY_ACCOUNT_ID, BILLING_MONTH) |
| **Date normalisation** | CM-029 TR-DATE-01; CM-051 TR-DATE-01 |
| **Timestamp normalisation** | CM-151 TR-TS-01 TIMESTAMP_NTZ → UTC TIMESTAMP |
| **Account-status derivation** | CM-028 TR-04 IS_ACTIVE from ACCOUNT_STATUS |
| **Soft deletion** | CM-032/033 TR-08 DELETED_FLAG=Y → IS_ACTIVE=0, DELETED_AT |
| **Referential-integrity validation** | CM-041 TR-FK-01 + VR-FK-001 |
| **Non-negative KWH/KW** | VR-USAGE-005, VR-USAGE-006 |
| **Billing-period validation** | VR-USAGE-003 BILL_END_DATE > BILL_START_DATE |
| **Monthly bill calculations** | CM-146 TR-10; CM-147 TR-11 |
| **Reference-table lookup** | TR-05 uses REF_CODE_VALUE domain ACCT_STATUS |
| **Corrected usage records** | MU-DEDUP-03 CORRECTION_FLAG=Y when newer UPDATED_AT |
| **Rerun/idempotency** | IL-IDEM-01 MERGE prevents duplicates on re-run |

---

## Mapping Version History

| Version | Date | Author | Changes |
|---------|------|--------|---------|
| 1.0 | 2025 Phase 1 | CDP Architecture Team | Initial catalogue — 152 column mappings across 8 entities |

---

## Cross-References

| Document | Purpose |
|---------|---------|
| `mapping-catalogue.yaml` | Machine-readable version |
| `05-column-level-mappings.md` | Detailed mapping table |
| `06-transformation-rules.md` | Transformation rule definitions |
| `07-validation-rules.md` | Validation rule definitions |
| `08-reference-code-translations.md` | Code translation tables |
| `04-entity-level-mappings.md` | Entity-level mapping overview |
