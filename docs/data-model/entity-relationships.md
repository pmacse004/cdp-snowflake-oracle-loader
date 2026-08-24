# Entity Relationships

**Document ID:** DM-003  
**Project:** CDP Snowflake to Oracle Data Loader  
**Version:** 1.0  
**Status:** Phase 1 — Approved  
**Last Updated:** 2025 (Phase 1)

---

## 1. Source Entity Relationship Diagram (Snowflake)

```mermaid
erDiagram
    REF_CODE_VALUE {
        number CODE_ID PK
        varchar CODE_DOMAIN
        varchar CODE_VALUE
        varchar CODE_LABEL
        timestamp UPDATED_AT
    }

    CUSTOMER {
        number CUSTOMER_ID PK
        varchar FIRST_NAME
        varchar LAST_NAME
        varchar ACCOUNT_STATUS
        varchar CUSTOMER_TYPE
        date START_DATE
        date END_DATE
        varchar DELETED_FLAG
        timestamp UPDATED_AT
    }

    CUSTOMER_CONTACT {
        number CONTACT_ID PK
        number CUSTOMER_ID FK
        varchar CONTACT_TYPE
        varchar ADDRESS_LINE1
        varchar EMAIL_ADDRESS
        varchar PHONE_NUMBER
        timestamp UPDATED_AT
    }

    ENERGY_ACCOUNT {
        number ENERGY_ACCOUNT_ID PK
        number CUSTOMER_ID FK
        varchar ACCOUNT_NUMBER
        varchar ACCOUNT_STATUS
        varchar RATE_CLASS
        date START_DATE
        date END_DATE
        timestamp UPDATED_AT
    }

    BILLING_ACCOUNT {
        number BILLING_ACCOUNT_ID PK
        number ENERGY_ACCOUNT_ID FK
        varchar BILLING_ACCOUNT_NUMBER
        varchar BILLING_CYCLE
        date EFFECTIVE_DATE
        date EXPIRY_DATE
        timestamp UPDATED_AT
    }

    SERVICE_PREMISE {
        number PREMISE_ID PK
        number ENERGY_ACCOUNT_ID FK
        varchar SERVICE_ADDRESS1
        varchar STATE_CODE
        varchar ZIP_CODE
        varchar ACTIVE_FLAG
        timestamp UPDATED_AT
    }

    METER {
        number METER_ID PK
        number PREMISE_ID FK
        varchar METER_NUMBER
        varchar METER_TYPE
        date INSTALL_DATE
        date REMOVAL_DATE
        varchar ACTIVE_FLAG
        timestamp UPDATED_AT
    }

    MONTHLY_USAGE {
        number USAGE_ID PK
        number ENERGY_ACCOUNT_ID FK
        number PREMISE_ID FK
        number METER_ID FK
        varchar BILLING_MONTH
        number KWH_USAGE
        number PEAK_DEMAND_KW
        number TOTAL_BILLED_AMOUNT
        varchar CORRECTION_FLAG
        timestamp UPDATED_AT
    }

    CUSTOMER ||--o{ CUSTOMER_CONTACT : "has"
    CUSTOMER ||--o{ ENERGY_ACCOUNT : "owns"
    ENERGY_ACCOUNT ||--o{ BILLING_ACCOUNT : "has"
    ENERGY_ACCOUNT ||--o{ SERVICE_PREMISE : "served at"
    SERVICE_PREMISE ||--o{ METER : "has installed"
    ENERGY_ACCOUNT ||--o{ MONTHLY_USAGE : "generates"
    METER ||--o{ MONTHLY_USAGE : "recorded by"
```

---

## 2. Target Entity Relationship Diagram (Oracle CDP_APP)

```mermaid
erDiagram
    REF_CODE_VALUE {
        number CODE_ID PK
        varchar CODE_DOMAIN
        varchar CODE_VALUE
        varchar CODE_LABEL
        number IS_ACTIVE
        timestamp CREATED_AT
        timestamp UPDATED_AT
    }

    CUSTOMER {
        number CUSTOMER_ID PK
        number SOURCE_CUSTOMER_ID UK
        varchar FIRST_NAME
        varchar LAST_NAME
        varchar FULL_NAME
        varchar ACCOUNT_STATUS
        varchar CUSTOMER_TYPE
        number IS_ACTIVE
        date START_DATE
        date END_DATE
        timestamp DELETED_AT
        timestamp CREATED_AT
        timestamp UPDATED_AT
    }

    CUSTOMER_CONTACT {
        number CONTACT_ID PK
        number SOURCE_CONTACT_ID UK
        number CUSTOMER_ID FK
        varchar CONTACT_TYPE
        varchar EMAIL_ADDRESS
        varchar PHONE_NUMBER
        number IS_PRIMARY
        date EFFECTIVE_DATE
        timestamp CREATED_AT
        timestamp UPDATED_AT
    }

    ENERGY_ACCOUNT {
        number ENERGY_ACCOUNT_ID PK
        number SOURCE_ENERGY_ACCOUNT_ID UK
        number CUSTOMER_ID FK
        varchar ACCOUNT_NUMBER
        varchar ACCOUNT_STATUS
        number IS_ACTIVE
        varchar RATE_CLASS
        date START_DATE
        date END_DATE
        timestamp CREATED_AT
        timestamp UPDATED_AT
    }

    BILLING_ACCOUNT {
        number BILLING_ACCOUNT_ID PK
        number SOURCE_BILLING_ACCOUNT_ID UK
        number ENERGY_ACCOUNT_ID FK
        varchar BILLING_ACCOUNT_NUMBER
        varchar BILLING_CYCLE
        date EFFECTIVE_DATE
        timestamp CREATED_AT
        timestamp UPDATED_AT
    }

    SERVICE_PREMISE {
        number PREMISE_ID PK
        number SOURCE_PREMISE_ID UK
        number ENERGY_ACCOUNT_ID FK
        varchar SERVICE_ADDRESS1
        varchar STATE_CODE
        varchar ZIP_CODE
        number IS_ACTIVE
        timestamp CREATED_AT
        timestamp UPDATED_AT
    }

    METER {
        number METER_ID PK
        number SOURCE_METER_ID UK
        number PREMISE_ID FK
        varchar METER_NUMBER
        varchar METER_TYPE
        date INSTALL_DATE
        number IS_ACTIVE
        timestamp CREATED_AT
        timestamp UPDATED_AT
    }

    MONTHLY_USAGE {
        number USAGE_ID PK
        number SOURCE_USAGE_ID UK
        number ENERGY_ACCOUNT_ID FK
        number PREMISE_ID FK
        number METER_ID FK
        varchar BILLING_MONTH
        number KWH_USAGE
        number PEAK_DEMAND_KW
        number TOTAL_BILLED_AMOUNT
        number CALCULATED_BILL_TOTAL
        varchar CORRECTION_FLAG
        timestamp SOURCE_UPDATED_AT
        timestamp CREATED_AT
        timestamp UPDATED_AT
    }

    CUSTOMER ||--o{ CUSTOMER_CONTACT : "has"
    CUSTOMER ||--o{ ENERGY_ACCOUNT : "owns"
    ENERGY_ACCOUNT ||--o{ BILLING_ACCOUNT : "has"
    ENERGY_ACCOUNT ||--o{ SERVICE_PREMISE : "served at"
    SERVICE_PREMISE ||--o{ METER : "has installed"
    ENERGY_ACCOUNT ||--o{ MONTHLY_USAGE : "generates"
    METER ||--o{ MONTHLY_USAGE : "recorded by"
```

---

## 3. ETL Control Table Relationships

```mermaid
erDiagram
    ETL_JOB_RUN {
        number RUN_ID PK
        number BATCH_RUN_ID
        varchar JOB_NAME
        varchar STATUS
        timestamp START_TIME
        timestamp END_TIME
        number RECORDS_READ
        number RECORDS_INSERTED
        number RECORDS_REJECTED
        varchar RECON_STATUS
    }

    ETL_WATERMARK {
        number WATERMARK_ID PK
        varchar ENTITY_NAME
        varchar JOB_TYPE
        timestamp LAST_WATERMARK_TS
        number LAST_WATERMARK_ID
    }

    ETL_RECORD_ERROR {
        number ERROR_ID PK
        number RUN_ID FK
        varchar SOURCE_ENTITY
        varchar SOURCE_RECORD_ID
        varchar ERROR_CODE
        varchar ERROR_MESSAGE
        varchar PAYLOAD_EXCERPT
        timestamp OCCURRED_AT
    }

    ETL_RECONCILIATION {
        number RECON_ID PK
        number RUN_ID FK
        varchar ENTITY_NAME
        number SOURCE_COUNT
        number TARGET_COUNT
        number SOURCE_KWH_TOTAL
        number TARGET_KWH_TOTAL
        number SOURCE_BILLED_TOTAL
        number TARGET_BILLED_TOTAL
        varchar RECON_STATUS
    }

    ETL_JOB_RUN ||--o{ ETL_RECORD_ERROR : "generates"
    ETL_JOB_RUN ||--o{ ETL_RECONCILIATION : "produces"
```

---

## 4. Load Dependency Order

The following order must be observed when loading entities to satisfy foreign-key constraints:

```mermaid
graph TD
    A[1. REF_CODE_VALUE] --> B[2. CUSTOMER]
    B --> C[3. CUSTOMER_CONTACT]
    B --> D[4. ENERGY_ACCOUNT]
    D --> E[5. BILLING_ACCOUNT]
    D --> F[6. SERVICE_PREMISE]
    F --> G[7. METER]
    D --> H[8. MONTHLY_USAGE]
    F --> H
    G --> H
```

---

## 5. Source-to-Target Key Mapping Summary

| Source Table | Source PK | Target Table | Source PK stored as | Target PK |
|---|---|---|---|---|
| REF.CODE_VALUE | CODE_ID | CDP_APP.REF_CODE_VALUE | SOURCE_CODE_ID | CODE_ID (sequence) |
| RAW.CUSTOMER | CUSTOMER_ID | CDP_APP.CUSTOMER | SOURCE_CUSTOMER_ID | CUSTOMER_ID (sequence) |
| RAW.CUSTOMER_CONTACT | CONTACT_ID | CDP_APP.CUSTOMER_CONTACT | SOURCE_CONTACT_ID | CONTACT_ID (sequence) |
| RAW.ENERGY_ACCOUNT | ENERGY_ACCOUNT_ID | CDP_APP.ENERGY_ACCOUNT | SOURCE_ENERGY_ACCOUNT_ID | ENERGY_ACCOUNT_ID (sequence) |
| RAW.BILLING_ACCOUNT | BILLING_ACCOUNT_ID | CDP_APP.BILLING_ACCOUNT | SOURCE_BILLING_ACCOUNT_ID | BILLING_ACCOUNT_ID (sequence) |
| RAW.SERVICE_PREMISE | PREMISE_ID | CDP_APP.SERVICE_PREMISE | SOURCE_PREMISE_ID | PREMISE_ID (sequence) |
| RAW.METER | METER_ID | CDP_APP.METER | SOURCE_METER_ID | METER_ID (sequence) |
| RAW.MONTHLY_USAGE | USAGE_ID | CDP_APP.MONTHLY_USAGE | SOURCE_USAGE_ID | USAGE_ID (sequence) |

The target surrogate key is generated from an Oracle sequence on INSERT and never changes. The source ID is stored for MERGE operations and watermark tracking.
