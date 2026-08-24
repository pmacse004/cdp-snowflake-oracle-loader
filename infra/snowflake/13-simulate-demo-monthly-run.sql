-- =============================================================================
-- Script 13: Simulate Demo Monthly Run
-- =============================================================================
-- Run as: CDP_ADMIN_ROLE
-- Database: CDP_UTIL_DB
-- Prerequisite: Script 12 has been run and initialLoadJob has completed.
--
-- PURPOSE
--   Inserts 10 new monthly usage rows for billing month 2024-07 (July).
--   This is a clearly subsequent month to the June data in the initial load,
--   demonstrating real incremental monthly processing.
--
-- IDEMPOTENCY
--   Uses MERGE on USAGE_ID. Safe to run multiple times.
--
-- STABLE IDENTIFIERS
--   DEMO_RUN_ID prefix: USG-D13-
--   Billing month: 2024-07
--   Uses the first 10 EA IDs from EA-000001 through EA-000010.
--
-- NOTE
--   No intentional invalid rows in this script.
--   All calculations follow ICA rules TR-BILL-02 through TR-BILL-07.
-- =============================================================================

-- PREFLIGHT GUARD
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
-- 10 NEW MONTHLY USAGE ROWS FOR JULY 2024
-- Rate plan RES-STD: fixed=8.50, energy=0.1150, demand=null, tax=0.080
--   FIXED  = 8.50
--   ENERGY = ROUND(KWH * 0.1150, 2)
--   DEMAND = 0  (no demand component for RES-STD)
--   SUB    = FIXED + ENERGY
--   TAX    = ROUND(SUB * 0.080, 2)
--   TOTAL  = SUB + TAX
--
-- IMPORTANT: ENERGY_ACCOUNT_ID must already exist in CUSTOMER.ENERGY_ACCOUNT
--   (loaded by script 06 initial data). These use EA-000001 through EA-000010.
-- ============================================================================
USE SCHEMA BILLING;

MERGE INTO BILLING.MONTHLY_USAGE tgt
USING (
    -- Each row: USAGE_ID, EA_ID, PREMISE_ID, METER_ID, KWH, PEAK_KW
    -- Premise and Meter IDs come from script 06 initial data.
    -- Using PREM-000001..010 and MTR-000001..010 which are created by 06.
    SELECT 'USG-D13-EA000001' AS UID, 'EA-000001' AS EAID, 'PREM-000001' AS PID, 'MTR-000001' AS MID, 485.000 AS KWH
    UNION ALL SELECT 'USG-D13-EA000002', 'EA-000002', 'PREM-000002', 'MTR-000002', 612.500
    UNION ALL SELECT 'USG-D13-EA000003', 'EA-000003', 'PREM-000003', 'MTR-000003', 334.200
    UNION ALL SELECT 'USG-D13-EA000004', 'EA-000004', 'PREM-000004', 'MTR-000004', 720.800
    UNION ALL SELECT 'USG-D13-EA000005', 'EA-000005', 'PREM-000005', 'MTR-000005', 295.600
    UNION ALL SELECT 'USG-D13-EA000006', 'EA-000006', 'PREM-000006', 'MTR-000006', 540.000
    UNION ALL SELECT 'USG-D13-EA000007', 'EA-000007', 'PREM-000007', 'MTR-000007', 410.400
    UNION ALL SELECT 'USG-D13-EA000008', 'EA-000008', 'PREM-000008', 'MTR-000008', 678.900
    UNION ALL SELECT 'USG-D13-EA000009', 'EA-000009', 'PREM-000009', 'MTR-000009', 225.100
    UNION ALL SELECT 'USG-D13-EA000010', 'EA-000010', 'PREM-000010', 'MTR-000010', 815.300
) src ON (tgt.USAGE_ID = src.UID)
WHEN MATCHED THEN UPDATE SET
    KWH_USAGE    = src.KWH,
    UPDATED_AT   = CURRENT_TIMESTAMP()
WHEN NOT MATCHED THEN INSERT
    (USAGE_ID, ENERGY_ACCOUNT_ID, PREMISE_ID, METER_ID,
     BILLING_MONTH, BILL_START_DATE, BILL_END_DATE, BILLING_DAYS,
     KWH_USAGE, KWH_ADJUSTED, PEAK_DEMAND_KW, PREV_METER_READING, CURR_METER_READING,
     READ_TYPE, RATE_PLAN,
     FIXED_CHARGE, ENERGY_CHARGE, DEMAND_CHARGE, SUBTOTAL_CHARGE, TAX_AMOUNT, TOTAL_BILLED,
     IS_CORRECTION, UPDATED_AT)
VALUES (
    src.UID, src.EAID, src.PID, src.MID,
    '2024-07',
    '2024-07-01'::DATE,
    '2024-07-31'::DATE,
    31,
    src.KWH,
    src.KWH,           -- KWH_ADJUSTED = KWH_USAGE (no loss factor for demo)
    NULL,              -- no demand measurement
    src.KWH * 3,       -- synthetic previous reading
    src.KWH * 4,       -- synthetic current reading
    'ACTUAL',
    'RES-STD',
    -- Charge calculations per ICA TR-BILL-02..07
    8.50::NUMBER(10,2),                                                      -- FIXED
    ROUND(src.KWH * 0.1150, 2)::NUMBER(10,2),                               -- ENERGY
    0.00::NUMBER(10,2),                                                      -- DEMAND (null rate → 0)
    (8.50 + ROUND(src.KWH * 0.1150, 2))::NUMBER(10,2),                      -- SUBTOTAL
    ROUND((8.50 + ROUND(src.KWH * 0.1150, 2)) * 0.080, 2)::NUMBER(10,2),   -- TAX
    ((8.50 + ROUND(src.KWH * 0.1150, 2)) +
     ROUND((8.50 + ROUND(src.KWH * 0.1150, 2)) * 0.080, 2))::NUMBER(10,2), -- TOTAL
    FALSE,
    CURRENT_TIMESTAMP()
);

-- ============================================================================
-- VERIFICATION
-- ============================================================================
SELECT
    'New July 2024 rows' AS CHECK_TYPE,
    COUNT(*) AS CNT,
    ROUND(SUM(TOTAL_BILLED), 2) AS TOTAL_BILLED,
    ROUND(SUM(KWH_USAGE), 3) AS TOTAL_KWH
FROM BILLING.MONTHLY_USAGE
WHERE USAGE_ID LIKE 'USG-D13-%'
  AND BILLING_MONTH = '2024-07';
