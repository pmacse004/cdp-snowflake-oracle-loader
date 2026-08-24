# ICA Context Document 12 — Monthly Usage Rules

**ICA Document ID:** ICA-12  
**Project:** CDP Snowflake to Oracle Data Loader  
**Version:** 1.1 (Phase 1 Amendment)  
**Status:** Phase 1 — Amended  
**Last Updated:** 2025 (Phase 1 Amendment)

**Amendment:** Monthly usage extraction now uses VW_MONTHLY_USAGE_BILLING_EXPORT which joins 6 source tables, applies synthetic rate-plan parameters, and performs all charge calculations in Snowflake with explicit rounding rules.

---

## 1. Purpose

Defines all rules governing the monthly electricity usage and billing load including multi-source extraction, charge calculations, deduplication, correction handling and reconciliation.

---

## 2. Trigger

| Trigger ID | Method | Description |
|------------|--------|-------------|
| MU-TRIG-01 | Scheduler | Configurable cron; default: first day of month, 06:00 UTC |
| MU-TRIG-02 | REST API | `POST /api/v1/jobs/monthly-load?billingMonth=YYYY-MM` |
| MU-TRIG-03 | Parameter | `billingMonth` defaults to previous calendar month |

---

## 3. Extraction Source

The monthly load reads from `CDP_DW.CLEAN.VW_MONTHLY_USAGE_BILLING_EXPORT` filtered by billing month:

```sql
SELECT *
FROM   CDP_DW.CLEAN.VW_MONTHLY_USAGE_BILLING_EXPORT
WHERE  BILLING_MONTH = :billingMonth
ORDER  BY USAGE_UPDATED_AT ASC, USAGE_ID_FOR_WM ASC
```

The view joins:
- `RAW.MONTHLY_USAGE` (primary)
- `RAW.ENERGY_ACCOUNT` (rate class, account number, customer ID)
- `RAW.METER` (multiplier, type)
- `RAW.BILLING_ACCOUNT` (current billing account number)
- `RAW.SERVICE_PREMISE` (address, distribution zone)
- `REF.CODE_VALUE` (rate plan parameters)

---

## 4. Charge Calculation Rules

All calculations are performed in Snowflake before the Spring Batch processor receives the row. The processor validates the results but does not recalculate.

### 4.1 Synthetic Rate Plan Parameters

Rate plan parameters are stored in `REF.CODE_VALUE` with `CODE_DOMAIN = 'RATE_PLAN'`. The `CODE_LABEL` field contains a JSON object:

```json
{"fixed": 8.50, "energy": 0.1150, "demand": null, "tax": 0.080}
```

These are entirely synthetic demonstration values — not real utility tariffs.

| Rate Plan | Fixed ($/month) | Energy ($/kWh) | Demand ($/kW) | Tax Rate |
|-----------|----------------|----------------|--------------|---------|
| `RES-1` | 8.50 | 0.1150 | — | 8.0% |
| `RES-2` | 8.50 | 0.0900 | — | 8.0% |
| `RES-3` | 8.50 | 0.1050 | — | 8.0% |
| `COM-1` | 22.00 | 0.1050 | 8.50 | 8.5% |
| `COM-2` | 22.00 | 0.0950 | 9.00 | 8.5% |
| `COM-3` | 15.00 | 0.1100 | — | 8.5% |
| `IND-1` | 75.00 | 0.0850 | 12.00 | 7.0% |
| `IND-2` | 60.00 | 0.0750 | 10.00 | 7.0% |
| `SOL-1` | 8.50 | 0.0700 | — | 8.0% |

### 4.2 Calculation Order

All monetary steps use `ROUND(x, 2)`. Usage step uses `ROUND(x, 6)`.

```
Step 1 — ADJUSTED_KWH:
  = ROUND( (CURR_METER_READING − PREV_METER_READING) × METER_MULTIPLIER, 6 )
  Note: compared to SOURCE_KWH_USAGE; if |diff| > 0.001 → READING_KWH_MISMATCH = 'Y'

Step 2 — FIXED_CHARGE:
  = ROUND( COALESCE(rate.fixed_charge, 0), 2 )

Step 3 — ENERGY_CHARGE_CALC:
  = ROUND( SOURCE_KWH_USAGE × COALESCE(rate.energy_rate, 0), 2 )
  (uses SOURCE_KWH_USAGE, not ADJUSTED_KWH, to match source billing system)

Step 4 — DEMAND_CHARGE_CALC:
  = ROUND( COALESCE(PEAK_DEMAND_KW, 0) × COALESCE(rate.demand_rate, 0), 2 )
  (0.00 when demand_rate IS NULL for this plan)

Step 5 — SUBTOTAL_CALC:
  = ROUND( FIXED_CHARGE + ENERGY_CHARGE_CALC + DEMAND_CHARGE_CALC, 2 )

Step 6 — TAX_AMOUNT_CALC:
  = ROUND( SUBTOTAL_CALC × COALESCE(rate.tax_rate, 0), 2 )

Step 7 — TOTAL_BILLED_CALC:
  = ROUND( SUBTOTAL_CALC + TAX_AMOUNT_CALC, 2 )
  (computed as SUBTOTAL + TAX, not SUBTOTAL × (1+tax), to ensure TOTAL = SUBTOTAL + TAX exactly)

Step 8 — BILL_TOTAL_VARIANCE:
  = ROUND( SOURCE_TOTAL_BILLED − TOTAL_BILLED_CALC, 2 )
  If |variance| > 0.01 → VAL-USAGE-011 warning; record loaded with variance stored
```

### 4.3 Why SOURCE_KWH_USAGE in Step 3?

The source system may apply its own KWH calculation rules (e.g., rollover handling, estimated reads). This demo uses `SOURCE_KWH_USAGE` for energy charge calculation to match the source billing system's value, while storing `ADJUSTED_KWH` for audit. The `READING_KWH_MISMATCH` flag identifies discrepancies.

---

## 5. Derived Fields Summary

| Target Column | Source | Calculated In | Rule |
|--------------|--------|--------------|------|
| `BILLING_DAYS_CALC` | BILL_START_DATE, BILL_END_DATE | Snowflake view | `DATEDIFF(day, start, end) + 1` |
| `ADJUSTED_KWH` | readings + multiplier | Snowflake view | TR-BILL-01 |
| `FIXED_CHARGE` | rate params | Snowflake view | TR-BILL-02 |
| `ENERGY_CHARGE_CALC` | KWH + energy rate | Snowflake view | TR-BILL-03 |
| `DEMAND_CHARGE_CALC` | KW + demand rate | Snowflake view | TR-BILL-04 |
| `SUBTOTAL_CALC` | fixed + energy + demand | Snowflake view | TR-BILL-05 |
| `TAX_AMOUNT_CALC` | subtotal × tax rate | Snowflake view | TR-BILL-06 |
| `TOTAL_BILLED_CALC` | subtotal + tax | Snowflake view | TR-BILL-07 |
| `BILL_TOTAL_VARIANCE` | source total − calculated | Snowflake view | TR-11 |
| `READING_KWH_MISMATCH` | adjusted vs source KWH | Snowflake view | Conditional flag |
| `USAGE_QUALITY_STATUS` | multi-condition CASE | Snowflake view | PASS/WARN/FAIL |

---

## 6. Business Key and Deduplication

| Rule ID | Rule |
|---------|------|
| MU-DEDUP-01 | Business key: `(ENERGY_ACCOUNT_ID [target Oracle ID], BILLING_MONTH)` |
| MU-DEDUP-02 | If key does NOT exist in Oracle → INSERT |
| MU-DEDUP-03 | If key EXISTS and incoming `SOURCE_UPDATED_AT (USAGE_UPDATED_AT from view) > existing SOURCE_UPDATED_AT` → UPDATE (correction); set CORRECTION_FLAG = 'Y' |
| MU-DEDUP-04 | If key EXISTS and incoming `SOURCE_UPDATED_AT ≤ existing` → SKIP (count as SKIPPED) |
| MU-DEDUP-05 | Oracle MERGE with WHEN MATCHED condition: `WHERE src.usage_ts > tgt.SOURCE_UPDATED_AT` |

---

## 7. Usage Quality Handling

| USAGE_QUALITY_STATUS | Action |
|---------------------|--------|
| `PASS` | Load normally |
| `WARN_KWH_MISMATCH` | Load; write warning to ETL_RECORD_ERROR; do not increment REJECTED |
| `FAIL_NEG_KWH` | REJECT; write to ETL_RECORD_ERROR with VAL-USAGE-005 |
| `FAIL_NEG_KW` | REJECT; write to ETL_RECORD_ERROR with VAL-USAGE-006 |
| `FAIL_DATE_ORDER` | REJECT; write to ETL_RECORD_ERROR with VAL-USAGE-003 |
| `FAIL_UNKNOWN_RATE` | REJECT; write to ETL_RECORD_ERROR with VAL-USAGE-007 |

---

## 8. FK Resolution

| Rule | Detail |
|------|--------|
| MU-FK-01 | ENERGY_ACCOUNT_ID: resolved via FK cache from source EA ID |
| MU-FK-02 | PREMISE_ID: resolved via FK cache |
| MU-FK-03 | METER_ID: resolved via FK cache |
| MU-FK-04 | Unresolvable FK → REJECT with VR-FK-001 |

---

## 9. Reconciliation

After load, compare Snowflake view aggregates vs Oracle aggregates for the billing month:

| Measure | Snowflake Query | Oracle Query | Tolerance |
|---------|----------------|-------------|-----------|
| Record count | `COUNT(*)` from view | `COUNT(*)` from MONTHLY_USAGE | 0 (explain with rejected count) |
| KWH total | `SUM(SOURCE_KWH_USAGE)` | `SUM(KWH_USAGE)` | ±0.001 per record |
| Peak KW total | `SUM(PEAK_DEMAND_KW)` | `SUM(PEAK_DEMAND_KW)` | ±0.001 per record |
| Fixed charge total | `SUM(FIXED_CHARGE)` | `SUM(FIXED_CHARGE)` | ±0.01 per record |
| Energy charge total | `SUM(ENERGY_CHARGE_CALC)` | `SUM(ENERGY_CHARGE)` | ±0.01 per record |
| Demand charge total | `SUM(DEMAND_CHARGE_CALC)` | `SUM(DEMAND_CHARGE)` | ±0.01 per record |
| Tax total | `SUM(TAX_AMOUNT_CALC)` | `SUM(TAX_AMOUNT)` | ±0.01 per record |
| Total billed | `SUM(TOTAL_BILLED_CALC)` | `SUM(TOTAL_BILLED_AMOUNT)` | ±0.01 per record |

---

## 10. Acceptance Criteria (Phase 6)

| AC | Criterion |
|----|-----------|
| MU-AC-01 | ~1,000 monthly usage records loaded with all calculated charge fields populated |
| MU-AC-02 | Re-running same billing month produces no duplicates |
| MU-AC-03 | Correction record (newer UPDATED_AT for same key) updates existing row; CORRECTION_FLAG = 'Y' |
| MU-AC-04 | Stale correction (older UPDATED_AT) is skipped |
| MU-AC-05 | TOTAL_BILLED_CALC = FIXED_CHARGE + ENERGY_CHARGE + DEMAND_CHARGE + TAX for all loaded records |
| MU-AC-06 | BILL_TOTAL_VARIANCE populated when source total differs from calculated total |
| MU-AC-07 | Records with FAIL_* USAGE_QUALITY_STATUS rejected; WARN_* records loaded |
| MU-AC-08 | All 8 reconciliation measures match within tolerance |
| MU-AC-09 | Rate plan with NULL demand rate produces DEMAND_CHARGE = 0.00 |
