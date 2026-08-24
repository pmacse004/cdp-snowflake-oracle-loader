# ICA Context Document 04 — Entity-Level Mappings

**ICA Document ID:** ICA-04  
**Project:** CDP Snowflake to Oracle Data Loader  
**Version:** 1.1 (Phase 1 Amendment)  
**Status:** Phase 1 — Amended  
**Last Updated:** 2025 (Phase 1 Amendment)

**Amendment:** All entity mappings now reflect multi-table source extraction via Snowflake views. Simple one-to-one table copies have been replaced with multi-source, joined, ranked and derived logical datasets.

---

## 1. Logical Dataset Overview

The ETL pipeline operates on two logical extraction datasets, each backed by a Snowflake view. These views join multiple source tables and perform selection, ranking and calculation in Snowflake before the Spring Batch processor receives the data.

| Dataset ID | Extraction View | Target Table(s) | Load Type | Business Key |
|------------|----------------|-----------------|-----------|--------------|
| LD-01 | `CLEAN.VW_DAILY_CUSTOMER_ACCOUNT_EXPORT` | `CDP_APP.CUSTOMER`, `CDP_APP.CUSTOMER_CONTACT`, `CDP_APP.ENERGY_ACCOUNT`, `CDP_APP.BILLING_ACCOUNT`, `CDP_APP.SERVICE_PREMISE`, `CDP_APP.METER` | Initial + Daily | `ENERGY_ACCOUNT_ID` (fan-out to per-entity MERGE) |
| LD-02 | `CLEAN.VW_MONTHLY_USAGE_BILLING_EXPORT` | `CDP_APP.MONTHLY_USAGE` | Monthly | `(ENERGY_ACCOUNT_ID, BILLING_MONTH)` |

---

## 2. Entity-Level Mapping Table

| Map ID | Source Object(s) | Target Table | Load Type | Business Key (MERGE) | Approach | Related Rules |
|--------|-----------------|-------------|-----------|---------------------|----------|---------------|
| EM-01 | `REF.CODE_VALUE` (single table) | `CDP_APP.REF_CODE_VALUE` | Initial + Daily | `(CODE_DOMAIN, CODE_VALUE)` | Direct map + IS_ACTIVE flag conversion; loaded before LD-01 to populate rate-label cache | TR-01, VR-FLAG-001 |
| EM-02 | `VW_DAILY_CUSTOMER_ACCOUNT_EXPORT` → `RAW.CUSTOMER` columns | `CDP_APP.CUSTOMER` | Initial + Daily | `SOURCE_CUSTOMER_ID` | Multi-source view; CUSTOMER columns extracted with title-case, FULL_NAME derivation, combined-status derivation, soft-delete handling; FK to CUSTOMER is root | TR-02, TR-03, TR-04, TR-05, TR-JOIN-01, VR-CUST-001–006 |
| EM-03 | `VW_DAILY_CUSTOMER_ACCOUNT_EXPORT` → ranked_contact CTE | `CDP_APP.CUSTOMER_CONTACT` | Initial + Daily | `SOURCE_CONTACT_ID` | One primary mailing contact per customer selected by ROW_NUMBER; email normalised; phone E.164; FK to CUSTOMER | TR-06, TR-07, TR-RANK-01, VR-EMAIL-001, VR-PHONE-001 |
| EM-04 | `VW_DAILY_CUSTOMER_ACCOUNT_EXPORT` → `RAW.ENERGY_ACCOUNT` + CUSTOMER columns | `CDP_APP.ENERGY_ACCOUNT` | Initial + Daily | `SOURCE_ENERGY_ACCOUNT_ID` | Combined status from CUSTOMER + ENERGY_ACCOUNT via CASE; IS_ACTIVE derived; soft-delete from both tables | TR-04, TR-05, TR-COMB-01, VR-EA-001–005 |
| EM-05 | `VW_DAILY_CUSTOMER_ACCOUNT_EXPORT` → ranked_billing CTE | `CDP_APP.BILLING_ACCOUNT` | Initial + Daily | `SOURCE_BILLING_ACCOUNT_ID` | Current billing account selected by EFFECTIVE_DATE ranking; PAPERLESS_BILLING Y→1/0 | TR-01, TR-RANK-02, VR-BA-001–002 |
| EM-06 | `VW_DAILY_CUSTOMER_ACCOUNT_EXPORT` → `RAW.SERVICE_PREMISE` columns | `CDP_APP.SERVICE_PREMISE` | Initial + Daily | `SOURCE_PREMISE_ID` | Premise joined via ENERGY_ACCOUNT; IS_ACTIVE derived from ACTIVE_FLAG; formatted address assembled in view | TR-01, TR-ADDR-01, VR-PREM-001–005 |
| EM-07 | `VW_DAILY_CUSTOMER_ACCOUNT_EXPORT` → ranked_meter CTE | `CDP_APP.METER` | Initial + Daily | `SOURCE_METER_ID` | Current active meter per premise selected by INSTALL_DATE ranking; multiplier validated | TR-01, TR-RANK-03, VR-MTR-001–004 |
| EM-08 | `VW_MONTHLY_USAGE_BILLING_EXPORT` → MONTHLY_USAGE + METER + ENERGY_ACCOUNT + BILLING_ACCOUNT + SERVICE_PREMISE + REF.CODE_VALUE | `CDP_APP.MONTHLY_USAGE` | Monthly | `(ENERGY_ACCOUNT_ID, BILLING_MONTH)` | Full charge calculations in view; correction/dedup handling in MERGE; FK resolution in processor | TR-10, TR-11, TR-BILL-01–07, VR-USAGE-001–012, VR-FK-001 |

---

## 3. LD-01 — Daily Customer/Account Dataset Detail

### 3.1 Source Tables and Join Structure

```
RAW.ENERGY_ACCOUNT (ea)          ← primary table; one row per record
    INNER JOIN RAW.CUSTOMER (c)  ON c.CUSTOMER_ID = ea.CUSTOMER_ID
    LEFT JOIN  ranked_contact(cc) ON cc.CUSTOMER_ID = c.CUSTOMER_ID AND cc.rn = 1
    LEFT JOIN  ranked_billing(ba) ON ba.ENERGY_ACCOUNT_ID = ea.ENERGY_ACCOUNT_ID AND ba.rn = 1
    LEFT JOIN  RAW.SERVICE_PREMISE(sp) ON sp.ENERGY_ACCOUNT_ID = ea.ENERGY_ACCOUNT_ID
    LEFT JOIN  ranked_meter(m)    ON m.PREMISE_ID = sp.PREMISE_ID AND m.rn = 1
    LEFT JOIN  REF.CODE_VALUE(rc_status) — status label lookup
    LEFT JOIN  REF.CODE_VALUE(rc_rate)   — rate-plan label lookup
    LEFT JOIN  REF.CODE_VALUE(rc_ctype)  — customer-type label lookup
```

All joins are LEFT except the CUSTOMER join (every account must have a customer). A missing contact, billing account, premise or meter is allowed — the record is still loaded with those columns null.

### 3.2 Selection / Ranking Rules

| CTE | Selected From | Ranking Key | Tie-break | Filter |
|-----|--------------|-------------|-----------|--------|
| `ranked_contact` | `RAW.CUSTOMER_CONTACT` | `IS_PRIMARY DESC, EFFECTIVE_DATE DESC` | `CONTACT_ID DESC` | `CONTACT_TYPE = 'MAILING'` AND not expired |
| `ranked_billing` | `RAW.BILLING_ACCOUNT` | `EFFECTIVE_DATE DESC` | `BILLING_ACCOUNT_ID DESC` | `EFFECTIVE_DATE <= today` AND not expired |
| `ranked_meter` | `RAW.METER` | `INSTALL_DATE DESC` | `METER_ID DESC` | `ACTIVE_FLAG = 'Y'` AND not removed |

### 3.3 Derived Columns in VW_DAILY_CUSTOMER_ACCOUNT_EXPORT

| Derived Column | Contributing Sources | Derivation Logic |
|----------------|---------------------|-----------------|
| `FULL_NAME_RAW` | `c.FIRST_NAME`, `c.LAST_NAME` | `TRIM(FIRST_NAME) \|\| ' ' \|\| TRIM(LAST_NAME)` — Layer 2 title-cases |
| `COMBINED_STATUS_CODE` | `c.ACCOUNT_STATUS`, `ea.ACCOUNT_STATUS`, `c.DELETED_FLAG`, `ea.DELETED_FLAG`, `ea.END_DATE` | Multi-condition CASE — see EM-04 |
| `COMBINED_STATUS_LABEL` | `rc_status.CODE_LABEL`, `COMBINED_STATUS_CODE` | Reference lookup on derived status code |
| `IS_ACTIVE` | `c.ACCOUNT_STATUS`, `ea.ACCOUNT_STATUS`, `c.DELETED_FLAG`, `ea.DELETED_FLAG`, `ea.END_DATE` | 1 if no inactive/closed/deleted condition, else 0 |
| `FORMATTED_MAILING_ADDRESS` | `cc.ADDRESS_LINE1..ZIP_CODE` | Concatenation with comma separators and null guards |
| `RATE_CLASS_DESCRIPTION` | `rc_rate.CODE_LABEL`, `ea.RATE_CLASS` | Reference lookup |
| `CUSTOMER_TYPE_LABEL` | `rc_ctype.CODE_LABEL`, `c.CUSTOMER_TYPE` | Reference lookup |
| `RECORD_EFFECTIVE_TS` | `c.UPDATED_AT`, `cc.UPDATED_AT`, `ea.UPDATED_AT`, `ba.UPDATED_AT`, `sp.UPDATED_AT`, `m.UPDATED_AT` | `GREATEST(...)` — maximum of all contributing timestamps |

### 3.4 Fan-Out Loading

One view row is loaded to **multiple** Oracle target tables by the Spring Batch processor (one ItemProcessor per entity type). The DailyIncrementalJob runs as steps in order:

```
Step 1: Load REF_CODE_VALUE    (single-table, no join — must precede cache use)
Step 2: Load CUSTOMER          (from LD-01 view — CUSTOMER columns only)
Step 3: Load CUSTOMER_CONTACT  (from LD-01 view — ranked_contact columns only)
Step 4: Load ENERGY_ACCOUNT    (from LD-01 view — ea + c columns for status derivation)
Step 5: Load BILLING_ACCOUNT   (from LD-01 view — ranked_billing columns only)
Step 6: Load SERVICE_PREMISE   (from LD-01 view — sp columns only)
Step 7: Load METER             (from LD-01 view — ranked_meter columns only)
```

Each step queries the same view but projects different columns. FK caches are populated between steps as in the original design.

---

## 4. LD-02 — Monthly Usage/Billing Dataset Detail

### 4.1 Source Tables and Join Structure

```
RAW.MONTHLY_USAGE (u)              ← primary table
    INNER JOIN RAW.ENERGY_ACCOUNT (ea) ON ea.ENERGY_ACCOUNT_ID = u.ENERGY_ACCOUNT_ID
    INNER JOIN RAW.METER (m)           ON m.METER_ID = u.METER_ID
    LEFT JOIN  current_billing (ba)    ON ba.ENERGY_ACCOUNT_ID = u.ENERGY_ACCOUNT_ID AND ba.rn = 1
    LEFT JOIN  RAW.SERVICE_PREMISE (sp) ON sp.PREMISE_ID = u.PREMISE_ID
    LEFT JOIN  rate_params (rp)        ON rp.RATE_PLAN = ea.RATE_CLASS
```

### 4.2 Calculated Columns in VW_MONTHLY_USAGE_BILLING_EXPORT

| Target Column | Calculation | Rounding | Sources |
|--------------|-------------|----------|---------|
| `BILLING_DAYS_CALC` | `DATEDIFF(day, BILL_START_DATE, BILL_END_DATE) + 1` | Integer | `u.BILL_START_DATE`, `u.BILL_END_DATE` |
| `ADJUSTED_KWH` | `(CURR_METER_READING - PREV_METER_READING) * METER_MULTIPLIER` | ROUND(x, 6) | `u.CURR_METER_READING`, `u.PREV_METER_READING`, `m.MULTIPLIER` |
| `FIXED_CHARGE` | `rate_fixed_charge` | ROUND(x, 2) | `rp.FIXED_CHARGE_RATE` |
| `ENERGY_CHARGE_CALC` | `KWH_USAGE * ENERGY_RATE_PER_KWH` | ROUND(x, 2) | `u.KWH_USAGE`, `rp.ENERGY_RATE_PER_KWH` |
| `DEMAND_CHARGE_CALC` | `PEAK_DEMAND_KW * DEMAND_RATE_PER_KW` (0 if no demand rate) | ROUND(x, 2) | `u.PEAK_DEMAND_KW`, `rp.DEMAND_RATE_PER_KW` |
| `SUBTOTAL_CALC` | `FIXED_CHARGE + ENERGY_CHARGE_CALC + DEMAND_CHARGE_CALC` | ROUND(x, 2) | Above |
| `TAX_AMOUNT_CALC` | `SUBTOTAL_CALC * TAX_RATE` | ROUND(x, 2) | `SUBTOTAL_CALC`, `rp.TAX_RATE` |
| `TOTAL_BILLED_CALC` | `SUBTOTAL_CALC * (1 + TAX_RATE)` | ROUND(x, 2) | `SUBTOTAL_CALC`, `rp.TAX_RATE` |
| `BILL_TOTAL_VARIANCE` | `SOURCE_TOTAL_BILLED - TOTAL_BILLED_CALC` | ROUND(x, 2) | `u.TOTAL_BILLED_AMOUNT`, `TOTAL_BILLED_CALC` |
| `READING_KWH_MISMATCH` | `ABS(ADJUSTED_KWH - SOURCE_KWH_USAGE) > 0.001` → Y/N | Boolean flag | `ADJUSTED_KWH`, `u.KWH_USAGE` |
| `USAGE_QUALITY_STATUS` | Multi-condition CASE (see view design) | Categorical | Multiple |

---

## 5. EM-01: REF_CODE_VALUE (unchanged from v1.0)

| Aspect | Detail |
|--------|--------|
| Source | `CDP_DW.REF.CODE_VALUE` — single table |
| Target | `CDP_APP.REF_CODE_VALUE` |
| Business key | `(CODE_DOMAIN, CODE_VALUE)` |
| Approach | Direct map + IS_ACTIVE Y→1/0 |
| Load order | Step 1 — must be loaded before LD-01 view extraction |

---

## 6. EM-02: CUSTOMER (from LD-01 view)

| Aspect | Detail |
|--------|--------|
| Source | `VW_DAILY_CUSTOMER_ACCOUNT_EXPORT` (CUSTOMER columns) |
| Contributing raw tables | `RAW.CUSTOMER`, `RAW.ENERGY_ACCOUNT` (for combined status) |
| Target | `CDP_APP.CUSTOMER` |
| Business key | `SOURCE_CUSTOMER_ID` |
| Key columns derived in view | `COMBINED_STATUS_CODE`, `IS_ACTIVE`, `RECORD_EFFECTIVE_TS` |
| Columns finished in processor | `FIRST_NAME` (title-case), `LAST_NAME` (title-case), `FULL_NAME` (TR-03), `ACCOUNT_STATUS` (canonical translate) |
| Soft delete | `c.DELETED_FLAG = Y` OR `ea.END_DATE < today` → `IS_ACTIVE=0`, `DELETED_AT`, `DELETION_REASON` |

---

## 7. EM-03: CUSTOMER_CONTACT (from ranked_contact CTE)

| Aspect | Detail |
|--------|--------|
| Source | `VW_DAILY_CUSTOMER_ACCOUNT_EXPORT` (ranked_contact columns) |
| Contributing raw tables | `RAW.CUSTOMER_CONTACT` |
| Selection rule | ROW_NUMBER: IS_PRIMARY DESC, EFFECTIVE_DATE DESC, CONTACT_ID DESC; only rn=1 row loaded |
| Business key | `SOURCE_CONTACT_ID` |
| Columns finished in processor | EMAIL_ADDRESS (lower-case + validate), PHONE_NUMBER (E.164) |
| Missing contact | NULL contact columns; CUSTOMER record still loaded |

---

## 8. EM-04: ENERGY_ACCOUNT (from LD-01 view)

| Aspect | Detail |
|--------|--------|
| Source | `VW_DAILY_CUSTOMER_ACCOUNT_EXPORT` (ENERGY_ACCOUNT + CUSTOMER columns) |
| Contributing raw tables | `RAW.ENERGY_ACCOUNT`, `RAW.CUSTOMER` |
| Status derivation | `COMBINED_STATUS_CODE` from multi-condition CASE in view; translated to canonical in processor |
| IS_ACTIVE derivation | Derived in view from combined conditions |
| Soft delete | Either source table deleted → IS_ACTIVE=0 |

---

## 9. EM-05: BILLING_ACCOUNT (from ranked_billing CTE)

| Aspect | Detail |
|--------|--------|
| Source | `VW_DAILY_CUSTOMER_ACCOUNT_EXPORT` (ranked_billing columns) |
| Contributing raw tables | `RAW.BILLING_ACCOUNT` |
| Selection rule | ROW_NUMBER: EFFECTIVE_DATE DESC, BILLING_ACCOUNT_ID DESC; only rn=1 (current) loaded |
| Business key | `SOURCE_BILLING_ACCOUNT_ID` |

---

## 10. EM-06: SERVICE_PREMISE (from LD-01 view)

| Aspect | Detail |
|--------|--------|
| Source | `VW_DAILY_CUSTOMER_ACCOUNT_EXPORT` (SERVICE_PREMISE columns) |
| Contributing raw tables | `RAW.SERVICE_PREMISE` |
| Address | `FORMATTED_MAILING_ADDRESS` assembled in view; city title-cased in processor |

---

## 11. EM-07: METER (from ranked_meter CTE)

| Aspect | Detail |
|--------|--------|
| Source | `VW_DAILY_CUSTOMER_ACCOUNT_EXPORT` (ranked_meter columns) |
| Contributing raw tables | `RAW.METER` |
| Selection rule | ROW_NUMBER: INSTALL_DATE DESC, METER_ID DESC; only rn=1 (current active meter) loaded |
| MULTIPLIER | Default 1.0000 if null; validated > 0 in processor |

---

## 12. EM-08: MONTHLY_USAGE (from LD-02 view)

| Aspect | Detail |
|--------|--------|
| Source | `VW_MONTHLY_USAGE_BILLING_EXPORT` |
| Contributing raw tables | `RAW.MONTHLY_USAGE`, `RAW.ENERGY_ACCOUNT`, `RAW.METER`, `RAW.BILLING_ACCOUNT`, `RAW.SERVICE_PREMISE`, `REF.CODE_VALUE` |
| Business key | `(ENERGY_ACCOUNT_ID [target], BILLING_MONTH)` |
| Calculated in view | FIXED_CHARGE, ENERGY_CHARGE_CALC, DEMAND_CHARGE_CALC, SUBTOTAL_CALC, TAX_AMOUNT_CALC, TOTAL_BILLED_CALC, BILL_TOTAL_VARIANCE, BILLING_DAYS_CALC, ADJUSTED_KWH, USAGE_QUALITY_STATUS |
| Correction logic | Oracle MERGE: update only if incoming `SOURCE_UPDATED_AT > TARGET.SOURCE_UPDATED_AT` |
| USAGE_QUALITY_STATUS = FAIL | Record REJECTED with appropriate VR error code |
| USAGE_QUALITY_STATUS = WARN | Record LOADED with warning flag in ETL_RECORD_ERROR |
