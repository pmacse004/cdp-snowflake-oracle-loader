# Daily Change Scenarios
## CDP Snowflake-to-Oracle Data Loader — Phase 3

**Document ID:** DG-002
**Version:** 1.0
**Status:** Phase 3 — Approved
**Last Updated:** 2025 (Phase 3)

---

## 1. Overview

Script `08-simulate-daily-changes.sql` generates a controlled set of source-data changes across ~750–1,000 logical records to demonstrate and test the Spring Batch **daily incremental load** defined in ICA-11 (Daily Load Rules).

Each change scenario is assigned an ID (`DC-01` … `DC-09`) that maps to a test case in the Phase 3 test plan.

---

## 2. Change Scenario Summary

| ID | Scenario | Approximate Record Count | Table Modified | UPDATED_AT Bumped |
|---|---|---|---|---|
| DC-01 | New customers | 100 new rows | `CUSTOMER.CUSTOMER` | New row timestamp |
| DC-02 | Customer name changes | ~149 rows | `CUSTOMER.CUSTOMER` | ✅ |
| DC-03a | Primary email changes | ~100 rows | `CUSTOMER.CUSTOMER_CONTACT` | ✅ |
| DC-03b | New secondary phone contacts | ~50 new rows | `CUSTOMER.CUSTOMER_CONTACT` | New row timestamp |
| DC-04 | New energy accounts | ~50 new rows | `CUSTOMER.ENERGY_ACCOUNT` | New row timestamp |
| DC-04b | New billing accounts for DC-04 | ~50 new rows | `CUSTOMER.BILLING_ACCOUNT` | New row timestamp |
| DC-04c | New premises for DC-04 | ~50 new rows | `SERVICE.PREMISE` | New row timestamp |
| DC-04d | New meters for DC-04c | ~50 new rows | `SERVICE.METER` | New row timestamp |
| DC-05 | Billing-account-number changes | ~100 rows | `CUSTOMER.BILLING_ACCOUNT` | ✅ |
| DC-06 | Premise address changes | ~100 rows | `SERVICE.PREMISE` | ✅ |
| DC-07a | Meter removal (old meter inactive) | ~50 rows | `SERVICE.METER` | ✅ |
| DC-07b | New meter installation | ~50 new rows | `SERVICE.METER` | New row timestamp |
| DC-08 | Account closures / inactivation | ~50 rows | `CUSTOMER.ENERGY_ACCOUNT` | ✅ |
| DC-09 | Customer soft-inactivation | ~50 rows | `CUSTOMER.CUSTOMER` | ✅ |

**Approximate total affected logical records: 750–1,000**

---

## 3. Detailed Scenario Descriptions

### DC-01: New Customers
**Business event:** 100 new customers sign up for electric service.

- `CUSTOMER_ID` format: `CUST-D1-000001` … `CUST-D1-000100`
- `STATUS_REASON = 'NEW_DAILY_BATCH_D1'` distinguishes daily-batch customers from initial load
- `CREATED_AT = CURRENT_TIMESTAMP()` → will exceed the initial load watermark
- No energy accounts, contacts or premises created for DC-01 customers in this scenario (they are picked up in DC-04 or subsequent batches)
- **ETL expectation:** 100 new customer INSERT operations via Oracle MERGE

### DC-02: Customer Name Changes
**Business event:** ~149 existing customers update their legal name (e.g., marriage, court order).

- `WHERE MOD(ABS(HASH(CUSTOMER_ID || 'DC02')), 67) = 0` → deterministic subset
- `FIRST_NAME = 'Updated-' || FIRST_NAME` (prefix ensures Spring Batch transformation tests can verify the change)
- `UPDATED_AT = CURRENT_TIMESTAMP()` → exceeds watermark → detected by daily incremental query
- **ETL expectation:** 149 MERGE WHEN MATCHED UPDATE operations

### DC-03a: Primary Email Changes
**Business event:** ~100 customers update their primary email address.

- Email suffix changed to `.upd@example.com`
- `UPDATED_AT` bumped → detected by the `EMAIL_UPDATED_AT` component of the composite watermark in `VW_DAILY_CUSTOMER_ACCOUNT_EXPORT`
- **ETL expectation:** 100 MERGE WHEN MATCHED UPDATE on customer contact data

### DC-03b: New Secondary Phone Contacts
**Business event:** ~50 customers add a secondary phone number.

- Non-primary contacts (`IS_PRIMARY = FALSE`)
- `CONTACT_ID` prefix: `CONT-D1-`
- Does not affect the composite watermark (only primary contacts contribute)
- Loaded as new contact rows if Spring Batch processes contact child records

### DC-04: New Energy Accounts
**Business event:** ~50 existing active customers open a second service account.

- Full chain created: `ENERGY_ACCOUNT → BILLING_ACCOUNT → PREMISE → METER`
- `ENERGY_ACCOUNT_ID` prefix: `EA-D1-`
- `ACCOUNT_STATUS = 'ACTIVE'`, `RATE_CLASS = 'RESIDENTIAL'`
- **ETL expectation:** 50 new energy account INSERT operations with child records

### DC-05: Billing-Account-Number Changes
**Business event:** ~100 billing accounts receive new account numbers (billing system re-keying).

- `BILLING_ACCOUNT_NBR = 'BILL-CHG-' || BILLING_ACCOUNT_NBR` (prefix for traceability)
- `UPDATED_AT` bumped → detected by `BA_UPDATED_AT` component of composite watermark
- **ETL expectation:** 100 Oracle MERGE updates to billing account number on target

### DC-06: Premise Address Changes
**Business event:** ~100 service premises have address corrections (street number/name updates).

- `ADDRESS_LINE1 = 'UPD-' || ADDRESS_LINE1`
- `UPDATED_AT` bumped → detected by `PREM_UPDATED_AT` watermark component
- **ETL expectation:** 100 Oracle MERGE updates to premise address

### DC-07: Meter Replacement
**Business event:** ~50 premises receive new smart meters (AMI upgrade).

- **DC-07a:** Existing meters set `IS_ACTIVE = FALSE`, `REMOVAL_DATE = CURRENT_DATE()`, `UPDATED_AT` bumped
- **DC-07b:** New `AMI` meters inserted (`METER_ID` prefix: `MTR-D1R-`)
- View `active_meter` CTE selects the latest active meter per premise → new meter picked up
- `MTR_UPDATED_AT` watermark component changes → daily load detects the change
- **ETL expectation:** Oracle MERGE updates meter reference on the energy account row

### DC-08: Account Closures / Inactivation
**Business event:** ~50 energy accounts are closed (e.g., customer moves away).

- `ACCOUNT_STATUS = 'INACTIVE'`, `CLOSE_DATE = CURRENT_DATE()`, `UPDATED_AT` bumped
- Account status change propagates through daily view `ACCOUNT_STATUS` column
- **ETL expectation:** Oracle MERGE sets `IS_ACTIVE = 0`, `END_DATE` on target energy account

### DC-09: Customer Soft-Inactivation
**Business event:** ~50 customers are inactivated (e.g., fraud hold, deceased customer).

- `ACCOUNT_STATUS = 'INACTIVE'`, `STATUS_REASON = 'INACTIVATED_DAILY_BATCH_D1'`
- `CUSTOMER_STATUS` column in daily view reflects the change
- **ETL expectation:** Oracle MERGE sets `IS_ACTIVE = 0` on target customer record

---

## 4. Watermark Coverage

The `VW_DAILY_CUSTOMER_ACCOUNT_EXPORT` view uses a 7-component composite watermark:

```sql
GREATEST(
    COALESCE(c.UPDATED_AT,        epoch),   -- DC-02, DC-09
    COALESCE(ea.UPDATED_AT,       epoch),   -- DC-04, DC-08
    COALESCE(cb.BA_UPDATED_AT,    epoch),   -- DC-05
    COALESCE(cp.PREM_UPDATED_AT,  epoch),   -- DC-06
    COALESCE(am.MTR_UPDATED_AT,   epoch),   -- DC-07
    COALESCE(pe.EMAIL_UPDATED_AT, epoch),   -- DC-03a
    COALESCE(pp.PHONE_UPDATED_AT, epoch)    -- (no phone scenario in batch D1)
)
```

Every DC scenario that bumps an `UPDATED_AT` value will increase the `RECORD_EFFECTIVE_TS` for the affected energy account row. The Spring Batch watermark query `WHERE RECORD_EFFECTIVE_TS > :lastWatermark` will detect these rows.

---

## 5. Idempotency and Repeat Safety

| Guard | Mechanism |
|---|---|
| DC-01 new customers | `WHERE (SELECT COUNT(*) … WHERE CUSTOMER_ID LIKE 'CUST-D1-%') = 0` |
| DC-02 name changes | `AND UPDATED_AT < DATEADD(MINUTE, -5, CURRENT_TIMESTAMP())` (will not re-update recently changed rows) |
| DC-03b new contacts | `AND NOT EXISTS (SELECT 1 … WHERE CONTACT_ID LIKE 'CONT-D1-%')` |
| DC-04 new accounts | `WHERE (SELECT COUNT(*) … WHERE ENERGY_ACCOUNT_ID LIKE 'EA-D1-%') = 0` |
| DC-07b new meters | `AND NOT EXISTS (SELECT 1 … WHERE METER_ID LIKE 'MTR-D1R-%')` |

Rerunning the script after the first execution will skip all guarded operations and affect 0 rows.

---

## 6. Expected Spring Batch Daily Load Results

| Metric | Expected Value |
|---|---|
| Records read from daily view | ~900–1,100 (changed records since last watermark) |
| Records inserted | ~150–200 (new customers + new accounts + new meters) |
| Records updated | ~550–700 (name/contact/billing/premise/meter/status changes) |
| Records skipped | ~0 (no stale duplicates on first run) |
| Records rejected | ~0 (all daily batch data is valid) |
| New watermark | `CURRENT_TIMESTAMP()` at time of daily batch execution |
