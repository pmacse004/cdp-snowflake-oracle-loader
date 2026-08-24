# Business Requirements

**Document ID:** BR-001  
**Project:** CDP Snowflake to Oracle Data Loader  
**Version:** 1.0  
**Status:** Phase 1 — Approved for Architecture  
**Last Updated:** 2025 (Phase 1)

---

## 1. Business Context

A US electric utility company maintains customer and energy-account data in a Snowflake cloud data platform (CDP). The operations team requires a reliable, auditable pipeline to replicate that data into an Oracle database for downstream reporting, billing reconciliation and customer-service applications.

All data in this demonstration is **synthetic and independently designed**. No real utility customer data, proprietary schemas or confidential information is used.

---

## 2. Business Objectives

| ID | Objective |
|----|-----------|
| BO-01 | Provide a working demonstration of an end-to-end Snowflake → Oracle data loader for a US electric utility customer domain. |
| BO-02 | Load all eligible synthetic customer, account, premise, meter and billing records from Snowflake into Oracle with verifiable completeness and accuracy. |
| BO-03 | Support daily incremental loads to keep Oracle current with changes in Snowflake, minimising data latency. |
| BO-04 | Support monthly loads of electricity usage and billing records, including correction handling. |
| BO-05 | Provide an operations dashboard so business and technical users can monitor load status, errors and reconciliation totals without database access. |
| BO-06 | Demonstrate IBM Consulting Advantage (ICA) Context Studio as the authoritative source of mapping and transformation governance. |
| BO-07 | Design the solution to scale toward approximately 1 million customers without a fundamental redesign. |

---

## 3. Stakeholders

| Role | Interest |
|------|----------|
| Data Engineering Lead | End-to-end pipeline correctness, restartability, performance |
| Business Analyst | Mapping accuracy, business-rule traceability to ICA |
| Operations / Support | Dashboard visibility, error recovery, watermark status |
| Security Officer | PII handling, credential management, audit trail |
| Solution Architect | Scalability, technology choices, Open Liberty migration path |
| IBM Consulting Client | Demonstrable value, understandable design, presentation readiness |

---

## 4. Business Scope

### 4.1 In Scope

- Synthetic customer master data (name, status, type)
- Customer contact information (address, email, phone)
- Energy / service accounts
- Billing accounts (account numbers)
- Service premises (physical service locations)
- Meters and meter attributes
- Monthly electricity usage and billing records
- Reference / code-value tables
- ETL control data (watermarks, job runs, errors, reconciliation)
- Operations dashboard

### 4.2 Out of Scope (Phase 1)

- Real customer data migration
- Integration with billing or CRM systems
- Payment processing
- Smart-meter (AMI) interval data
- Outage management data
- Real-time streaming (Kafka / Spark)
- Kubernetes deployment

---

## 5. Business Rules Summary

| ID | Rule |
|----|------|
| BR-01 | Every customer must have a unique, stable source identifier that survives updates. |
| BR-02 | A customer may have one or more energy accounts, but each energy account belongs to exactly one customer. |
| BR-03 | Each energy account is associated with exactly one service premise and one billing account at any point in time. |
| BR-04 | A meter is physically located at a service premise. A premise may have multiple meters over time (replacement), but only one active meter at a time. |
| BR-05 | Monthly usage records are keyed by energy account + billing month. A duplicate key indicates a correction; the latest record wins. |
| BR-06 | Account status must be one of the defined code values (ACTIVE, INACTIVE, PENDING, CLOSED). |
| BR-07 | Energy usage (KWH) and peak demand (KW) must be non-negative. |
| BR-08 | Bill end date must be after bill start date; both must fall within the billing month year/month. |
| BR-09 | Total billed amount = energy charge + tax amount (within rounding tolerance of $0.01). |
| BR-10 | Watermarks must not advance past records that have not been successfully loaded. |
| BR-11 | A single bad record must not abort an entire job step unless the configurable fatal-error threshold is exceeded. |
| BR-12 | Rejected records must be stored with sufficient information to diagnose and reprocess them. |
| BR-13 | All financial and usage values use decimal arithmetic (no floating-point). |
| BR-14 | Soft-deleted / inactivated records must be preserved in Oracle with an inactivation timestamp and reason code. |
| BR-15 | All technical timestamps are stored in UTC; billing dates are stored as business dates with no time component. |

---

## 6. Load-Type Business Requirements

### 6.1 Initial Load

- Load all currently eligible source records across all entities in dependency order (reference data first, customers last).
- Reconcile source counts and Oracle target counts after load completion.
- Reconcile aggregate KWH, KW and billed totals for monthly usage.
- Initial load must be idempotent: re-running it must not create duplicates.

### 6.2 Daily Incremental Load

- Detect and load records changed or inserted since the last successful watermark.
- Support new customers, contact changes, new energy accounts, billing-account-number changes, premise changes, account closures and soft deletions / inactivations.
- Use a composite watermark of `(UPDATED_AT, SOURCE_ID)` to handle equal timestamps.
- Advance the watermark only after the load step is fully committed.
- Provide restart capability: a failed daily load can be restarted from the last safe watermark.

### 6.3 Monthly Usage Load

- Load electricity usage and billing records for the relevant billing month(s).
- Prevent duplicate usage records using an `(ENERGY_ACCOUNT_ID, BILLING_MONTH)` business key.
- Support corrections: if a record with the same business key arrives with a later `UPDATED_AT`, treat it as a correction and overwrite the existing record.
- Reconcile KWH, KW and billed totals after load.

---

## 7. Compliance and Audit Requirements

| ID | Requirement |
|----|-------------|
| CA-01 | All ETL load events must be recorded with start time, end time, status, record counts and watermark values. |
| CA-02 | Every rejected record must be stored with a structured error code, error message and safe excerpt of the source payload. |
| CA-03 | Audit columns (`CREATED_AT`, `UPDATED_AT`, `CREATED_BY`, `UPDATED_BY`) must be present on all business and control tables. |
| CA-04 | No password, private key, token or secret may be stored in source control. |
| CA-05 | Personally identifiable information (PII) must not appear in application logs. |

---

## 8. Assumptions

- All source data is synthetic.
- The Snowflake account `LJPNAFI-RW79936` is accessible from the development machine.
- A dedicated least-privilege service user will be provisioned in Phase 2.
- Oracle Database Free 23c runs locally in Docker.
- IBM Consulting Advantage (ICA) is used for mapping governance but the running application does not connect to ICA at runtime.

---

*For functional and non-functional requirements see:*  
[`docs/requirements/functional-requirements.md`](functional-requirements.md)  
[`docs/requirements/non-functional-requirements.md`](non-functional-requirements.md)
