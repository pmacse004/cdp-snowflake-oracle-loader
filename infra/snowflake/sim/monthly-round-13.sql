-- =============================================================================
-- Monthly Load Simulation — Round 13  |  Billing Month: 2027-01
-- =============================================================================
-- Run as: CDP_ADMIN_ROLE  |  Database: CDP_UTIL_DB  |  Warehouse: CDP_LOADER_WH
--
-- SCENARIO  New year — estimated reads for newly opened accounts
-- RATE PLANS  RES-1, RES-2 (time-of-use), COM-1, IND-1
-- REJECTION  None — all ESTIMATED reads, clean load
-- TRIGGER    POST http://localhost:8080/api/jobs/monthly
-- PREREQUISITE  monthly-round-12.sql must have been run.
-- =============================================================================

USE ROLE CDP_ADMIN_ROLE;
USE DATABASE CDP_UTIL_DB;
USE WAREHOUSE CDP_LOADER_WH;

MERGE INTO BILLING.MONTHLY_USAGE tgt
USING (
    SELECT col1 AS UID, col2 AS EAID, col3 AS KWH, col4 AS PEAK_KW, col5 AS RATE, col6 AS READ_T
    FROM VALUES
        ('USG-SIM-R13-001', 'EA-SIM-R14-001',  480.000, NULL, 'RES-1',  'ACTUAL'),
        ('USG-SIM-R13-002', 'EA-SIM-R14-002',  490.000, NULL, 'RES-2',  'ACTUAL'),
        ('USG-SIM-R13-003', 'EA-SIM-R14-003', 4500.000, 20.0, 'COM-1',  'ACTUAL'),
        ('USG-SIM-R13-004', 'EA-SIM-R14-004', 4200.000, 18.0, 'COM-1',  'ACTUAL'),
        ('USG-SIM-R13-005', 'EA-SIM-R15-001',  510.000, NULL, 'RES-1',  'ESTIMATED'),
        ('USG-SIM-R13-006', 'EA-SIM-R15-002',  490.000, NULL, 'RES-1',  'ESTIMATED'),
        ('USG-SIM-R13-007', 'EA-SIM-R15-003', 3800.000, NULL, 'COM-1',  'ACTUAL'),
        ('USG-SIM-R13-008', 'EA-SIM-R15-004',  525.000, NULL, 'RES-1',  'ESTIMATED'),
        ('USG-SIM-R13-009', 'EA-SIM-R11-001',19200.000, 88.0, 'IND-1',  'ACTUAL'),
        ('USG-SIM-R13-010', 'EA-SIM-R11-002',22800.000, 98.0, 'IND-1',  'ACTUAL')
        AS v(col1, col2, col3, col4, col5, col6)
) src ON (tgt.USAGE_ID = src.UID)
WHEN MATCHED THEN UPDATE SET KWH_USAGE = src.KWH, UPDATED_AT = CURRENT_TIMESTAMP()
WHEN NOT MATCHED THEN INSERT
    (USAGE_ID, ENERGY_ACCOUNT_ID, PREMISE_ID, METER_ID,
     BILLING_MONTH, BILL_START_DATE, BILL_END_DATE, BILLING_DAYS,
     KWH_USAGE, KWH_ADJUSTED, PEAK_DEMAND_KW,
     PREV_METER_READING, CURR_METER_READING, READ_TYPE, RATE_PLAN,
     FIXED_CHARGE, ENERGY_CHARGE, DEMAND_CHARGE,
     SUBTOTAL_CHARGE, TAX_AMOUNT, TOTAL_BILLED, IS_CORRECTION, UPDATED_AT)
VALUES (
    src.UID, src.EAID, 'PREM-SIM', 'MTR-SIM',
    '2027-01', '2027-01-01'::DATE, '2027-01-31'::DATE, 31,
    src.KWH, src.KWH, src.PEAK_KW,
    src.KWH * 3, src.KWH * 4, src.READ_T, src.RATE,
    CASE src.RATE WHEN 'IND-1' THEN 75.00 WHEN 'COM-1' THEN 22.00 WHEN 'RES-2' THEN 8.50 ELSE 8.50 END,
    CASE src.RATE WHEN 'IND-1' THEN ROUND(src.KWH*0.0850,2)
                  WHEN 'COM-1' THEN ROUND(src.KWH*0.1050,2)
                  WHEN 'RES-2' THEN ROUND(src.KWH*0.0900,2)
                  ELSE              ROUND(src.KWH*0.1150,2) END,
    CASE WHEN src.PEAK_KW IS NOT NULL AND src.RATE='COM-1' THEN ROUND(src.PEAK_KW*8.50,2)
         WHEN src.PEAK_KW IS NOT NULL AND src.RATE='IND-1' THEN ROUND(src.PEAK_KW*12.00,2)
         ELSE 0.00 END,
    CASE src.RATE
        WHEN 'IND-1' THEN ROUND(75.00+ROUND(src.KWH*0.0850,2)+ROUND(src.PEAK_KW*12.00,2),2)
        WHEN 'COM-1' THEN ROUND(22.00+ROUND(src.KWH*0.1050,2)+ROUND(src.PEAK_KW*8.50,2),2)
        WHEN 'RES-2' THEN ROUND(8.50 +ROUND(src.KWH*0.0900,2),2)
        ELSE              ROUND(8.50 +ROUND(src.KWH*0.1150,2),2) END,
    CASE src.RATE
        WHEN 'IND-1' THEN ROUND((75.00+ROUND(src.KWH*0.0850,2)+ROUND(src.PEAK_KW*12.00,2))*0.070,2)
        WHEN 'COM-1' THEN ROUND((22.00+ROUND(src.KWH*0.1050,2)+ROUND(src.PEAK_KW*8.50,2))*0.085,2)
        ELSE              ROUND((8.50 +ROUND(src.KWH*0.1150,2))*0.080,2) END,
    CASE src.RATE
        WHEN 'IND-1' THEN ROUND((75.00+ROUND(src.KWH*0.0850,2)+ROUND(src.PEAK_KW*12.00,2))*1.070,2)
        WHEN 'COM-1' THEN ROUND((22.00+ROUND(src.KWH*0.1050,2)+ROUND(src.PEAK_KW*8.50,2))*1.085,2)
        ELSE              ROUND((8.50 +ROUND(src.KWH*0.1150,2))*1.080,2) END,
    FALSE, CURRENT_TIMESTAMP()
);

SELECT BILLING_MONTH, COUNT(*) AS rows, ROUND(SUM(KWH_USAGE),2) AS total_kwh, ROUND(SUM(TOTAL_BILLED),2) AS total_billed
FROM BILLING.MONTHLY_USAGE WHERE USAGE_ID LIKE 'USG-SIM-R13-%' GROUP BY BILLING_MONTH;
