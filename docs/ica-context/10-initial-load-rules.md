# ICA Context Document 10 — Initial Load Rules

**ICA Document ID:** ICA-10  
**Project:** CDP Snowflake to Oracle Data Loader  
**Version:** 1.0  
**Status:** Phase 1 — Approved  
**Last Updated:** 2025 (Phase 1)

---

## 1. Purpose

This document defines all rules governing the initial full-load of Snowflake source data into Oracle. The initial load is a one-time operation (re-runnable / idempotent) that establishes the baseline Oracle dataset.

---

## 2. Trigger

| Trigger ID | Method | Description |
|------------|--------|-------------|
| IL-TRIG-01 | REST API | `POST /api/v1/jobs/initial-load` — manual trigger only |
| IL-TRIG-02 | No scheduler | The initial load is NOT scheduled; it is manual only |

---

## 3. Pre-conditions

| Rule ID | Rule |
|---------|------|
| IL-PRE-01 | Oracle schemas CDP_APP, CDP_CTL, CDP_BATCH must exist (created by Flyway migrations). |
| IL-PRE-02 | All Flyway migrations must have completed successfully. |
| IL-PRE-03 | The Snowflake source must be accessible using the service user credentials. |
| IL-PRE-04 | `ETL_WATERMARK` must be seeded with epoch-zero rows for all entities (Flyway data migration). |
| IL-PRE-05 | Only one initial load job may run at a time (enforced by Spring Batch duplicate-run check). |
| IL-PRE-06 | If a previous initial load completed successfully, a second full initial load requires a manual watermark reset or will behave as an incremental load (which is safe and correct). |

---

## 4. Load Sequence

The initial load job executes steps in strict dependency order:

```
Step 1:  loadReferenceData      → CDP_APP.REF_CODE_VALUE
Step 2:  loadCustomers          → CDP_APP.CUSTOMER
Step 3:  loadCustomerContacts   → CDP_APP.CUSTOMER_CONTACT
Step 4:  loadEnergyAccounts     → CDP_APP.ENERGY_ACCOUNT
Step 5:  loadBillingAccounts    → CDP_APP.BILLING_ACCOUNT
Step 6:  loadServicePremises    → CDP_APP.SERVICE_PREMISE
Step 7:  loadMeters             → CDP_APP.METER
Step 8:  loadMonthlyUsage       → CDP_APP.MONTHLY_USAGE
Step 9:  reconcileInitialLoad   → CDP_CTL.ETL_RECONCILIATION
```

If any step fails before Step 9, the job is marked FAILED and can be restarted.

---

## 5. Extraction

| Rule ID | Rule |
|---------|------|
| IL-EXT-01 | Each entity is extracted with `ORDER BY UPDATED_AT ASC, <PK> ASC` with no watermark filter (watermark = epoch zero on first run). |
| IL-EXT-02 | Extraction uses configurable JDBC fetch size (default 500). |
| IL-EXT-03 | For each entity, the maximum `(UPDATED_AT, SOURCE_ID)` seen in the extract must be tracked for watermark advancement. |

---

## 6. Transformation

All transformation rules in ICA-06 and validation rules in ICA-07 apply during initial load exactly as during incremental loads.

---

## 7. Loading

| Rule ID | Rule |
|---------|------|
| IL-LD-01 | All writes use Oracle MERGE on the entity business key (see EM-01 through EM-08). |
| IL-LD-02 | Each entity is written in configurable chunks (default 500 rows per commit). |
| IL-LD-03 | The watermark for each entity is updated after each chunk commit (per WM-01 through WM-07). |
| IL-LD-04 | `CREATED_AT` / `CREATED_BY` are set on INSERT; `UPDATED_AT` / `UPDATED_BY` on INSERT and UPDATE. |
| IL-LD-05 | FK lookups use an in-memory cache populated during the parent entity's load step. |
| IL-LD-06 | The FK cache for each entity must be populated before child entity processing begins. |

---

## 8. FK Cache Population

Before child entity processing begins, the FK cache is populated:

```
After loadCustomers completes:
  Populate cache: {sourceCustomerId → targetCustomerId} from CDP_APP.CUSTOMER

After loadEnergyAccounts completes:
  Populate cache: {sourceEnergyAccountId → targetEnergyAccountId}

After loadServicePremises completes:
  Populate cache: {sourcePremiseId → targetPremiseId}
```

This is a read of the full target entity table (or the recently written subset) into Java memory.

---

## 9. Error Handling

All error handling rules in ICA-13 apply during initial load. Key points:
- A rejected record does not stop the step unless the fatal-error threshold is exceeded.
- Rejected records are written to `ETL_RECORD_ERROR`.
- The watermark still advances past the rejected record (via the next successfully written record).

---

## 10. Completion

| Rule ID | Rule |
|---------|------|
| IL-COMP-01 | On successful completion of all data-load steps, the reconciliation step runs. |
| IL-COMP-02 | `ETL_JOB_RUN` is updated with status=COMPLETED, counts, end_time, and final watermark values. |
| IL-COMP-03 | `ETL_RECONCILIATION` is populated with source and target counts and aggregate totals for each entity. |

---

## 11. Idempotency

| Rule ID | Rule |
|---------|------|
| IL-IDEM-01 | Re-running the initial load job is safe because all writes are MERGE operations. |
| IL-IDEM-02 | Re-running after a reset watermark (epoch zero) will re-process all records and update them to their current source values — no duplicates. |
| IL-IDEM-03 | `SOURCE_*_ID` unique constraints on target tables prevent phantom duplicates even if MERGE were bypassed. |

---

## 12. Acceptance Criteria (for Phase 4 testing)

| AC | Criterion |
|----|-----------|
| IL-AC-01 | All ~10,000 customers loaded to Oracle with zero duplicates. |
| IL-AC-02 | All child entity counts match expected ratios. |
| IL-AC-03 | Reconciliation step reports 0 count difference for all entities. |
| IL-AC-04 | Monthly usage KWH, KW and billed totals match source aggregates. |
| IL-AC-05 | All rejected records written to ETL_RECORD_ERROR with correct error codes. |
| IL-AC-06 | Re-running the initial load produces identical Oracle state (no extra rows). |
| IL-AC-07 | Watermarks advanced to maximum UPDATED_AT/SOURCE_ID per entity after completion. |
