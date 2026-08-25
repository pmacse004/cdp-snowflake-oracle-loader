-- =============================================================================
-- Monthly Load Simulation — Round 18  |  Billing Month: 2027-06
-- =============================================================================
-- Run as: CDP_ADMIN_ROLE  |  Database: CDP_UTIL_DB  |  Warehouse: CDP_LOADER_WH
--
-- SCENARIO  Corrections for two estimated reads + new wave
-- RATE PLANS  RES-1, COM-1, IND-1
-- REJECTION  REJ-M1: negative KWH_USAGE → VR-USAGE-001
-- TRIGGER    POST http://localhost:8080/api/jobs/monthly
-- PREREQUISITE  monthly-round-17.sql must have been run.
-- =============================================================================

USE ROLE CDP_ADMIN_ROLE;
USE DATABASE CDP_UTIL_DB;
USE WAREHOUSE CDP_LOADER_WH;

MERGE INTO BILLING.MONTHLY_USAGE tgt
USING (
    SELECT col1 AS UID, col2 AS EAID, col3 AS KWH, col4 AS PEAK_KW, col5 AS RATE, col6 AS IS_CORR, col7 AS CORR_RSN
    FROM VALUES
        ('USG-SIM-R18-001', 'EA-SIM-R18-001',  520.000, NULL, 'RES-1', FALSE, NULL),
        ('USG-SIM-R18-002', 'EA-SIM-R18-003',  505.000, NULL, 'RES-1', FALSE, NULL),
        ('USG-SIM-R18-003', 'EA-SIM-R18-004', 3700.000, NULL, 'COM-3', FALSE, NULL),
        ('USG-SIM-R18-004', 'EA-SIM-R20-001',16000.000, 74.0, 'IND-1', FALSE, NULL),
        ('USG-SIM-R18-005', 'EA-SIM-R20-003',18500.000, 85.0, 'IND-1', FALSE, NULL),
        -- corrections for R13 estimated reads
        ('USG-SIM-R18-COR1','EA-SIM-R15-001',  518.000, NULL, 'RES-1', TRUE, 'METER_READ_CORRECTION'),
        ('USG-SIM-R18-COR2','EA-SIM-R15-004',  532.000, NULL, 'RES-1', TRUE, 'METER_READ_CORRECTION'),
        -- REJ-M1: negative KWH
        ('USG-SIM-R18-REJ', 'EA-SIM-R19-003', -95.000,  NULL, 'RES-1', FALSE, NULL)
        AS v(col1,col2,col3,col4,col5,col6,col7)
) src ON (tgt.USAGE_ID = src.UID)
WHEN MATCHED THEN UPDATE SET KWH_USAGE = src.KWH, UPDATED_AT = CURRENT_TIMESTAMP()
WHEN NOT MATCHED THEN INSERT
    (USAGE_ID, ENERGY_ACCOUNT_ID, PREMISE_ID, METER_ID,
     BILLING_MONTH, BILL_START_DATE, BILL_END_DATE, BILLING_DAYS,
     KWH_USAGE, KWH_ADJUSTED, PEAK_DEMAND_KW,
     PREV_METER_READING, CURR_METER_READING, READ_TYPE, RATE_PLAN,
     FIXED_CHARGE, ENERGY_CHARGE, DEMAND_CHARGE,
     SUBTOTAL_CHARGE, TAX_AMOUNT, TOTAL_BILLED,
     IS_CORRECTION, CORRECTION_REASON, UPDATED_AT)
VALUES (
    src.UID, src.EAID, 'PREM-SIM', 'MTR-SIM',
    '2027-06', '2027-06-01'::DATE, '2027-06-30'::DATE, 30,
    src.KWH, src.KWH, src.PEAK_KW,
    ABS(src.KWH) * 3, ABS(src.KWH) * 4, 'ACTUAL', src.RATE,
    CASE WHEN src.PEAK_KW IS NOT NULL THEN 75.00 WHEN src.RATE='COM-3' THEN 15.00 ELSE 8.50 END,
    CASE WHEN src.PEAK_KW IS NOT NULL THEN ROUND(src.KWH*0.0850,2)
         WHEN src.RATE='COM-3'        THEN ROUND(src.KWH*0.1100,2)
         ELSE                              ROUND(src.KWH*0.1150,2) END,
    CASE WHEN src.PEAK_KW IS NOT NULL THEN ROUND(src.PEAK_KW*12.00,2) ELSE 0.00 END,
    CASE WHEN src.PEAK_KW IS NOT NULL THEN ROUND(75.00+ROUND(src.KWH*0.0850,2)+ROUND(src.PEAK_KW*12.00,2),2)
         WHEN src.RATE='COM-3'        THEN ROUND(15.00+ROUND(src.KWH*0.1100,2),2)
         ELSE                              ROUND(8.50 +ROUND(src.KWH*0.1150,2),2) END,
    CASE WHEN src.PEAK_KW IS NOT NULL THEN ROUND((75.00+ROUND(src.KWH*0.0850,2)+ROUND(src.PEAK_KW*12.00,2))*0.070,2)
         WHEN src.RATE='COM-3'        THEN ROUND((15.00+ROUND(src.KWH*0.1100,2))*0.085,2)
         ELSE                              ROUND((8.50 +ROUND(src.KWH*0.1150,2))*0.080,2) END,
    CASE WHEN src.PEAK_KW IS NOT NULL THEN ROUND((75.00+ROUND(src.KWH*0.0850,2)+ROUND(src.PEAK_KW*12.00,2))*1.070,2)
         WHEN src.RATE='COM-3'        THEN ROUND((15.00+ROUND(src.KWH*0.1100,2))*1.085,2)
         ELSE                              ROUND((8.50 +ROUND(src.KWH*0.1150,2))*1.080,2) END,
    src.IS_CORR, src.CORR_RSN, CURRENT_TIMESTAMP()
);

SELECT BILLING_MONTH, COUNT(*) AS rows, ROUND(SUM(KWH_USAGE),2) AS total_kwh, ROUND(SUM(TOTAL_BILLED),2) AS total_billed
FROM BILLING.MONTHLY_USAGE WHERE USAGE_ID LIKE 'USG-SIM-R18-%' GROUP BY BILLING_MONTH;
