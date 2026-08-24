# ICA Context Document 14 — Reconciliation Rules

**ICA Document ID:** ICA-14
**Project:** CDP Snowflake to Oracle Data Loader
**Version:** 1.1 (Phase 1 Amendment)
**Status:** Phase 1 — Amended
**Last Updated:** 2025 (Phase 1 Amendment)

**Amendment:** Reconciliation now covers derived datasets from multi-table views. Monthly usage reconciliation includes all 8 charge measures (fixed, energy, demand, tax, subtotal, total billed). Rounding tolerances are explicitly specified.

---

## 1. Purpose

This document defines the reconciliation strategy for verifying completeness and accuracy of each load. Reconciliation compares source Snowflake aggregates (from the extraction views) to Oracle target aggregates.

---

## 2. Reconciliation Step

Every load job includes a final reconciliation step that:

1. Queries Snowflake for source counts and aggregates (using the same extraction scope as the load).
2. Queries Oracle for target counts and aggregates.
3. Computes differences.
4. Writes one `ETL_RECONCILIATION` row per entity.
5. Sets overall `ETL_JOB_RUN.RECON_STATUS`.

---

## 3. Reconciliation Queries

### 3.1 Initial Load — Entity Count Reconciliation

The initial load reads from `VW_DAILY_CUSTOMER_ACCOUNT_EXPORT`. Source count is the number of distinct ENERGY_ACCOUNT_IDs in the view; target count is the Oracle table row count.

```sql
-- Source: distinct energy account records in the view
SELECT COUNT(*) AS SRC_COUNT
FROM CDP_DW.CLEAN.VW_DAILY_CUSTOMER_ACCOUNT_EXPORT;

-- Target: per entity table
SELECT COUNT(*) AS TGT_COUNT FROM CDP_APP.CUSTOMER;
SELECT COUNT(*) AS TGT_COUNT FROM CDP_APP.ENERGY_ACCOUNT;
-- etc.
```

### 3.2 Daily Load — Delta Reconciliation

The daily load builds a candidate set from 6 source tables. Source delta count is the size of the candidate set; target count is INSERT + UPDATE from ETL_JOB_RUN counters per entity.

```sql
-- Source delta: size of the UNION candidate set (see ICA-09 Section 3.2)
-- Captured in ETL_JOB_RUN.RECORDS_READ at job start

-- Balance check per entity:
-- source_delta = inserted + updated + skipped + rejected
-- If source_delta ≠ (inserted + updated + skipped + rejected): RECON_STATUS = FAIL
```

### 3.3 Monthly Usage — Aggregate Reconciliation (8 measures)

```sql
-- Source (Snowflake — from the usage billing view)
SELECT COUNT(*)                   AS SRC_COUNT,
       SUM(SOURCE_KWH_USAGE)      AS SRC_KWH,
       SUM(PEAK_DEMAND_KW)        AS SRC_KW,
       SUM(FIXED_CHARGE)          AS SRC_FIXED_CHARGE,
       SUM(ENERGY_CHARGE_CALC)    AS SRC_ENERGY_CHARGE,
       SUM(DEMAND_CHARGE_CALC)    AS SRC_DEMAND_CHARGE,
       SUM(TAX_AMOUNT_CALC)       AS SRC_TAX,
       SUM(TOTAL_BILLED_CALC)     AS SRC_TOTAL_BILLED
FROM CDP_DW.CLEAN.VW_MONTHLY_USAGE_BILLING_EXPORT
WHERE BILLING_MONTH = :billingMonth;

-- Target (Oracle)
SELECT COUNT(*)                   AS TGT_COUNT,
       SUM(KWH_USAGE)             AS TGT_KWH,
       SUM(PEAK_DEMAND_KW)        AS TGT_KW,
       SUM(FIXED_CHARGE)          AS TGT_FIXED_CHARGE,
       SUM(ENERGY_CHARGE)         AS TGT_ENERGY_CHARGE,
       SUM(DEMAND_CHARGE)         AS TGT_DEMAND_CHARGE,
       SUM(TAX_AMOUNT)            AS TGT_TAX,
       SUM(TOTAL_BILLED_AMOUNT)   AS TGT_TOTAL_BILLED
FROM CDP_APP.MONTHLY_USAGE
WHERE BILLING_MONTH = :billingMonth;
```

---

## 4. Reconciliation Pass/Fail Logic

### 4.1 Count Reconciliation

| Rule ID | Rule |
|---------|------|
| RECON-CNT-01 | `COUNT_DIFFERENCE = SOURCE_COUNT − TARGET_COUNT` |
| RECON-CNT-02 | If `COUNT_DIFFERENCE = 0`: COUNT status = PASS |
| RECON-CNT-03 | If `COUNT_DIFFERENCE > 0` and `COUNT_DIFFERENCE ≤ RECORDS_REJECTED`: COUNT status = PASS with note "Difference explained by rejected records" |
| RECON-CNT-04 | If `COUNT_DIFFERENCE > RECORDS_REJECTED` or `COUNT_DIFFERENCE < 0`: COUNT status = FAIL |

### 4.2 KWH Aggregate Reconciliation

| Rule ID | Rule |
|---------|------|
| RECON-KWH-01 | `KWH_DIFFERENCE = SOURCE_KWH_TOTAL − TARGET_KWH_TOTAL` |
| RECON-KWH-02 | Tolerance: `abs(KWH_DIFFERENCE) ≤ 0.001 × TARGET_COUNT` (rounding tolerance for scale-3 → scale-6 conversion, per record) |
| RECON-KWH-03 | Outside tolerance: FAIL |

### 4.3 KW Aggregate Reconciliation

Same rules as KWH (tolerance = 0.001 × TARGET_COUNT).

### 4.4 Fixed Charge Reconciliation

| Rule ID | Rule |
|---------|------|
| RECON-FIXED-01 | `FIXED_DIFF = SRC_FIXED_CHARGE − TGT_FIXED_CHARGE` |
| RECON-FIXED-02 | Tolerance: `abs(FIXED_DIFF) ≤ 0.01 × TARGET_COUNT` (penny per record) |
| RECON-FIXED-03 | Outside tolerance: FAIL |

### 4.5 Energy Charge Reconciliation

| Rule ID | Rule |
|---------|------|
| RECON-ENERGY-01 | `ENERGY_DIFF = SRC_ENERGY_CHARGE − TGT_ENERGY_CHARGE` |
| RECON-ENERGY-02 | Tolerance: `abs(ENERGY_DIFF) ≤ 0.01 × TARGET_COUNT` |
| RECON-ENERGY-03 | Outside tolerance: FAIL |

### 4.6 Demand Charge Reconciliation

| Rule ID | Rule |
|---------|------|
| RECON-DEMAND-01 | `DEMAND_DIFF = SRC_DEMAND_CHARGE − TGT_DEMAND_CHARGE` |
| RECON-DEMAND-02 | Tolerance: `abs(DEMAND_DIFF) ≤ 0.01 × TARGET_COUNT` |
| RECON-DEMAND-03 | Outside tolerance: FAIL |

### 4.7 Tax Reconciliation

| Rule ID | Rule |
|---------|------|
| RECON-TAX-01 | `TAX_DIFF = SRC_TAX − TGT_TAX` |
| RECON-TAX-02 | Tolerance: `abs(TAX_DIFF) ≤ 0.01 × TARGET_COUNT` |
| RECON-TAX-03 | Outside tolerance: FAIL |

### 4.8 Total Billed Amount Reconciliation

| Rule ID | Rule |
|---------|------|
| RECON-BILL-01 | `BILLED_DIFFERENCE = SOURCE_BILLED_TOTAL − TARGET_BILLED_TOTAL` |
| RECON-BILL-02 | Tolerance: `abs(BILLED_DIFFERENCE) ≤ 0.01 × TARGET_COUNT` (penny per record) |
| RECON-BILL-03 | Outside tolerance: FAIL |

### 4.5 Overall Run RECON_STATUS

```
RECON_STATUS = PASS if all entity-level statuses are PASS
RECON_STATUS = FAIL if any entity-level status is FAIL
```

---

## 5. ETL_RECONCILIATION Schema

Each entity produces one row per job run:

| Column | Type | Description |
|--------|------|-------------|
| RECON_ID | NUMBER(15) PK | Auto-generated |
| RUN_ID | NUMBER(15) FK | FK → ETL_JOB_RUN |
| ENTITY_NAME | VARCHAR2(50) | e.g., 'CUSTOMER', 'MONTHLY_USAGE' |
| SOURCE_COUNT | NUMBER(15) | Count from Snowflake |
| TARGET_COUNT | NUMBER(15) | Count from Oracle |
| COUNT_DIFFERENCE | NUMBER(15) | SOURCE - TARGET |
| SOURCE_KWH_TOTAL | NUMBER(20,6) | Monthly usage only |
| TARGET_KWH_TOTAL | NUMBER(20,6) | Monthly usage only |
| KWH_DIFFERENCE | NUMBER(20,6) | Monthly usage only |
| SOURCE_KW_TOTAL | NUMBER(20,6) | Monthly usage only |
| TARGET_KW_TOTAL | NUMBER(20,6) | Monthly usage only |
| KW_DIFFERENCE | NUMBER(20,6) | Monthly usage only |
| SOURCE_BILLED_TOTAL | NUMBER(20,2) | Monthly usage only |
| TARGET_BILLED_TOTAL | NUMBER(20,2) | Monthly usage only |
| BILLED_DIFFERENCE | NUMBER(20,2) | Monthly usage only |
| RECON_STATUS | VARCHAR2(20) | PASS / FAIL |
| RECON_NOTES | VARCHAR2(1000) | Explanation of discrepancies |
| CREATED_AT | TIMESTAMP | UTC |

---

## 6. Dashboard Reconciliation View

The dashboard must show:
- Latest reconciliation per entity (counts, KWH, KW, billed)
- PASS/FAIL indicator per entity
- Overall run PASS/FAIL
- Historical reconciliation table (job run history)
- Download as CSV

---

## 7. Acceptance Criteria (Phase 6)

| AC | Criterion |
|----|-----------|
| RECON-AC-01 | Initial load reconciliation shows 0 count difference for all entities. |
| RECON-AC-02 | Monthly usage reconciliation shows 0 KWH difference (within tolerance). |
| RECON-AC-03 | Monthly usage reconciliation shows 0 billed-amount difference (within penny-per-record tolerance). |
| RECON-AC-04 | Reconciliation correctly identifies rejected records as the explanation for count differences. |
| RECON-AC-05 | Reconciliation report can be downloaded from the dashboard. |
| RECON-AC-06 | RECON_STATUS = FAIL causes ETL_JOB_RUN.RECON_STATUS = FAIL. |
