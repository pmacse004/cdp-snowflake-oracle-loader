# ICA Context Document 01 — Business Glossary

**ICA Document ID:** ICA-01  
**Project:** CDP Snowflake to Oracle Data Loader  
**Version:** 1.0  
**Status:** Phase 1 — Approved  
**Last Updated:** 2025 (Phase 1)

> This document is maintained in IBM Consulting Advantage (ICA) Context Studio. It is the authoritative source of business term definitions for the CDP Snowflake to Oracle Data Loader project.

---

## 1. Purpose

This glossary defines the canonical business terms used throughout the mapping catalogue, transformation rules, validation rules and application code. Every term is assigned a stable ID for cross-referencing.

---

## 2. Glossary

| Term ID | Term | Definition | Domain | Related Terms |
|---------|------|-----------|--------|--------------|
| GL-001 | Customer | An individual or organization that has or has had an electricity service relationship with the utility. | Customer | Energy Account, Customer Contact |
| GL-002 | Customer Type | Classification of a customer: RESIDENTIAL, COMMERCIAL, or INDUSTRIAL. | Customer | Rate Class |
| GL-003 | Account Status | The lifecycle state of a customer or energy account. Valid values: ACTIVE, INACTIVE, PENDING, CLOSED. | Customer, Account | IS_ACTIVE |
| GL-004 | Customer Contact | Contact information associated with a customer, including mailing address, service address, email and phone. | Customer | Customer |
| GL-005 | Contact Type | The category of a contact record: MAILING, SERVICE, BILLING, EMAIL, PHONE. | Customer | Customer Contact |
| GL-006 | Energy Account | A service account that tracks electricity consumption and billing for a customer at one or more premises. | Account | Customer, Service Premise, Billing Account |
| GL-007 | Billing Account | The financial account associated with an energy account, including the billing account number and billing cycle. | Account | Energy Account |
| GL-008 | Billing Account Number | A unique identifier assigned to the billing relationship between a customer and the utility. Sensitive business data. | Account | Billing Account |
| GL-009 | Service Premise | The physical location at which electricity service is delivered. | Premise | Energy Account, Meter |
| GL-010 | Distribution Zone | A geographic grid zone used for capacity planning and outage management. | Premise | Service Premise |
| GL-011 | Meter | A physical device installed at a service premise that measures electricity consumption. | Meter | Service Premise, Monthly Usage |
| GL-012 | Meter Number | The physical serial number printed on the meter. | Meter | Meter |
| GL-013 | Meter Type | The technology type of the meter: ANALOG, DIGITAL, or SMART_AMI. | Meter | Meter |
| GL-014 | Meter Multiplier | A correction factor applied to raw meter readings to calculate actual consumption. Default is 1.0. | Meter | KWH Usage |
| GL-015 | Billing Month | A calendar month expressed as YYYY-MM representing the period for which a usage and billing record is generated. | Usage | Monthly Usage |
| GL-016 | Bill Start Date | The first day of the metered billing period. | Usage | Billing Month, Bill End Date |
| GL-017 | Bill End Date | The last day of the metered billing period. | Usage | Billing Month, Bill Start Date |
| GL-018 | Billing Days | The number of days in the billing period (Bill End Date − Bill Start Date + 1). | Usage | Bill Start Date, Bill End Date |
| GL-019 | KWH Usage | The total electrical energy consumed during the billing period, measured in kilowatt-hours. | Usage | Monthly Usage |
| GL-020 | Peak Demand KW | The maximum instantaneous electrical demand recorded during the billing period, measured in kilowatts. | Usage | Monthly Usage |
| GL-021 | Previous Meter Reading | The meter register value at the start of the billing period. | Usage | KWH Usage |
| GL-022 | Current Meter Reading | The meter register value at the end of the billing period. | Usage | KWH Usage |
| GL-023 | Rate Plan | The pricing tariff code applied to calculate the energy charge for the billing period. | Usage | Energy Charge |
| GL-024 | Energy Charge | The component of the total bill representing the cost of electricity consumed. | Usage | Monthly Usage |
| GL-025 | Tax Amount | The total taxes applied to the energy charge. | Usage | Monthly Usage |
| GL-026 | Total Billed Amount | The total amount due for the billing period: Energy Charge + Tax Amount. | Usage | Energy Charge, Tax Amount |
| GL-027 | Read Type | Indicates whether the current meter reading was physically measured (A = Actual) or mathematically estimated (E = Estimated). | Usage | Monthly Usage |
| GL-028 | Correction Record | A monthly usage record that supersedes a previously loaded record for the same Energy Account and Billing Month. | Usage | Monthly Usage, Correction Flag |
| GL-029 | Soft Delete | The process of marking a record as inactive in the target system without physically removing it, preserving historical data. | ETL | IS_ACTIVE, DELETED_AT |
| GL-030 | Watermark | A composite value `(UPDATED_AT, SOURCE_ID)` that records the position of the last successfully processed source record for a given entity and job type. | ETL | Incremental Load |
| GL-031 | Incremental Load | An ETL load that extracts and processes only source records that have changed since the last successful watermark. | ETL | Watermark, Daily Load |
| GL-032 | Initial Load | A full-scan ETL load that extracts and loads all eligible source records, typically performed once to populate the target system. | ETL | Watermark |
| GL-033 | Daily Load | The scheduled incremental load that runs each day to synchronise changes made in the source system. | ETL | Incremental Load |
| GL-034 | Monthly Usage Load | The scheduled load that processes monthly electricity usage and billing records for one or more billing months. | ETL | Monthly Usage |
| GL-035 | Idempotent | A property of an operation such that executing it multiple times with the same input produces the same result as executing it once. | ETL | MERGE |
| GL-036 | MERGE | An Oracle SQL operation that performs an upsert: INSERT if the row does not exist, UPDATE if it does. | ETL | Idempotent |
| GL-037 | ETL | Extract, Transform, Load — the process of reading data from a source, applying transformations, and writing it to a target. | ETL | |
| GL-038 | Fatal Error Threshold | A configurable percentage of rejected records within a batch step above which the step is immediately failed. Default: 5%. | ETL | Error Handling |
| GL-039 | Reconciliation | The process of comparing source and target record counts and aggregate totals to verify load completeness and accuracy. | ETL | ETL_RECONCILIATION |
| GL-040 | PII | Personally Identifiable Information — data that can be used to identify a specific individual. In this project: customer names, email, phone, mailing address. | Security | |
| GL-041 | Rate Class | A tariff category assigned to an energy account that determines the pricing schedule applied to usage. | Account | Rate Plan, Energy Account |
| GL-042 | Account Closure | The business event of permanently ending a customer's energy service. Results in END_DATE set and status changed to CLOSED. | Account | Account Status |
| GL-043 | Inactivation | The temporary suspension of a customer or account. Status changes to INACTIVE; record is preserved. | Account | Account Status, Soft Delete |
| GL-044 | Service Type | The type of utility service on an energy account: ELECTRIC, GAS, SOLAR. This project uses ELECTRIC only. | Account | Energy Account |
| GL-045 | Billing Cycle | The frequency at which bills are generated: MONTHLY or BIMONTHLY. | Account | Billing Account |
| GL-046 | E.164 | An international telephone numbering format specifying up to 15 digits, prefixed with a + sign and country code. US: +1XXXXXXXXXX. | Data Quality | Phone Normalization |
| GL-047 | UTC | Coordinated Universal Time. All technical timestamps are stored in UTC. Billing dates have no time component. | Technical | |
| GL-048 | CDP | Customer Data Platform — the Snowflake-based source system from which customer data is extracted. | Technical | |
| GL-049 | ICA | IBM Consulting Advantage — the governance platform hosting authoritative mapping and transformation rules for this project. | Governance | |
| GL-050 | Flyway | An open-source database migration tool used to manage Oracle schema versioning through version-controlled SQL scripts. | Technical | |
