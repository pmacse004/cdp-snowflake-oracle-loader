-- =============================================================================
-- V004__create_target_business_tables.sql
-- =============================================================================
-- Flyway migration — Oracle target business tables.
-- Run as: CDP_LOADER (application user — NOT SYSDBA)
--
-- All table names are unqualified — Flyway connects as CDP_LOADER so all
-- objects are created in the CDP_LOADER schema automatically.
--
-- No FLOAT or BINARY_FLOAT — money and usage values use NUMBER only.
-- Audit columns on every table: CREATED_AT, UPDATED_AT, ETL_RUN_ID, ETL_LOAD_TS.
-- =============================================================================

-- ---------------------------------------------------------------------------
-- TGT_CUSTOMER
-- ---------------------------------------------------------------------------
CREATE TABLE TGT_CUSTOMER (
    CUSTOMER_ID             VARCHAR2(20)    NOT NULL,
    FIRST_NAME              VARCHAR2(100)   NOT NULL,
    LAST_NAME               VARCHAR2(100)   NOT NULL,
    MIDDLE_NAME             VARCHAR2(100),
    NAME_SUFFIX             VARCHAR2(20),
    FULL_NAME_NORMALIZED    VARCHAR2(300)   NOT NULL,
    CUSTOMER_TYPE           VARCHAR2(30)    NOT NULL,
    CUSTOMER_TYPE_LABEL     VARCHAR2(100),
    PREFERRED_LANGUAGE      VARCHAR2(10)    DEFAULT 'EN' NOT NULL,
    ACCOUNT_STATUS          VARCHAR2(30)    NOT NULL,
    ACCOUNT_STATUS_LABEL    VARCHAR2(100),
    IS_ACTIVE               NUMBER(1,0)     DEFAULT 1    NOT NULL,
    SOURCE_UPDATED_AT       TIMESTAMP,
    ETL_RUN_ID              NUMBER(19,0)    NOT NULL,
    ETL_LOAD_TS             TIMESTAMP       DEFAULT SYS_EXTRACT_UTC(SYSTIMESTAMP) NOT NULL,
    CREATED_AT              TIMESTAMP       DEFAULT SYS_EXTRACT_UTC(SYSTIMESTAMP) NOT NULL,
    UPDATED_AT              TIMESTAMP       DEFAULT SYS_EXTRACT_UTC(SYSTIMESTAMP) NOT NULL,
    CONSTRAINT pk_tgt_customer          PRIMARY KEY (CUSTOMER_ID),
    CONSTRAINT ck_tgt_cust_is_active    CHECK (IS_ACTIVE IN (0,1))
);

CREATE INDEX idx_tgt_cust_status    ON TGT_CUSTOMER (ACCOUNT_STATUS);
CREATE INDEX idx_tgt_cust_type      ON TGT_CUSTOMER (CUSTOMER_TYPE);
CREATE INDEX idx_tgt_cust_name      ON TGT_CUSTOMER (LAST_NAME, FIRST_NAME);
CREATE INDEX idx_tgt_cust_updated   ON TGT_CUSTOMER (SOURCE_UPDATED_AT);

COMMENT ON TABLE  TGT_CUSTOMER                      IS 'Customer master — loaded from Snowflake CUSTOMER.CUSTOMER';
COMMENT ON COLUMN TGT_CUSTOMER.FULL_NAME_NORMALIZED IS 'Derived: TRIM(UPPER(FIRST||MIDDLE||LAST)) — TR-COMB-01';
COMMENT ON COLUMN TGT_CUSTOMER.IS_ACTIVE            IS '1=active; 0=soft-deleted/inactivated';

-- ---------------------------------------------------------------------------
-- TGT_CUSTOMER_CONTACT
-- ---------------------------------------------------------------------------
CREATE TABLE TGT_CUSTOMER_CONTACT (
    CONTACT_ID          VARCHAR2(20)    NOT NULL,
    CUSTOMER_ID         VARCHAR2(20)    NOT NULL,
    CONTACT_TYPE        VARCHAR2(30)    NOT NULL,
    CONTACT_VALUE       VARCHAR2(500)   NOT NULL,
    IS_PRIMARY          NUMBER(1,0)     DEFAULT 0    NOT NULL,
    IS_VERIFIED         NUMBER(1,0)     DEFAULT 0    NOT NULL,
    EFFECTIVE_DATE      DATE            NOT NULL,
    END_DATE            DATE,
    ETL_RUN_ID          NUMBER(19,0)    NOT NULL,
    ETL_LOAD_TS         TIMESTAMP       DEFAULT SYS_EXTRACT_UTC(SYSTIMESTAMP) NOT NULL,
    CREATED_AT          TIMESTAMP       DEFAULT SYS_EXTRACT_UTC(SYSTIMESTAMP) NOT NULL,
    UPDATED_AT          TIMESTAMP       DEFAULT SYS_EXTRACT_UTC(SYSTIMESTAMP) NOT NULL,
    CONSTRAINT pk_tgt_contact           PRIMARY KEY (CONTACT_ID),
    CONSTRAINT fk_tgt_cont_cust         FOREIGN KEY (CUSTOMER_ID) REFERENCES TGT_CUSTOMER (CUSTOMER_ID),
    CONSTRAINT ck_tgt_cont_primary      CHECK (IS_PRIMARY  IN (0,1)),
    CONSTRAINT ck_tgt_cont_verified     CHECK (IS_VERIFIED IN (0,1))
);

CREATE INDEX idx_tgt_cont_customer  ON TGT_CUSTOMER_CONTACT (CUSTOMER_ID);
CREATE INDEX idx_tgt_cont_type      ON TGT_CUSTOMER_CONTACT (CONTACT_TYPE);

-- ---------------------------------------------------------------------------
-- TGT_ENERGY_ACCOUNT
-- ---------------------------------------------------------------------------
CREATE TABLE TGT_ENERGY_ACCOUNT (
    ENERGY_ACCOUNT_ID   VARCHAR2(20)    NOT NULL,
    CUSTOMER_ID         VARCHAR2(20)    NOT NULL,
    ACCOUNT_NUMBER      VARCHAR2(30)    NOT NULL,
    ACCOUNT_STATUS      VARCHAR2(30)    NOT NULL,
    SERVICE_TYPE        VARCHAR2(30)    DEFAULT 'ELECTRIC' NOT NULL,
    RATE_CLASS          VARCHAR2(30)    NOT NULL,
    OPEN_DATE           DATE            NOT NULL,
    CLOSE_DATE          DATE,
    IS_ACTIVE           NUMBER(1,0)     DEFAULT 1    NOT NULL,
    SOURCE_UPDATED_AT   TIMESTAMP,
    ETL_RUN_ID          NUMBER(19,0)    NOT NULL,
    ETL_LOAD_TS         TIMESTAMP       DEFAULT SYS_EXTRACT_UTC(SYSTIMESTAMP) NOT NULL,
    CREATED_AT          TIMESTAMP       DEFAULT SYS_EXTRACT_UTC(SYSTIMESTAMP) NOT NULL,
    UPDATED_AT          TIMESTAMP       DEFAULT SYS_EXTRACT_UTC(SYSTIMESTAMP) NOT NULL,
    CONSTRAINT pk_tgt_energy_acct       PRIMARY KEY (ENERGY_ACCOUNT_ID),
    CONSTRAINT fk_tgt_ea_customer       FOREIGN KEY (CUSTOMER_ID) REFERENCES TGT_CUSTOMER (CUSTOMER_ID),
    CONSTRAINT uq_tgt_ea_acct_nbr       UNIQUE (ACCOUNT_NUMBER),
    CONSTRAINT ck_tgt_ea_is_active      CHECK (IS_ACTIVE IN (0,1))
);

CREATE INDEX idx_tgt_ea_customer    ON TGT_ENERGY_ACCOUNT (CUSTOMER_ID);
CREATE INDEX idx_tgt_ea_status      ON TGT_ENERGY_ACCOUNT (ACCOUNT_STATUS);
CREATE INDEX idx_tgt_ea_updated     ON TGT_ENERGY_ACCOUNT (SOURCE_UPDATED_AT);

-- ---------------------------------------------------------------------------
-- TGT_BILLING_ACCOUNT
-- ---------------------------------------------------------------------------
CREATE TABLE TGT_BILLING_ACCOUNT (
    BILLING_ACCOUNT_ID  VARCHAR2(20)    NOT NULL,
    ENERGY_ACCOUNT_ID   VARCHAR2(20)    NOT NULL,
    BILLING_ACCOUNT_NBR VARCHAR2(30)    NOT NULL,
    BILLING_CYCLE       VARCHAR2(10)    NOT NULL,
    PAYMENT_METHOD      VARCHAR2(30)    DEFAULT 'PAPER_BILL' NOT NULL,
    AUTO_PAY_ENROLLED   NUMBER(1,0)     DEFAULT 0    NOT NULL,
    PAPERLESS_ENROLLED  NUMBER(1,0)     DEFAULT 0    NOT NULL,
    EFFECTIVE_DATE      DATE            NOT NULL,
    END_DATE            DATE,
    IS_CURRENT          NUMBER(1,0)     DEFAULT 1    NOT NULL,
    SOURCE_UPDATED_AT   TIMESTAMP,
    ETL_RUN_ID          NUMBER(19,0)    NOT NULL,
    ETL_LOAD_TS         TIMESTAMP       DEFAULT SYS_EXTRACT_UTC(SYSTIMESTAMP) NOT NULL,
    CREATED_AT          TIMESTAMP       DEFAULT SYS_EXTRACT_UTC(SYSTIMESTAMP) NOT NULL,
    UPDATED_AT          TIMESTAMP       DEFAULT SYS_EXTRACT_UTC(SYSTIMESTAMP) NOT NULL,
    CONSTRAINT pk_tgt_billing_acct      PRIMARY KEY (BILLING_ACCOUNT_ID),
    CONSTRAINT fk_tgt_ba_ea             FOREIGN KEY (ENERGY_ACCOUNT_ID) REFERENCES TGT_ENERGY_ACCOUNT (ENERGY_ACCOUNT_ID),
    CONSTRAINT ck_tgt_ba_autopay        CHECK (AUTO_PAY_ENROLLED  IN (0,1)),
    CONSTRAINT ck_tgt_ba_paperless      CHECK (PAPERLESS_ENROLLED IN (0,1)),
    CONSTRAINT ck_tgt_ba_is_current     CHECK (IS_CURRENT         IN (0,1))
);

CREATE INDEX idx_tgt_ba_ea  ON TGT_BILLING_ACCOUNT (ENERGY_ACCOUNT_ID);
CREATE INDEX idx_tgt_ba_nbr ON TGT_BILLING_ACCOUNT (BILLING_ACCOUNT_NBR);

-- ---------------------------------------------------------------------------
-- TGT_PREMISE
-- ---------------------------------------------------------------------------
CREATE TABLE TGT_PREMISE (
    PREMISE_ID          VARCHAR2(20)    NOT NULL,
    ENERGY_ACCOUNT_ID   VARCHAR2(20)    NOT NULL,
    ADDRESS_LINE1       VARCHAR2(200)   NOT NULL,
    ADDRESS_LINE2       VARCHAR2(200),
    CITY                VARCHAR2(100)   NOT NULL,
    STATE_CODE          VARCHAR2(2)     NOT NULL,
    ZIP_CODE            VARCHAR2(10)    NOT NULL,
    COUNTY              VARCHAR2(100),
    GEO_LATITUDE        NUMBER(10,6),
    GEO_LONGITUDE       NUMBER(11,6),
    PREMISE_TYPE        VARCHAR2(30),
    FULL_ADDRESS        VARCHAR2(600),
    EFFECTIVE_DATE      DATE            NOT NULL,
    END_DATE            DATE,
    IS_CURRENT          NUMBER(1,0)     DEFAULT 1    NOT NULL,
    SOURCE_UPDATED_AT   TIMESTAMP,
    ETL_RUN_ID          NUMBER(19,0)    NOT NULL,
    ETL_LOAD_TS         TIMESTAMP       DEFAULT SYS_EXTRACT_UTC(SYSTIMESTAMP) NOT NULL,
    CREATED_AT          TIMESTAMP       DEFAULT SYS_EXTRACT_UTC(SYSTIMESTAMP) NOT NULL,
    UPDATED_AT          TIMESTAMP       DEFAULT SYS_EXTRACT_UTC(SYSTIMESTAMP) NOT NULL,
    CONSTRAINT pk_tgt_premise           PRIMARY KEY (PREMISE_ID),
    CONSTRAINT fk_tgt_prem_ea           FOREIGN KEY (ENERGY_ACCOUNT_ID) REFERENCES TGT_ENERGY_ACCOUNT (ENERGY_ACCOUNT_ID),
    CONSTRAINT ck_tgt_prem_is_current   CHECK (IS_CURRENT IN (0,1))
);

CREATE INDEX idx_tgt_prem_ea    ON TGT_PREMISE (ENERGY_ACCOUNT_ID);
CREATE INDEX idx_tgt_prem_zip   ON TGT_PREMISE (ZIP_CODE);
CREATE INDEX idx_tgt_prem_state ON TGT_PREMISE (STATE_CODE);

COMMENT ON COLUMN TGT_PREMISE.FULL_ADDRESS IS 'Derived: ADDRESS_LINE1 + ADDRESS_LINE2 + CITY + STATE + ZIP — TR-COMB-02';

-- ---------------------------------------------------------------------------
-- TGT_METER
-- ---------------------------------------------------------------------------
CREATE TABLE TGT_METER (
    METER_ID            VARCHAR2(20)    NOT NULL,
    PREMISE_ID          VARCHAR2(20)    NOT NULL,
    METER_NUMBER        VARCHAR2(30)    NOT NULL,
    METER_TYPE          VARCHAR2(30)    DEFAULT 'ANALOG' NOT NULL,
    MANUFACTURER        VARCHAR2(100),
    MODEL               VARCHAR2(100),
    INSTALL_DATE        DATE            NOT NULL,
    REMOVAL_DATE        DATE,
    IS_ACTIVE           NUMBER(1,0)     DEFAULT 1    NOT NULL,
    SOURCE_UPDATED_AT   TIMESTAMP,
    ETL_RUN_ID          NUMBER(19,0)    NOT NULL,
    ETL_LOAD_TS         TIMESTAMP       DEFAULT SYS_EXTRACT_UTC(SYSTIMESTAMP) NOT NULL,
    CREATED_AT          TIMESTAMP       DEFAULT SYS_EXTRACT_UTC(SYSTIMESTAMP) NOT NULL,
    UPDATED_AT          TIMESTAMP       DEFAULT SYS_EXTRACT_UTC(SYSTIMESTAMP) NOT NULL,
    CONSTRAINT pk_tgt_meter             PRIMARY KEY (METER_ID),
    CONSTRAINT fk_tgt_mtr_premise       FOREIGN KEY (PREMISE_ID) REFERENCES TGT_PREMISE (PREMISE_ID),
    CONSTRAINT uq_tgt_mtr_number        UNIQUE (METER_NUMBER),
    CONSTRAINT ck_tgt_mtr_is_active     CHECK (IS_ACTIVE IN (0,1))
);

CREATE INDEX idx_tgt_mtr_premise ON TGT_METER (PREMISE_ID);

-- ---------------------------------------------------------------------------
-- TGT_MONTHLY_USAGE
-- ---------------------------------------------------------------------------
CREATE TABLE TGT_MONTHLY_USAGE (
    USAGE_ID                VARCHAR2(30)    NOT NULL,
    ENERGY_ACCOUNT_ID       VARCHAR2(20)    NOT NULL,
    PREMISE_ID              VARCHAR2(20)    NOT NULL,
    METER_ID                VARCHAR2(20)    NOT NULL,
    BILLING_MONTH           VARCHAR2(7)     NOT NULL,
    BILL_START_DATE         DATE            NOT NULL,
    BILL_END_DATE           DATE            NOT NULL,
    BILLING_DAYS            NUMBER(3,0)     NOT NULL,
    KWH_USAGE               NUMBER(12,3)    NOT NULL,
    KWH_EFFECTIVE           NUMBER(12,3)    NOT NULL,
    PEAK_DEMAND_KW          NUMBER(10,3),
    PREV_METER_READING      NUMBER(12,3),
    CURR_METER_READING      NUMBER(12,3),
    READ_TYPE               VARCHAR2(10)    DEFAULT 'ACTUAL' NOT NULL,
    RATE_PLAN               VARCHAR2(30)    NOT NULL,
    FIXED_CHARGE            NUMBER(10,2)    DEFAULT 0    NOT NULL,
    ENERGY_CHARGE           NUMBER(10,2)    DEFAULT 0    NOT NULL,
    DEMAND_CHARGE           NUMBER(10,2)    DEFAULT 0    NOT NULL,
    SUBTOTAL_CHARGE         NUMBER(10,2)    DEFAULT 0    NOT NULL,
    TAX_AMOUNT              NUMBER(10,2)    DEFAULT 0    NOT NULL,
    TOTAL_BILLED            NUMBER(10,2)    DEFAULT 0    NOT NULL,
    USAGE_QUALITY_STATUS    VARCHAR2(20)    DEFAULT 'ACTUAL' NOT NULL,
    IS_CORRECTION           NUMBER(1,0)     DEFAULT 0    NOT NULL,
    CORRECTION_REASON       VARCHAR2(200),
    SOURCE_UPDATED_AT       TIMESTAMP,
    ETL_RUN_ID              NUMBER(19,0)    NOT NULL,
    ETL_LOAD_TS             TIMESTAMP       DEFAULT SYS_EXTRACT_UTC(SYSTIMESTAMP) NOT NULL,
    CREATED_AT              TIMESTAMP       DEFAULT SYS_EXTRACT_UTC(SYSTIMESTAMP) NOT NULL,
    UPDATED_AT              TIMESTAMP       DEFAULT SYS_EXTRACT_UTC(SYSTIMESTAMP) NOT NULL,
    CONSTRAINT pk_tgt_monthly_usage     PRIMARY KEY (USAGE_ID),
    CONSTRAINT fk_tgt_usg_ea            FOREIGN KEY (ENERGY_ACCOUNT_ID) REFERENCES TGT_ENERGY_ACCOUNT (ENERGY_ACCOUNT_ID),
    CONSTRAINT uq_tgt_usg_ea_month      UNIQUE (ENERGY_ACCOUNT_ID, BILLING_MONTH),
    CONSTRAINT ck_tgt_usg_kwh           CHECK (KWH_USAGE >= 0),
    CONSTRAINT ck_tgt_usg_demand        CHECK (PEAK_DEMAND_KW IS NULL OR PEAK_DEMAND_KW >= 0),
    CONSTRAINT ck_tgt_usg_total         CHECK (TOTAL_BILLED >= 0),
    CONSTRAINT ck_tgt_usg_quality       CHECK (USAGE_QUALITY_STATUS IN ('ACTUAL','ESTIMATED','CORRECTED')),
    CONSTRAINT ck_tgt_usg_is_corr       CHECK (IS_CORRECTION IN (0,1))
);

CREATE INDEX idx_tgt_usg_ea         ON TGT_MONTHLY_USAGE (ENERGY_ACCOUNT_ID);
CREATE INDEX idx_tgt_usg_month      ON TGT_MONTHLY_USAGE (BILLING_MONTH);
CREATE INDEX idx_tgt_usg_meter      ON TGT_MONTHLY_USAGE (METER_ID);
CREATE INDEX idx_tgt_usg_rate       ON TGT_MONTHLY_USAGE (RATE_PLAN);
CREATE INDEX idx_tgt_usg_quality    ON TGT_MONTHLY_USAGE (USAGE_QUALITY_STATUS);

COMMENT ON TABLE  TGT_MONTHLY_USAGE                       IS 'Monthly electricity usage and billing — loaded from Snowflake BILLING.MONTHLY_USAGE';
COMMENT ON COLUMN TGT_MONTHLY_USAGE.KWH_EFFECTIVE         IS 'COALESCE(KWH_ADJUSTED, KWH_USAGE) — actual basis for energy charge';
COMMENT ON COLUMN TGT_MONTHLY_USAGE.USAGE_QUALITY_STATUS  IS 'ACTUAL / ESTIMATED / CORRECTED — derived from READ_TYPE + IS_CORRECTION';
COMMENT ON COLUMN TGT_MONTHLY_USAGE.SUBTOTAL_CHARGE       IS 'FIXED + ENERGY + DEMAND charges before tax';
COMMENT ON COLUMN TGT_MONTHLY_USAGE.TOTAL_BILLED          IS 'SUBTOTAL_CHARGE + TAX_AMOUNT (additive form — never subtract)';
