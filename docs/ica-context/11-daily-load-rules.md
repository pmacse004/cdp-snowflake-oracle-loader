# ICA Context Document 11 — Daily Load Rules

**ICA Document ID:** ICA-11  
**Project:** CDP Snowflake to Oracle Data Loader  
**Version:** 1.1 (Phase 1 Amendment)  
**Status:** Phase 1 — Amended  
**Last Updated:** 2025 (Phase 1 Amendment)

**Amendment:** Daily load now uses multi-source change-candidate detection via UNION of per-table watermark queries, with full-state extraction from VW_DAILY_CUSTOMER_ACCOUNT_EXPORT for affected records.

---

## 1. Purpose

This document defines all rules governing the daily incremental load, which detects and loads changes from Snowflake to Oracle since the last successful watermark across all contributing source tables.

---

## 2. Trigger

| Trigger ID | Method | Description |
|------------|--------|-------------|
| DL-TRIG-01 | Scheduler | Cron expression configurable in `application.yml`; default `0 0 2 * * ?` (2:00 AM UTC) |
| DL-TRIG-02 | REST API | `POST /api/v1/jobs/daily-load` — manual on-demand trigger |

---

## 3. Supported Change Types

| Change ID | Change Type | Detected Via | Example |
|-----------|------------|-------------|---------|
| DL-CHG-01 | New customer | `CUSTOMER.UPDATED_AT` watermark | Customer record inserted |
| DL-CHG-02 | Customer name update | `CUSTOMER.UPDATED_AT` watermark | FIRST_NAME or LAST_NAME changed |
| DL-CHG-03 | Primary contact change | `CUSTOMER_CONTACT.UPDATED_AT` watermark | Email address updated |
| DL-CHG-04 | New contact record | `CUSTOMER_CONTACT.UPDATED_AT` watermark | New mailing address added |
| DL-CHG-05 | New energy account | `ENERGY_ACCOUNT.UPDATED_AT` watermark | Account opened |
| DL-CHG-06 | Billing account number change | `BILLING_ACCOUNT.UPDATED_AT` watermark | New billing account effective |
| DL-CHG-07 | Premise change | `SERVICE_PREMISE.UPDATED_AT` watermark | Address correction |
| DL-CHG-08 | Account closure | `ENERGY_ACCOUNT.UPDATED_AT` watermark | ACCOUNT_STATUS → CLOSED |
| DL-CHG-09 | Customer inactivation | `CUSTOMER.UPDATED_AT` watermark | ACCOUNT_STATUS → INACTIVE |
| DL-CHG-10 | Meter replacement | `METER.UPDATED_AT` watermark | New meter installed, old removed |
| DL-CHG-11 | Rate-plan code label change | `CODE_VALUE.UPDATED_AT` watermark | Description updated in REF table |
| DL-CHG-12 | Soft delete | `CUSTOMER.UPDATED_AT` or `ENERGY_ACCOUNT.UPDATED_AT` | DELETED_FLAG → Y |

---

## 4. Multi-Source Change Detection

See ICA-09 Section 3 for the complete multi-source watermark strategy. Summary for daily load:

### 4.1 Per-Table Watermarks Used

| Table | Watermark Label | Yields |
|-------|----------------|--------|
| `RAW.CUSTOMER` | `(cust_last_ts, cust_last_id)` | Affected ENERGY_ACCOUNT_IDs via JOIN |
| `RAW.CUSTOMER_CONTACT` | `(contact_last_ts, contact_last_id)` | Affected ENERGY_ACCOUNT_IDs via CUSTOMER_ID JOIN |
| `RAW.ENERGY_ACCOUNT` | `(ea_last_ts, ea_last_id)` | Direct ENERGY_ACCOUNT_IDs |
| `RAW.BILLING_ACCOUNT` | `(ba_last_ts, ba_last_id)` | Affected ENERGY_ACCOUNT_IDs via FK |
| `RAW.SERVICE_PREMISE` | `(sp_last_ts, sp_last_id)` | Affected ENERGY_ACCOUNT_IDs via FK |
| `RAW.METER` | `(meter_last_ts, meter_last_id)` | Affected ENERGY_ACCOUNT_IDs via PREMISE→ENERGY_ACCOUNT |
| `REF.CODE_VALUE` | `(code_last_ts, code_last_id)` | Broad re-extract if domain in {ACCT_STATUS, RATE_PLAN, CUST_TYPE} |

### 4.2 Reference-Data Broad Re-extract

If any CODE_VALUE in domains `{ACCT_STATUS, RATE_PLAN, CUST_TYPE}` changed:
- All ENERGY_ACCOUNTs using the affected code are added to the candidate set
- The CODE_VALUE table itself is reloaded first (Step 1 of the job)

This may cause a large number of accounts to be re-extracted in a single daily run. The operator will see this in `ETL_JOB_RUN.RECORDS_READ`.

---

## 5. Load Sequence

```
Step 1:  loadChangedReferenceData     (direct from REF.CODE_VALUE, per-table watermark)
Step 2:  buildChangeCandidateSet      (UNION query across 6 tables; produces candidate EA_ID list)
Step 3:  loadChangedCustomers         (from VW_DAILY_CUSTOMER_ACCOUNT_EXPORT WHERE EA_ID IN candidates)
Step 4:  loadChangedCustomerContacts  (same view, ranked_contact columns)
Step 5:  loadChangedEnergyAccounts    (same view, EA columns)
Step 6:  loadChangedBillingAccounts   (same view, ranked_billing columns)
Step 7:  loadChangedServicePremises   (same view, SERVICE_PREMISE columns)
Step 8:  loadChangedMeters            (same view, ranked_meter columns)
Step 9:  reconcileDailyLoad
```

Step 2 is a read-only Snowflake query. Steps 3–8 each project the relevant columns from the same view over the same candidate set.

---

## 6. Soft Delete / Inactivation Rules (unchanged from v1.0)

| Rule ID | Rule |
|---------|------|
| DL-SD-01 | Source `DELETED_FLAG = 'Y'` (customer or energy account) → IS_ACTIVE=0, DELETED_AT set, DELETION_REASON='SOURCE_DELETED' |
| DL-SD-02 | `COMBINED_STATUS_CODE` of INACTIVE or CLOSED → IS_ACTIVE=0 |
| DL-SD-03 | Soft-deleted records preserved in Oracle; physical DELETE never performed |
| DL-SD-04 | Re-activation in source (DELETED_FLAG returns N) → MERGE updates IS_ACTIVE back to 1, DELETED_AT → NULL |

---

## 7. Watermark Rules

All watermark rules from ICA-09 apply. Key specifics for daily load:

| Rule ID | Rule |
|---------|------|
| DL-WM-01 | Per-table watermarks used with `JOB_TYPE = 'DAILY'` |
| DL-WM-02 | After the initial load completes, DAILY watermarks are set equal to INITIAL watermarks via a post-initial-load step listener |
| DL-WM-03 | The candidate-union query snapshot is taken at job start; watermarks do not advance until the associated chunk commits |
| DL-WM-04 | Each table's watermark advances based on the `{TABLE}_UPDATED_AT` and `{TABLE}_ID_FOR_WM` columns present in the view output |

---

## 8. Reconciliation

After all data-load steps complete:

| Measure | Source | Target | Tolerance |
|---------|--------|--------|-----------|
| Customer delta count | Rows in CUSTOMER changed since watermark | New INSERT + UPDATE count from ETL_JOB_RUN | rejected_count explains difference |
| Contact delta count | Same | Same | Same |
| Energy account delta count | Same | Same | Same |
| Billing account delta count | Same | Same | Same |
| Premise delta count | Same | Same | Same |
| Meter delta count | Same | Same | Same |

No KWH/billed totals for daily load (those are monthly-only metrics).

---

## 9. Acceptance Criteria (Phase 6 testing)

| AC | Criterion |
|----|-----------|
| DL-AC-01 | A contact email change in Snowflake propagates to Oracle in the next daily run even though CUSTOMER.UPDATED_AT did not change |
| DL-AC-02 | A billing account number change propagates via the BILLING_ACCOUNT watermark |
| DL-AC-03 | A meter replacement (new meter record) propagates via the METER watermark |
| DL-AC-04 | A rate-plan code label change triggers re-extract for all accounts using that plan |
| DL-AC-05 | Re-running the same daily load does not create duplicates |
| DL-AC-06 | Watermark not advanced when step fails mid-chunk |
| DL-AC-07 | Restart after failure re-processes only records beyond the last safe watermark |
| DL-AC-08 | 1,000 changed records (spread across 4+ contributing tables) processed in ≤ 5 minutes |
| DL-AC-09 | COMBINED_STATUS_CODE correctly derived when CUSTOMER=ACT but ENERGY_ACCOUNT=CLO → CLOSED |
