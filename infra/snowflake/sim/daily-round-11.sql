-- =============================================================================
-- Daily Load Simulation — Round 11
-- =============================================================================
-- Run as: CDP_ADMIN_ROLE  |  Database: CDP_UTIL_DB  |  Warehouse: CDP_LOADER_WH
--
-- SCENARIO  New industrial + commercial wave — 40 customers, full contacts, phone
--           + email, energy accounts, plus cross-round updates and suspensions
-- REJECTION REJ-D1: blank FIRST_NAME (VR-CUST-001) × 2
--           REJ-D2: invalid email (VR-CONT-001) × 2
-- TRIGGER   POST http://localhost:8080/api/jobs/daily
-- PREREQUISITE  Rounds 1-10 (demo-daily-load-simulation.sql) must have been run.
-- CUSTOMERS  40 valid + 2 blank-name rejections
-- ACCOUNTS   44 energy accounts (incl. 2 second accounts for multi-premises)
-- CONTACTS   40 email + 20 phone + 2 invalid email rejections
-- =============================================================================

USE ROLE CDP_ADMIN_ROLE;
USE DATABASE CDP_UTIL_DB;
USE WAREHOUSE CDP_LOADER_WH;

-- ============================================================
-- 11a.  New customers — 40 valid rows
-- ============================================================
INSERT INTO CUSTOMER.CUSTOMER
    (CUSTOMER_ID, FIRST_NAME, LAST_NAME, ACCOUNT_STATUS, CUSTOMER_TYPE,
     PREFERRED_LANGUAGE, CREATED_AT, UPDATED_AT)
SELECT col1, col2, col3, col4, col5, col6, CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()
FROM VALUES
    ('CUST-SIM-R11-001', 'Tariq',      'Okafor',       'ACTIVE', 'INDUSTRIAL',  'EN'),
    ('CUST-SIM-R11-002', 'Svetlana',   'Volkov',        'ACTIVE', 'INDUSTRIAL',  'EN'),
    ('CUST-SIM-R11-003', 'Diego',      'Alvarado',      'ACTIVE', 'COMMERCIAL',  'EN'),
    ('CUST-SIM-R11-004', 'Fiona',      'Macgregor',     'ACTIVE', 'RESIDENTIAL', 'EN'),
    ('CUST-SIM-R11-005', 'Hiroshi',    'Taniguchi',     'ACTIVE', 'INDUSTRIAL',  'EN'),
    ('CUST-SIM-R11-006', 'Amaka',      'Obiechina',     'ACTIVE', 'COMMERCIAL',  'EN'),
    ('CUST-SIM-R11-007', 'Bartosz',    'Wiśniewski',    'ACTIVE', 'RESIDENTIAL', 'EN'),
    ('CUST-SIM-R11-008', 'Catalina',   'Herrera',       'ACTIVE', 'RESIDENTIAL', 'EN'),
    ('CUST-SIM-R11-009', 'Desmond',    'Achebe',        'ACTIVE', 'COMMERCIAL',  'EN'),
    ('CUST-SIM-R11-010', 'Evelina',    'Kovačević',     'ACTIVE', 'RESIDENTIAL', 'EN'),
    ('CUST-SIM-R11-011', 'Fumiko',     'Hayashi',       'ACTIVE', 'RESIDENTIAL', 'EN'),
    ('CUST-SIM-R11-012', 'Geraldo',    'Pereira',       'ACTIVE', 'COMMERCIAL',  'EN'),
    ('CUST-SIM-R11-013', 'Hafsah',     'Yusuf',         'ACTIVE', 'RESIDENTIAL', 'EN'),
    ('CUST-SIM-R11-014', 'Ivan',       'Novikov',       'ACTIVE', 'INDUSTRIAL',  'EN'),
    ('CUST-SIM-R11-015', 'Jana',       'Procházková',   'ACTIVE', 'RESIDENTIAL', 'EN'),
    ('CUST-SIM-R11-016', 'Kofi',       'Mensah',        'ACTIVE', 'COMMERCIAL',  'EN'),
    ('CUST-SIM-R11-017', 'Laila',      'Benali',        'ACTIVE', 'RESIDENTIAL', 'AR'),
    ('CUST-SIM-R11-018', 'Mikael',     'Ström',         'ACTIVE', 'RESIDENTIAL', 'EN'),
    ('CUST-SIM-R11-019', 'Nadia',      'Benoist',       'ACTIVE', 'COMMERCIAL',  'FR'),
    ('CUST-SIM-R11-020', 'Orlando',    'Esposito',      'ACTIVE', 'RESIDENTIAL', 'EN'),
    ('CUST-SIM-R11-021', 'Pita',       'Havili',        'ACTIVE', 'RESIDENTIAL', 'EN'),
    ('CUST-SIM-R11-022', 'Quynh',      'Nguyen',        'ACTIVE', 'RESIDENTIAL', 'EN'),
    ('CUST-SIM-R11-023', 'Rashida',    'Kamara',        'ACTIVE', 'COMMERCIAL',  'EN'),
    ('CUST-SIM-R11-024', 'Soren',      'Dalgaard',      'ACTIVE', 'RESIDENTIAL', 'EN'),
    ('CUST-SIM-R11-025', 'Tamara',     'Okonkwo',       'ACTIVE', 'RESIDENTIAL', 'EN'),
    ('CUST-SIM-R11-026', 'Umar',       'Hussain',       'ACTIVE', 'COMMERCIAL',  'EN'),
    ('CUST-SIM-R11-027', 'Valentina',  'Greco',         'ACTIVE', 'RESIDENTIAL', 'EN'),
    ('CUST-SIM-R11-028', 'Walid',      'Mansouri',      'ACTIVE', 'COMMERCIAL',  'AR'),
    ('CUST-SIM-R11-029', 'Xiu',        'Chen',          'ACTIVE', 'RESIDENTIAL', 'EN'),
    ('CUST-SIM-R11-030', 'Yolanda',    'Ferreira',      'ACTIVE', 'RESIDENTIAL', 'EN'),
    ('CUST-SIM-R11-031', 'Zubair',     'Malik',         'ACTIVE', 'INDUSTRIAL',  'EN'),
    ('CUST-SIM-R11-032', 'Abena',      'Asante',        'ACTIVE', 'RESIDENTIAL', 'EN'),
    ('CUST-SIM-R11-033', 'Benedikt',   'Huber',         'ACTIVE', 'COMMERCIAL',  'DE'),
    ('CUST-SIM-R11-034', 'Chiara',     'Romano',        'ACTIVE', 'RESIDENTIAL', 'EN'),
    ('CUST-SIM-R11-035', 'Dawit',      'Tesfaye',       'ACTIVE', 'RESIDENTIAL', 'EN'),
    ('CUST-SIM-R11-036', 'Elif',       'Yilmaz',        'ACTIVE', 'RESIDENTIAL', 'EN'),
    ('CUST-SIM-R11-037', 'Florian',    'Müller',        'ACTIVE', 'COMMERCIAL',  'DE'),
    ('CUST-SIM-R11-038', 'Giselle',    'Fontaine',      'ACTIVE', 'RESIDENTIAL', 'FR'),
    ('CUST-SIM-R11-039', 'Hector',     'Dominguez',     'ACTIVE', 'COMMERCIAL',  'EN'),
    ('CUST-SIM-R11-040', 'Ingrid',     'Magnusdóttir',  'ACTIVE', 'RESIDENTIAL', 'EN')
    AS v(col1,col2,col3,col4,col5,col6)
WHERE NOT EXISTS (SELECT 1 FROM CUSTOMER.CUSTOMER WHERE CUSTOMER_ID = v.col1);

-- ============================================================
-- 11b.  Rejections: blank FIRST_NAME
-- ============================================================
INSERT INTO CUSTOMER.CUSTOMER
    (CUSTOMER_ID, FIRST_NAME, LAST_NAME, ACCOUNT_STATUS, CUSTOMER_TYPE,
     PREFERRED_LANGUAGE, CREATED_AT, UPDATED_AT)
SELECT col1, col2, col3, col4, col5, col6, CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()
FROM VALUES
    ('CUST-SIM-R11-RJ1', '', 'NoNameA',  'ACTIVE', 'RESIDENTIAL', 'EN'),
    ('CUST-SIM-R11-RJ2', '', 'NoNameB',  'ACTIVE', 'COMMERCIAL',  'EN')
    AS v(col1,col2,col3,col4,col5,col6)
WHERE NOT EXISTS (SELECT 1 FROM CUSTOMER.CUSTOMER WHERE CUSTOMER_ID = v.col1);

-- ============================================================
-- 11c.  Primary email contacts — all 40 valid customers
-- ============================================================
INSERT INTO CUSTOMER.CUSTOMER_CONTACT
    (CONTACT_ID, CUSTOMER_ID, CONTACT_TYPE, CONTACT_VALUE,
     IS_PRIMARY, IS_VERIFIED, EFFECTIVE_DATE, CREATED_AT, UPDATED_AT)
SELECT col1, col2, col3, col4, TRUE, TRUE, CURRENT_DATE(), CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()
FROM VALUES
    ('CC-SIM-R11-001E', 'CUST-SIM-R11-001', 'EMAIL', 'tariq.okafor@demo.com'),
    ('CC-SIM-R11-002E', 'CUST-SIM-R11-002', 'EMAIL', 'svetlana.volkov@demo.com'),
    ('CC-SIM-R11-003E', 'CUST-SIM-R11-003', 'EMAIL', 'diego.alvarado@demo.com'),
    ('CC-SIM-R11-004E', 'CUST-SIM-R11-004', 'EMAIL', 'fiona.macgregor@demo.com'),
    ('CC-SIM-R11-005E', 'CUST-SIM-R11-005', 'EMAIL', 'hiroshi.taniguchi@demo.com'),
    ('CC-SIM-R11-006E', 'CUST-SIM-R11-006', 'EMAIL', 'amaka.obiechina@demo.com'),
    ('CC-SIM-R11-007E', 'CUST-SIM-R11-007', 'EMAIL', 'bartosz.wisniewski@demo.com'),
    ('CC-SIM-R11-008E', 'CUST-SIM-R11-008', 'EMAIL', 'catalina.herrera@demo.com'),
    ('CC-SIM-R11-009E', 'CUST-SIM-R11-009', 'EMAIL', 'desmond.achebe@demo.com'),
    ('CC-SIM-R11-010E', 'CUST-SIM-R11-010', 'EMAIL', 'evelina.kovacevic@demo.com'),
    ('CC-SIM-R11-011E', 'CUST-SIM-R11-011', 'EMAIL', 'fumiko.hayashi@demo.com'),
    ('CC-SIM-R11-012E', 'CUST-SIM-R11-012', 'EMAIL', 'geraldo.pereira@demo.com'),
    ('CC-SIM-R11-013E', 'CUST-SIM-R11-013', 'EMAIL', 'hafsah.yusuf@demo.com'),
    ('CC-SIM-R11-014E', 'CUST-SIM-R11-014', 'EMAIL', 'ivan.novikov@demo.com'),
    ('CC-SIM-R11-015E', 'CUST-SIM-R11-015', 'EMAIL', 'jana.prochazkova@demo.com'),
    ('CC-SIM-R11-016E', 'CUST-SIM-R11-016', 'EMAIL', 'kofi.mensah@demo.com'),
    ('CC-SIM-R11-017E', 'CUST-SIM-R11-017', 'EMAIL', 'laila.benali@demo.com'),
    ('CC-SIM-R11-018E', 'CUST-SIM-R11-018', 'EMAIL', 'mikael.strom@demo.com'),
    ('CC-SIM-R11-019E', 'CUST-SIM-R11-019', 'EMAIL', 'nadia.benoist@demo.com'),
    ('CC-SIM-R11-020E', 'CUST-SIM-R11-020', 'EMAIL', 'orlando.esposito@demo.com'),
    ('CC-SIM-R11-021E', 'CUST-SIM-R11-021', 'EMAIL', 'pita.havili@demo.com'),
    ('CC-SIM-R11-022E', 'CUST-SIM-R11-022', 'EMAIL', 'quynh.nguyen@demo.com'),
    ('CC-SIM-R11-023E', 'CUST-SIM-R11-023', 'EMAIL', 'rashida.kamara@demo.com'),
    ('CC-SIM-R11-024E', 'CUST-SIM-R11-024', 'EMAIL', 'soren.dalgaard@demo.com'),
    ('CC-SIM-R11-025E', 'CUST-SIM-R11-025', 'EMAIL', 'tamara.okonkwo@demo.com'),
    ('CC-SIM-R11-026E', 'CUST-SIM-R11-026', 'EMAIL', 'umar.hussain@demo.com'),
    ('CC-SIM-R11-027E', 'CUST-SIM-R11-027', 'EMAIL', 'valentina.greco@demo.com'),
    ('CC-SIM-R11-028E', 'CUST-SIM-R11-028', 'EMAIL', 'walid.mansouri@demo.com'),
    ('CC-SIM-R11-029E', 'CUST-SIM-R11-029', 'EMAIL', 'xiu.chen@demo.com'),
    ('CC-SIM-R11-030E', 'CUST-SIM-R11-030', 'EMAIL', 'yolanda.ferreira@demo.com'),
    ('CC-SIM-R11-031E', 'CUST-SIM-R11-031', 'EMAIL', 'zubair.malik@demo.com'),
    ('CC-SIM-R11-032E', 'CUST-SIM-R11-032', 'EMAIL', 'abena.asante@demo.com'),
    ('CC-SIM-R11-033E', 'CUST-SIM-R11-033', 'EMAIL', 'benedikt.huber@demo.com'),
    ('CC-SIM-R11-034E', 'CUST-SIM-R11-034', 'EMAIL', 'chiara.romano@demo.com'),
    ('CC-SIM-R11-035E', 'CUST-SIM-R11-035', 'EMAIL', 'dawit.tesfaye@demo.com'),
    ('CC-SIM-R11-036E', 'CUST-SIM-R11-036', 'EMAIL', 'elif.yilmaz@demo.com'),
    ('CC-SIM-R11-037E', 'CUST-SIM-R11-037', 'EMAIL', 'florian.muller@demo.com'),
    ('CC-SIM-R11-038E', 'CUST-SIM-R11-038', 'EMAIL', 'giselle.fontaine@demo.com'),
    ('CC-SIM-R11-039E', 'CUST-SIM-R11-039', 'EMAIL', 'hector.dominguez@demo.com'),
    ('CC-SIM-R11-040E', 'CUST-SIM-R11-040', 'EMAIL', 'ingrid.magnusdottir@demo.com')
    AS v(col1,col2,col3,col4)
WHERE NOT EXISTS (SELECT 1 FROM CUSTOMER.CUSTOMER_CONTACT WHERE CONTACT_ID = v.col1);

-- ============================================================
-- 11d.  Phone contacts — first 20 customers
-- ============================================================
INSERT INTO CUSTOMER.CUSTOMER_CONTACT
    (CONTACT_ID, CUSTOMER_ID, CONTACT_TYPE, CONTACT_VALUE,
     IS_PRIMARY, IS_VERIFIED, EFFECTIVE_DATE, CREATED_AT, UPDATED_AT)
SELECT col1, col2, col3, col4, TRUE, FALSE, CURRENT_DATE(), CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()
FROM VALUES
    ('CC-SIM-R11-001P', 'CUST-SIM-R11-001', 'PHONE', '555-1101'),
    ('CC-SIM-R11-002P', 'CUST-SIM-R11-002', 'PHONE', '555-1102'),
    ('CC-SIM-R11-003P', 'CUST-SIM-R11-003', 'PHONE', '555-1103'),
    ('CC-SIM-R11-004P', 'CUST-SIM-R11-004', 'PHONE', '555-1104'),
    ('CC-SIM-R11-005P', 'CUST-SIM-R11-005', 'PHONE', '555-1105'),
    ('CC-SIM-R11-006P', 'CUST-SIM-R11-006', 'PHONE', '555-1106'),
    ('CC-SIM-R11-007P', 'CUST-SIM-R11-007', 'PHONE', '555-1107'),
    ('CC-SIM-R11-008P', 'CUST-SIM-R11-008', 'PHONE', '555-1108'),
    ('CC-SIM-R11-009P', 'CUST-SIM-R11-009', 'PHONE', '555-1109'),
    ('CC-SIM-R11-010P', 'CUST-SIM-R11-010', 'PHONE', '555-1110'),
    ('CC-SIM-R11-011P', 'CUST-SIM-R11-011', 'PHONE', '555-1111'),
    ('CC-SIM-R11-012P', 'CUST-SIM-R11-012', 'PHONE', '555-1112'),
    ('CC-SIM-R11-013P', 'CUST-SIM-R11-013', 'PHONE', '555-1113'),
    ('CC-SIM-R11-014P', 'CUST-SIM-R11-014', 'PHONE', '555-1114'),
    ('CC-SIM-R11-015P', 'CUST-SIM-R11-015', 'PHONE', '555-1115'),
    ('CC-SIM-R11-016P', 'CUST-SIM-R11-016', 'PHONE', '555-1116'),
    ('CC-SIM-R11-017P', 'CUST-SIM-R11-017', 'PHONE', '555-1117'),
    ('CC-SIM-R11-018P', 'CUST-SIM-R11-018', 'PHONE', '555-1118'),
    ('CC-SIM-R11-019P', 'CUST-SIM-R11-019', 'PHONE', '555-1119'),
    ('CC-SIM-R11-020P', 'CUST-SIM-R11-020', 'PHONE', '555-1120')
    AS v(col1,col2,col3,col4)
WHERE NOT EXISTS (SELECT 1 FROM CUSTOMER.CUSTOMER_CONTACT WHERE CONTACT_ID = v.col1);

-- ============================================================
-- 11e.  Rejections: invalid email (no @)
-- ============================================================
INSERT INTO CUSTOMER.CUSTOMER_CONTACT
    (CONTACT_ID, CUSTOMER_ID, CONTACT_TYPE, CONTACT_VALUE,
     IS_PRIMARY, IS_VERIFIED, EFFECTIVE_DATE, CREATED_AT, UPDATED_AT)
SELECT col1, col2, col3, col4, TRUE, FALSE, CURRENT_DATE(), CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()
FROM VALUES
    ('CC-SIM-R11-RJE1', 'CUST-SIM-R11-001', 'EMAIL', 'not.valid.email'),
    ('CC-SIM-R11-RJE2', 'CUST-SIM-R11-002', 'EMAIL', 'also-not-valid')
    AS v(col1,col2,col3,col4)
WHERE NOT EXISTS (SELECT 1 FROM CUSTOMER.CUSTOMER_CONTACT WHERE CONTACT_ID = v.col1);

-- ============================================================
-- 11f.  Energy accounts — 40 primary + 4 second accounts
-- ============================================================
INSERT INTO CUSTOMER.ENERGY_ACCOUNT
    (ENERGY_ACCOUNT_ID, CUSTOMER_ID, ACCOUNT_NUMBER, ACCOUNT_STATUS,
     SERVICE_TYPE, RATE_CLASS, OPEN_DATE, CREATED_AT, UPDATED_AT)
SELECT col1, col2, col3, col4, col5, col6, CURRENT_DATE(), CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()
FROM VALUES
    ('EA-SIM-R11-001', 'CUST-SIM-R11-001', 'ACCT-SIM-R11-001', 'ACTIVE', 'ELECTRIC', 'LARGE_INDUSTRIAL'),
    ('EA-SIM-R11-002', 'CUST-SIM-R11-002', 'ACCT-SIM-R11-002', 'ACTIVE', 'ELECTRIC', 'LARGE_INDUSTRIAL'),
    ('EA-SIM-R11-003', 'CUST-SIM-R11-003', 'ACCT-SIM-R11-003', 'ACTIVE', 'ELECTRIC', 'SMALL_COMMERCIAL'),
    ('EA-SIM-R11-004', 'CUST-SIM-R11-004', 'ACCT-SIM-R11-004', 'ACTIVE', 'ELECTRIC', 'RESIDENTIAL'),
    ('EA-SIM-R11-005', 'CUST-SIM-R11-005', 'ACCT-SIM-R11-005', 'ACTIVE', 'ELECTRIC', 'LARGE_INDUSTRIAL'),
    ('EA-SIM-R11-006', 'CUST-SIM-R11-006', 'ACCT-SIM-R11-006', 'ACTIVE', 'ELECTRIC', 'MEDIUM_COMMERCIAL'),
    ('EA-SIM-R11-007', 'CUST-SIM-R11-007', 'ACCT-SIM-R11-007', 'ACTIVE', 'ELECTRIC', 'RESIDENTIAL'),
    ('EA-SIM-R11-008', 'CUST-SIM-R11-008', 'ACCT-SIM-R11-008', 'ACTIVE', 'ELECTRIC', 'RESIDENTIAL'),
    ('EA-SIM-R11-009', 'CUST-SIM-R11-009', 'ACCT-SIM-R11-009', 'ACTIVE', 'ELECTRIC', 'MEDIUM_COMMERCIAL'),
    ('EA-SIM-R11-010', 'CUST-SIM-R11-010', 'ACCT-SIM-R11-010', 'ACTIVE', 'ELECTRIC', 'RESIDENTIAL'),
    ('EA-SIM-R11-011', 'CUST-SIM-R11-011', 'ACCT-SIM-R11-011', 'ACTIVE', 'ELECTRIC', 'RESIDENTIAL'),
    ('EA-SIM-R11-012', 'CUST-SIM-R11-012', 'ACCT-SIM-R11-012', 'ACTIVE', 'ELECTRIC', 'SMALL_COMMERCIAL'),
    ('EA-SIM-R11-013', 'CUST-SIM-R11-013', 'ACCT-SIM-R11-013', 'ACTIVE', 'ELECTRIC', 'RESIDENTIAL'),
    ('EA-SIM-R11-014', 'CUST-SIM-R11-014', 'ACCT-SIM-R11-014', 'ACTIVE', 'ELECTRIC', 'LARGE_INDUSTRIAL'),
    ('EA-SIM-R11-015', 'CUST-SIM-R11-015', 'ACCT-SIM-R11-015', 'ACTIVE', 'ELECTRIC', 'RESIDENTIAL'),
    ('EA-SIM-R11-016', 'CUST-SIM-R11-016', 'ACCT-SIM-R11-016', 'ACTIVE', 'ELECTRIC', 'MEDIUM_COMMERCIAL'),
    ('EA-SIM-R11-017', 'CUST-SIM-R11-017', 'ACCT-SIM-R11-017', 'ACTIVE', 'ELECTRIC', 'RESIDENTIAL'),
    ('EA-SIM-R11-018', 'CUST-SIM-R11-018', 'ACCT-SIM-R11-018', 'ACTIVE', 'ELECTRIC', 'RESIDENTIAL'),
    ('EA-SIM-R11-019', 'CUST-SIM-R11-019', 'ACCT-SIM-R11-019', 'ACTIVE', 'ELECTRIC', 'SMALL_COMMERCIAL'),
    ('EA-SIM-R11-020', 'CUST-SIM-R11-020', 'ACCT-SIM-R11-020', 'ACTIVE', 'ELECTRIC', 'RESIDENTIAL'),
    ('EA-SIM-R11-021', 'CUST-SIM-R11-021', 'ACCT-SIM-R11-021', 'ACTIVE', 'ELECTRIC', 'RESIDENTIAL'),
    ('EA-SIM-R11-022', 'CUST-SIM-R11-022', 'ACCT-SIM-R11-022', 'ACTIVE', 'ELECTRIC', 'RESIDENTIAL'),
    ('EA-SIM-R11-023', 'CUST-SIM-R11-023', 'ACCT-SIM-R11-023', 'ACTIVE', 'ELECTRIC', 'MEDIUM_COMMERCIAL'),
    ('EA-SIM-R11-024', 'CUST-SIM-R11-024', 'ACCT-SIM-R11-024', 'ACTIVE', 'ELECTRIC', 'RESIDENTIAL'),
    ('EA-SIM-R11-025', 'CUST-SIM-R11-025', 'ACCT-SIM-R11-025', 'ACTIVE', 'ELECTRIC', 'RESIDENTIAL'),
    ('EA-SIM-R11-026', 'CUST-SIM-R11-026', 'ACCT-SIM-R11-026', 'ACTIVE', 'ELECTRIC', 'MEDIUM_COMMERCIAL'),
    ('EA-SIM-R11-027', 'CUST-SIM-R11-027', 'ACCT-SIM-R11-027', 'ACTIVE', 'ELECTRIC', 'RESIDENTIAL'),
    ('EA-SIM-R11-028', 'CUST-SIM-R11-028', 'ACCT-SIM-R11-028', 'ACTIVE', 'ELECTRIC', 'SMALL_COMMERCIAL'),
    ('EA-SIM-R11-029', 'CUST-SIM-R11-029', 'ACCT-SIM-R11-029', 'ACTIVE', 'ELECTRIC', 'RESIDENTIAL'),
    ('EA-SIM-R11-030', 'CUST-SIM-R11-030', 'ACCT-SIM-R11-030', 'ACTIVE', 'ELECTRIC', 'RESIDENTIAL'),
    ('EA-SIM-R11-031', 'CUST-SIM-R11-031', 'ACCT-SIM-R11-031', 'ACTIVE', 'ELECTRIC', 'LARGE_INDUSTRIAL'),
    ('EA-SIM-R11-032', 'CUST-SIM-R11-032', 'ACCT-SIM-R11-032', 'ACTIVE', 'ELECTRIC', 'RESIDENTIAL'),
    ('EA-SIM-R11-033', 'CUST-SIM-R11-033', 'ACCT-SIM-R11-033', 'ACTIVE', 'ELECTRIC', 'MEDIUM_COMMERCIAL'),
    ('EA-SIM-R11-034', 'CUST-SIM-R11-034', 'ACCT-SIM-R11-034', 'ACTIVE', 'ELECTRIC', 'RESIDENTIAL'),
    ('EA-SIM-R11-035', 'CUST-SIM-R11-035', 'ACCT-SIM-R11-035', 'ACTIVE', 'ELECTRIC', 'RESIDENTIAL'),
    ('EA-SIM-R11-036', 'CUST-SIM-R11-036', 'ACCT-SIM-R11-036', 'ACTIVE', 'ELECTRIC', 'RESIDENTIAL'),
    ('EA-SIM-R11-037', 'CUST-SIM-R11-037', 'ACCT-SIM-R11-037', 'ACTIVE', 'ELECTRIC', 'MEDIUM_COMMERCIAL'),
    ('EA-SIM-R11-038', 'CUST-SIM-R11-038', 'ACCT-SIM-R11-038', 'ACTIVE', 'ELECTRIC', 'RESIDENTIAL'),
    ('EA-SIM-R11-039', 'CUST-SIM-R11-039', 'ACCT-SIM-R11-039', 'ACTIVE', 'ELECTRIC', 'SMALL_COMMERCIAL'),
    ('EA-SIM-R11-040', 'CUST-SIM-R11-040', 'ACCT-SIM-R11-040', 'ACTIVE', 'ELECTRIC', 'RESIDENTIAL'),
    -- Second premises for industrial/commercial customers
    ('EA-SIM-R11-B01', 'CUST-SIM-R11-001', 'ACCT-SIM-R11-B01', 'ACTIVE', 'ELECTRIC', 'LARGE_INDUSTRIAL'),
    ('EA-SIM-R11-B05', 'CUST-SIM-R11-005', 'ACCT-SIM-R11-B05', 'ACTIVE', 'ELECTRIC', 'LARGE_INDUSTRIAL'),
    ('EA-SIM-R11-B14', 'CUST-SIM-R11-014', 'ACCT-SIM-R11-B14', 'ACTIVE', 'ELECTRIC', 'LARGE_INDUSTRIAL'),
    ('EA-SIM-R11-B31', 'CUST-SIM-R11-031', 'ACCT-SIM-R11-B31', 'ACTIVE', 'ELECTRIC', 'LARGE_INDUSTRIAL')
    AS v(col1,col2,col3,col4,col5,col6)
WHERE NOT EXISTS (SELECT 1 FROM CUSTOMER.ENERGY_ACCOUNT WHERE ENERGY_ACCOUNT_ID = v.col1);

-- ============================================================
-- 11g.  Cross-round updates — Round 10 customers
-- ============================================================
UPDATE CUSTOMER.CUSTOMER
SET PREFERRED_LANGUAGE = 'DE', UPDATED_AT = CURRENT_TIMESTAMP()
WHERE CUSTOMER_ID IN ('CUST-SIM-R10-001', 'CUST-SIM-R10-002', 'CUST-SIM-R10-003');

UPDATE CUSTOMER.CUSTOMER
SET ACCOUNT_STATUS = 'INACTIVE', STATUS_REASON = 'MOVED_AWAY', UPDATED_AT = CURRENT_TIMESTAMP()
WHERE CUSTOMER_ID IN ('CUST-SIM-R10-004');

UPDATE CUSTOMER.CUSTOMER_CONTACT
SET IS_VERIFIED = TRUE, UPDATED_AT = CURRENT_TIMESTAMP()
WHERE CONTACT_ID IN (
    'CC-SIM-R10-001E','CC-SIM-R10-002E','CC-SIM-R10-003E','CC-SIM-R10-004E'
);

-- ============================================================
-- 11h.  Suspend two Round 9 accounts — overdue balance
-- ============================================================
UPDATE CUSTOMER.ENERGY_ACCOUNT
SET ACCOUNT_STATUS = 'SUSPENDED', UPDATED_AT = CURRENT_TIMESTAMP()
WHERE ENERGY_ACCOUNT_ID IN ('EA-SIM-R9-001', 'EA-SIM-R9-002');

-- Verification
SELECT 'R11 customers inserted'      AS label, COUNT(*) AS cnt FROM CUSTOMER.CUSTOMER       WHERE CUSTOMER_ID       LIKE 'CUST-SIM-R11-%'
UNION ALL
SELECT 'R11 energy accounts inserted',          COUNT(*)        FROM CUSTOMER.ENERGY_ACCOUNT WHERE ENERGY_ACCOUNT_ID LIKE 'EA-SIM-R11-%'
UNION ALL
SELECT 'R11 email contacts inserted',           COUNT(*)        FROM CUSTOMER.CUSTOMER_CONTACT WHERE CONTACT_ID      LIKE 'CC-SIM-R11-%'
ORDER BY 1;
