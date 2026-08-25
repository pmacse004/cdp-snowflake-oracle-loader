-- =============================================================================
-- Daily Load Simulation — Round 12
-- =============================================================================
-- Run as: CDP_ADMIN_ROLE  |  Database: CDP_UTIL_DB  |  Warehouse: CDP_LOADER_WH
--
-- SCENARIO  Solar net-metering customers + commercial wave — 40 customers
-- REJECTION REJ-D1: blank FIRST_NAME (VR-CUST-001) × 2
--           REJ-D2: invalid email (VR-CONT-001) × 2
-- TRIGGER   POST http://localhost:8080/api/jobs/daily
-- PREREQUISITE  daily-round-11.sql must have been run.
-- CUSTOMERS  40 valid + 2 blank-name rejections
-- ACCOUNTS   44 energy accounts (incl. 4 second accounts for solar/commercial)
-- CONTACTS   40 email + 20 phone + 2 invalid email rejections
-- =============================================================================

USE ROLE CDP_ADMIN_ROLE;
USE DATABASE CDP_UTIL_DB;
USE WAREHOUSE CDP_LOADER_WH;

-- ============================================================
-- 12a.  New customers — 40 valid rows
-- ============================================================
INSERT INTO CUSTOMER.CUSTOMER
    (CUSTOMER_ID, FIRST_NAME, LAST_NAME, ACCOUNT_STATUS, CUSTOMER_TYPE,
     PREFERRED_LANGUAGE, CREATED_AT, UPDATED_AT)
SELECT col1, col2, col3, col4, col5, col6, CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()
FROM VALUES
    ('CUST-SIM-R12-001', 'Amelia',    'Johansson',     'ACTIVE', 'RESIDENTIAL', 'EN'),
    ('CUST-SIM-R12-002', 'Ibrahim',   'Al-Farsi',       'ACTIVE', 'RESIDENTIAL', 'AR'),
    ('CUST-SIM-R12-003', 'Chloe',     'Beaumont',       'ACTIVE', 'RESIDENTIAL', 'FR'),
    ('CUST-SIM-R12-004', 'Yusuf',     'Adeyemi',        'ACTIVE', 'RESIDENTIAL', 'EN'),
    ('CUST-SIM-R12-005', 'Nkechi',    'Obi',             'ACTIVE', 'COMMERCIAL',  'EN'),
    ('CUST-SIM-R12-006', 'Patrik',    'Lindqvist',      'ACTIVE', 'COMMERCIAL',  'EN'),
    ('CUST-SIM-R12-007', 'Roksana',   'Witek',          'ACTIVE', 'COMMERCIAL',  'EN'),
    ('CUST-SIM-R12-008', 'Sebastiao', 'Carvalho',       'ACTIVE', 'COMMERCIAL',  'EN'),
    ('CUST-SIM-R12-009', 'Thanh',     'Pham',           'ACTIVE', 'INDUSTRIAL',  'EN'),
    ('CUST-SIM-R12-010', 'Ursula',    'Bachmann',       'ACTIVE', 'INDUSTRIAL',  'DE'),
    ('CUST-SIM-R12-011', 'Vusi',      'Dlamini',        'ACTIVE', 'INDUSTRIAL',  'EN'),
    ('CUST-SIM-R12-012', 'Wren',      'Nakagawa',       'ACTIVE', 'COMMERCIAL',  'EN'),
    ('CUST-SIM-R12-013', 'Xochitl',   'Morales',        'ACTIVE', 'RESIDENTIAL', 'EN'),
    ('CUST-SIM-R12-014', 'Yaw',       'Boateng',        'ACTIVE', 'RESIDENTIAL', 'EN'),
    ('CUST-SIM-R12-015', 'Zara',      'Petrov',         'ACTIVE', 'RESIDENTIAL', 'EN'),
    ('CUST-SIM-R12-016', 'Adil',      'Benomar',        'ACTIVE', 'COMMERCIAL',  'FR'),
    ('CUST-SIM-R12-017', 'Bianca',    'De Luca',        'ACTIVE', 'RESIDENTIAL', 'EN'),
    ('CUST-SIM-R12-018', 'Cedric',    'Dupont',         'ACTIVE', 'COMMERCIAL',  'FR'),
    ('CUST-SIM-R12-019', 'Daniyar',   'Seitkali',       'ACTIVE', 'COMMERCIAL',  'EN'),
    ('CUST-SIM-R12-020', 'Esther',    'Mwangi',         'ACTIVE', 'RESIDENTIAL', 'EN'),
    ('CUST-SIM-R12-021', 'Faris',     'Jaber',          'ACTIVE', 'RESIDENTIAL', 'AR'),
    ('CUST-SIM-R12-022', 'Giovanna',  'Conti',          'ACTIVE', 'RESIDENTIAL', 'EN'),
    ('CUST-SIM-R12-023', 'Hamid',     'Rezaei',         'ACTIVE', 'COMMERCIAL',  'EN'),
    ('CUST-SIM-R12-024', 'Isadora',   'Magalhães',      'ACTIVE', 'RESIDENTIAL', 'EN'),
    ('CUST-SIM-R12-025', 'Jens',      'Rasmussen',      'ACTIVE', 'RESIDENTIAL', 'EN'),
    ('CUST-SIM-R12-026', 'Kalani',    'Akana',          'ACTIVE', 'COMMERCIAL',  'EN'),
    ('CUST-SIM-R12-027', 'Lena',      'Bauer',          'ACTIVE', 'RESIDENTIAL', 'DE'),
    ('CUST-SIM-R12-028', 'Mounir',    'Belkacem',       'ACTIVE', 'COMMERCIAL',  'FR'),
    ('CUST-SIM-R12-029', 'Naomi',     'Osei',           'ACTIVE', 'RESIDENTIAL', 'EN'),
    ('CUST-SIM-R12-030', 'Ola',       'Nygaard',        'ACTIVE', 'RESIDENTIAL', 'EN'),
    ('CUST-SIM-R12-031', 'Pradeep',   'Nair',           'ACTIVE', 'INDUSTRIAL',  'EN'),
    ('CUST-SIM-R12-032', 'Quinlan',   'Fitzpatrick',    'ACTIVE', 'RESIDENTIAL', 'EN'),
    ('CUST-SIM-R12-033', 'Ronja',     'Holm',           'ACTIVE', 'RESIDENTIAL', 'EN'),
    ('CUST-SIM-R12-034', 'Samira',    'El-Amrani',      'ACTIVE', 'COMMERCIAL',  'AR'),
    ('CUST-SIM-R12-035', 'Tomas',     'Dvořák',         'ACTIVE', 'RESIDENTIAL', 'EN'),
    ('CUST-SIM-R12-036', 'Umut',      'Çelik',          'ACTIVE', 'RESIDENTIAL', 'EN'),
    ('CUST-SIM-R12-037', 'Vera',      'Sorokina',       'ACTIVE', 'COMMERCIAL',  'EN'),
    ('CUST-SIM-R12-038', 'Wendell',   'Oduya',          'ACTIVE', 'RESIDENTIAL', 'EN'),
    ('CUST-SIM-R12-039', 'Xiomara',   'Vargas',         'ACTIVE', 'RESIDENTIAL', 'EN'),
    ('CUST-SIM-R12-040', 'Yuki',      'Shimizu',        'ACTIVE', 'COMMERCIAL',  'EN')
    AS v(col1,col2,col3,col4,col5,col6)
WHERE NOT EXISTS (SELECT 1 FROM CUSTOMER.CUSTOMER WHERE CUSTOMER_ID = v.col1);

-- ============================================================
-- 12b.  Rejections: blank FIRST_NAME
-- ============================================================
INSERT INTO CUSTOMER.CUSTOMER
    (CUSTOMER_ID, FIRST_NAME, LAST_NAME, ACCOUNT_STATUS, CUSTOMER_TYPE,
     PREFERRED_LANGUAGE, CREATED_AT, UPDATED_AT)
SELECT col1, col2, col3, col4, col5, col6, CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()
FROM VALUES
    ('CUST-SIM-R12-RJ1', '', 'EmptyFirst',  'ACTIVE', 'RESIDENTIAL', 'EN'),
    ('CUST-SIM-R12-RJ2', '', 'BlankCorp',   'ACTIVE', 'COMMERCIAL',  'EN')
    AS v(col1,col2,col3,col4,col5,col6)
WHERE NOT EXISTS (SELECT 1 FROM CUSTOMER.CUSTOMER WHERE CUSTOMER_ID = v.col1);

-- ============================================================
-- 12c.  Primary email contacts — all 40 valid customers
-- ============================================================
INSERT INTO CUSTOMER.CUSTOMER_CONTACT
    (CONTACT_ID, CUSTOMER_ID, CONTACT_TYPE, CONTACT_VALUE,
     IS_PRIMARY, IS_VERIFIED, EFFECTIVE_DATE, CREATED_AT, UPDATED_AT)
SELECT col1, col2, col3, col4, TRUE, TRUE, CURRENT_DATE(), CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()
FROM VALUES
    ('CC-SIM-R12-001E', 'CUST-SIM-R12-001', 'EMAIL', 'amelia.johansson@demo.com'),
    ('CC-SIM-R12-002E', 'CUST-SIM-R12-002', 'EMAIL', 'ibrahim.alfarsi@demo.com'),
    ('CC-SIM-R12-003E', 'CUST-SIM-R12-003', 'EMAIL', 'chloe.beaumont@demo.com'),
    ('CC-SIM-R12-004E', 'CUST-SIM-R12-004', 'EMAIL', 'yusuf.adeyemi@demo.com'),
    ('CC-SIM-R12-005E', 'CUST-SIM-R12-005', 'EMAIL', 'nkechi.obi@demo.com'),
    ('CC-SIM-R12-006E', 'CUST-SIM-R12-006', 'EMAIL', 'patrik.lindqvist@demo.com'),
    ('CC-SIM-R12-007E', 'CUST-SIM-R12-007', 'EMAIL', 'roksana.witek@demo.com'),
    ('CC-SIM-R12-008E', 'CUST-SIM-R12-008', 'EMAIL', 'sebastiao.carvalho@demo.com'),
    ('CC-SIM-R12-009E', 'CUST-SIM-R12-009', 'EMAIL', 'thanh.pham@demo.com'),
    ('CC-SIM-R12-010E', 'CUST-SIM-R12-010', 'EMAIL', 'ursula.bachmann@demo.com'),
    ('CC-SIM-R12-011E', 'CUST-SIM-R12-011', 'EMAIL', 'vusi.dlamini@demo.com'),
    ('CC-SIM-R12-012E', 'CUST-SIM-R12-012', 'EMAIL', 'wren.nakagawa@demo.com'),
    ('CC-SIM-R12-013E', 'CUST-SIM-R12-013', 'EMAIL', 'xochitl.morales@demo.com'),
    ('CC-SIM-R12-014E', 'CUST-SIM-R12-014', 'EMAIL', 'yaw.boateng@demo.com'),
    ('CC-SIM-R12-015E', 'CUST-SIM-R12-015', 'EMAIL', 'zara.petrov@demo.com'),
    ('CC-SIM-R12-016E', 'CUST-SIM-R12-016', 'EMAIL', 'adil.benomar@demo.com'),
    ('CC-SIM-R12-017E', 'CUST-SIM-R12-017', 'EMAIL', 'bianca.deluca@demo.com'),
    ('CC-SIM-R12-018E', 'CUST-SIM-R12-018', 'EMAIL', 'cedric.dupont@demo.com'),
    ('CC-SIM-R12-019E', 'CUST-SIM-R12-019', 'EMAIL', 'daniyar.seitkali@demo.com'),
    ('CC-SIM-R12-020E', 'CUST-SIM-R12-020', 'EMAIL', 'esther.mwangi@demo.com'),
    ('CC-SIM-R12-021E', 'CUST-SIM-R12-021', 'EMAIL', 'faris.jaber@demo.com'),
    ('CC-SIM-R12-022E', 'CUST-SIM-R12-022', 'EMAIL', 'giovanna.conti@demo.com'),
    ('CC-SIM-R12-023E', 'CUST-SIM-R12-023', 'EMAIL', 'hamid.rezaei@demo.com'),
    ('CC-SIM-R12-024E', 'CUST-SIM-R12-024', 'EMAIL', 'isadora.magalhaes@demo.com'),
    ('CC-SIM-R12-025E', 'CUST-SIM-R12-025', 'EMAIL', 'jens.rasmussen@demo.com'),
    ('CC-SIM-R12-026E', 'CUST-SIM-R12-026', 'EMAIL', 'kalani.akana@demo.com'),
    ('CC-SIM-R12-027E', 'CUST-SIM-R12-027', 'EMAIL', 'lena.bauer@demo.com'),
    ('CC-SIM-R12-028E', 'CUST-SIM-R12-028', 'EMAIL', 'mounir.belkacem@demo.com'),
    ('CC-SIM-R12-029E', 'CUST-SIM-R12-029', 'EMAIL', 'naomi.osei@demo.com'),
    ('CC-SIM-R12-030E', 'CUST-SIM-R12-030', 'EMAIL', 'ola.nygaard@demo.com'),
    ('CC-SIM-R12-031E', 'CUST-SIM-R12-031', 'EMAIL', 'pradeep.nair@demo.com'),
    ('CC-SIM-R12-032E', 'CUST-SIM-R12-032', 'EMAIL', 'quinlan.fitzpatrick@demo.com'),
    ('CC-SIM-R12-033E', 'CUST-SIM-R12-033', 'EMAIL', 'ronja.holm@demo.com'),
    ('CC-SIM-R12-034E', 'CUST-SIM-R12-034', 'EMAIL', 'samira.elamrani@demo.com'),
    ('CC-SIM-R12-035E', 'CUST-SIM-R12-035', 'EMAIL', 'tomas.dvorak@demo.com'),
    ('CC-SIM-R12-036E', 'CUST-SIM-R12-036', 'EMAIL', 'umut.celik@demo.com'),
    ('CC-SIM-R12-037E', 'CUST-SIM-R12-037', 'EMAIL', 'vera.sorokina@demo.com'),
    ('CC-SIM-R12-038E', 'CUST-SIM-R12-038', 'EMAIL', 'wendell.oduya@demo.com'),
    ('CC-SIM-R12-039E', 'CUST-SIM-R12-039', 'EMAIL', 'xiomara.vargas@demo.com'),
    ('CC-SIM-R12-040E', 'CUST-SIM-R12-040', 'EMAIL', 'yuki.shimizu@demo.com')
    AS v(col1,col2,col3,col4)
WHERE NOT EXISTS (SELECT 1 FROM CUSTOMER.CUSTOMER_CONTACT WHERE CONTACT_ID = v.col1);

-- ============================================================
-- 12d.  Phone contacts — first 20 customers
-- ============================================================
INSERT INTO CUSTOMER.CUSTOMER_CONTACT
    (CONTACT_ID, CUSTOMER_ID, CONTACT_TYPE, CONTACT_VALUE,
     IS_PRIMARY, IS_VERIFIED, EFFECTIVE_DATE, CREATED_AT, UPDATED_AT)
SELECT col1, col2, col3, col4, TRUE, FALSE, CURRENT_DATE(), CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()
FROM VALUES
    ('CC-SIM-R12-001P', 'CUST-SIM-R12-001', 'PHONE', '555-1201'),
    ('CC-SIM-R12-002P', 'CUST-SIM-R12-002', 'PHONE', '555-1202'),
    ('CC-SIM-R12-003P', 'CUST-SIM-R12-003', 'PHONE', '555-1203'),
    ('CC-SIM-R12-004P', 'CUST-SIM-R12-004', 'PHONE', '555-1204'),
    ('CC-SIM-R12-005P', 'CUST-SIM-R12-005', 'PHONE', '555-1205'),
    ('CC-SIM-R12-006P', 'CUST-SIM-R12-006', 'PHONE', '555-1206'),
    ('CC-SIM-R12-007P', 'CUST-SIM-R12-007', 'PHONE', '555-1207'),
    ('CC-SIM-R12-008P', 'CUST-SIM-R12-008', 'PHONE', '555-1208'),
    ('CC-SIM-R12-009P', 'CUST-SIM-R12-009', 'PHONE', '555-1209'),
    ('CC-SIM-R12-010P', 'CUST-SIM-R12-010', 'PHONE', '555-1210'),
    ('CC-SIM-R12-011P', 'CUST-SIM-R12-011', 'PHONE', '555-1211'),
    ('CC-SIM-R12-012P', 'CUST-SIM-R12-012', 'PHONE', '555-1212'),
    ('CC-SIM-R12-013P', 'CUST-SIM-R12-013', 'PHONE', '555-1213'),
    ('CC-SIM-R12-014P', 'CUST-SIM-R12-014', 'PHONE', '555-1214'),
    ('CC-SIM-R12-015P', 'CUST-SIM-R12-015', 'PHONE', '555-1215'),
    ('CC-SIM-R12-016P', 'CUST-SIM-R12-016', 'PHONE', '555-1216'),
    ('CC-SIM-R12-017P', 'CUST-SIM-R12-017', 'PHONE', '555-1217'),
    ('CC-SIM-R12-018P', 'CUST-SIM-R12-018', 'PHONE', '555-1218'),
    ('CC-SIM-R12-019P', 'CUST-SIM-R12-019', 'PHONE', '555-1219'),
    ('CC-SIM-R12-020P', 'CUST-SIM-R12-020', 'PHONE', '555-1220')
    AS v(col1,col2,col3,col4)
WHERE NOT EXISTS (SELECT 1 FROM CUSTOMER.CUSTOMER_CONTACT WHERE CONTACT_ID = v.col1);

-- ============================================================
-- 12e.  Rejections: invalid email (no @)
-- ============================================================
INSERT INTO CUSTOMER.CUSTOMER_CONTACT
    (CONTACT_ID, CUSTOMER_ID, CONTACT_TYPE, CONTACT_VALUE,
     IS_PRIMARY, IS_VERIFIED, EFFECTIVE_DATE, CREATED_AT, UPDATED_AT)
SELECT col1, col2, col3, col4, TRUE, FALSE, CURRENT_DATE(), CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()
FROM VALUES
    ('CC-SIM-R12-RJE1', 'CUST-SIM-R12-001', 'EMAIL', 'amelia.johansson-nodomain'),
    ('CC-SIM-R12-RJE2', 'CUST-SIM-R12-005', 'EMAIL', 'nkechi.obi.invalid')
    AS v(col1,col2,col3,col4)
WHERE NOT EXISTS (SELECT 1 FROM CUSTOMER.CUSTOMER_CONTACT WHERE CONTACT_ID = v.col1);

-- ============================================================
-- 12f.  Energy accounts — 40 primary + 4 second accounts
-- ============================================================
INSERT INTO CUSTOMER.ENERGY_ACCOUNT
    (ENERGY_ACCOUNT_ID, CUSTOMER_ID, ACCOUNT_NUMBER, ACCOUNT_STATUS,
     SERVICE_TYPE, RATE_CLASS, OPEN_DATE, CREATED_AT, UPDATED_AT)
SELECT col1, col2, col3, col4, col5, col6, CURRENT_DATE(), CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()
FROM VALUES
    ('EA-SIM-R12-001', 'CUST-SIM-R12-001', 'ACCT-SIM-R12-001', 'ACTIVE', 'SOLAR',    'SOLAR_NET'),
    ('EA-SIM-R12-002', 'CUST-SIM-R12-002', 'ACCT-SIM-R12-002', 'ACTIVE', 'SOLAR',    'SOLAR_NET'),
    ('EA-SIM-R12-003', 'CUST-SIM-R12-003', 'ACCT-SIM-R12-003', 'ACTIVE', 'SOLAR',    'SOLAR_NET'),
    ('EA-SIM-R12-004', 'CUST-SIM-R12-004', 'ACCT-SIM-R12-004', 'ACTIVE', 'SOLAR',    'SOLAR_NET'),
    ('EA-SIM-R12-005', 'CUST-SIM-R12-005', 'ACCT-SIM-R12-005', 'ACTIVE', 'ELECTRIC', 'SMALL_COMMERCIAL'),
    ('EA-SIM-R12-006', 'CUST-SIM-R12-006', 'ACCT-SIM-R12-006', 'ACTIVE', 'ELECTRIC', 'MEDIUM_COMMERCIAL'),
    ('EA-SIM-R12-007', 'CUST-SIM-R12-007', 'ACCT-SIM-R12-007', 'ACTIVE', 'ELECTRIC', 'SMALL_COMMERCIAL'),
    ('EA-SIM-R12-008', 'CUST-SIM-R12-008', 'ACCT-SIM-R12-008', 'ACTIVE', 'ELECTRIC', 'MEDIUM_COMMERCIAL'),
    ('EA-SIM-R12-009', 'CUST-SIM-R12-009', 'ACCT-SIM-R12-009', 'ACTIVE', 'ELECTRIC', 'LARGE_INDUSTRIAL'),
    ('EA-SIM-R12-010', 'CUST-SIM-R12-010', 'ACCT-SIM-R12-010', 'ACTIVE', 'ELECTRIC', 'LARGE_INDUSTRIAL'),
    ('EA-SIM-R12-011', 'CUST-SIM-R12-011', 'ACCT-SIM-R12-011', 'ACTIVE', 'ELECTRIC', 'LARGE_INDUSTRIAL'),
    ('EA-SIM-R12-012', 'CUST-SIM-R12-012', 'ACCT-SIM-R12-012', 'ACTIVE', 'ELECTRIC', 'MEDIUM_COMMERCIAL'),
    ('EA-SIM-R12-013', 'CUST-SIM-R12-013', 'ACCT-SIM-R12-013', 'ACTIVE', 'ELECTRIC', 'RESIDENTIAL'),
    ('EA-SIM-R12-014', 'CUST-SIM-R12-014', 'ACCT-SIM-R12-014', 'ACTIVE', 'ELECTRIC', 'RESIDENTIAL'),
    ('EA-SIM-R12-015', 'CUST-SIM-R12-015', 'ACCT-SIM-R12-015', 'ACTIVE', 'ELECTRIC', 'RESIDENTIAL'),
    ('EA-SIM-R12-016', 'CUST-SIM-R12-016', 'ACCT-SIM-R12-016', 'ACTIVE', 'ELECTRIC', 'SMALL_COMMERCIAL'),
    ('EA-SIM-R12-017', 'CUST-SIM-R12-017', 'ACCT-SIM-R12-017', 'ACTIVE', 'ELECTRIC', 'RESIDENTIAL'),
    ('EA-SIM-R12-018', 'CUST-SIM-R12-018', 'ACCT-SIM-R12-018', 'ACTIVE', 'ELECTRIC', 'MEDIUM_COMMERCIAL'),
    ('EA-SIM-R12-019', 'CUST-SIM-R12-019', 'ACCT-SIM-R12-019', 'ACTIVE', 'ELECTRIC', 'MEDIUM_COMMERCIAL'),
    ('EA-SIM-R12-020', 'CUST-SIM-R12-020', 'ACCT-SIM-R12-020', 'ACTIVE', 'ELECTRIC', 'RESIDENTIAL'),
    ('EA-SIM-R12-021', 'CUST-SIM-R12-021', 'ACCT-SIM-R12-021', 'ACTIVE', 'ELECTRIC', 'RESIDENTIAL'),
    ('EA-SIM-R12-022', 'CUST-SIM-R12-022', 'ACCT-SIM-R12-022', 'ACTIVE', 'ELECTRIC', 'RESIDENTIAL'),
    ('EA-SIM-R12-023', 'CUST-SIM-R12-023', 'ACCT-SIM-R12-023', 'ACTIVE', 'ELECTRIC', 'MEDIUM_COMMERCIAL'),
    ('EA-SIM-R12-024', 'CUST-SIM-R12-024', 'ACCT-SIM-R12-024', 'ACTIVE', 'ELECTRIC', 'RESIDENTIAL'),
    ('EA-SIM-R12-025', 'CUST-SIM-R12-025', 'ACCT-SIM-R12-025', 'ACTIVE', 'ELECTRIC', 'RESIDENTIAL'),
    ('EA-SIM-R12-026', 'CUST-SIM-R12-026', 'ACCT-SIM-R12-026', 'ACTIVE', 'ELECTRIC', 'SMALL_COMMERCIAL'),
    ('EA-SIM-R12-027', 'CUST-SIM-R12-027', 'ACCT-SIM-R12-027', 'ACTIVE', 'ELECTRIC', 'RESIDENTIAL'),
    ('EA-SIM-R12-028', 'CUST-SIM-R12-028', 'ACCT-SIM-R12-028', 'ACTIVE', 'ELECTRIC', 'MEDIUM_COMMERCIAL'),
    ('EA-SIM-R12-029', 'CUST-SIM-R12-029', 'ACCT-SIM-R12-029', 'ACTIVE', 'ELECTRIC', 'RESIDENTIAL'),
    ('EA-SIM-R12-030', 'CUST-SIM-R12-030', 'ACCT-SIM-R12-030', 'ACTIVE', 'ELECTRIC', 'RESIDENTIAL'),
    ('EA-SIM-R12-031', 'CUST-SIM-R12-031', 'ACCT-SIM-R12-031', 'ACTIVE', 'ELECTRIC', 'LARGE_INDUSTRIAL'),
    ('EA-SIM-R12-032', 'CUST-SIM-R12-032', 'ACCT-SIM-R12-032', 'ACTIVE', 'ELECTRIC', 'RESIDENTIAL'),
    ('EA-SIM-R12-033', 'CUST-SIM-R12-033', 'ACCT-SIM-R12-033', 'ACTIVE', 'ELECTRIC', 'RESIDENTIAL'),
    ('EA-SIM-R12-034', 'CUST-SIM-R12-034', 'ACCT-SIM-R12-034', 'ACTIVE', 'ELECTRIC', 'MEDIUM_COMMERCIAL'),
    ('EA-SIM-R12-035', 'CUST-SIM-R12-035', 'ACCT-SIM-R12-035', 'ACTIVE', 'ELECTRIC', 'RESIDENTIAL'),
    ('EA-SIM-R12-036', 'CUST-SIM-R12-036', 'ACCT-SIM-R12-036', 'ACTIVE', 'ELECTRIC', 'RESIDENTIAL'),
    ('EA-SIM-R12-037', 'CUST-SIM-R12-037', 'ACCT-SIM-R12-037', 'ACTIVE', 'ELECTRIC', 'MEDIUM_COMMERCIAL'),
    ('EA-SIM-R12-038', 'CUST-SIM-R12-038', 'ACCT-SIM-R12-038', 'ACTIVE', 'ELECTRIC', 'RESIDENTIAL'),
    ('EA-SIM-R12-039', 'CUST-SIM-R12-039', 'ACCT-SIM-R12-039', 'ACTIVE', 'ELECTRIC', 'RESIDENTIAL'),
    ('EA-SIM-R12-040', 'CUST-SIM-R12-040', 'ACCT-SIM-R12-040', 'ACTIVE', 'ELECTRIC', 'SMALL_COMMERCIAL'),
    -- Second premises
    ('EA-SIM-R12-B09', 'CUST-SIM-R12-009', 'ACCT-SIM-R12-B09', 'ACTIVE', 'ELECTRIC', 'LARGE_INDUSTRIAL'),
    ('EA-SIM-R12-B10', 'CUST-SIM-R12-010', 'ACCT-SIM-R12-B10', 'ACTIVE', 'ELECTRIC', 'LARGE_INDUSTRIAL'),
    ('EA-SIM-R12-B11', 'CUST-SIM-R12-011', 'ACCT-SIM-R12-B11', 'ACTIVE', 'ELECTRIC', 'LARGE_INDUSTRIAL'),
    ('EA-SIM-R12-B31', 'CUST-SIM-R12-031', 'ACCT-SIM-R12-B31', 'ACTIVE', 'ELECTRIC', 'LARGE_INDUSTRIAL')
    AS v(col1,col2,col3,col4,col5,col6)
WHERE NOT EXISTS (SELECT 1 FROM CUSTOMER.ENERGY_ACCOUNT WHERE ENERGY_ACCOUNT_ID = v.col1);

-- ============================================================
-- 12g.  Cross-round updates — Round 11 customers
-- ============================================================
UPDATE CUSTOMER.CUSTOMER
SET PREFERRED_LANGUAGE = 'ES', UPDATED_AT = CURRENT_TIMESTAMP()
WHERE CUSTOMER_ID IN ('CUST-SIM-R11-005','CUST-SIM-R11-006','CUST-SIM-R11-007','CUST-SIM-R11-008');

UPDATE CUSTOMER.CUSTOMER
SET LAST_NAME = 'Mensah-Asante', UPDATED_AT = CURRENT_TIMESTAMP()
WHERE CUSTOMER_ID = 'CUST-SIM-R11-016';

UPDATE CUSTOMER.CUSTOMER_CONTACT
SET IS_VERIFIED = TRUE, UPDATED_AT = CURRENT_TIMESTAMP()
WHERE CONTACT_ID IN (
    'CC-SIM-R11-005E','CC-SIM-R11-006E','CC-SIM-R11-007E','CC-SIM-R11-008E',
    'CC-SIM-R11-009E','CC-SIM-R11-010E'
);

-- Reactivate accounts suspended in Round 11
UPDATE CUSTOMER.ENERGY_ACCOUNT
SET ACCOUNT_STATUS = 'ACTIVE', UPDATED_AT = CURRENT_TIMESTAMP()
WHERE ENERGY_ACCOUNT_ID IN ('EA-SIM-R9-001', 'EA-SIM-R9-002');

-- Upgrade industrial rate class for R11 commercial
UPDATE CUSTOMER.ENERGY_ACCOUNT
SET RATE_CLASS = 'LARGE_INDUSTRIAL', UPDATED_AT = CURRENT_TIMESTAMP()
WHERE ENERGY_ACCOUNT_ID IN ('EA-SIM-R11-001','EA-SIM-R11-002','EA-SIM-R11-005');

-- Verification
SELECT 'R12 customers inserted'      AS label, COUNT(*) AS cnt FROM CUSTOMER.CUSTOMER       WHERE CUSTOMER_ID       LIKE 'CUST-SIM-R12-%'
UNION ALL
SELECT 'R12 energy accounts inserted',          COUNT(*)        FROM CUSTOMER.ENERGY_ACCOUNT WHERE ENERGY_ACCOUNT_ID LIKE 'EA-SIM-R12-%'
UNION ALL
SELECT 'R12 email contacts inserted',           COUNT(*)        FROM CUSTOMER.CUSTOMER_CONTACT WHERE CONTACT_ID      LIKE 'CC-SIM-R12-%'
ORDER BY 1;
