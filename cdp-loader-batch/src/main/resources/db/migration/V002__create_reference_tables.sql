-- =============================================================================
-- V002__create_reference_tables.sql
-- =============================================================================
-- Flyway migration — Oracle reference / lookup tables.
-- Run as: CDP_LOADER (application user — NOT SYSDBA)
-- =============================================================================

CREATE TABLE REF_CODE_VALUE (
    CODE_VALUE_ID       NUMBER(10,0)    GENERATED ALWAYS AS IDENTITY    NOT NULL,
    DOMAIN              VARCHAR2(50)    NOT NULL,
    CODE                VARCHAR2(30)    NOT NULL,
    CODE_LABEL          VARCHAR2(500)   NOT NULL,
    DESCRIPTION         VARCHAR2(500),
    DISPLAY_ORDER       NUMBER(5,0)     DEFAULT 0                       NOT NULL,
    IS_ACTIVE           NUMBER(1,0)     DEFAULT 1                       NOT NULL,
    CREATED_AT          TIMESTAMP       DEFAULT SYS_EXTRACT_UTC(SYSTIMESTAMP) NOT NULL,
    UPDATED_AT          TIMESTAMP       DEFAULT SYS_EXTRACT_UTC(SYSTIMESTAMP) NOT NULL,
    CONSTRAINT pk_ref_code_value        PRIMARY KEY (CODE_VALUE_ID),
    CONSTRAINT uq_ref_domain_code       UNIQUE (DOMAIN, CODE),
    CONSTRAINT ck_ref_is_active         CHECK (IS_ACTIVE IN (0,1))
);

CREATE INDEX idx_ref_cv_domain ON REF_CODE_VALUE (DOMAIN);

COMMENT ON TABLE  REF_CODE_VALUE             IS 'Reference code values translated from Snowflake REF.CODE_VALUE';
COMMENT ON COLUMN REF_CODE_VALUE.DOMAIN      IS 'Code domain, e.g. ACCT_STATUS, RATE_PLAN, CUST_TYPE';
COMMENT ON COLUMN REF_CODE_VALUE.CODE        IS 'Code value, e.g. ACTIVE, RES_STD';
COMMENT ON COLUMN REF_CODE_VALUE.CODE_LABEL  IS 'Human-readable label or JSON parameters for rate plans';
