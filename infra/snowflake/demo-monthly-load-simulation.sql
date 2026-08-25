-- =============================================================================
-- Demo Monthly Load Simulation — 10 Rounds
-- =============================================================================
-- Run as: CDP_ADMIN_ROLE
-- Database: CDP_UTIL_DB
-- Warehouse: CDP_LOADER_WH
--
-- PURPOSE
--   Populates BILLING.MONTHLY_USAGE with 10 rounds of monthly billing data
--   across 10 distinct billing months (2026-01 through 2026-10), using the
--   energy accounts inserted by demo-daily-load-simulation.sql (EA-SIM-R*-*).
--
--   Each round = one billing month.  Trigger the monthly job after each round:
--         POST http://localhost:8080/api/jobs/monthly
--
-- HOW TO USE
--   1. Ensure demo-daily-load-simulation.sql has been run (EA-SIM-* accounts exist).
--   2. Run all 10 rounds at once, or one round at a time.
--   3. After each round trigger the monthly job from the UI or via the API.
--
-- REJECTION SCENARIOS INJECTED (selected rounds)
--   REJ-M1  KWH_USAGE negative            → VR-USAGE-001 (negative consumption)
--   REJ-M2  BILL_END_DATE < BILL_START_DATE → VR-USAGE-002 (inverted date range)
--   REJ-M3  RATE_PLAN unknown ('USG-XXX-REJ') → no rate match → NULL calculated charges
--
-- ROUND NAMING
--   USAGE_ID prefix: USG-SIM-R{N}-{EA_SHORT}
--   Billing months:  2026-01 (R1) through 2026-10 (R10)
--
-- RATE PLANS USED
--   Residential : RES-1 (fixed $8.50, $0.1150/kWh, 8% tax)
--   Commercial  : COM-1 (fixed $22.00, $0.1050/kWh, $8.50/kW demand, 8.5% tax)
--   Industrial  : IND-1 (fixed $75.00, $0.0850/kWh, $12.00/kW demand, 7% tax)
--   Solar       : SOL-1 (fixed $8.50, $0.0700/kWh credit, 8% tax)
--
-- IDEMPOTENCY
--   All inserts use MERGE ON USAGE_ID, so rerunning is safe.
--
-- UNIQUE CONSTRAINT
--   BILLING.MONTHLY_USAGE has: UNIQUE (ENERGY_ACCOUNT_ID, BILLING_MONTH)
--   Each round uses a different BILLING_MONTH so no cross-round conflicts.
-- =============================================================================

USE ROLE CDP_ADMIN_ROLE;
USE DATABASE CDP_UTIL_DB;
USE WAREHOUSE CDP_LOADER_WH;

-- =============================================================================
-- ===== ROUND 1: Billing month 2026-01 — Residential baseline ================
-- =============================================================================

MERGE INTO BILLING.MONTHLY_USAGE tgt
USING (
    SELECT col1 AS UID, col2 AS EAID, col3 AS KWH, col4 AS RATE
    FROM VALUES
        ('USG-SIM-R1-001', 'EA-SIM-R1-001', 485.000, 'RES-1'),
        ('USG-SIM-R1-002', 'EA-SIM-R1-002', 612.500, 'RES-1'),
        ('USG-SIM-R1-003', 'EA-SIM-R1-003', 334.200, 'COM-1'),
        ('USG-SIM-R1-004', 'EA-SIM-R1-004', 720.800, 'RES-1'),
        ('USG-SIM-R1-005', 'EA-SIM-R2-001', 510.000, 'RES-1'),
        ('USG-SIM-R1-006', 'EA-SIM-R2-002', 890.000, 'COM-1'),
        ('USG-SIM-R1-007', 'EA-SIM-R2-003', 345.000, 'RES-1')
        AS v(col1, col2, col3, col4)
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
    '2026-01', '2026-01-01'::DATE, '2026-01-31'::DATE, 31,
    src.KWH, src.KWH, NULL,
    src.KWH * 3, src.KWH * 4, 'ACTUAL', src.RATE,
    8.50,
    ROUND(src.KWH * 0.1150, 2),
    0.00,
    ROUND(8.50 + ROUND(src.KWH * 0.1150, 2), 2),
    ROUND((8.50 + ROUND(src.KWH * 0.1150, 2)) * 0.080, 2),
    ROUND((8.50 + ROUND(src.KWH * 0.1150, 2)) +
          ROUND((8.50 + ROUND(src.KWH * 0.1150, 2)) * 0.080, 2), 2),
    FALSE, CURRENT_TIMESTAMP()
);

-- =============================================================================
-- ===== ROUND 2: Billing month 2026-02 — Rejection: negative KWH =============
-- =============================================================================

MERGE INTO BILLING.MONTHLY_USAGE tgt
USING (
    SELECT col1 AS UID, col2 AS EAID, col3 AS KWH
    FROM VALUES
        ('USG-SIM-R2-001', 'EA-SIM-R1-001', 502.000),
        ('USG-SIM-R2-002', 'EA-SIM-R1-002', 635.000),
        ('USG-SIM-R2-003', 'EA-SIM-R1-004', 698.500),
        ('USG-SIM-R2-004', 'EA-SIM-R2-001', 487.000),
        ('USG-SIM-R2-005', 'EA-SIM-R2-003', 320.000),
        -- REJ-M1: negative KWH — rejected by VR-USAGE-001
        ('USG-SIM-R2-REJ', 'EA-SIM-R1-003', -50.000)
        AS v(col1, col2, col3)
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
    '2026-02', '2026-02-01'::DATE, '2026-02-28'::DATE, 28,
    src.KWH, src.KWH, NULL,
    ABS(src.KWH) * 3, ABS(src.KWH) * 4, 'ACTUAL', 'RES-1',
    8.50,
    ROUND(src.KWH * 0.1150, 2),
    0.00,
    ROUND(8.50 + ROUND(src.KWH * 0.1150, 2), 2),
    ROUND((8.50 + ROUND(src.KWH * 0.1150, 2)) * 0.080, 2),
    ROUND((8.50 + ROUND(src.KWH * 0.1150, 2)) +
          ROUND((8.50 + ROUND(src.KWH * 0.1150, 2)) * 0.080, 2), 2),
    FALSE, CURRENT_TIMESTAMP()
);

-- =============================================================================
-- ===== ROUND 3: Billing month 2026-03 — Commercial with demand charge ========
-- =============================================================================

MERGE INTO BILLING.MONTHLY_USAGE tgt
USING (
    SELECT col1 AS UID, col2 AS EAID, col3 AS KWH, col4 AS PEAK_KW
    FROM VALUES
        ('USG-SIM-R3-001', 'EA-SIM-R1-001',  520.000,   NULL),
        ('USG-SIM-R3-002', 'EA-SIM-R1-002',  670.000,   NULL),
        ('USG-SIM-R3-003', 'EA-SIM-R1-003', 4200.000,  18.5),
        ('USG-SIM-R3-004', 'EA-SIM-R2-002', 3800.000,  15.2),
        ('USG-SIM-R3-005', 'EA-SIM-R3-001',  430.000,   NULL),
        ('USG-SIM-R3-006', 'EA-SIM-R3-002',  395.000,   NULL),
        ('USG-SIM-R3-007', 'EA-SIM-R3-003',  480.000,   NULL)
        AS v(col1, col2, col3, col4)
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
    '2026-03', '2026-03-01'::DATE, '2026-03-31'::DATE, 31,
    src.KWH, src.KWH, src.PEAK_KW,
    src.KWH * 3, src.KWH * 4, 'ACTUAL',
    CASE WHEN src.PEAK_KW IS NOT NULL THEN 'COM-1' ELSE 'RES-1' END,
    CASE WHEN src.PEAK_KW IS NOT NULL THEN 22.00 ELSE 8.50 END,
    CASE WHEN src.PEAK_KW IS NOT NULL THEN ROUND(src.KWH * 0.1050, 2) ELSE ROUND(src.KWH * 0.1150, 2) END,
    CASE WHEN src.PEAK_KW IS NOT NULL THEN ROUND(src.PEAK_KW * 8.5000, 2) ELSE 0.00 END,
    CASE WHEN src.PEAK_KW IS NOT NULL
         THEN ROUND(22.00 + ROUND(src.KWH * 0.1050, 2) + ROUND(src.PEAK_KW * 8.5000, 2), 2)
         ELSE ROUND(8.50 + ROUND(src.KWH * 0.1150, 2), 2) END,
    CASE WHEN src.PEAK_KW IS NOT NULL
         THEN ROUND((22.00 + ROUND(src.KWH * 0.1050, 2) + ROUND(src.PEAK_KW * 8.5000, 2)) * 0.085, 2)
         ELSE ROUND((8.50 + ROUND(src.KWH * 0.1150, 2)) * 0.080, 2) END,
    CASE WHEN src.PEAK_KW IS NOT NULL
         THEN ROUND((22.00 + ROUND(src.KWH * 0.1050, 2) + ROUND(src.PEAK_KW * 8.5000, 2)) * 1.085, 2)
         ELSE ROUND((8.50 + ROUND(src.KWH * 0.1150, 2)) * 1.080, 2) END,
    FALSE, CURRENT_TIMESTAMP()
);

-- =============================================================================
-- ===== ROUND 4: Billing month 2026-04 — Estimated reads =====================
-- =============================================================================

MERGE INTO BILLING.MONTHLY_USAGE tgt
USING (
    SELECT col1 AS UID, col2 AS EAID, col3 AS KWH, col4 AS READ_T
    FROM VALUES
        ('USG-SIM-R4-001', 'EA-SIM-R1-001', 498.000, 'ACTUAL'),
        ('USG-SIM-R4-002', 'EA-SIM-R1-002', 590.000, 'ESTIMATED'),
        ('USG-SIM-R4-003', 'EA-SIM-R1-004', 672.000, 'ESTIMATED'),
        ('USG-SIM-R4-004', 'EA-SIM-R3-001', 455.000, 'ACTUAL'),
        ('USG-SIM-R4-005', 'EA-SIM-R3-002', 410.000, 'ACTUAL'),
        ('USG-SIM-R4-006', 'EA-SIM-R4-001', 530.000, 'ACTUAL'),
        ('USG-SIM-R4-007', 'EA-SIM-R4-002', 465.000, 'ACTUAL'),
        ('USG-SIM-R4-008', 'EA-SIM-R4-003', 3600.000,'ACTUAL'),
        ('USG-SIM-R4-009', 'EA-SIM-R4-004', 580.000, 'ACTUAL')
        AS v(col1, col2, col3, col4)
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
    '2026-04', '2026-04-01'::DATE, '2026-04-30'::DATE, 30,
    src.KWH, src.KWH, NULL,
    src.KWH * 3, src.KWH * 4, src.READ_T, 'RES-1',
    8.50,
    ROUND(src.KWH * 0.1150, 2),
    0.00,
    ROUND(8.50 + ROUND(src.KWH * 0.1150, 2), 2),
    ROUND((8.50 + ROUND(src.KWH * 0.1150, 2)) * 0.080, 2),
    ROUND((8.50 + ROUND(src.KWH * 0.1150, 2)) * 1.080, 2),
    FALSE, CURRENT_TIMESTAMP()
);

-- =============================================================================
-- ===== ROUND 5: Billing month 2026-05 — Correction records ==================
-- =============================================================================

MERGE INTO BILLING.MONTHLY_USAGE tgt
USING (
    SELECT col1 AS UID, col2 AS EAID, col3 AS KWH, col4 AS IS_CORR, col5 AS REASON
    FROM VALUES
        ('USG-SIM-R5-001', 'EA-SIM-R1-001', 515.000, FALSE, NULL),
        ('USG-SIM-R5-002', 'EA-SIM-R1-002', 640.000, FALSE, NULL),
        ('USG-SIM-R5-003', 'EA-SIM-R1-004', 695.000, FALSE, NULL),
        -- correction for EA-SIM-R1-002 April estimated read
        ('USG-SIM-R5-COR', 'EA-SIM-R4-002', 608.000, TRUE,  'METER_READ_CORRECTION'),
        ('USG-SIM-R5-004', 'EA-SIM-R5-001', 490.000, FALSE, NULL),
        ('USG-SIM-R5-005', 'EA-SIM-R5-002', 520.000, FALSE, NULL),
        ('USG-SIM-R5-006', 'EA-SIM-R5-003', 445.000, FALSE, NULL)
        AS v(col1, col2, col3, col4, col5)
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
    '2026-05', '2026-05-01'::DATE, '2026-05-31'::DATE, 31,
    src.KWH, src.KWH, NULL,
    src.KWH * 3, src.KWH * 4, 'ACTUAL', 'RES-1',
    8.50,
    ROUND(src.KWH * 0.1150, 2),
    0.00,
    ROUND(8.50 + ROUND(src.KWH * 0.1150, 2), 2),
    ROUND((8.50 + ROUND(src.KWH * 0.1150, 2)) * 0.080, 2),
    ROUND((8.50 + ROUND(src.KWH * 0.1150, 2)) * 1.080, 2),
    src.IS_CORR, src.REASON, CURRENT_TIMESTAMP()
);

-- =============================================================================
-- ===== ROUND 6: Billing month 2026-06 — Inverted date rejection ==============
-- =============================================================================

MERGE INTO BILLING.MONTHLY_USAGE tgt
USING (
    SELECT col1 AS UID, col2 AS EAID, col3 AS KWH,
           col4 AS START_DT, col5 AS END_DT, col6 AS DAYS
    FROM VALUES
        ('USG-SIM-R6-001', 'EA-SIM-R1-001', 545.000, '2026-06-01'::DATE, '2026-06-30'::DATE, 30),
        ('USG-SIM-R6-002', 'EA-SIM-R1-002', 660.000, '2026-06-01'::DATE, '2026-06-30'::DATE, 30),
        ('USG-SIM-R6-003', 'EA-SIM-R1-004', 710.000, '2026-06-01'::DATE, '2026-06-30'::DATE, 30),
        ('USG-SIM-R6-004', 'EA-SIM-R6-001', 480.000, '2026-06-01'::DATE, '2026-06-30'::DATE, 30),
        ('USG-SIM-R6-005', 'EA-SIM-R6-002', 490.000, '2026-06-01'::DATE, '2026-06-30'::DATE, 30),
        ('USG-SIM-R6-006', 'EA-SIM-R6-003', 3900.000,'2026-06-01'::DATE, '2026-06-30'::DATE, 30),
        -- REJ-M2: BILL_END_DATE < BILL_START_DATE — rejected by VR-USAGE-002
        ('USG-SIM-R6-REJ', 'EA-SIM-R6-004', 500.000, '2026-06-30'::DATE, '2026-06-01'::DATE, -29)
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
    '2026-06', src.START_DT, src.END_DT, src.DAYS,
    src.KWH, src.KWH, NULL,
    src.KWH * 3, src.KWH * 4, 'ACTUAL', 'RES-1',
    8.50,
    ROUND(src.KWH * 0.1150, 2),
    0.00,
    ROUND(8.50 + ROUND(src.KWH * 0.1150, 2), 2),
    ROUND((8.50 + ROUND(src.KWH * 0.1150, 2)) * 0.080, 2),
    ROUND((8.50 + ROUND(src.KWH * 0.1150, 2)) * 1.080, 2),
    FALSE, CURRENT_TIMESTAMP()
);

-- =============================================================================
-- ===== ROUND 7: Billing month 2026-07 — Solar + industrial accounts ==========
-- =============================================================================

MERGE INTO BILLING.MONTHLY_USAGE tgt
USING (
    SELECT col1 AS UID, col2 AS EAID, col3 AS KWH, col4 AS PEAK_KW, col5 AS RATE
    FROM VALUES
        ('USG-SIM-R7-001', 'EA-SIM-R1-001',  512.000,   NULL, 'RES-1'),
        ('USG-SIM-R7-002', 'EA-SIM-R1-002',  648.000,   NULL, 'RES-1'),
        ('USG-SIM-R7-003', 'EA-SIM-R7-001',  505.000,   NULL, 'RES-1'),
        ('USG-SIM-R7-004', 'EA-SIM-R7-002',  520.000,   NULL, 'RES-1'),
        ('USG-SIM-R7-005', 'EA-SIM-R7-003',  510.000,   NULL, 'RES-1'),
        -- Commercial accounts from Round 7 daily sim
        ('USG-SIM-R7-006', 'EA-SIM-R7-B01',  4500.000,  20.0, 'COM-1'),
        ('USG-SIM-R7-007', 'EA-SIM-R7-B02',  9200.000,  42.0, 'IND-1')
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
    '2026-07', '2026-07-01'::DATE, '2026-07-31'::DATE, 31,
    src.KWH, src.KWH, src.PEAK_KW,
    src.KWH * 3, src.KWH * 4, 'ACTUAL', src.RATE,
    CASE src.RATE WHEN 'COM-1' THEN 22.00 WHEN 'IND-1' THEN 75.00 ELSE 8.50 END,
    CASE src.RATE WHEN 'COM-1' THEN ROUND(src.KWH * 0.1050, 2)
                  WHEN 'IND-1' THEN ROUND(src.KWH * 0.0850, 2)
                  ELSE              ROUND(src.KWH * 0.1150, 2) END,
    CASE WHEN src.PEAK_KW IS NOT NULL AND src.RATE = 'COM-1' THEN ROUND(src.PEAK_KW * 8.50, 2)
         WHEN src.PEAK_KW IS NOT NULL AND src.RATE = 'IND-1' THEN ROUND(src.PEAK_KW * 12.00, 2)
         ELSE 0.00 END,
    CASE src.RATE
        WHEN 'COM-1' THEN ROUND(22.00 + ROUND(src.KWH*0.1050,2) + ROUND(src.PEAK_KW*8.50,2), 2)
        WHEN 'IND-1' THEN ROUND(75.00 + ROUND(src.KWH*0.0850,2) + ROUND(src.PEAK_KW*12.00,2), 2)
        ELSE              ROUND(8.50 + ROUND(src.KWH*0.1150,2), 2) END,
    CASE src.RATE
        WHEN 'COM-1' THEN ROUND((22.00 + ROUND(src.KWH*0.1050,2) + ROUND(src.PEAK_KW*8.50,2))  * 0.085, 2)
        WHEN 'IND-1' THEN ROUND((75.00 + ROUND(src.KWH*0.0850,2) + ROUND(src.PEAK_KW*12.00,2)) * 0.070, 2)
        ELSE              ROUND((8.50  + ROUND(src.KWH*0.1150,2))                                * 0.080, 2) END,
    CASE src.RATE
        WHEN 'COM-1' THEN ROUND((22.00 + ROUND(src.KWH*0.1050,2) + ROUND(src.PEAK_KW*8.50,2))  * 1.085, 2)
        WHEN 'IND-1' THEN ROUND((75.00 + ROUND(src.KWH*0.0850,2) + ROUND(src.PEAK_KW*12.00,2)) * 1.070, 2)
        ELSE              ROUND((8.50  + ROUND(src.KWH*0.1150,2))                                * 1.080, 2) END,
    FALSE, CURRENT_TIMESTAMP()
);

-- =============================================================================
-- ===== ROUND 8: Billing month 2026-08 — Unknown rate plan rejection ===========
-- =============================================================================

MERGE INTO BILLING.MONTHLY_USAGE tgt
USING (
    SELECT col1 AS UID, col2 AS EAID, col3 AS KWH, col4 AS RATE
    FROM VALUES
        ('USG-SIM-R8-001', 'EA-SIM-R1-001', 555.000, 'RES-1'),
        ('USG-SIM-R8-002', 'EA-SIM-R1-002', 672.000, 'RES-1'),
        ('USG-SIM-R8-003', 'EA-SIM-R8-001', 4100.000,'COM-1'),
        ('USG-SIM-R8-004', 'EA-SIM-R8-002', 3950.000,'COM-1'),
        ('USG-SIM-R8-005', 'EA-SIM-R8-003', 3800.000,'COM-1'),
        ('USG-SIM-R8-006', 'EA-SIM-R8-004', 4300.000,'COM-1'),
        -- REJ-M3: unknown rate plan — no rate match → NULL charges
        ('USG-SIM-R8-REJ', 'EA-SIM-R1-004', 690.000, 'USG-XXX-REJ')
        AS v(col1, col2, col3, col4)
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
    '2026-08', '2026-08-01'::DATE, '2026-08-31'::DATE, 31,
    src.KWH, src.KWH, NULL,
    src.KWH * 3, src.KWH * 4, 'ACTUAL', src.RATE,
    -- Valid rows: RES-1 rates; rejection row: NULL charges (no rate match in view)
    CASE WHEN src.RATE = 'COM-1' THEN 22.00 ELSE 8.50 END,
    CASE WHEN src.RATE = 'COM-1' THEN ROUND(src.KWH * 0.1050, 2)
         ELSE ROUND(src.KWH * 0.1150, 2) END,
    0.00,
    CASE WHEN src.RATE = 'COM-1' THEN ROUND(22.00 + ROUND(src.KWH*0.1050,2), 2)
         ELSE ROUND(8.50 + ROUND(src.KWH*0.1150,2), 2) END,
    CASE WHEN src.RATE = 'COM-1' THEN ROUND((22.00 + ROUND(src.KWH*0.1050,2)) * 0.085, 2)
         ELSE ROUND((8.50 + ROUND(src.KWH*0.1150,2)) * 0.080, 2) END,
    CASE WHEN src.RATE = 'COM-1' THEN ROUND((22.00 + ROUND(src.KWH*0.1050,2)) * 1.085, 2)
         ELSE ROUND((8.50 + ROUND(src.KWH*0.1150,2)) * 1.080, 2) END,
    FALSE, CURRENT_TIMESTAMP()
);

-- =============================================================================
-- ===== ROUND 9: Billing month 2026-09 — Large volume + multi-account =========
-- =============================================================================

MERGE INTO BILLING.MONTHLY_USAGE tgt
USING (
    SELECT col1 AS UID, col2 AS EAID, col3 AS KWH, col4 AS PEAK_KW, col5 AS RATE
    FROM VALUES
        ('USG-SIM-R9-001', 'EA-SIM-R1-001',  525.000,   NULL, 'RES-1'),
        ('USG-SIM-R9-002', 'EA-SIM-R1-002',  680.000,   NULL, 'RES-1'),
        ('USG-SIM-R9-003', 'EA-SIM-R9-001',  495.000,   NULL, 'RES-1'),
        ('USG-SIM-R9-004', 'EA-SIM-R9-002',  510.000,   NULL, 'RES-1'),
        ('USG-SIM-R9-005', 'EA-SIM-R9-003',  470.000,   NULL, 'RES-1'),
        ('USG-SIM-R9-006', 'EA-SIM-R8-001', 4250.000,  19.5, 'COM-1'),
        ('USG-SIM-R9-007', 'EA-SIM-R8-002', 3900.000,  16.0, 'COM-1'),
        ('USG-SIM-R9-008', 'EA-SIM-R7-B02',11500.000,  55.0, 'IND-1'),
        ('USG-SIM-R9-009', 'EA-SIM-R5-001',  498.000,   NULL, 'RES-1'),
        ('USG-SIM-R9-010', 'EA-SIM-R5-002',  512.000,   NULL, 'RES-1')
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
    '2026-09', '2026-09-01'::DATE, '2026-09-30'::DATE, 30,
    src.KWH, src.KWH, src.PEAK_KW,
    src.KWH * 3, src.KWH * 4, 'ACTUAL', src.RATE,
    CASE src.RATE WHEN 'COM-1' THEN 22.00 WHEN 'IND-1' THEN 75.00 ELSE 8.50 END,
    CASE src.RATE WHEN 'COM-1' THEN ROUND(src.KWH * 0.1050, 2)
                  WHEN 'IND-1' THEN ROUND(src.KWH * 0.0850, 2)
                  ELSE              ROUND(src.KWH * 0.1150, 2) END,
    CASE WHEN src.PEAK_KW IS NOT NULL AND src.RATE = 'COM-1' THEN ROUND(src.PEAK_KW * 8.50, 2)
         WHEN src.PEAK_KW IS NOT NULL AND src.RATE = 'IND-1' THEN ROUND(src.PEAK_KW * 12.00, 2)
         ELSE 0.00 END,
    CASE src.RATE
        WHEN 'COM-1' THEN ROUND(22.00 + ROUND(src.KWH*0.1050,2) + ROUND(src.PEAK_KW*8.50,2), 2)
        WHEN 'IND-1' THEN ROUND(75.00 + ROUND(src.KWH*0.0850,2) + ROUND(src.PEAK_KW*12.00,2), 2)
        ELSE              ROUND(8.50  + ROUND(src.KWH*0.1150,2), 2) END,
    CASE src.RATE
        WHEN 'COM-1' THEN ROUND((22.00 + ROUND(src.KWH*0.1050,2) + ROUND(src.PEAK_KW*8.50,2))  * 0.085, 2)
        WHEN 'IND-1' THEN ROUND((75.00 + ROUND(src.KWH*0.0850,2) + ROUND(src.PEAK_KW*12.00,2)) * 0.070, 2)
        ELSE              ROUND((8.50  + ROUND(src.KWH*0.1150,2))                                * 0.080, 2) END,
    CASE src.RATE
        WHEN 'COM-1' THEN ROUND((22.00 + ROUND(src.KWH*0.1050,2) + ROUND(src.PEAK_KW*8.50,2))  * 1.085, 2)
        WHEN 'IND-1' THEN ROUND((75.00 + ROUND(src.KWH*0.0850,2) + ROUND(src.PEAK_KW*12.00,2)) * 1.070, 2)
        ELSE              ROUND((8.50  + ROUND(src.KWH*0.1150,2))                                * 1.080, 2) END,
    FALSE, CURRENT_TIMESTAMP()
);

-- =============================================================================
-- ===== ROUND 10: Billing month 2026-10 — Final batch, all types ==============
-- =============================================================================

MERGE INTO BILLING.MONTHLY_USAGE tgt
USING (
    SELECT col1 AS UID, col2 AS EAID, col3 AS KWH, col4 AS PEAK_KW, col5 AS RATE
    FROM VALUES
        ('USG-SIM-R10-001', 'EA-SIM-R1-001',  538.000,   NULL, 'RES-1'),
        ('USG-SIM-R10-002', 'EA-SIM-R1-002',  695.000,   NULL, 'RES-1'),
        ('USG-SIM-R10-003', 'EA-SIM-R1-004',  730.000,   NULL, 'RES-1'),
        ('USG-SIM-R10-004', 'EA-SIM-R10-001', 480.000,   NULL, 'RES-1'),
        ('USG-SIM-R10-005', 'EA-SIM-R10-002', 510.000,   NULL, 'RES-1'),
        ('USG-SIM-R10-006', 'EA-SIM-R10-003', 495.000,   NULL, 'RES-1'),
        ('USG-SIM-R10-007', 'EA-SIM-R10-004', 525.000,   NULL, 'RES-1'),
        ('USG-SIM-R10-008', 'EA-SIM-R8-001', 4400.000,  21.0, 'COM-1'),
        ('USG-SIM-R10-009', 'EA-SIM-R7-B02',12000.000,  58.0, 'IND-1'),
        -- correction record closing out the simulation
        ('USG-SIM-R10-COR', 'EA-SIM-R1-003', 4100.000,  17.5, 'COM-1')
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
    '2026-10', '2026-10-01'::DATE, '2026-10-31'::DATE, 31,
    src.KWH, src.KWH, src.PEAK_KW,
    src.KWH * 3, src.KWH * 4, 'ACTUAL', src.RATE,
    CASE src.RATE WHEN 'COM-1' THEN 22.00 WHEN 'IND-1' THEN 75.00 ELSE 8.50 END,
    CASE src.RATE WHEN 'COM-1' THEN ROUND(src.KWH * 0.1050, 2)
                  WHEN 'IND-1' THEN ROUND(src.KWH * 0.0850, 2)
                  ELSE              ROUND(src.KWH * 0.1150, 2) END,
    CASE WHEN src.PEAK_KW IS NOT NULL AND src.RATE = 'COM-1' THEN ROUND(src.PEAK_KW * 8.50, 2)
         WHEN src.PEAK_KW IS NOT NULL AND src.RATE = 'IND-1' THEN ROUND(src.PEAK_KW * 12.00, 2)
         ELSE 0.00 END,
    CASE src.RATE
        WHEN 'COM-1' THEN ROUND(22.00 + ROUND(src.KWH*0.1050,2) + ROUND(src.PEAK_KW*8.50,2), 2)
        WHEN 'IND-1' THEN ROUND(75.00 + ROUND(src.KWH*0.0850,2) + ROUND(src.PEAK_KW*12.00,2), 2)
        ELSE              ROUND(8.50  + ROUND(src.KWH*0.1150,2), 2) END,
    CASE src.RATE
        WHEN 'COM-1' THEN ROUND((22.00 + ROUND(src.KWH*0.1050,2) + ROUND(src.PEAK_KW*8.50,2))  * 0.085, 2)
        WHEN 'IND-1' THEN ROUND((75.00 + ROUND(src.KWH*0.0850,2) + ROUND(src.PEAK_KW*12.00,2)) * 0.070, 2)
        ELSE              ROUND((8.50  + ROUND(src.KWH*0.1150,2))                                * 0.080, 2) END,
    CASE src.RATE
        WHEN 'COM-1' THEN ROUND((22.00 + ROUND(src.KWH*0.1050,2) + ROUND(src.PEAK_KW*8.50,2))  * 1.085, 2)
        WHEN 'IND-1' THEN ROUND((75.00 + ROUND(src.KWH*0.0850,2) + ROUND(src.PEAK_KW*12.00,2)) * 1.070, 2)
        ELSE              ROUND((8.50  + ROUND(src.KWH*0.1150,2))                                * 1.080, 2) END,
    FALSE, CURRENT_TIMESTAMP()
);

-- =============================================================================
-- Verification: count what was inserted across all 10 rounds
-- =============================================================================
SELECT
    BILLING_MONTH,
    COUNT(*)                           AS ROW_COUNT,
    SUM(CASE WHEN USAGE_ID LIKE '%-REJ' THEN 1 ELSE 0 END) AS REJECTIONS,
    SUM(CASE WHEN USAGE_ID LIKE '%-COR' THEN 1 ELSE 0 END) AS CORRECTIONS,
    ROUND(SUM(KWH_USAGE), 2)           AS TOTAL_KWH,
    ROUND(SUM(TOTAL_BILLED), 2)        AS TOTAL_BILLED
FROM BILLING.MONTHLY_USAGE
WHERE USAGE_ID LIKE 'USG-SIM-%'
GROUP BY BILLING_MONTH
ORDER BY BILLING_MONTH;
