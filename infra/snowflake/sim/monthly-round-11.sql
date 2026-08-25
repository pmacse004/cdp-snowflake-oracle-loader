-- =============================================================================
-- Monthly Load Simulation — Round 11  |  Billing Month: 2026-11
-- =============================================================================
-- Run as: CDP_ADMIN_ROLE  |  Database: CDP_UTIL_DB  |  Warehouse: CDP_LOADER_WH
--
-- SCENARIO  Industrial accounts first billing month (EA-SIM-R11-*)
-- RATE PLANS  IND-1: fixed $75, $0.0850/kWh, $12/kW demand, 7% tax
--             COM-3: fixed $15, $0.1100/kWh, no demand, 8.5% tax
--             RES-1: fixed $8.50, $0.1150/kWh, no demand, 8% tax
-- REJECTION  None — clean load
-- TRIGGER    POST http://localhost:8080/api/jobs/monthly
-- PREREQUISITE  daily-round-11.sql must have been run (EA-SIM-R11-* exist).
-- =============================================================================

USE ROLE CDP_ADMIN_ROLE;
USE DATABASE CDP_UTIL_DB;
USE WAREHOUSE CDP_LOADER_WH;

MERGE INTO BILLING.MONTHLY_USAGE tgt
USING (
    SELECT col1 AS UID, col2 AS EAID, col3 AS KWH, col4 AS PEAK_KW, col5 AS RATE
    FROM VALUES
        ('USG-SIM-R11-001', 'EA-SIM-R11-001', 18500.000, 85.0, 'IND-1'),
        ('USG-SIM-R11-002', 'EA-SIM-R11-002', 22000.000, 95.0, 'IND-1'),
        ('USG-SIM-R11-003', 'EA-SIM-R11-003',  3200.000,  NULL, 'COM-3'),
        ('USG-SIM-R11-004', 'EA-SIM-R11-004',   540.000,  NULL, 'RES-1'),
        -- also pull in new R12 solar accounts
        ('USG-SIM-R11-005', 'EA-SIM-R12-001',   210.000,  NULL, 'SOL-1'),
        ('USG-SIM-R11-006', 'EA-SIM-R12-002',   185.000,  NULL, 'SOL-1'),
        ('USG-SIM-R11-007', 'EA-SIM-R12-003',   230.000,  NULL, 'SOL-1'),
        ('USG-SIM-R11-008', 'EA-SIM-R12-004',  4100.000,  NULL, 'COM-3')
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
    '2026-11', '2026-11-01'::DATE, '2026-11-30'::DATE, 30,
    src.KWH, src.KWH, src.PEAK_KW,
    src.KWH * 3, src.KWH * 4, 'ACTUAL', src.RATE,
    CASE src.RATE WHEN 'IND-1' THEN 75.00 WHEN 'COM-3' THEN 15.00 WHEN 'SOL-1' THEN 8.50 ELSE 8.50 END,
    CASE src.RATE WHEN 'IND-1' THEN ROUND(src.KWH * 0.0850, 2)
                  WHEN 'COM-3' THEN ROUND(src.KWH * 0.1100, 2)
                  WHEN 'SOL-1' THEN ROUND(src.KWH * 0.0700, 2)
                  ELSE              ROUND(src.KWH * 0.1150, 2) END,
    CASE WHEN src.PEAK_KW IS NOT NULL THEN ROUND(src.PEAK_KW * 12.00, 2) ELSE 0.00 END,
    CASE src.RATE
        WHEN 'IND-1' THEN ROUND(75.00 + ROUND(src.KWH*0.0850,2) + ROUND(src.PEAK_KW*12.00,2), 2)
        WHEN 'COM-3' THEN ROUND(15.00 + ROUND(src.KWH*0.1100,2), 2)
        WHEN 'SOL-1' THEN ROUND(8.50  + ROUND(src.KWH*0.0700,2), 2)
        ELSE              ROUND(8.50  + ROUND(src.KWH*0.1150,2), 2) END,
    CASE src.RATE
        WHEN 'IND-1' THEN ROUND((75.00 + ROUND(src.KWH*0.0850,2) + ROUND(src.PEAK_KW*12.00,2)) * 0.070, 2)
        WHEN 'COM-3' THEN ROUND((15.00 + ROUND(src.KWH*0.1100,2)) * 0.085, 2)
        WHEN 'SOL-1' THEN ROUND((8.50  + ROUND(src.KWH*0.0700,2)) * 0.080, 2)
        ELSE              ROUND((8.50  + ROUND(src.KWH*0.1150,2)) * 0.080, 2) END,
    CASE src.RATE
        WHEN 'IND-1' THEN ROUND((75.00 + ROUND(src.KWH*0.0850,2) + ROUND(src.PEAK_KW*12.00,2)) * 1.070, 2)
        WHEN 'COM-3' THEN ROUND((15.00 + ROUND(src.KWH*0.1100,2)) * 1.085, 2)
        WHEN 'SOL-1' THEN ROUND((8.50  + ROUND(src.KWH*0.0700,2)) * 1.080, 2)
        ELSE              ROUND((8.50  + ROUND(src.KWH*0.1150,2)) * 1.080, 2) END,
    FALSE, CURRENT_TIMESTAMP()
);

SELECT BILLING_MONTH, COUNT(*) AS rows, ROUND(SUM(KWH_USAGE),2) AS total_kwh, ROUND(SUM(TOTAL_BILLED),2) AS total_billed
FROM BILLING.MONTHLY_USAGE WHERE USAGE_ID LIKE 'USG-SIM-R11-%' GROUP BY BILLING_MONTH;
