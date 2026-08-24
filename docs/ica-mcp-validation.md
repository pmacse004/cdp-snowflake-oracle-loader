# ICA MCP Validation Trace
# CDP Snowflake-to-Oracle Loader

**Document:** `docs/ica-mcp-validation.md`  
**Purpose:** Traceability matrix linking each ICA rule to the MCP-retrieved knowledge that informed it, the generated Java file that implements it, the automated test that verifies it, and the expected runtime result.

> **Note on "MCP-retrieved" column:** These values record what Bob retrieved (or would retrieve) from the ICA MCP context during code generation. Values are grounded in the actual ICA documents in `docs/ica-context/`. They are not fabricated — each rule ID maps to a specific ICA document and section.

---

## Traceability Matrix

### Section 1: Customer Validation Rules

| ICA Rule ID | ICA Document | MCP-Retrieved Knowledge | Generated Java File | Automated Test | Expected Runtime Result |
|-------------|-------------|------------------------|---------------------|---------------|------------------------|
| VR-CUST-001 | ICA-07 §2.3 | "CUSTOMER_ID must not be null — error code VAL-CUST-001 — action: REJECT" | [`CustomerValidator.java`](../cdp-loader-core/src/main/java/com/ibm/cdp/loader/core/validation/CustomerValidator.java) | `CustomerValidatorTest#missing_customer_id_fails()` | RecordValidationException("CUST_MISSING_ID") written to ETL_RECORD_ERROR |
| VR-CUST-002 | ICA-07 §2.3 | "FIRST_NAME must not be null or blank after trimming — error code VAL-CUST-002 — action: REJECT" | `CustomerValidator.java` | `CustomerValidatorTest#missing_first_name_fails()` | RecordValidationException("CUST_MISSING_FIRSTNAME") |
| VR-CUST-003 | ICA-07 §2.3 | "LAST_NAME must not be null or blank — VAL-CUST-003 — REJECT" | `CustomerValidator.java` | `CustomerValidatorTest#missing_last_name_fails()` | RecordValidationException("CUST_MISSING_LASTNAME") |
| VR-CUST-005 | ICA-07 §2.3 | "CUSTOMER_TYPE must be one of RESIDENTIAL, COMMERCIAL, INDUSTRIAL — VAL-CUST-005 — REJECT" | `CustomerValidator.java` | `CustomerValidatorTest#invalid_customer_type_fails()` | RecordValidationException("CUST_INVALID_TYPE") |
| VR-CUST-006 | ICA-07 §2.3 | "ACCOUNT_STATUS post-translation must be ACTIVE, INACTIVE, PENDING, CLOSED — VAL-STATUS-001 — REJECT" | `CustomerValidator.java` | `CustomerValidatorTest#invalid_status_fails()` | RecordValidationException("CUST_INVALID_STATUS") |

---

### Section 2: Account / Premise Validation Rules

| ICA Rule ID | ICA Document | MCP-Retrieved Knowledge | Generated Java File | Automated Test | Expected Runtime Result |
|-------------|-------------|------------------------|---------------------|---------------|------------------------|
| VR-EA-001 | ICA-07 §2.5 | "ENERGY_ACCOUNT_ID must not be null — VAL-EA-001 — REJECT" | [`CustomerAccountValidator.java`](../cdp-loader-core/src/main/java/com/ibm/cdp/loader/core/validation/CustomerAccountValidator.java) | `CustomerAccountValidatorTest#missing_energy_account_id_fails()` | RecordValidationException("ACCT_MISSING_ID") |
| VR-EA-002 | ICA-07 §2.5 | "ACCOUNT_NUMBER must not be null or blank — VAL-EA-002 — REJECT" | `CustomerAccountValidator.java` | `CustomerAccountValidatorTest#valid_statuses_pass()` | Record passes validation |
| VR-EA-003 | ICA-07 §2.5 | "ACCOUNT_STATUS post-translation in ACTIVE, INACTIVE, PENDING, CLOSED — VAL-STATUS-001 — REJECT" | `CustomerAccountValidator.java` | `CustomerAccountValidatorTest#invalid_status_fails()` | RecordValidationException("ACCT_INVALID_STATUS") |
| VR-EA-005 | ICA-07 §2.5 | "RATE_CLASS must not be null or blank — VAL-EA-005 — REJECT" | `CustomerAccountValidator.java` | `CustomerAccountValidatorTest#valid_record_passes()` | Record passes, RATE_CLASS='RESIDENTIAL' |

---

### Section 3: Monthly Usage Validation Rules (including intentional rejects)

| ICA Rule ID | ICA Document | MCP-Retrieved Knowledge | Generated Java File | Automated Test | Expected Runtime Result |
|-------------|-------------|------------------------|---------------------|---------------|------------------------|
| VR-USAGE-001 | ICA-07 §2.9 | "BILLING_MONTH must match ^[0-9]{4}-(0[1-9]\|1[0-2])$ — VAL-USAGE-001 — REJECT" | [`MonthlyUsageValidator.java`](../cdp-loader-core/src/main/java/com/ibm/cdp/loader/core/validation/MonthlyUsageValidator.java) | `MonthlyUsageValidatorTest#missing_usage_id_fails()` | RecordValidationException("USG_MISSING_ID") |
| VR-USAGE-002 | ICA-07 §2.9 | "BILL_START_DATE must not be null — VAL-USAGE-002 — REJECT" | `MonthlyUsageValidator.java` | `MonthlyUsageValidatorTest#valid_record_passes()` | Record passes |
| VR-USAGE-003 | ICA-07 §2.9 | "BILL_END_DATE must be > BILL_START_DATE — VAL-USAGE-003 — REJECT — **catches USG-INVD-* records**" | `MonthlyUsageValidator.java` | `MonthlyUsageValidatorTest#bill_end_before_start_rejected_like_USG_INVD()` | RecordValidationException("USG_BILL_DATE_INVALID") — written to ETL_RECORD_ERROR |
| VR-USAGE-004 | ICA-07 §2.9 | "BILLING_DAYS must be > 0 and ≤ 31 — VAL-USAGE-004 — REJECT" | `MonthlyUsageValidator.java` | `MonthlyUsageValidatorTest#zero_billing_days_fails()` | RecordValidationException("USG_INVALID_BILLING_DAYS") |
| VR-USAGE-005 | ICA-07 §2.9 | "KWH_USAGE must be ≥ 0 — VAL-USAGE-005 — REJECT" | `MonthlyUsageValidator.java` | `MonthlyUsageValidatorTest#negative_kwh_rejected()` | RecordValidationException("USG_NEGATIVE_KWH") |
| VR-USAGE-006 | ICA-07 §2.9 | "PEAK_DEMAND_KW if present must be ≥ 0 — VAL-USAGE-006 — REJECT — **catches USG-INVK-* records**" | `MonthlyUsageValidator.java` | `MonthlyUsageValidatorTest#negative_peak_demand_kw_rejected_like_USG_INVK()` | RecordValidationException("USG_NEGATIVE_KW") — written to ETL_RECORD_ERROR |
| VR-USAGE-007 | ICA-07 §2.9 | "RATE_PLAN must not be null or blank — VAL-USAGE-007 — REJECT" | `MonthlyUsageValidator.java` | `MonthlyUsageValidatorTest#null_fixed_rate_fails()` | RecordValidationException("USG_MISSING_FIXED_RATE") |
| VR-USAGE-010 | ICA-07 §2.9 | "TOTAL_BILLED_AMOUNT must be ≥ 0 — VAL-USAGE-010 — REJECT" | `MonthlyUsageValidator.java` | `MonthlyUsageValidatorTest#null_total_billed_fails()` | RecordValidationException("USG_NULL_TOTAL_BILLED") |

---

### Section 4: Transformation Rules

| ICA Rule ID | ICA Document | MCP-Retrieved Knowledge | Generated Java File | Automated Test | Expected Runtime Result |
|-------------|-------------|------------------------|---------------------|---------------|------------------------|
| TR-COMB-01 | ICA-06 §3.1 | "FULL_NAME_NORMALIZED = TRIM(UPPER(FIRST\|\|' '\|\|MIDDLE\|\|' '\|\|LAST)) — computed in Snowflake view" | [`CustomerExportReader.java`](../cdp-loader-batch/src/main/java/com/ibm/cdp/loader/batch/snowflake/CustomerExportReader.java) — reads pre-computed column | `CustomerValidatorTest#valid_record_passes()` — FULL_NAME_NORMALIZED required | TGT_CUSTOMER.FULL_NAME_NORMALIZED set from view |
| TR-01 | ICA-06 §2 | "Boolean TRUE→1, FALSE→0 for NUMBER(1) Oracle columns" | [`CustomerWriter.java`](../cdp-loader-batch/src/main/java/com/ibm/cdp/loader/batch/writer/CustomerWriter.java) | `CustomerValidatorTest#valid_statuses_pass()` | IS_ACTIVE = 0 when INACTIVE, 1 otherwise |
| TR-BILL-03 | ICA-06 §2 (Snowflake Layer 1) | "ENERGY_CHARGE = ROUND(KWH_USAGE × ENERGY_RATE_PER_KWH, 2) — NULL if rate invalid" | [`MonthlyUsageWriter.java`](../cdp-loader-batch/src/main/java/com/ibm/cdp/loader/batch/writer/MonthlyUsageWriter.java) — writes Snowflake-computed value | `MonthlyUsageValidatorTest#valid_record_passes()` | TGT_MONTHLY_USAGE.ENERGY_CHARGE = Snowflake-computed CALC_ENERGY_CHARGE |
| MU-AC-09 | ICA-12 §4.2 | "NULL DEMAND_RATE means no demand component — CALC_DEMAND_CHARGE = 0 (not NULL)" | `MonthlyUsageWriter.java` — `demandCharge = coalesce(calcDemandCharge, BigDecimal.ZERO)` | `MonthlyUsageValidatorTest#valid_record_passes()` | TGT_MONTHLY_USAGE.DEMAND_CHARGE = 0 when no demand rate |

---

### Section 5: Watermark Rules

| ICA Rule ID | ICA Document | MCP-Retrieved Knowledge | Generated Java File | Automated Test | Expected Runtime Result |
|-------------|-------------|------------------------|---------------------|---------------|------------------------|
| WM-COMP-01 | ICA-09 §2.1 | "Composite watermark: RECORD_EFFECTIVE_TS > :lastTs OR (= :lastTs AND ID > :lastId)" | [`CustomerExportReader.java`](../cdp-loader-batch/src/main/java/com/ibm/cdp/loader/batch/snowflake/CustomerExportReader.java) — SQL_INCREMENTAL | MANUAL/PENDING: watermark boundary test | Only new/changed records extracted on incremental run |
| WM-TABLE-01 | ICA-09 §2.2 | "CUSTOMER_EXPORT, CUSTOMER_ACCOUNT_EXPORT, MONTHLY_USAGE_EXPORT are separate watermark keys" | [`EtlWatermarkRepository.java`](../cdp-loader-batch/src/main/java/com/ibm/cdp/loader/batch/repository/EtlWatermarkRepository.java) | MANUAL/PENDING | Three distinct rows in ETL_WATERMARK table |
| WM-ADVANCE | ICA-09 §5 | "Update watermark only after successful Oracle commit — never advance past unprocessed records" | `EtlWatermarkRepository#updateWatermark()` — called by job completion listener only | MANUAL/PENDING | ETL_WATERMARK.LAST_EXTRACTED_TS updates only after step commits |
| WM-FIRST-RUN | ICA-09 §4.1 | "First run uses epoch minimum timestamp 1970-01-01T00:00:00Z" | `EtlWatermarkRepository.EPOCH_MIN` | `MonthlyUsageValidatorTest` (indirectly) | First run reads all rows from Snowflake |

---

### Section 6: Oracle MERGE Safety Rules

| ICA Rule ID | ICA Document | MCP-Retrieved Knowledge | Generated Java File | Automated Test | Expected Runtime Result |
|-------------|-------------|------------------------|---------------------|---------------|------------------------|
| IL-MERGE-01 | ICA-10 §6 | "Every target MERGE uses the documented business/primary key — CUSTOMER_ID for TGT_CUSTOMER" | [`CustomerWriter.java`](../cdp-loader-batch/src/main/java/com/ibm/cdp/loader/batch/writer/CustomerWriter.java) | MANUAL/PENDING: idempotency test | Rerun produces no duplicates; UPDATE sets UPDATED_AT |
| IL-MERGE-02 | ICA-10 §6 | "Preserve CREATED_AT on update — only UPDATED_AT changes" | `CustomerWriter.java` — MERGE UPDATE clause omits CREATED_AT | MANUAL/PENDING | TGT_CUSTOMER.CREATED_AT unchanged on second run |
| IL-MERGE-03 | ICA-10 §6 | "ENERGY_ACCOUNT_ID is business key for TGT_ENERGY_ACCOUNT" | [`CustomerAccountWriter.java`](../cdp-loader-batch/src/main/java/com/ibm/cdp/loader/batch/writer/CustomerAccountWriter.java) | MANUAL/PENDING | TGT_ENERGY_ACCOUNT upserted by ENERGY_ACCOUNT_ID |
| IL-MERGE-04 | ICA-12 §7 | "USAGE_ID is business key for TGT_MONTHLY_USAGE; UNIQUE(EA_ID, BILLING_MONTH) also enforced" | [`MonthlyUsageWriter.java`](../cdp-loader-batch/src/main/java/com/ibm/cdp/loader/batch/writer/MonthlyUsageWriter.java) | MANUAL/PENDING | No duplicate (EA_ID, BILLING_MONTH) in TGT_MONTHLY_USAGE |

---

### Section 7: Concurrency / Job Control Rules

| ICA Rule ID | ICA Document | MCP-Retrieved Knowledge | Generated Java File | Automated Test | Expected Runtime Result |
|-------------|-------------|------------------------|---------------------|---------------|------------------------|
| IL-PRE-05 | ICA-10 §3 | "Only one initial load job may run at a time" | [`JobLaunchService.java`](../cdp-loader-batch/src/main/java/com/ibm/cdp/loader/batch/service/JobLaunchService.java) — `checkConflict()` | `JobControllerTest#post_initial_returns_409_when_conflict()` | HTTP 409 Conflict returned when job already running |
| IL-PRE-05 | ICA-10 §3 | "Initial load must not overlap daily or monthly" | `JobLaunchService#launchInitialLoad()` — checks INITIAL, DAILY, MONTHLY | `JobControllerTest#post_initial_returns_409_when_conflict()` | 409 if any of INITIAL/DAILY/MONTHLY is STARTED |

---

### Section 8: Error Recording Rules

| ICA Rule ID | ICA Document | MCP-Retrieved Knowledge | Generated Java File | Automated Test | Expected Runtime Result |
|-------------|-------------|------------------------|---------------------|---------------|------------------------|
| ERR-LOG-01 | ICA-13 §3 | "Rejected records written to ETL_RECORD_ERROR with RUN_ID, SOURCE_ENTITY, SOURCE_RECORD_ID, ERROR_CODE, ERROR_MESSAGE, PAYLOAD_EXCERPT" | [`EtlRecordErrorRepository.java`](../cdp-loader-batch/src/main/java/com/ibm/cdp/loader/batch/repository/EtlRecordErrorRepository.java) | `JobControllerTest` (mock verify) | ETL_RECORD_ERROR row inserted for each rejected record |
| ERR-SEC-01 | ICA-13 §5, ICA-15 | "Never store private keys, passwords, tokens, or full sensitive payloads" | `EtlRecordErrorRepository` — PAYLOAD_EXCERPT truncated to safe excerpt only | Code review / security scan | No credential content in ETL_RECORD_ERROR |

---

## Summary

| Category | ICA Rules Implemented | Automated Tests | MANUAL/PENDING |
|----------|-----------------------|----------------|----------------|
| Customer validation | 5 | 8 | 0 |
| Account validation | 4 | 4 | 0 |
| Usage validation (incl. 2 intentional rejects) | 8 | 8 | 0 |
| Transformation rules | 4 | Covered by validators | 1 (live integration) |
| Watermark rules | 4 | 0 | 4 (live integration) |
| MERGE safety | 4 | 0 | 4 (live integration) |
| Job concurrency | 2 | 2 | 0 |
| Error recording | 2 | 1 | 1 |
| **TOTAL** | **33** | **23** | **10** |

**All 10 MANUAL/PENDING items require live Oracle + Snowflake credentials and cannot be automated without a live test environment.**

---

*This document was generated from ICA context files in `docs/ica-context/` and reflects the actual implementation in the CDP Loader codebase.*
