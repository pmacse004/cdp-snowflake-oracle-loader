-- =============================================================================
-- V003__create_etl_control_tables.sql
-- =============================================================================
-- Flyway migration — ETL control tables.
-- Run as: CDP_LOADER (application user — NOT SYSDBA)
--
-- Tables:
--   ETL_WATERMARK       — per-table incremental load watermarks
--   ETL_JOB_RUN         — detailed job run audit log
--   ETL_RECORD_ERROR    — rejected record store
--   ETL_RECONCILIATION  — source-to-target count and aggregate comparison
-- =============================================================================

-- ---------------------------------------------------------------------------
-- ETL_WATERMARK
-- ---------------------------------------------------------------------------
CREATE TABLE ETL_WATERMARK (
    WATERMARK_ID        NUMBER(10,0)    GENERATED ALWAYS AS IDENTITY    NOT NULL,
    JOB_TYPE            VARCHAR2(30)    NOT NULL,
    TABLE_NAME          VARCHAR2(100)   NOT NULL,
    LAST_EXTRACTED_TS   TIMESTAMP       NOT NULL,
    LAST_MAX_SOURCE_ID  VARCHAR2(50),
    LAST_RUN_ID         NUMBER(19,0),
    RECORD_COUNT        NUMBER(10,0)    DEFAULT 0    NOT NULL,
    IS_ACTIVE           NUMBER(1,0)     DEFAULT 1    NOT NULL,
    CREATED_AT          TIMESTAMP       DEFAULT SYS_EXTRACT_UTC(SYSTIMESTAMP) NOT NULL,
    UPDATED_AT          TIMESTAMP       DEFAULT SYS_EXTRACT_UTC(SYSTIMESTAMP) NOT NULL,
    CONSTRAINT pk_etl_watermark         PRIMARY KEY (WATERMARK_ID),
    CONSTRAINT uq_etl_wm_job_table      UNIQUE (JOB_TYPE, TABLE_NAME),
    CONSTRAINT ck_etl_wm_job_type       CHECK (JOB_TYPE IN ('INITIAL','DAILY','MONTHLY')),
    CONSTRAINT ck_etl_wm_is_active      CHECK (IS_ACTIVE IN (0,1))
);

COMMENT ON TABLE  ETL_WATERMARK                    IS 'Per-table incremental load watermarks';
COMMENT ON COLUMN ETL_WATERMARK.TABLE_NAME         IS 'Fully qualified Snowflake table name (SCHEMA.TABLE)';
COMMENT ON COLUMN ETL_WATERMARK.LAST_EXTRACTED_TS  IS 'UTC timestamp of the last record successfully extracted';
COMMENT ON COLUMN ETL_WATERMARK.LAST_MAX_SOURCE_ID IS 'Max source ID at LAST_EXTRACTED_TS — tie-break for equal timestamps';

-- ---------------------------------------------------------------------------
-- ETL_JOB_RUN
-- ---------------------------------------------------------------------------
CREATE TABLE ETL_JOB_RUN (
    RUN_ID              NUMBER(19,0)    GENERATED ALWAYS AS IDENTITY    NOT NULL,
    JOB_NAME            VARCHAR2(100)   NOT NULL,
    JOB_TYPE            VARCHAR2(30)    NOT NULL,
    SPRING_EXEC_ID      NUMBER(19,0),
    STATUS              VARCHAR2(20)    NOT NULL,
    START_TIME          TIMESTAMP,
    END_TIME            TIMESTAMP,
    DURATION_SECONDS    NUMBER(10,2),
    RECORDS_READ        NUMBER(10,0)    DEFAULT 0    NOT NULL,
    RECORDS_INSERTED    NUMBER(10,0)    DEFAULT 0    NOT NULL,
    RECORDS_UPDATED     NUMBER(10,0)    DEFAULT 0    NOT NULL,
    RECORDS_SKIPPED     NUMBER(10,0)    DEFAULT 0    NOT NULL,
    RECORDS_REJECTED    NUMBER(10,0)    DEFAULT 0    NOT NULL,
    THROUGHPUT_RPS      NUMBER(10,2),
    WATERMARK_BEFORE    VARCHAR2(50),
    WATERMARK_AFTER     VARCHAR2(50),
    ERROR_SUMMARY       VARCHAR2(500),
    TRIGGERED_BY        VARCHAR2(100)   DEFAULT 'API' NOT NULL,
    CREATED_AT          TIMESTAMP       DEFAULT SYS_EXTRACT_UTC(SYSTIMESTAMP) NOT NULL,
    UPDATED_AT          TIMESTAMP       DEFAULT SYS_EXTRACT_UTC(SYSTIMESTAMP) NOT NULL,
    CONSTRAINT pk_etl_job_run           PRIMARY KEY (RUN_ID),
    CONSTRAINT ck_etl_jr_job_type       CHECK (JOB_TYPE IN ('INITIAL','DAILY','MONTHLY')),
    CONSTRAINT ck_etl_jr_status         CHECK (STATUS IN ('STARTED','COMPLETED','FAILED','STOPPED','ABANDONED'))
);

CREATE INDEX idx_etl_jr_job_name    ON ETL_JOB_RUN (JOB_NAME);
CREATE INDEX idx_etl_jr_status      ON ETL_JOB_RUN (STATUS);
CREATE INDEX idx_etl_jr_start_time  ON ETL_JOB_RUN (START_TIME DESC);

COMMENT ON TABLE  ETL_JOB_RUN                IS 'Job-level audit log — one row per job execution';
COMMENT ON COLUMN ETL_JOB_RUN.SPRING_EXEC_ID IS 'Links to BATCH_JOB_EXECUTION for Spring Batch detail';

-- ---------------------------------------------------------------------------
-- ETL_RECORD_ERROR
-- ---------------------------------------------------------------------------
CREATE TABLE ETL_RECORD_ERROR (
    ERROR_ID            NUMBER(19,0)    GENERATED ALWAYS AS IDENTITY    NOT NULL,
    RUN_ID              NUMBER(19,0)    NOT NULL,
    JOB_NAME            VARCHAR2(100)   NOT NULL,
    STEP_NAME           VARCHAR2(100)   NOT NULL,
    SOURCE_ENTITY       VARCHAR2(100)   NOT NULL,
    SOURCE_RECORD_ID    VARCHAR2(100),
    ERROR_CODE          VARCHAR2(50)    NOT NULL,
    ERROR_MESSAGE       VARCHAR2(1000)  NOT NULL,
    PAYLOAD_EXCERPT     VARCHAR2(2000),
    ERROR_TIMESTAMP     TIMESTAMP       DEFAULT SYS_EXTRACT_UTC(SYSTIMESTAMP) NOT NULL,
    IS_RETRYABLE        NUMBER(1,0)     DEFAULT 0    NOT NULL,
    CONSTRAINT pk_etl_record_error      PRIMARY KEY (ERROR_ID),
    CONSTRAINT fk_err_run_id            FOREIGN KEY (RUN_ID) REFERENCES ETL_JOB_RUN (RUN_ID),
    CONSTRAINT ck_err_is_retryable      CHECK (IS_RETRYABLE IN (0,1))
);

CREATE INDEX idx_etl_err_run_id   ON ETL_RECORD_ERROR (RUN_ID);
CREATE INDEX idx_etl_err_source   ON ETL_RECORD_ERROR (SOURCE_ENTITY);
CREATE INDEX idx_etl_err_code     ON ETL_RECORD_ERROR (ERROR_CODE);
CREATE INDEX idx_etl_err_ts       ON ETL_RECORD_ERROR (ERROR_TIMESTAMP DESC);

COMMENT ON TABLE  ETL_RECORD_ERROR                  IS 'Rejected source records with error details';
COMMENT ON COLUMN ETL_RECORD_ERROR.PAYLOAD_EXCERPT  IS 'Safe payload excerpt — SSN and sensitive fields masked';

-- ---------------------------------------------------------------------------
-- ETL_RECONCILIATION
-- ---------------------------------------------------------------------------
CREATE TABLE ETL_RECONCILIATION (
    RECON_ID            NUMBER(19,0)    GENERATED ALWAYS AS IDENTITY    NOT NULL,
    RUN_ID              NUMBER(19,0)    NOT NULL,
    JOB_TYPE            VARCHAR2(30)    NOT NULL,
    ENTITY_NAME         VARCHAR2(100)   NOT NULL,
    RECON_METRIC        VARCHAR2(100)   NOT NULL,
    SOURCE_VALUE        NUMBER(20,6),
    TARGET_VALUE        NUMBER(20,6),
    VARIANCE            NUMBER(20,6),
    VARIANCE_PCT        NUMBER(10,6),
    TOLERANCE_PCT       NUMBER(10,6),
    STATUS              VARCHAR2(20)    NOT NULL,
    NOTES               VARCHAR2(500),
    RECON_TIMESTAMP     TIMESTAMP       DEFAULT SYS_EXTRACT_UTC(SYSTIMESTAMP) NOT NULL,
    CONSTRAINT pk_etl_reconciliation    PRIMARY KEY (RECON_ID),
    CONSTRAINT fk_recon_run_id          FOREIGN KEY (RUN_ID) REFERENCES ETL_JOB_RUN (RUN_ID),
    CONSTRAINT ck_recon_job_type        CHECK (JOB_TYPE IN ('INITIAL','DAILY','MONTHLY')),
    CONSTRAINT ck_recon_status          CHECK (STATUS IN ('PASS','FAIL','WARNING'))
);

CREATE INDEX idx_etl_recon_run_id   ON ETL_RECONCILIATION (RUN_ID);
CREATE INDEX idx_etl_recon_entity   ON ETL_RECONCILIATION (ENTITY_NAME);
CREATE INDEX idx_etl_recon_status   ON ETL_RECONCILIATION (STATUS);

COMMENT ON TABLE  ETL_RECONCILIATION              IS 'Source-to-target count and aggregate reconciliation results';
COMMENT ON COLUMN ETL_RECONCILIATION.RECON_METRIC IS 'e.g. COUNT, TOTAL_KWH, TOTAL_ENERGY_CHARGE, TOTAL_BILLED';
COMMENT ON COLUMN ETL_RECONCILIATION.VARIANCE_PCT IS 'ABS((source-target)/source)*100';
