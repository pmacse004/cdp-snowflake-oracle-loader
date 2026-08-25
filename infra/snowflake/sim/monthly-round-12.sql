-- =============================================================================
-- Monthly Load Simulation — Round 12  |  Billing Month: 2026-12
-- =============================================================================
-- Run as: CDP_ADMIN_ROLE  |  Database: CDP_UTIL_DB  |  Warehouse: CDP_LOADER_WH
--
-- SCENARIO  December high-consumption month + rejection: negative KWH
-- RATE PLANS  RES-1, COM-1, IND-1, SOL-1
-- REJECTION  REJ-M1: negative KWH_USAGE → VR-USAGE-001
-- TRIGGER    POST http://localhost:8080/api/jobs/monthly
-- PREREQUISITE  monthly-round-11.sql must have been run.
-- =============================================================================

USE ROLE CDP_ADMIN_ROLE;
USE DATABASE CDP_UTIL_DB;
USE WAREHOUSE CDP_LOADER_WH;

MERGE INTO BILLING.MONTHLY_USAGE tgt
USING (
    SELECT col1 AS UID, col2 AS EAID, col3 AS KWH, col4 AS PEAK_KW, col5 AS RATE
    FROM VALUES
        ('USG-SIM-R12-001', 'EA-SIM-R13-001',  620.000, NULL, 'RES-1'),
        ('USG-SIM-R12-002', 'EA-SIM-R13-002',  595.000, NULL, 'RES-1'),
        ('USG-SIM-R12-003', 'EA-SIM-R13-003',  610.000, NULL, 'RES-1'),
        ('USG-SIM-R12-004', 'EA-SIM-R11-001', 21000.000, 92.0,'IND-1'),
        ('USG-SIM-R12-005', 'EA-SIM-R11-002', 24500.000,101.0,'IND-1'),
        ('USG-SIM-R12-006', 'EA-SIM-R12-001',  195.000, NULL, 'SOL-1'),
        ('USG-SIM-R12-007', 'EA-SIM-R12-002',  175.000, NULL, 'SOL-1'),
        -- REJ-M1: negative KWH
        ('USG-SIM-R12-REJ', 'EA-SIM-R13-004', -80.000,  NULL, 'RES-1')
        AS v(col1, col2, col3, col4, col5)
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
    '2026-12', '2026-12-01'::DATE, '2026-12-31'::DATE, 31,
    src.KWH, src.KWH, src.PEAK_KW,
    ABS(src.KWH) * 3, ABS(src.KWH) * 4, 'ACTUAL', src.RATE,
    CASE src.RATE WHEN 'IND-1' THEN 75.00 WHEN 'SOL-1' THEN 8.50 ELSE 8.50 END,
    CASE src.RATE WHEN 'IND-1' THEN ROUND(src.KWH * 0.0850, 2)
                  WHEN 'SOL-1' THEN ROUND(src.KWH * 0.0700, 2)
                  ELSE              ROUND(src.KWH * 0.1150, 2) END,
    CASE WHEN src.PEAK_KW IS NOT NULL THEN ROUND(src.PEAK_KW * 12.00, 2) ELSE 0.00 END,
    CASE src.RATE
        WHEN 'IND-1' THEN ROUND(75.00 + ROUND(src.KWH*0.0850,2) + ROUND(src.PEAK_KW*12.00,2), 2)
        WHEN 'SOL-1' THEN ROUND(8.50  + ROUND(src.KWH*0.0700,2), 2)
        ELSE              ROUND(8.50  + ROUND(src.KWH*0.1150,2), 2) END,
    CASE src.RATE
        WHEN 'IND-1' THEN ROUND((75.00 + ROUND(src.KWH*0.0850,2) + ROUND(src.PEAK_KW*12.00,2)) * 0.070, 2)
        WHEN 'SOL-1' THEN ROUND((8.50  + ROUND(src.KWH*0.0700,2)) * 0.080, 2)
        ELSE              ROUND((8.50  + ROUND(src.KWH*0.1150,2)) * 0.080, 2) END,
    CASE src.RATE
        WHEN 'IND-1' THEN ROUND((75.00 + ROUND(src.KWH*0.0850,2) + ROUND(src.PEAK_KW*12.00,2)) * 1.070, 2)
        WHEN 'SOL-1' THEN ROUND((8.50  + ROUND(src.KWH*0.0700,2)) * 1.080, 2)
        ELSE              ROUND((8.50  + ROUND(src.KWH*0.1150,2)) * 1.080, 2) END,
    FALSE, CURRENT_TIMESTAMP()
);

SELECT BILLING_MONTH, COUNT(*) AS rows, ROUND(SUM(KWH_USAGE),2) AS total_kwh, ROUND(SUM(TOTAL_BILLED),2) AS total_billed
FROM BILLING.MONTHLY_USAGE WHERE USAGE_ID LIKE 'USG-SIM-R12-%' GROUP BY BILLING_MONTH;
