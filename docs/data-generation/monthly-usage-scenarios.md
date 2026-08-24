# Monthly Usage Scenarios
## CDP Snowflake-to-Oracle Data Loader — Phase 3

**Document ID:** DG-003
**Version:** 1.0
**Status:** Phase 3 — Approved
**Last Updated:** 2025 (Phase 3)

---

## 1. Overview

Script `09-simulate-monthly-usage.sql` generates monthly electricity usage and billing records for the **current billing month** targeting approximately 1,000 records. It is designed to exercise all rules in ICA-12 (Monthly Usage Rules) including the charge calculation order, correction handling, deduplication and error-handling paths.

---

## 2. Billing Month Determination

| Variable | Value |
|---|---|
| `BILLING_MONTH_TARGET` | `TO_CHAR(DATE_TRUNC('MONTH', CURRENT_DATE()), 'YYYY-MM')` |
| `BILL_START` | First day of current calendar month |
| `BILL_END` | Last day of current calendar month (`DATEADD(DAY, -1, DATEADD(MONTH, 1, BILL_START))`) |
| `BILLING_DAYS` | `DATEDIFF(DAY, BILL_START, BILL_END) + 1` |

Because the billing month is computed at execution time, reruns on different days will target different months. The deduplication guard prevents duplicate records for the same account/month combination.

---

## 3. Record Categories

| Category | Section | Approx. Count | USAGE_ID Pattern | Notes |
|---|---|---|---|---|
| Normal actual reads | §1 | ~840 | `USG-EA-xxx-YYYY-MM` | 90% of normal records |
| Estimated reads | §1 | ~92 | Same pattern, `READ_TYPE='ESTIMATED'` | 10% of normal records |
| Zero-KWH boundary | §2a | 1 | `USG-BOUNDARY-ZERO-…` | Vacant account; only fixed charge |
| Correction records | §3 | ~3 | Existing prior-month rows (UPDATE) | `IS_CORRECTION = TRUE` |
| Negative KWH (invalid) | §4 | 1 | `USG-INVALID-NEGKWH-…` | VR-USAGE-005: FAIL_NEG_KWH |
| Inverted date order (invalid) | §4 | 1 | `USG-INVALID-DATEORD-…` | VR-USAGE-003: FAIL_DATE_ORDER |

**Total new rows for current month: ~935–940**

---

## 4. Normal Records — Charge Calculation

All normal records use the ICA-12 §4 calculation order, implemented identically in both the source data generation and the export view:

```
Step 1: FIXED_CHARGE      = FIXED_RATE                             (NULL if missing)
Step 2: ENERGY_CHARGE     = ROUND(KWH_USAGE × ENERGY_RATE, 2)     (NULL if rate NULL)
Step 3: DEMAND_CHARGE     = ROUND(KW × DEMAND_RATE, 2)            (0 if rate NULL — ICA MU-AC-09)
Step 4: SUBTOTAL_CHARGE   = ROUND(FIXED + ENERGY + DEMAND, 2)
Step 5: TAX_AMOUNT        = ROUND(SUBTOTAL × TAX_RATE, 2)
Step 6: TOTAL_BILLED      = SUBTOTAL + TAX
```

Source table values (`FIXED_CHARGE`, `ENERGY_CHARGE`, etc.) are pre-computed using the same formula so that `source TOTAL_BILLED ≈ CALC_TOTAL_BILLED` from the export view, satisfying reconciliation check `V-CR-005`.

---

## 5. Rate Plan Assignment

Rate plans are assigned deterministically from `RATE_CLASS`:

| RATE_CLASS | Rate plan(s) |
|---|---|
| `RESIDENTIAL` | Round-robin: RES-1, RES-2, RES-3 |
| `SMALL_COMMERCIAL` | COM-3 |
| `MEDIUM_COMMERCIAL` | COM-1 or COM-2 (hash parity) |
| `LARGE_INDUSTRIAL` | IND-1 or IND-2 (hash parity) |
| `SOLAR_NET` | SOL-1 |

---

## 6. KWH Usage Ranges

Usage values are derived from `RATE_CLASS` with a hash-based offset to produce realistic variation:

| RATE_CLASS | KWH Range | PEAK_DEMAND_KW Range |
|---|---|---|
| RESIDENTIAL | 200 – 2,000 kWh | N/A (null) |
| SMALL_COMMERCIAL | 1,000 – 4,000 kWh | N/A (null) |
| MEDIUM_COMMERCIAL | 5,000 – 15,000 kWh | 10 – 100 kW |
| LARGE_INDUSTRIAL | 50,000 – 150,000 kWh | 100 – 500 kW |
| SOLAR_NET | 200 – 600 kWh | N/A (null) |

---

## 7. Boundary Cases

### 7.1 Zero-KWH Record
- `KWH_USAGE = 0`, `KWH_ADJUSTED = 0`, `PEAK_DEMAND_KW = NULL`
- `PREV_METER_READING = CURR_METER_READING` (no consumption)
- Charges: `FIXED_CHARGE = 8.50`, `ENERGY_CHARGE = 0.00`, `DEMAND_CHARGE = 0.00`
- `SUBTOTAL = 8.50`, `TAX = ROUND(8.50 × 0.08, 2) = 0.68`, `TOTAL = 9.18`
- **Business meaning:** Vacant account; property unoccupied but service connected

### 7.2 Estimated Read
- `READ_TYPE = 'ESTIMATED'`
- Generated at ~10% of normal records via `MOD(HASH(...), 10) = 9`
- `USAGE_QUALITY_STATUS` in view = `'ESTIMATED'`
- **ETL behaviour:** Loaded normally; Spring Batch does not reject estimated reads

---

## 8. Correction Records (§3)

Three prior-month records are updated to simulate billing corrections:

| Field | Before | After |
|---|---|---|
| `KWH_USAGE` | Original value | Original × 0.98 (2% correction) |
| `KWH_ADJUSTED` | Original value | Same as new KWH_USAGE |
| `IS_CORRECTION` | FALSE | TRUE |
| `CORRECTION_REASON` | NULL | `'METER_REREAD_CORRECTION'` |
| `UPDATED_AT` | Prior timestamp | `CURRENT_TIMESTAMP()` |

**Spring Batch behaviour (ICA-12 MU-DEDUP-03):**
- Business key `(ENERGY_ACCOUNT_ID, BILLING_MONTH)` already exists in Oracle
- `SOURCE_UPDATED_AT (UPDATED_AT from view)` > existing `SOURCE_UPDATED_AT` → UPDATE
- `CORRECTION_FLAG` set to `'Y'` on Oracle target row
- Original KWH/charge values are overwritten with corrected values

---

## 9. Controlled Invalid Records (§4)

Two deliberately invalid records are inserted for error-handling demonstration:

### 9.1 Negative KWH (USG-INVALID-NEGKWH-…)
- `KWH_USAGE = -50.000`
- Violates `VR-USAGE-005`: KWH must be ≥ 0
- View returns `USAGE_QUALITY_STATUS = 'FAIL_NEG_KWH'`
- **ETL behaviour:** REJECT; write to `ETL_RECORD_ERROR`; not loaded to Oracle

### 9.2 Inverted Date Order (USG-INVALID-DATEORD-…)
- `BILL_START_DATE = current month end`, `BILL_END_DATE = current month start` (swapped)
- `BILLING_DAYS = -1` (negative)
- Violates `VR-USAGE-003`: `BILL_END_DATE >= BILL_START_DATE`
- View returns `USAGE_QUALITY_STATUS = 'FAIL_DATE_ORDER'`
- **ETL behaviour:** REJECT; write to `ETL_RECORD_ERROR`; not loaded to Oracle

---

## 10. Deduplication and Idempotency

| Rule | Implementation |
|---|---|
| MU-DEDUP-01 | Business key: `(ENERGY_ACCOUNT_ID, BILLING_MONTH)` |
| MU-DEDUP-02 | INSERT guard: `NOT EXISTS (SELECT 1 FROM BILLING.MONTHLY_USAGE WHERE … BILLING_MONTH = target)` |
| MU-DEDUP-03 | Correction: UPDATE where `IS_CORRECTION = FALSE AND UPDATED_AT < DATEADD(MINUTE, -5, …)` |
| Script rerun | Normal records skipped by `NOT EXISTS` guard; corrections only applied once (UPDATED_AT guard) |

Rerunning `09-simulate-monthly-usage.sql` after successful execution will insert 0 rows and update 0 rows.

---

## 11. Expected Monthly Load Test Results (Spring Batch — Phase 6)

| Metric | Expected |
|---|---|
| Records read from monthly view (for target month) | ~940 |
| Records inserted (new) | ~935 (new accounts not yet in Oracle for this month) |
| Records updated (corrections) | ~3 |
| Records skipped (stale UPDATED_AT) | 0 on first run; ~935 on rerun |
| Records rejected (FAIL_* quality) | 2 (negative KWH + date order) |
| KWH sum reconciliation | Source ≈ Oracle (within ±0.001 per record) |
| Total billed reconciliation | Source ≈ Oracle (within ±0.01 per record) |
