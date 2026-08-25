-- =============================================================================
-- Daily Load Simulation — Round 13
-- =============================================================================
-- Run as: CDP_ADMIN_ROLE  |  Database: CDP_UTIL_DB  |  Warehouse: CDP_LOADER_WH
--
-- SCENARIO  Account closures + re-openings + large residential wave — 40 customers
-- REJECTION REJ-D1: blank FIRST_NAME (VR-CUST-001) × 2
--           REJ-D2: invalid email (VR-CONT-001) × 2
-- TRIGGER   POST http://localhost:8080/api/jobs/daily
-- PREREQUISITE  daily-round-12.sql must have been run.
-- CUSTOMERS  40 valid + 2 blank-name rejections
-- ACCOUNTS   44 energy accounts (incl. 4 second accounts)
-- CONTACTS   40 email + 20 phone + 2 invalid email rejections
-- =============================================================================

USE ROLE CDP_ADMIN_ROLE;
USE DATABASE CDP_UTIL_DB;
USE WAREHOUSE CDP_LOADER_WH;

-- ============================================================
-- 13a.  New customers — 40 valid rows
-- ============================================================
INSERT INTO CUSTOMER.CUSTOMER
    (CUSTOMER_ID, FIRST_NAME, LAST_NAME, ACCOUNT_STATUS, CUSTOMER_TYPE,
     PREFERRED_LANGUAGE, CREATED_AT, UPDATED_AT)
SELECT col1, col2, col3, col4, col5, col6, CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()
FROM VALUES
    ('CUST-SIM-R13-001', 'Elena',     'Popescu',        'ACTIVE', 'RESIDENTIAL', 'EN'),
    ('CUST-SIM-R13-002', 'Kwabena',   'Mensah',         'ACTIVE', 'RESIDENTIAL', 'EN'),
    ('CUST-SIM-R13-003', 'Rina',      'Hashimoto',      'ACTIVE', 'RESIDENTIAL', 'EN'),
    ('CUST-SIM-R13-004', 'Patrick',   'O''Sullivan',    'ACTIVE', 'COMMERCIAL',  'EN'),
    ('CUST-SIM-R13-005', 'Amira',     'Benali',         'ACTIVE', 'RESIDENTIAL', 'AR'),
    ('CUST-SIM-R13-006', 'Bram',      'De Vries',       'ACTIVE', 'RESIDENTIAL', 'EN'),
    ('CUST-SIM-R13-007', 'Carmen',    'Jimenez',        'ACTIVE', 'RESIDENTIAL', 'EN'),
    ('CUST-SIM-R13-008', 'Dmitri',    'Sokolov',        'ACTIVE', 'COMMERCIAL',  'EN'),
    ('CUST-SIM-R13-009', 'Elan',      'Ben-David',      'ACTIVE', 'COMMERCIAL',  'EN'),
    ('CUST-SIM-R13-010', 'Fatou',     'Diallo',         'ACTIVE', 'RESIDENTIAL', 'FR'),
    ('CUST-SIM-R13-011', 'Gunnar',    'Eriksson',       'ACTIVE', 'COMMERCIAL',  'EN'),
    ('CUST-SIM-R13-012', 'Hyun-Ji',   'Park',           'ACTIVE', 'COMMERCIAL',  'EN'),
    ('CUST-SIM-R13-013', 'Ifeoma',    'Eze',            'ACTIVE', 'COMMERCIAL',  'EN'),
    ('CUST-SIM-R13-014', 'Josip',     'Kovačić',        'ACTIVE', 'COMMERCIAL',  'EN'),
    ('CUST-SIM-R13-015', 'Karin',     'Nilsson',        'ACTIVE', 'COMMERCIAL',  'EN'),
    ('CUST-SIM-R13-016', 'Lior',      'Shapira',        'ACTIVE', 'COMMERCIAL',  'EN'),
    ('CUST-SIM-R13-017', 'Marwa',     'Hassan',         'ACTIVE', 'COMMERCIAL',  'AR'),
    ('CUST-SIM-R13-018', 'Niko',      'Papadopoulos',   'ACTIVE', 'COMMERCIAL',  'EN'),
    ('CUST-SIM-R13-019', 'Olumide',   'Adewale',        'ACTIVE', 'COMMERCIAL',  'EN'),
    ('CUST-SIM-R13-020', 'Pilar',     'Ruiz',           'ACTIVE', 'COMMERCIAL',  'EN'),
    ('CUST-SIM-R13-021', 'Quentin',   'Nakamura',       'ACTIVE', 'INDUSTRIAL',  'EN'),
    ('CUST-SIM-R13-022', 'Raisa',     'Virtanen',       'ACTIVE', 'INDUSTRIAL',  'EN'),
    ('CUST-SIM-R13-023', 'Sione',     'Taufa',          'ACTIVE', 'INDUSTRIAL',  'EN'),
    ('CUST-SIM-R13-024', 'Thandi',    'Nkosi',          'ACTIVE', 'INDUSTRIAL',  'EN'),
    ('CUST-SIM-R13-025', 'Uday',      'Sharma',         'ACTIVE', 'INDUSTRIAL',  'EN'),
    ('CUST-SIM-R13-026', 'Vilde',     'Andersen',       'ACTIVE', 'INDUSTRIAL',  'EN'),
    ('CUST-SIM-R13-027', 'Wanjiru',   'Kamau',          'ACTIVE', 'INDUSTRIAL',  'EN'),
    ('CUST-SIM-R13-028', 'Xander',    'Visser',         'ACTIVE', 'INDUSTRIAL',  'EN'),
    ('CUST-SIM-R13-029', 'Yana',      'Bondarenko',     'ACTIVE', 'INDUSTRIAL',  'EN'),
    ('CUST-SIM-R13-030', 'Zaid',      'Al-Rashidi',     'ACTIVE', 'INDUSTRIAL',  'AR'),
    ('CUST-SIM-R13-031', 'Adaora',    'Okonkwo',        'ACTIVE', 'RESIDENTIAL', 'EN'),
    ('CUST-SIM-R13-032', 'Bjorn',     'Haugen',         'ACTIVE', 'RESIDENTIAL', 'EN'),
    ('CUST-SIM-R13-033', 'Celeste',   'Mbeki',          'ACTIVE', 'RESIDENTIAL', 'EN'),
    ('CUST-SIM-R13-034', 'Dilan',     'Özdemir',        'ACTIVE', 'RESIDENTIAL', 'EN'),
    ('CUST-SIM-R13-035', 'Emre',      'Yıldız',         'ACTIVE', 'RESIDENTIAL', 'EN'),
    ('CUST-SIM-R13-036', 'Filippa',   'Berg',           'ACTIVE', 'RESIDENTIAL', 'EN'),
    ('CUST-SIM-R13-037', 'Gao',       'Wei',            'ACTIVE', 'RESIDENTIAL', 'EN'),
    ('CUST-SIM-R13-038', 'Hasina',    'Rakotondrabe',   'ACTIVE', 'RESIDENTIAL', 'FR'),
    ('CUST-SIM-R13-039', 'Ikaika',    'Kahananui',      'ACTIVE', 'RESIDENTIAL', 'EN'),
    ('CUST-SIM-R13-040', 'Jovana',    'Petrović',       'ACTIVE', 'RESIDENTIAL', 'EN')
    AS v(col1,col2,col3,col4,col5,col6)
WHERE NOT EXISTS (SELECT 1 FROM CUSTOMER.CUSTOMER WHERE CUSTOMER_ID = v.col1);

-- ============================================================
-- 13b.  Rejections: blank FIRST_NAME
-- ============================================================
INSERT INTO CUSTOMER.CUSTOMER
    (CUSTOMER_ID, FIRST_NAME, LAST_NAME, ACCOUNT_STATUS, CUSTOMER_TYPE,
     PREFERRED_LANGUAGE, CREATED_AT, UPDATED_AT)
SELECT col1, col2, col3, col4, col5, col6, CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()
FROM VALUES
    ('CUST-SIM-R13-RJ1', '', 'NoFirst',    'ACTIVE', 'RESIDENTIAL', 'EN'),
    ('CUST-SIM-R13-RJ2', '', 'MissingName','ACTIVE', 'COMMERCIAL',  'EN')
    AS v(col1,col2,col3,col4,col5,col6)
WHERE NOT EXISTS (SELECT 1 FROM CUSTOMER.CUSTOMER WHERE CUSTOMER_ID = v.col1);

-- ============================================================
-- 13c.  Primary email contacts — all 40 valid customers
-- ============================================================
INSERT INTO CUSTOMER.CUSTOMER_CONTACT
    (CONTACT_ID, CUSTOMER_ID, CONTACT_TYPE, CONTACT_VALUE,
     IS_PRIMARY, IS_VERIFIED, EFFECTIVE_DATE, CREATED_AT, UPDATED_AT)
SELECT col1, col2, col3, col4, TRUE, TRUE, CURRENT_DATE(), CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()
FROM VALUES
    ('CC-SIM-R13-001E', 'CUST-SIM-R13-001', 'EMAIL', 'elena.popescu@demo.com'),
    ('CC-SIM-R13-002E', 'CUST-SIM-R13-002', 'EMAIL', 'kwabena.mensah@demo.com'),
    ('CC-SIM-R13-003E', 'CUST-SIM-R13-003', 'EMAIL', 'rina.hashimoto@demo.com'),
    ('CC-SIM-R13-004E', 'CUST-SIM-R13-004', 'EMAIL', 'patrick.osullivan@demo.com'),
    ('CC-SIM-R13-005E', 'CUST-SIM-R13-005', 'EMAIL', 'amira.benali@demo.com'),
    ('CC-SIM-R13-006E', 'CUST-SIM-R13-006', 'EMAIL', 'bram.devries@demo.com'),
    ('CC-SIM-R13-007E', 'CUST-SIM-R13-007', 'EMAIL', 'carmen.jimenez@demo.com'),
    ('CC-SIM-R13-008E', 'CUST-SIM-R13-008', 'EMAIL', 'dmitri.sokolov@demo.com'),
    ('CC-SIM-R13-009E', 'CUST-SIM-R13-009', 'EMAIL', 'elan.bendavid@demo.com'),
    ('CC-SIM-R13-010E', 'CUST-SIM-R13-010', 'EMAIL', 'fatou.diallo@demo.com'),
    ('CC-SIM-R13-011E', 'CUST-SIM-R13-011', 'EMAIL', 'gunnar.eriksson@demo.com'),
    ('CC-SIM-R13-012E', 'CUST-SIM-R13-012', 'EMAIL', 'hyunji.park@demo.com'),
    ('CC-SIM-R13-013E', 'CUST-SIM-R13-013', 'EMAIL', 'ifeoma.eze@demo.com'),
    ('CC-SIM-R13-014E', 'CUST-SIM-R13-014', 'EMAIL', 'josip.kovacic@demo.com'),
    ('CC-SIM-R13-015E', 'CUST-SIM-R13-015', 'EMAIL', 'karin.nilsson@demo.com'),
    ('CC-SIM-R13-016E', 'CUST-SIM-R13-016', 'EMAIL', 'lior.shapira@demo.com'),
    ('CC-SIM-R13-017E', 'CUST-SIM-R13-017', 'EMAIL', 'marwa.hassan@demo.com'),
    ('CC-SIM-R13-018E', 'CUST-SIM-R13-018', 'EMAIL', 'niko.papadopoulos@demo.com'),
    ('CC-SIM-R13-019E', 'CUST-SIM-R13-019', 'EMAIL', 'olumide.adewale@demo.com'),
    ('CC-SIM-R13-020E', 'CUST-SIM-R13-020', 'EMAIL', 'pilar.ruiz@demo.com'),
    ('CC-SIM-R13-021E', 'CUST-SIM-R13-021', 'EMAIL', 'quentin.nakamura@demo.com'),
    ('CC-SIM-R13-022E', 'CUST-SIM-R13-022', 'EMAIL', 'raisa.virtanen@demo.com'),
    ('CC-SIM-R13-023E', 'CUST-SIM-R13-023', 'EMAIL', 'sione.taufa@demo.com'),
    ('CC-SIM-R13-024E', 'CUST-SIM-R13-024', 'EMAIL', 'thandi.nkosi@demo.com'),
    ('CC-SIM-R13-025E', 'CUST-SIM-R13-025', 'EMAIL', 'uday.sharma@demo.com'),
    ('CC-SIM-R13-026E', 'CUST-SIM-R13-026', 'EMAIL', 'vilde.andersen@demo.com'),
    ('CC-SIM-R13-027E', 'CUST-SIM-R13-027', 'EMAIL', 'wanjiru.kamau@demo.com'),
    ('CC-SIM-R13-028E', 'CUST-SIM-R13-028', 'EMAIL', 'xander.visser@demo.com'),
    ('CC-SIM-R13-029E', 'CUST-SIM-R13-029', 'EMAIL', 'yana.bondarenko@demo.com'),
    ('CC-SIM-R13-030E', 'CUST-SIM-R13-030', 'EMAIL', 'zaid.alrashidi@demo.com'),
    ('CC-SIM-R13-031E', 'CUST-SIM-R13-031', 'EMAIL', 'adaora.okonkwo@demo.com'),
    ('CC-SIM-R13-032E', 'CUST-SIM-R13-032', 'EMAIL', 'bjorn.haugen@demo.com'),
    ('CC-SIM-R13-033E', 'CUST-SIM-R13-033', 'EMAIL', 'celeste.mbeki@demo.com'),
    ('CC-SIM-R13-034E', 'CUST-SIM-R13-034', 'EMAIL', 'dilan.ozdemir@demo.com'),
    ('CC-SIM-R13-035E', 'CUST-SIM-R13-035', 'EMAIL', 'emre.yildiz@demo.com'),
    ('CC-SIM-R13-036E', 'CUST-SIM-R13-036', 'EMAIL', 'filippa.berg@demo.com'),
    ('CC-SIM-R13-037E', 'CUST-SIM-R13-037', 'EMAIL', 'gao.wei@demo.com'),
    ('CC-SIM-R13-038E', 'CUST-SIM-R13-038', 'EMAIL', 'hasina.rakotondrabe@demo.com'),
    ('CC-SIM-R13-039E', 'CUST-SIM-R13-039', 'EMAIL', 'ikaika.kahananui@demo.com'),
    ('CC-SIM-R13-040E', 'CUST-SIM-R13-040', 'EMAIL', 'jovana.petrovic@demo.com')
    AS v(col1,col2,col3,col4)
WHERE NOT EXISTS (SELECT 1 FROM CUSTOMER.CUSTOMER_CONTACT WHERE CONTACT_ID = v.col1);

-- ============================================================
-- 13d.  Phone contacts — first 20 customers
-- ============================================================
INSERT INTO CUSTOMER.CUSTOMER_CONTACT
    (CONTACT_ID, CUSTOMER_ID, CONTACT_TYPE, CONTACT_VALUE,
     IS_PRIMARY, IS_VERIFIED, EFFECTIVE_DATE, CREATED_AT, UPDATED_AT)
SELECT col1, col2, col3, col4, TRUE, FALSE, CURRENT_DATE(), CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()
FROM VALUES
    ('CC-SIM-R13-001P', 'CUST-SIM-R13-001', 'PHONE', '555-1301'),
    ('CC-SIM-R13-002P', 'CUST-SIM-R13-002', 'PHONE', '555-1302'),
    ('CC-SIM-R13-003P', 'CUST-SIM-R13-003', 'PHONE', '555-1303'),
    ('CC-SIM-R13-004P', 'CUST-SIM-R13-004', 'PHONE', '555-1304'),
    ('CC-SIM-R13-005P', 'CUST-SIM-R13-005', 'PHONE', '555-1305'),
    ('CC-SIM-R13-006P', 'CUST-SIM-R13-006', 'PHONE', '555-1306'),
    ('CC-SIM-R13-007P', 'CUST-SIM-R13-007', 'PHONE', '555-1307'),
    ('CC-SIM-R13-008P', 'CUST-SIM-R13-008', 'PHONE', '555-1308'),
    ('CC-SIM-R13-009P', 'CUST-SIM-R13-009', 'PHONE', '555-1309'),
    ('CC-SIM-R13-010P', 'CUST-SIM-R13-010', 'PHONE', '555-1310'),
    ('CC-SIM-R13-011P', 'CUST-SIM-R13-011', 'PHONE', '555-1311'),
    ('CC-SIM-R13-012P', 'CUST-SIM-R13-012', 'PHONE', '555-1312'),
    ('CC-SIM-R13-013P', 'CUST-SIM-R13-013', 'PHONE', '555-1313'),
    ('CC-SIM-R13-014P', 'CUST-SIM-R13-014', 'PHONE', '555-1314'),
    ('CC-SIM-R13-015P', 'CUST-SIM-R13-015', 'PHONE', '555-1315'),
    ('CC-SIM-R13-016P', 'CUST-SIM-R13-016', 'PHONE', '555-1316'),
    ('CC-SIM-R13-017P', 'CUST-SIM-R13-017', 'PHONE', '555-1317'),
    ('CC-SIM-R13-018P', 'CUST-SIM-R13-018', 'PHONE', '555-1318'),
    ('CC-SIM-R13-019P', 'CUST-SIM-R13-019', 'PHONE', '555-1319'),
    ('CC-SIM-R13-020P', 'CUST-SIM-R13-020', 'PHONE', '555-1320')
    AS v(col1,col2,col3,col4)
WHERE NOT EXISTS (SELECT 1 FROM CUSTOMER.CUSTOMER_CONTACT WHERE CONTACT_ID = v.col1);

-- ============================================================
-- 13e.  Rejections: invalid email (no @)
-- ============================================================
INSERT INTO CUSTOMER.CUSTOMER_CONTACT
    (CONTACT_ID, CUSTOMER_ID, CONTACT_TYPE, CONTACT_VALUE,
     IS_PRIMARY, IS_VERIFIED, EFFECTIVE_DATE, CREATED_AT, UPDATED_AT)
SELECT col1, col2, col3, col4, TRUE, FALSE, CURRENT_DATE(), CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()
FROM VALUES
    ('CC-SIM-R13-RJE1', 'CUST-SIM-R13-001', 'EMAIL', 'elena.popescu-at-demo.com'),
    ('CC-SIM-R13-RJE2', 'CUST-SIM-R13-004', 'EMAIL', 'patrick.osullivan_nodomain')
    AS v(col1,col2,col3,col4)
WHERE NOT EXISTS (SELECT 1 FROM CUSTOMER.CUSTOMER_CONTACT WHERE CONTACT_ID = v.col1);

-- ============================================================
-- 13f.  Energy accounts — 40 primary + 4 second accounts
-- ============================================================
INSERT INTO CUSTOMER.ENERGY_ACCOUNT
    (ENERGY_ACCOUNT_ID, CUSTOMER_ID, ACCOUNT_NUMBER, ACCOUNT_STATUS,
     SERVICE_TYPE, RATE_CLASS, OPEN_DATE, CREATED_AT, UPDATED_AT)
SELECT col1, col2, col3, col4, col5, col6, CURRENT_DATE(), CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()
FROM VALUES
    ('EA-SIM-R13-001', 'CUST-SIM-R13-001', 'ACCT-SIM-R13-001', 'ACTIVE', 'ELECTRIC', 'RESIDENTIAL'),
    ('EA-SIM-R13-002', 'CUST-SIM-R13-002', 'ACCT-SIM-R13-002', 'ACTIVE', 'ELECTRIC', 'RESIDENTIAL'),
    ('EA-SIM-R13-003', 'CUST-SIM-R13-003', 'ACCT-SIM-R13-003', 'ACTIVE', 'ELECTRIC', 'RESIDENTIAL'),
    ('EA-SIM-R13-004', 'CUST-SIM-R13-004', 'ACCT-SIM-R13-004', 'ACTIVE', 'ELECTRIC', 'SMALL_COMMERCIAL'),
    ('EA-SIM-R13-005', 'CUST-SIM-R13-005', 'ACCT-SIM-R13-005', 'ACTIVE', 'ELECTRIC', 'RESIDENTIAL'),
    ('EA-SIM-R13-006', 'CUST-SIM-R13-006', 'ACCT-SIM-R13-006', 'ACTIVE', 'ELECTRIC', 'RESIDENTIAL'),
    ('EA-SIM-R13-007', 'CUST-SIM-R13-007', 'ACCT-SIM-R13-007', 'ACTIVE', 'ELECTRIC', 'RESIDENTIAL'),
    ('EA-SIM-R13-008', 'CUST-SIM-R13-008', 'ACCT-SIM-R13-008', 'ACTIVE', 'ELECTRIC', 'MEDIUM_COMMERCIAL'),
    ('EA-SIM-R13-009', 'CUST-SIM-R13-009', 'ACCT-SIM-R13-009', 'ACTIVE', 'ELECTRIC', 'MEDIUM_COMMERCIAL'),
    ('EA-SIM-R13-010', 'CUST-SIM-R13-010', 'ACCT-SIM-R13-010', 'ACTIVE', 'ELECTRIC', 'RESIDENTIAL'),
    ('EA-SIM-R13-011', 'CUST-SIM-R13-011', 'ACCT-SIM-R13-011', 'ACTIVE', 'ELECTRIC', 'SMALL_COMMERCIAL'),
    ('EA-SIM-R13-012', 'CUST-SIM-R13-012', 'ACCT-SIM-R13-012', 'ACTIVE', 'ELECTRIC', 'MEDIUM_COMMERCIAL'),
    ('EA-SIM-R13-013', 'CUST-SIM-R13-013', 'ACCT-SIM-R13-013', 'ACTIVE', 'ELECTRIC', 'MEDIUM_COMMERCIAL'),
    ('EA-SIM-R13-014', 'CUST-SIM-R13-014', 'ACCT-SIM-R13-014', 'ACTIVE', 'ELECTRIC', 'SMALL_COMMERCIAL'),
    ('EA-SIM-R13-015', 'CUST-SIM-R13-015', 'ACCT-SIM-R13-015', 'ACTIVE', 'ELECTRIC', 'MEDIUM_COMMERCIAL'),
    ('EA-SIM-R13-016', 'CUST-SIM-R13-016', 'ACCT-SIM-R13-016', 'ACTIVE', 'ELECTRIC', 'SMALL_COMMERCIAL'),
    ('EA-SIM-R13-017', 'CUST-SIM-R13-017', 'ACCT-SIM-R13-017', 'ACTIVE', 'ELECTRIC', 'MEDIUM_COMMERCIAL'),
    ('EA-SIM-R13-018', 'CUST-SIM-R13-018', 'ACCT-SIM-R13-018', 'ACTIVE', 'ELECTRIC', 'MEDIUM_COMMERCIAL'),
    ('EA-SIM-R13-019', 'CUST-SIM-R13-019', 'ACCT-SIM-R13-019', 'ACTIVE', 'ELECTRIC', 'SMALL_COMMERCIAL'),
    ('EA-SIM-R13-020', 'CUST-SIM-R13-020', 'ACCT-SIM-R13-020', 'ACTIVE', 'ELECTRIC', 'MEDIUM_COMMERCIAL'),
    ('EA-SIM-R13-021', 'CUST-SIM-R13-021', 'ACCT-SIM-R13-021', 'ACTIVE', 'ELECTRIC', 'LARGE_INDUSTRIAL'),
    ('EA-SIM-R13-022', 'CUST-SIM-R13-022', 'ACCT-SIM-R13-022', 'ACTIVE', 'ELECTRIC', 'LARGE_INDUSTRIAL'),
    ('EA-SIM-R13-023', 'CUST-SIM-R13-023', 'ACCT-SIM-R13-023', 'ACTIVE', 'ELECTRIC', 'LARGE_INDUSTRIAL'),
    ('EA-SIM-R13-024', 'CUST-SIM-R13-024', 'ACCT-SIM-R13-024', 'ACTIVE', 'ELECTRIC', 'LARGE_INDUSTRIAL'),
    ('EA-SIM-R13-025', 'CUST-SIM-R13-025', 'ACCT-SIM-R13-025', 'ACTIVE', 'ELECTRIC', 'LARGE_INDUSTRIAL'),
    ('EA-SIM-R13-026', 'CUST-SIM-R13-026', 'ACCT-SIM-R13-026', 'ACTIVE', 'ELECTRIC', 'LARGE_INDUSTRIAL'),
    ('EA-SIM-R13-027', 'CUST-SIM-R13-027', 'ACCT-SIM-R13-027', 'ACTIVE', 'ELECTRIC', 'LARGE_INDUSTRIAL'),
    ('EA-SIM-R13-028', 'CUST-SIM-R13-028', 'ACCT-SIM-R13-028', 'ACTIVE', 'ELECTRIC', 'LARGE_INDUSTRIAL'),
    ('EA-SIM-R13-029', 'CUST-SIM-R13-029', 'ACCT-SIM-R13-029', 'ACTIVE', 'ELECTRIC', 'LARGE_INDUSTRIAL'),
    ('EA-SIM-R13-030', 'CUST-SIM-R13-030', 'ACCT-SIM-R13-030', 'ACTIVE', 'ELECTRIC', 'LARGE_INDUSTRIAL'),
    ('EA-SIM-R13-031', 'CUST-SIM-R13-031', 'ACCT-SIM-R13-031', 'ACTIVE', 'ELECTRIC', 'RESIDENTIAL'),
    ('EA-SIM-R13-032', 'CUST-SIM-R13-032', 'ACCT-SIM-R13-032', 'ACTIVE', 'ELECTRIC', 'RESIDENTIAL'),
    ('EA-SIM-R13-033', 'CUST-SIM-R13-033', 'ACCT-SIM-R13-033', 'ACTIVE', 'ELECTRIC', 'RESIDENTIAL'),
    ('EA-SIM-R13-034', 'CUST-SIM-R13-034', 'ACCT-SIM-R13-034', 'ACTIVE', 'ELECTRIC', 'RESIDENTIAL'),
    ('EA-SIM-R13-035', 'CUST-SIM-R13-035', 'ACCT-SIM-R13-035', 'ACTIVE', 'ELECTRIC', 'RESIDENTIAL'),
    ('EA-SIM-R13-036', 'CUST-SIM-R13-036', 'ACCT-SIM-R13-036', 'ACTIVE', 'ELECTRIC', 'RESIDENTIAL'),
    ('EA-SIM-R13-037', 'CUST-SIM-R13-037', 'ACCT-SIM-R13-037', 'ACTIVE', 'ELECTRIC', 'RESIDENTIAL'),
    ('EA-SIM-R13-038', 'CUST-SIM-R13-038', 'ACCT-SIM-R13-038', 'ACTIVE', 'ELECTRIC', 'RESIDENTIAL'),
    ('EA-SIM-R13-039', 'CUST-SIM-R13-039', 'ACCT-SIM-R13-039', 'ACTIVE', 'ELECTRIC', 'RESIDENTIAL'),
    ('EA-SIM-R13-040', 'CUST-SIM-R13-040', 'ACCT-SIM-R13-040', 'ACTIVE', 'ELECTRIC', 'RESIDENTIAL'),
    -- Second premises for industrial customers
    ('EA-SIM-R13-B21', 'CUST-SIM-R13-021', 'ACCT-SIM-R13-B21', 'ACTIVE', 'ELECTRIC', 'LARGE_INDUSTRIAL'),
    ('EA-SIM-R13-B22', 'CUST-SIM-R13-022', 'ACCT-SIM-R13-B22', 'ACTIVE', 'ELECTRIC', 'LARGE_INDUSTRIAL'),
    ('EA-SIM-R13-B23', 'CUST-SIM-R13-023', 'ACCT-SIM-R13-B23', 'ACTIVE', 'ELECTRIC', 'LARGE_INDUSTRIAL'),
    ('EA-SIM-R13-B24', 'CUST-SIM-R13-024', 'ACCT-SIM-R13-B24', 'ACTIVE', 'ELECTRIC', 'LARGE_INDUSTRIAL')
    AS v(col1,col2,col3,col4,col5,col6)
WHERE NOT EXISTS (SELECT 1 FROM CUSTOMER.ENERGY_ACCOUNT WHERE ENERGY_ACCOUNT_ID = v.col1);

-- ============================================================
-- 13g.  Cross-round updates
-- ============================================================
-- Close R11 accounts that have been inactive
UPDATE CUSTOMER.ENERGY_ACCOUNT
SET ACCOUNT_STATUS = 'CLOSED', CLOSE_DATE = CURRENT_DATE(), UPDATED_AT = CURRENT_TIMESTAMP()
WHERE ENERGY_ACCOUNT_ID IN ('EA-SIM-R11-007', 'EA-SIM-R11-008');

-- Reactivate customer inactivated in Round 11
UPDATE CUSTOMER.CUSTOMER
SET ACCOUNT_STATUS = 'ACTIVE', STATUS_REASON = NULL, UPDATED_AT = CURRENT_TIMESTAMP()
WHERE CUSTOMER_ID = 'CUST-SIM-R10-004';

-- Surname update for R12 customer
UPDATE CUSTOMER.CUSTOMER
SET LAST_NAME = 'Al-Rashidi-Hassan', UPDATED_AT = CURRENT_TIMESTAMP()
WHERE CUSTOMER_ID = 'CUST-SIM-R12-001';

-- Verify R12 email contacts
UPDATE CUSTOMER.CUSTOMER_CONTACT
SET IS_VERIFIED = TRUE, UPDATED_AT = CURRENT_TIMESTAMP()
WHERE CONTACT_ID IN (
    'CC-SIM-R12-011E','CC-SIM-R12-012E','CC-SIM-R12-013E','CC-SIM-R12-014E',
    'CC-SIM-R12-015E','CC-SIM-R12-016E','CC-SIM-R12-017E','CC-SIM-R12-018E',
    'CC-SIM-R12-019E','CC-SIM-R12-020E'
);

-- Inactivate R11 customers who have voluntarily closed
UPDATE CUSTOMER.CUSTOMER
SET ACCOUNT_STATUS = 'INACTIVE', STATUS_REASON = 'VOLUNTARY_CLOSURE', UPDATED_AT = CURRENT_TIMESTAMP()
WHERE CUSTOMER_ID IN ('CUST-SIM-R11-036', 'CUST-SIM-R11-037');

-- Verify R11 phones
UPDATE CUSTOMER.CUSTOMER_CONTACT
SET IS_VERIFIED = TRUE, UPDATED_AT = CURRENT_TIMESTAMP()
WHERE CONTACT_ID IN (
    'CC-SIM-R11-001P','CC-SIM-R11-002P','CC-SIM-R11-003P','CC-SIM-R11-004P',
    'CC-SIM-R11-005P','CC-SIM-R11-006P','CC-SIM-R11-007P','CC-SIM-R11-008P',
    'CC-SIM-R11-009P','CC-SIM-R11-010P'
);

-- Verification
SELECT 'R13 customers inserted'      AS label, COUNT(*) AS cnt FROM CUSTOMER.CUSTOMER       WHERE CUSTOMER_ID       LIKE 'CUST-SIM-R13-%'
UNION ALL
SELECT 'R13 energy accounts inserted',          COUNT(*)        FROM CUSTOMER.ENERGY_ACCOUNT WHERE ENERGY_ACCOUNT_ID LIKE 'EA-SIM-R13-%'
UNION ALL
SELECT 'R13 email contacts inserted',           COUNT(*)        FROM CUSTOMER.CUSTOMER_CONTACT WHERE CONTACT_ID      LIKE 'CC-SIM-R13-%'
ORDER BY 1;
