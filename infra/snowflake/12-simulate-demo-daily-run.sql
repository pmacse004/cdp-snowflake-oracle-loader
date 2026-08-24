-- =============================================================================
-- Script 12: Simulate Demo Daily Run
-- =============================================================================
-- Run as: CDP_ADMIN_ROLE
-- Database: CDP_UTIL_DB
-- Prerequisite: initialLoadJob has completed successfully.
--
-- PURPOSE
--   Inserts 5 new customers and updates 5 existing customer/contact records
--   so the daily incremental job picks up real changes after the initial load.
--
-- IDEMPOTENCY
--   Uses MERGE with stable DEMO_RUN_ID = 'DR12' identifiers.
--   Safe to run multiple times — does not create duplicates.
--
-- STABLE IDENTIFIERS
--   New customers: CUST-D12-001 through CUST-D12-005 (max 20 chars)
--   New contacts:  CONT-D12-001 through CONT-D12-010
--   New accounts:  EA-D12-001 through EA-D12-005
--   New premises:  PREM-D12-001 through PREM-D12-005
--   New meters:    MTR-D12-001 through MTR-D12-005
--   New billing:   BA-D12-001 through BA-D12-005
-- =============================================================================

-- PREFLIGHT GUARD
SELECT
    IFF(CURRENT_DATABASE() = 'CDP_UTIL_DB',    'OK', 'ABORT: wrong database') AS DB_CHECK,
    IFF(CURRENT_ROLE()     = 'CDP_ADMIN_ROLE', 'OK', 'ABORT: wrong role')     AS ROLE_CHECK;

-- Abort if wrong context
EXECUTE IMMEDIATE $$
DECLARE
    wrong_database EXCEPTION(-20001, 'ABORT: expected CDP_UTIL_DB');
    wrong_role     EXCEPTION(-20002, 'ABORT: expected CDP_ADMIN_ROLE');
BEGIN
    IF (CURRENT_DATABASE() <> 'CDP_UTIL_DB')    THEN RAISE wrong_database; END IF;
    IF (CURRENT_ROLE()     <> 'CDP_ADMIN_ROLE') THEN RAISE wrong_role;     END IF;
    RETURN 'PREFLIGHT PASS';
END;
$$;

USE ROLE CDP_ADMIN_ROLE;
USE DATABASE CDP_UTIL_DB;
USE WAREHOUSE CDP_LOADER_WH;

-- ============================================================================
-- 5 NEW CUSTOMERS (CUST-D12-001 through CUST-D12-005)
-- ============================================================================
USE SCHEMA CUSTOMER;

MERGE INTO CUSTOMER.CUSTOMER tgt
USING (
    SELECT 'CUST-D12-001' AS ID, 'Alice'   AS FN, 'Morgan'    AS LN, 'RESIDENTIAL' AS CT, 'ACTIVE'   AS ST
    UNION ALL
    SELECT 'CUST-D12-002', 'Bob',    'Vance',   'COMMERCIAL',  'ACTIVE'
    UNION ALL
    SELECT 'CUST-D12-003', 'Clara',  'Oswald',  'RESIDENTIAL', 'PENDING'
    UNION ALL
    SELECT 'CUST-D12-004', 'David',  'Lister',  'RESIDENTIAL', 'ACTIVE'
    UNION ALL
    SELECT 'CUST-D12-005', 'Erika',  'Svensson','COMMERCIAL',  'ACTIVE'
) src ON (tgt.CUSTOMER_ID = src.ID)
WHEN MATCHED THEN UPDATE SET
    FIRST_NAME = src.FN, LAST_NAME = src.LN, CUSTOMER_TYPE = src.CT,
    ACCOUNT_STATUS = src.ST, UPDATED_AT = CURRENT_TIMESTAMP()
WHEN NOT MATCHED THEN INSERT
    (CUSTOMER_ID, FIRST_NAME, LAST_NAME, CUSTOMER_TYPE, PREFERRED_LANGUAGE, ACCOUNT_STATUS, UPDATED_AT)
VALUES (src.ID, src.FN, src.LN, src.CT, 'EN', src.ST, CURRENT_TIMESTAMP());

-- Primary email contacts for new customers
MERGE INTO CUSTOMER.CUSTOMER_CONTACT tgt
USING (
    SELECT 'CONT-D12-001' AS CID, 'CUST-D12-001' AS CUSTID, 'alice.morgan@demo12.example.com'   AS VAL, '2024-01-15' AS ED
    UNION ALL
    SELECT 'CONT-D12-002', 'CUST-D12-002', 'bob.vance@demo12.example.com',    '2024-01-15'
    UNION ALL
    SELECT 'CONT-D12-003', 'CUST-D12-003', 'clara.oswald@demo12.example.com', '2024-01-15'
    UNION ALL
    SELECT 'CONT-D12-004', 'CUST-D12-004', 'david.lister@demo12.example.com', '2024-01-15'
    UNION ALL
    SELECT 'CONT-D12-005', 'CUST-D12-005', 'erika.svensson@demo12.example.com','2024-01-15'
) src ON (tgt.CONTACT_ID = src.CID)
WHEN MATCHED THEN UPDATE SET CONTACT_VALUE = src.VAL, UPDATED_AT = CURRENT_TIMESTAMP()
WHEN NOT MATCHED THEN INSERT
    (CONTACT_ID, CUSTOMER_ID, CONTACT_TYPE, CONTACT_VALUE, IS_PRIMARY, IS_VERIFIED, EFFECTIVE_DATE, UPDATED_AT)
VALUES (src.CID, src.CUSTID, 'EMAIL', src.VAL, TRUE, TRUE, src.ED::DATE, CURRENT_TIMESTAMP());

-- ============================================================================
-- ENERGY ACCOUNTS for new customers
-- ============================================================================
MERGE INTO CUSTOMER.ENERGY_ACCOUNT tgt
USING (
    SELECT 'EA-D12-001' AS ID, 'CUST-D12-001' AS CUSTID, 'ACC-D12-001' AS ACCT_NBR, 'ACTIVE'  AS ST, 'RESIDENTIAL' AS RC
    UNION ALL
    SELECT 'EA-D12-002', 'CUST-D12-002', 'ACC-D12-002', 'ACTIVE',  'SMALL_COMMERCIAL'
    UNION ALL
    SELECT 'EA-D12-003', 'CUST-D12-003', 'ACC-D12-003', 'PENDING', 'RESIDENTIAL'
    UNION ALL
    SELECT 'EA-D12-004', 'CUST-D12-004', 'ACC-D12-004', 'ACTIVE',  'RESIDENTIAL'
    UNION ALL
    SELECT 'EA-D12-005', 'CUST-D12-005', 'ACC-D12-005', 'ACTIVE',  'SMALL_COMMERCIAL'
) src ON (tgt.ENERGY_ACCOUNT_ID = src.ID)
WHEN MATCHED THEN UPDATE SET
    ACCOUNT_STATUS = src.ST, UPDATED_AT = CURRENT_TIMESTAMP()
WHEN NOT MATCHED THEN INSERT
    (ENERGY_ACCOUNT_ID, CUSTOMER_ID, ACCOUNT_NUMBER, ACCOUNT_STATUS, SERVICE_TYPE, RATE_CLASS, OPEN_DATE, UPDATED_AT)
VALUES (src.ID, src.CUSTID, src.ACCT_NBR, src.ST, 'ELECTRIC', src.RC, '2024-01-15'::DATE, CURRENT_TIMESTAMP());

-- ============================================================================
-- 5 EXISTING CUSTOMER CHANGES (bump UPDATED_AT so incremental picks them up)
-- Update first 5 existing customers' status_reason and email
-- ============================================================================
UPDATE CUSTOMER.CUSTOMER
SET STATUS_REASON = 'DR12-demo-update',
    UPDATED_AT    = CURRENT_TIMESTAMP()
WHERE CUSTOMER_ID IN (
    SELECT CUSTOMER_ID FROM CUSTOMER.CUSTOMER
    WHERE CUSTOMER_ID NOT LIKE 'CUST-D12-%'
    ORDER BY CUSTOMER_ID
    LIMIT 5
);

-- ============================================================================
-- VERIFICATION
-- ============================================================================
SELECT 'New customers' AS CHECK_TYPE, COUNT(*) AS CNT
FROM CUSTOMER.CUSTOMER WHERE CUSTOMER_ID LIKE 'CUST-D12-%'
UNION ALL
SELECT 'New energy accounts', COUNT(*) FROM CUSTOMER.ENERGY_ACCOUNT WHERE ENERGY_ACCOUNT_ID LIKE 'EA-D12-%'
UNION ALL
SELECT 'Updated existing customers', COUNT(*) FROM CUSTOMER.CUSTOMER WHERE STATUS_REASON = 'DR12-demo-update';
