# Phase 3 Test Plan
## CDP Snowflake-to-Oracle Data Loader

**Document ID:** TP-003
**Version:** 1.0
**Status:** Phase 3 — Approved
**Last Updated:** 2025 (Phase 3)

---

## 1. Scope

This test plan covers all validation activities for Phase 3 (Snowflake synthetic data generation). It does not cover Spring Batch ETL execution (Phase 5/6) or frontend tests (Phase 8). Tests in this plan are executed against Snowflake SQL scripts and can be run without a running Spring Boot application.

---

## 2. Test Environment

| Component | Value |
|---|---|
| Snowflake account | `LJPNAFI-RW79936` |
| Database | `CDP_UTIL_DB` |
| Schemas | `REF`, `CUSTOMER`, `SERVICE`, `BILLING`, `STAGING` |
| Execution role | `CDP_ADMIN_ROLE` |
| Test execution | Manual worksheet run of `07-validate-initial-data.sql` and `10-validate-export-views.sql` |

---

## 3. Test Categories

| Category | Script | Check IDs |
|---|---|---|
| Row counts | 07 | V-RC-001 to V-RC-009 |
| Referential integrity | 07 | V-RI-001 to V-RI-007 |
| Duplicate key | 07 | V-DK-001 to V-DK-005 |
| Mandatory fields | 07 | V-MF-001 to V-MF-004 |
| Invalid status/code | 07 | V-CV-001 to V-CV-005 |
| Usage data quality | 07 | V-UQ-001 to V-UQ-007 |
| Contact constraints | 07 | V-CC-001 to V-CC-002 |
| Meter constraints | 07 | V-MC-001 to V-MC-002 |
| Timestamp ordering | 07 | V-TS-001 to V-TS-003 |
| Daily view coverage | 10 | V-DV-001 to V-DV-012 |
| Monthly view coverage | 10 | V-MV-001 to V-MV-007 |
| Charge reconciliation | 10 | V-CR-001 to V-CR-005 |
| Aggregate reconciliation | 10 | V-AR-001 to V-AR-002 |
| VARIANT NULL handling | 10 | V-VN-001 to V-VN-005 |
| Invalid records present | 10 | V-IR-001 |
| Incremental change coverage | 10 | V-IC-001 to V-IC-002 |

---

## 4. Test Cases

### 4.1 Row Count Tests

| ID | Test Name | Expected | Pass Criterion |
|---|---|---|---|
| V-RC-001 | CUSTOMER rows | ≥ 10,000 | `COUNT(*) >= 10000` |
| V-RC-002 | CUSTOMER_CONTACT rows | ≥ 10,000 | `COUNT(*) >= 10000` |
| V-RC-003 | ENERGY_ACCOUNT rows | ≥ 10,000 | `COUNT(*) >= 10000` |
| V-RC-004 | BILLING_ACCOUNT rows | ≥ 10,000 | `COUNT(*) >= 10000` |
| V-RC-005 | PREMISE rows | ≥ 10,000 | `COUNT(*) >= 10000` |
| V-RC-006 | METER rows | ≥ 10,000 | `COUNT(*) >= 10000` |
| V-RC-007 | MONTHLY_USAGE rows | ≥ 25,000 | `COUNT(*) >= 25000` |
| V-RC-008 | REF.CODE_VALUE rows | ≥ 43 | `COUNT(*) >= 43` |
| V-RC-009 | RATE_PLAN codes | = 9 | `COUNT(*) = 9` |

### 4.2 Referential Integrity Tests

| ID | Test Name | Expected | Pass Criterion |
|---|---|---|---|
| V-RI-001 | CUSTOMER_CONTACT orphans | 0 | No orphaned contacts |
| V-RI-002 | ENERGY_ACCOUNT orphans | 0 | No orphaned accounts |
| V-RI-003 | BILLING_ACCOUNT orphans | 0 | No orphaned billing accounts |
| V-RI-004 | PREMISE orphans | 0 | No orphaned premises |
| V-RI-005 | METER orphans | 0 | No orphaned meters |
| V-RI-006 | MONTHLY_USAGE orphans | 0 | No orphaned usage rows |
| V-RI-007 | MONTHLY_USAGE rate plan FK | 0 | All RATE_PLAN codes in REF |

### 4.3 Duplicate Key Tests

| ID | Test Name | Expected | Pass Criterion |
|---|---|---|---|
| V-DK-001 | CUSTOMER_ID duplicates | 0 | No duplicate IDs |
| V-DK-002 | ACCOUNT_NUMBER duplicates | 0 | No duplicate account numbers |
| V-DK-003 | METER_NUMBER duplicates | 0 | No duplicate meter numbers |
| V-DK-004 | Usage (EA, month) duplicates | 0 | No duplicate business keys |
| V-DK-005 | REF (domain, code) duplicates | 0 | No duplicate reference codes |

### 4.4 Usage Data Quality Tests

| ID | Test Name | Expected | Pass Criterion |
|---|---|---|---|
| V-UQ-001 | Negative KWH | ≤ 5 (only intended invalids) | At most controlled invalid rows |
| V-UQ-002 | Negative PEAK_DEMAND | 0 | No negative demand |
| V-UQ-003 | Curr reading < prev reading | 0 | No inverted readings |
| V-UQ-004 | Inverted billing period | ≤ 2 (controlled invalids) | Only intended invalids |
| V-UQ-005 | Billing days out of range | ≤ 2 (controlled invalids) | Only intended invalids |
| V-UQ-006 | Negative TOTAL_BILLED | 0 | No negative totals |
| V-UQ-007 | Negative charge components | 0 | No negative charges |

### 4.5 Charge Calculation Reconciliation Tests

| ID | Test Name | Expected | Pass Criterion |
|---|---|---|---|
| V-CR-001 | Total = Subtotal + Tax | 0 violations | Additive form exact |
| V-CR-002 | Subtotal = Fixed + Energy + Demand | 0 violations | Component sum exact |
| V-CR-003 | No negative CALC charges | 0 violations | All charges ≥ 0 |
| V-CR-004 | Null demand rate → 0 demand charge | 0 violations | ICA MU-AC-09 verified |
| V-CR-005 | Source total vs calculated total | ≤ tolerance | Within 0.05 per record |

### 4.6 VARIANT Conversion Tests

| ID | Test Name | Input | Expected |
|---|---|---|---|
| V-VN-001 | Valid JSON number | `{"fixed":8.50}` | `8.50` |
| V-VN-002 | Quoted number string | `{"fixed":"8.50"}` | `8.50` |
| V-VN-003 | Missing key | `{}` | `NULL` |
| V-VN-004 | JSON null | `{"demand":null}` | `NULL` |
| V-VN-005 | Non-numeric text | `{"fixed":"N/A"}` | `NULL` (no exception) |

---

## 5. Test Execution Procedure

### 5.1 Prerequisites
1. Snowflake account connected as `CDP_ADMIN_ROLE`
2. `05-seed-reference-data.sql` executed successfully
3. `06-generate-initial-data.sql` executed successfully
4. `08-simulate-daily-changes.sql` executed successfully
5. `09-simulate-monthly-usage.sql` executed successfully

### 5.2 Execution Steps

```
Step 1: Open Snowflake worksheet
Step 2: Set role: USE ROLE CDP_ADMIN_ROLE
Step 3: Set database: USE DATABASE CDP_UTIL_DB
Step 4: Run 07-validate-initial-data.sql — review all PASS/FAIL/WARN results
Step 5: Run 10-validate-export-views.sql — review all PASS/FAIL/WARN results
Step 6: Capture results for phase-3-completion-report.md
```

### 5.3 Pass Criteria
All tests must return `STATUS = 'PASS'`.
`STATUS = 'WARN'` is acceptable for V-DV-006 (some emails may be missing for non-primary contacts), V-CR-005 (charge tolerance), and V-IC-001/V-IC-002 (only if daily batch not yet run).
Any `STATUS = 'FAIL'` must be investigated and resolved before Phase 4 begins.

---

## 6. Test Traceability

| Test ID | ICA Rule | Acceptance Criterion |
|---|---|---|
| V-RC-001 | DA-06 | 10,000 customers generated |
| V-DK-004 | MU-DEDUP-01 | No duplicate (EA, BILLING_MONTH) |
| V-UQ-001 | VR-USAGE-005 | Negative KWH rejects |
| V-UQ-003 | VR-USAGE-004 | Inverted readings rejects |
| V-CR-001 | TR-BILL-07 | TOTAL = SUBTOTAL + TAX |
| V-CR-004 | MU-AC-09 | NULL demand → 0 demand charge |
| V-VN-003 | ICA-12 §4.1 | Missing rate key → NULL |
| V-VN-004 | ICA-12 §4.1 | JSON null → NULL |
| V-IR-001 | ICA-07 VR-USAGE-005 | Invalid records present for rejection test |

---

## 7. Known Gaps (addressed in later phases)

| Gap | Resolved in |
|---|---|
| Spring Batch watermark boundary tests | Phase 5 |
| Oracle target record count reconciliation | Phase 6 |
| Restartability tests | Phase 5 |
| Performance test (10,000+ customers through pipeline) | Phase 6 |
| Frontend component tests | Phase 8 |
