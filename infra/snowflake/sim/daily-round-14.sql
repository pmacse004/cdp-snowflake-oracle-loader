-- =============================================================================
-- Daily Load Simulation — Round 14
-- =============================================================================
-- Run as: CDP_ADMIN_ROLE  |  Database: CDP_UTIL_DB  |  Warehouse: CDP_LOADER_WH
--
-- SCENARIO  Bulk language migration + multilingual commercial wave — 40 customers
-- REJECTION REJ-D1: blank FIRST_NAME (VR-CUST-001) × 2
--           REJ-D2: invalid email (VR-CONT-001) × 2
-- TRIGGER   POST http://localhost:8080/api/jobs/daily
-- PREREQUISITE  daily-round-13.sql must have been run.
-- CUSTOMERS  40 valid + 2 blank-name rejections
-- ACCOUNTS   44 energy accounts (incl. 4 second accounts)
-- CONTACTS   40 email + 20 phone + 2 invalid email rejections
-- =============================================================================

USE ROLE CDP_ADMIN_ROLE;
USE DATABASE CDP_UTIL_DB;
USE WAREHOUSE CDP_LOADER_WH;

-- ============================================================
-- 14a.  New customers — 40 valid rows
-- ============================================================
INSERT INTO CUSTOMER.CUSTOMER
    (CUSTOMER_ID, FIRST_NAME, LAST_NAME, ACCOUNT_STATUS, CUSTOMER_TYPE,
     PREFERRED_LANGUAGE, CREATED_AT, UPDATED_AT)
SELECT col1, col2, col3, col4, col5, col6, CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()
FROM VALUES
    ('CUST-SIM-R14-001', 'Nour',       'Khalil',         'ACTIVE', 'RESIDENTIAL', 'AR'),
    ('CUST-SIM-R14-002', 'Sebastien',  'Moreau',         'ACTIVE', 'RESIDENTIAL', 'FR'),
    ('CUST-SIM-R14-003', 'Adaeze',     'Eze',            'ACTIVE', 'RESIDENTIAL', 'EN'),
    ('CUST-SIM-R13-004', 'Viktor',     'Hoffmann',       'ACTIVE', 'RESIDENTIAL', 'DE'),
    ('CUST-SIM-R14-005', 'Asel',       'Bakytbekova',    'ACTIVE', 'RESIDENTIAL', 'EN'),
    ('CUST-SIM-R14-006', 'Brendan',    'Otieno',         'ACTIVE', 'RESIDENTIAL', 'EN'),
    ('CUST-SIM-R14-007', 'Chidinma',   'Obi',            'ACTIVE', 'RESIDENTIAL', 'EN'),
    ('CUST-SIM-R14-008', 'Dorota',     'Kowalczyk',      'ACTIVE', 'RESIDENTIAL', 'EN'),
    ('CUST-SIM-R14-009', 'Emeka',      'Okonkwo',        'ACTIVE', 'COMMERCIAL',  'EN'),
    ('CUST-SIM-R14-010', 'Fumiya',     'Saito',          'ACTIVE', 'COMMERCIAL',  'EN'),
    ('CUST-SIM-R14-011', 'Gertrude',   'Akwesi',         'ACTIVE', 'COMMERCIAL',  'EN'),
    ('CUST-SIM-R14-012', 'Hana',       'Kovářová',       'ACTIVE', 'COMMERCIAL',  'EN'),
    ('CUST-SIM-R14-013', 'Ibrahima',   'Diallo',         'ACTIVE', 'COMMERCIAL',  'FR'),
    ('CUST-SIM-R14-014', 'Jade',       'Tran',           'ACTIVE', 'COMMERCIAL',  'EN'),
    ('CUST-SIM-R14-015', 'Khadjatou',  'Bah',            'ACTIVE', 'COMMERCIAL',  'FR'),
    ('CUST-SIM-R14-016', 'Ludovico',   'Ferrari',        'ACTIVE', 'COMMERCIAL',  'EN'),
    ('CUST-SIM-R14-017', 'Malak',      'El-Sayed',       'ACTIVE', 'COMMERCIAL',  'AR'),
    ('CUST-SIM-R14-018', 'Nikoletta',  'Varga',          'ACTIVE', 'COMMERCIAL',  'EN'),
    ('CUST-SIM-R14-019', 'Obiageli',   'Nwachukwu',      'ACTIVE', 'COMMERCIAL',  'EN'),
    ('CUST-SIM-R14-020', 'Pavel',      'Novotný',        'ACTIVE', 'COMMERCIAL',  'EN'),
    ('CUST-SIM-R14-021', 'Qian',       'Zhang',          'ACTIVE', 'COMMERCIAL',  'EN'),
    ('CUST-SIM-R14-022', 'Rebeka',     'Saarinen',       'ACTIVE', 'COMMERCIAL',  'EN'),
    ('CUST-SIM-R14-023', 'Sipho',      'Mkhize',         'ACTIVE', 'COMMERCIAL',  'EN'),
    ('CUST-SIM-R14-024', 'Takahiro',   'Yamamoto',       'ACTIVE', 'COMMERCIAL',  'EN'),
    ('CUST-SIM-R14-025', 'Urte',       'Žukauskaite',    'ACTIVE', 'COMMERCIAL',  'EN'),
    ('CUST-SIM-R14-026', 'Valentino',  'Rossi',          'ACTIVE', 'COMMERCIAL',  'EN'),
    ('CUST-SIM-R14-027', 'Wambui',     'Kariuki',        'ACTIVE', 'INDUSTRIAL',  'EN'),
    ('CUST-SIM-R14-028', 'Xochilt',    'Torres',         'ACTIVE', 'INDUSTRIAL',  'EN'),
    ('CUST-SIM-R14-029', 'Yahya',      'Al-Mansouri',    'ACTIVE', 'INDUSTRIAL',  'AR'),
    ('CUST-SIM-R14-030', 'Zuzanna',    'Kowalska',       'ACTIVE', 'INDUSTRIAL',  'EN'),
    ('CUST-SIM-R14-031', 'Aaron',      'Kibaki',         'ACTIVE', 'RESIDENTIAL', 'EN'),
    ('CUST-SIM-R14-032', 'Beatriz',    'Souza',          'ACTIVE', 'RESIDENTIAL', 'EN'),
    ('CUST-SIM-R14-033', 'Cengiz',     'Arslan',         'ACTIVE', 'RESIDENTIAL', 'EN'),
    ('CUST-SIM-R14-034', 'Delphine',   'Laurent',        'ACTIVE', 'RESIDENTIAL', 'FR'),
    ('CUST-SIM-R14-035', 'Ekaterina',  'Morozova',       'ACTIVE', 'RESIDENTIAL', 'EN'),
    ('CUST-SIM-R14-036', 'Femi',       'Adebayo',        'ACTIVE', 'RESIDENTIAL', 'EN'),
    ('CUST-SIM-R14-037', 'Gabriela',   'Popović',        'ACTIVE', 'RESIDENTIAL', 'EN'),
    ('CUST-SIM-R14-038', 'Haruto',     'Ito',            'ACTIVE', 'RESIDENTIAL', 'EN'),
    ('CUST-SIM-R14-039', 'Ingeborg',   'Hansen',         'ACTIVE', 'RESIDENTIAL', 'EN'),
    ('CUST-SIM-R14-040', 'Jamal',      'Moussa',         'ACTIVE', 'RESIDENTIAL', 'AR')
    AS v(col1,col2,col3,col4,col5,col6)
WHERE NOT EXISTS (SELECT 1 FROM CUSTOMER.CUSTOMER WHERE CUSTOMER_ID = v.col1);

-- ============================================================
-- 14b.  Rejections: blank FIRST_NAME
-- ============================================================
INSERT INTO CUSTOMER.CUSTOMER
    (CUSTOMER_ID, FIRST_NAME, LAST_NAME, ACCOUNT_STATUS, CUSTOMER_TYPE,
     PREFERRED_LANGUAGE, CREATED_AT, UPDATED_AT)
SELECT col1, col2, col3, col4, col5, col6, CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()
FROM VALUES
    ('CUST-SIM-R14-RJ1', '', 'BlankFirst',   'ACTIVE', 'COMMERCIAL', 'EN'),
    ('CUST-SIM-R14-RJ2', '', 'NoFirstName',  'ACTIVE', 'INDUSTRIAL', 'EN')
    AS v(col1,col2,col3,col4,col5,col6)
WHERE NOT EXISTS (SELECT 1 FROM CUSTOMER.CUSTOMER WHERE CUSTOMER_ID = v.col1);

-- ============================================================
-- 14c.  Primary email contacts — all 40 valid customers
-- ============================================================
INSERT INTO CUSTOMER.CUSTOMER_CONTACT
    (CONTACT_ID, CUSTOMER_ID, CONTACT_TYPE, CONTACT_VALUE,
     IS_PRIMARY, IS_VERIFIED, EFFECTIVE_DATE, CREATED_AT, UPDATED_AT)
SELECT col1, col2, col3, col4, TRUE, TRUE, CURRENT_DATE(), CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()
FROM VALUES
    ('CC-SIM-R14-001E', 'CUST-SIM-R14-001', 'EMAIL', 'nour.khalil@demo.com'),
    ('CC-SIM-R14-002E', 'CUST-SIM-R14-002', 'EMAIL', 'sebastien.moreau@demo.com'),
    ('CC-SIM-R14-003E', 'CUST-SIM-R14-003', 'EMAIL', 'adaeze.eze@demo.com'),
    ('CC-SIM-R14-004E', 'CUST-SIM-R13-004', 'EMAIL', 'viktor.hoffmann@demo.com'),
    ('CC-SIM-R14-005E', 'CUST-SIM-R14-005', 'EMAIL', 'asel.bakytbekova@demo.com'),
    ('CC-SIM-R14-006E', 'CUST-SIM-R14-006', 'EMAIL', 'brendan.otieno@demo.com'),
    ('CC-SIM-R14-007E', 'CUST-SIM-R14-007', 'EMAIL', 'chidinma.obi@demo.com'),
    ('CC-SIM-R14-008E', 'CUST-SIM-R14-008', 'EMAIL', 'dorota.kowalczyk@demo.com'),
    ('CC-SIM-R14-009E', 'CUST-SIM-R14-009', 'EMAIL', 'emeka.okonkwo@demo.com'),
    ('CC-SIM-R14-010E', 'CUST-SIM-R14-010', 'EMAIL', 'fumiya.saito@demo.com'),
    ('CC-SIM-R14-011E', 'CUST-SIM-R14-011', 'EMAIL', 'gertrude.akwesi@demo.com'),
    ('CC-SIM-R14-012E', 'CUST-SIM-R14-012', 'EMAIL', 'hana.kovarova@demo.com'),
    ('CC-SIM-R14-013E', 'CUST-SIM-R14-013', 'EMAIL', 'ibrahima.diallo@demo.com'),
    ('CC-SIM-R14-014E', 'CUST-SIM-R14-014', 'EMAIL', 'jade.tran@demo.com'),
    ('CC-SIM-R14-015E', 'CUST-SIM-R14-015', 'EMAIL', 'khadjatou.bah@demo.com'),
    ('CC-SIM-R14-016E', 'CUST-SIM-R14-016', 'EMAIL', 'ludovico.ferrari@demo.com'),
    ('CC-SIM-R14-017E', 'CUST-SIM-R14-017', 'EMAIL', 'malak.elsayed@demo.com'),
    ('CC-SIM-R14-018E', 'CUST-SIM-R14-018', 'EMAIL', 'nikoletta.varga@demo.com'),
    ('CC-SIM-R14-019E', 'CUST-SIM-R14-019', 'EMAIL', 'obiageli.nwachukwu@demo.com'),
    ('CC-SIM-R14-020E', 'CUST-SIM-R14-020', 'EMAIL', 'pavel.novotny@demo.com'),
    ('CC-SIM-R14-021E', 'CUST-SIM-R14-021', 'EMAIL', 'qian.zhang@demo.com'),
    ('CC-SIM-R14-022E', 'CUST-SIM-R14-022', 'EMAIL', 'rebeka.saarinen@demo.com'),
    ('CC-SIM-R14-023E', 'CUST-SIM-R14-023', 'EMAIL', 'sipho.mkhize@demo.com'),
    ('CC-SIM-R14-024E', 'CUST-SIM-R14-024', 'EMAIL', 'takahiro.yamamoto@demo.com'),
    ('CC-SIM-R14-025E', 'CUST-SIM-R14-025', 'EMAIL', 'urte.zukauskaite@demo.com'),
    ('CC-SIM-R14-026E', 'CUST-SIM-R14-026', 'EMAIL', 'valentino.rossi@demo.com'),
    ('CC-SIM-R14-027E', 'CUST-SIM-R14-027', 'EMAIL', 'wambui.kariuki@demo.com'),
    ('CC-SIM-R14-028E', 'CUST-SIM-R14-028', 'EMAIL', 'xochilt.torres@demo.com'),
    ('CC-SIM-R14-029E', 'CUST-SIM-R14-029', 'EMAIL', 'yahya.almansouri@demo.com'),
    ('CC-SIM-R14-030E', 'CUST-SIM-R14-030', 'EMAIL', 'zuzanna.kowalska@demo.com'),
    ('CC-SIM-R14-031E', 'CUST-SIM-R14-031', 'EMAIL', 'aaron.kibaki@demo.com'),
    ('CC-SIM-R14-032E', 'CUST-SIM-R14-032', 'EMAIL', 'beatriz.souza@demo.com'),
    ('CC-SIM-R14-033E', 'CUST-SIM-R14-033', 'EMAIL', 'cengiz.arslan@demo.com'),
    ('CC-SIM-R14-034E', 'CUST-SIM-R14-034', 'EMAIL', 'delphine.laurent@demo.com'),
    ('CC-SIM-R14-035E', 'CUST-SIM-R14-035', 'EMAIL', 'ekaterina.morozova@demo.com'),
    ('CC-SIM-R14-036E', 'CUST-SIM-R14-036', 'EMAIL', 'femi.adebayo@demo.com'),
    ('CC-SIM-R14-037E', 'CUST-SIM-R14-037', 'EMAIL', 'gabriela.popovic@demo.com'),
    ('CC-SIM-R14-038E', 'CUST-SIM-R14-038', 'EMAIL', 'haruto.ito@demo.com'),
    ('CC-SIM-R14-039E', 'CUST-SIM-R14-039', 'EMAIL', 'ingeborg.hansen@demo.com'),
    ('CC-SIM-R14-040E', 'CUST-SIM-R14-040', 'EMAIL', 'jamal.moussa@demo.com')
    AS v(col1,col2,col3,col4)
WHERE NOT EXISTS (SELECT 1 FROM CUSTOMER.CUSTOMER_CONTACT WHERE CONTACT_ID = v.col1);

-- ============================================================
-- 14d.  Phone contacts — first 20 customers
-- ============================================================
INSERT INTO CUSTOMER.CUSTOMER_CONTACT
    (CONTACT_ID, CUSTOMER_ID, CONTACT_TYPE, CONTACT_VALUE,
     IS_PRIMARY, IS_VERIFIED, EFFECTIVE_DATE, CREATED_AT, UPDATED_AT)
SELECT col1, col2, col3, col4, TRUE, FALSE, CURRENT_DATE(), CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()
FROM VALUES
    ('CC-SIM-R14-001P', 'CUST-SIM-R14-001', 'PHONE', '555-1401'),
    ('CC-SIM-R14-002P', 'CUST-SIM-R14-002', 'PHONE', '555-1402'),
    ('CC-SIM-R14-003P', 'CUST-SIM-R14-003', 'PHONE', '555-1403'),
    ('CC-SIM-R14-004P', 'CUST-SIM-R13-004', 'PHONE', '555-1404'),
    ('CC-SIM-R14-005P', 'CUST-SIM-R14-005', 'PHONE', '555-1405'),
    ('CC-SIM-R14-006P', 'CUST-SIM-R14-006', 'PHONE', '555-1406'),
    ('CC-SIM-R14-007P', 'CUST-SIM-R14-007', 'PHONE', '555-1407'),
    ('CC-SIM-R14-008P', 'CUST-SIM-R14-008', 'PHONE', '555-1408'),
    ('CC-SIM-R14-009P', 'CUST-SIM-R14-009', 'PHONE', '555-1409'),
    ('CC-SIM-R14-010P', 'CUST-SIM-R14-010', 'PHONE', '555-1410'),
    ('CC-SIM-R14-011P', 'CUST-SIM-R14-011', 'PHONE', '555-1411'),
    ('CC-SIM-R14-012P', 'CUST-SIM-R14-012', 'PHONE', '555-1412'),
    ('CC-SIM-R14-013P', 'CUST-SIM-R14-013', 'PHONE', '555-1413'),
    ('CC-SIM-R14-014P', 'CUST-SIM-R14-014', 'PHONE', '555-1414'),
    ('CC-SIM-R14-015P', 'CUST-SIM-R14-015', 'PHONE', '555-1415'),
    ('CC-SIM-R14-016P', 'CUST-SIM-R14-016', 'PHONE', '555-1416'),
    ('CC-SIM-R14-017P', 'CUST-SIM-R14-017', 'PHONE', '555-1417'),
    ('CC-SIM-R14-018P', 'CUST-SIM-R14-018', 'PHONE', '555-1418'),
    ('CC-SIM-R14-019P', 'CUST-SIM-R14-019', 'PHONE', '555-1419'),
    ('CC-SIM-R14-020P', 'CUST-SIM-R14-020', 'PHONE', '555-1420')
    AS v(col1,col2,col3,col4)
WHERE NOT EXISTS (SELECT 1 FROM CUSTOMER.CUSTOMER_CONTACT WHERE CONTACT_ID = v.col1);

-- ============================================================
-- 14e.  Rejections: invalid email
-- ============================================================
INSERT INTO CUSTOMER.CUSTOMER_CONTACT
    (CONTACT_ID, CUSTOMER_ID, CONTACT_TYPE, CONTACT_VALUE,
     IS_PRIMARY, IS_VERIFIED, EFFECTIVE_DATE, CREATED_AT, UPDATED_AT)
SELECT col1, col2, col3, col4, TRUE, FALSE, CURRENT_DATE(), CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()
FROM VALUES
    ('CC-SIM-R14-RJE1', 'CUST-SIM-R14-001', 'EMAIL', 'nour.khalil-invalid'),
    ('CC-SIM-R14-RJE2', 'CUST-SIM-R14-009', 'EMAIL', 'emeka.okonkwo_nodomain')
    AS v(col1,col2,col3,col4)
WHERE NOT EXISTS (SELECT 1 FROM CUSTOMER.CUSTOMER_CONTACT WHERE CONTACT_ID = v.col1);

-- ============================================================
-- 14f.  Energy accounts — 40 primary + 4 second accounts
-- ============================================================
INSERT INTO CUSTOMER.ENERGY_ACCOUNT
    (ENERGY_ACCOUNT_ID, CUSTOMER_ID, ACCOUNT_NUMBER, ACCOUNT_STATUS,
     SERVICE_TYPE, RATE_CLASS, OPEN_DATE, CREATED_AT, UPDATED_AT)
SELECT col1, col2, col3, col4, col5, col6, CURRENT_DATE(), CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()
FROM VALUES
    ('EA-SIM-R14-001', 'CUST-SIM-R14-001', 'ACCT-SIM-R14-001', 'ACTIVE', 'ELECTRIC', 'RESIDENTIAL'),
    ('EA-SIM-R14-002', 'CUST-SIM-R14-002', 'ACCT-SIM-R14-002', 'ACTIVE', 'ELECTRIC', 'RESIDENTIAL'),
    ('EA-SIM-R14-003', 'CUST-SIM-R14-003', 'ACCT-SIM-R14-003', 'ACTIVE', 'ELECTRIC', 'RESIDENTIAL'),
    ('EA-SIM-R14-004', 'CUST-SIM-R13-004', 'ACCT-SIM-R14-004', 'ACTIVE', 'ELECTRIC', 'RESIDENTIAL'),
    ('EA-SIM-R14-005', 'CUST-SIM-R14-005', 'ACCT-SIM-R14-005', 'ACTIVE', 'SOLAR',    'SOLAR_NET'),
    ('EA-SIM-R14-006', 'CUST-SIM-R14-006', 'ACCT-SIM-R14-006', 'ACTIVE', 'SOLAR',    'SOLAR_NET'),
    ('EA-SIM-R14-007', 'CUST-SIM-R14-007', 'ACCT-SIM-R14-007', 'ACTIVE', 'SOLAR',    'SOLAR_NET'),
    ('EA-SIM-R14-008', 'CUST-SIM-R14-008', 'ACCT-SIM-R14-008', 'ACTIVE', 'SOLAR',    'SOLAR_NET'),
    ('EA-SIM-R14-009', 'CUST-SIM-R14-009', 'ACCT-SIM-R14-009', 'ACTIVE', 'ELECTRIC', 'MEDIUM_COMMERCIAL'),
    ('EA-SIM-R14-010', 'CUST-SIM-R14-010', 'ACCT-SIM-R14-010', 'ACTIVE', 'ELECTRIC', 'MEDIUM_COMMERCIAL'),
    ('EA-SIM-R14-011', 'CUST-SIM-R14-011', 'ACCT-SIM-R14-011', 'ACTIVE', 'ELECTRIC', 'SMALL_COMMERCIAL'),
    ('EA-SIM-R14-012', 'CUST-SIM-R14-012', 'ACCT-SIM-R14-012', 'ACTIVE', 'ELECTRIC', 'MEDIUM_COMMERCIAL'),
    ('EA-SIM-R14-013', 'CUST-SIM-R14-013', 'ACCT-SIM-R14-013', 'ACTIVE', 'ELECTRIC', 'SMALL_COMMERCIAL'),
    ('EA-SIM-R14-014', 'CUST-SIM-R14-014', 'ACCT-SIM-R14-014', 'ACTIVE', 'ELECTRIC', 'MEDIUM_COMMERCIAL'),
    ('EA-SIM-R14-015', 'CUST-SIM-R14-015', 'ACCT-SIM-R14-015', 'ACTIVE', 'ELECTRIC', 'SMALL_COMMERCIAL'),
    ('EA-SIM-R14-016', 'CUST-SIM-R14-016', 'ACCT-SIM-R14-016', 'ACTIVE', 'ELECTRIC', 'MEDIUM_COMMERCIAL'),
    ('EA-SIM-R14-017', 'CUST-SIM-R14-017', 'ACCT-SIM-R14-017', 'ACTIVE', 'ELECTRIC', 'MEDIUM_COMMERCIAL'),
    ('EA-SIM-R14-018', 'CUST-SIM-R14-018', 'ACCT-SIM-R14-018', 'ACTIVE', 'ELECTRIC', 'SMALL_COMMERCIAL'),
    ('EA-SIM-R14-019', 'CUST-SIM-R14-019', 'ACCT-SIM-R14-019', 'ACTIVE', 'ELECTRIC', 'MEDIUM_COMMERCIAL'),
    ('EA-SIM-R14-020', 'CUST-SIM-R14-020', 'ACCT-SIM-R14-020', 'ACTIVE', 'ELECTRIC', 'MEDIUM_COMMERCIAL'),
    ('EA-SIM-R14-021', 'CUST-SIM-R14-021', 'ACCT-SIM-R14-021', 'ACTIVE', 'ELECTRIC', 'MEDIUM_COMMERCIAL'),
    ('EA-SIM-R14-022', 'CUST-SIM-R14-022', 'ACCT-SIM-R14-022', 'ACTIVE', 'ELECTRIC', 'SMALL_COMMERCIAL'),
    ('EA-SIM-R14-023', 'CUST-SIM-R14-023', 'ACCT-SIM-R14-023', 'ACTIVE', 'ELECTRIC', 'MEDIUM_COMMERCIAL'),
    ('EA-SIM-R14-024', 'CUST-SIM-R14-024', 'ACCT-SIM-R14-024', 'ACTIVE', 'ELECTRIC', 'MEDIUM_COMMERCIAL'),
    ('EA-SIM-R14-025', 'CUST-SIM-R14-025', 'ACCT-SIM-R14-025', 'ACTIVE', 'ELECTRIC', 'SMALL_COMMERCIAL'),
    ('EA-SIM-R14-026', 'CUST-SIM-R14-026', 'ACCT-SIM-R14-026', 'ACTIVE', 'ELECTRIC', 'MEDIUM_COMMERCIAL'),
    ('EA-SIM-R14-027', 'CUST-SIM-R14-027', 'ACCT-SIM-R14-027', 'ACTIVE', 'ELECTRIC', 'LARGE_INDUSTRIAL'),
    ('EA-SIM-R14-028', 'CUST-SIM-R14-028', 'ACCT-SIM-R14-028', 'ACTIVE', 'ELECTRIC', 'LARGE_INDUSTRIAL'),
    ('EA-SIM-R14-029', 'CUST-SIM-R14-029', 'ACCT-SIM-R14-029', 'ACTIVE', 'ELECTRIC', 'LARGE_INDUSTRIAL'),
    ('EA-SIM-R14-030', 'CUST-SIM-R14-030', 'ACCT-SIM-R14-030', 'ACTIVE', 'ELECTRIC', 'LARGE_INDUSTRIAL'),
    ('EA-SIM-R14-031', 'CUST-SIM-R14-031', 'ACCT-SIM-R14-031', 'ACTIVE', 'ELECTRIC', 'RESIDENTIAL'),
    ('EA-SIM-R14-032', 'CUST-SIM-R14-032', 'ACCT-SIM-R14-032', 'ACTIVE', 'ELECTRIC', 'RESIDENTIAL'),
    ('EA-SIM-R14-033', 'CUST-SIM-R14-033', 'ACCT-SIM-R14-033', 'ACTIVE', 'ELECTRIC', 'RESIDENTIAL'),
    ('EA-SIM-R14-034', 'CUST-SIM-R14-034', 'ACCT-SIM-R14-034', 'ACTIVE', 'ELECTRIC', 'RESIDENTIAL'),
    ('EA-SIM-R14-035', 'CUST-SIM-R14-035', 'ACCT-SIM-R14-035', 'ACTIVE', 'ELECTRIC', 'RESIDENTIAL'),
    ('EA-SIM-R14-036', 'CUST-SIM-R14-036', 'ACCT-SIM-R14-036', 'ACTIVE', 'ELECTRIC', 'RESIDENTIAL'),
    ('EA-SIM-R14-037', 'CUST-SIM-R14-037', 'ACCT-SIM-R14-037', 'ACTIVE', 'ELECTRIC', 'RESIDENTIAL'),
    ('EA-SIM-R14-038', 'CUST-SIM-R14-038', 'ACCT-SIM-R14-038', 'ACTIVE', 'ELECTRIC', 'RESIDENTIAL'),
    ('EA-SIM-R14-039', 'CUST-SIM-R14-039', 'ACCT-SIM-R14-039', 'ACTIVE', 'ELECTRIC', 'RESIDENTIAL'),
    ('EA-SIM-R14-040', 'CUST-SIM-R14-040', 'ACCT-SIM-R14-040', 'ACTIVE', 'ELECTRIC', 'RESIDENTIAL'),
    -- Second premises for industrial customers
    ('EA-SIM-R14-B27', 'CUST-SIM-R14-027', 'ACCT-SIM-R14-B27', 'ACTIVE', 'ELECTRIC', 'LARGE_INDUSTRIAL'),
    ('EA-SIM-R14-B28', 'CUST-SIM-R14-028', 'ACCT-SIM-R14-B28', 'ACTIVE', 'ELECTRIC', 'LARGE_INDUSTRIAL'),
    ('EA-SIM-R14-B29', 'CUST-SIM-R14-029', 'ACCT-SIM-R14-B29', 'ACTIVE', 'ELECTRIC', 'LARGE_INDUSTRIAL'),
    ('EA-SIM-R14-B30', 'CUST-SIM-R14-030', 'ACCT-SIM-R14-B30', 'ACTIVE', 'ELECTRIC', 'LARGE_INDUSTRIAL')
    AS v(col1,col2,col3,col4,col5,col6)
WHERE NOT EXISTS (SELECT 1 FROM CUSTOMER.ENERGY_ACCOUNT WHERE ENERGY_ACCOUNT_ID = v.col1);

-- ============================================================
-- 14g.  Cross-round updates
-- ============================================================
-- Bulk language migration — R13 residential to ES
UPDATE CUSTOMER.CUSTOMER
SET PREFERRED_LANGUAGE = 'ES', UPDATED_AT = CURRENT_TIMESTAMP()
WHERE CUSTOMER_ID IN (
    'CUST-SIM-R13-001','CUST-SIM-R13-002','CUST-SIM-R13-003',
    'CUST-SIM-R13-005','CUST-SIM-R13-006','CUST-SIM-R13-007',
    'CUST-SIM-R13-008','CUST-SIM-R13-009','CUST-SIM-R13-010'
);

-- R13 commercial cohort to FR
UPDATE CUSTOMER.CUSTOMER
SET PREFERRED_LANGUAGE = 'FR', UPDATED_AT = CURRENT_TIMESTAMP()
WHERE CUSTOMER_ID IN (
    'CUST-SIM-R13-011','CUST-SIM-R13-012','CUST-SIM-R13-013',
    'CUST-SIM-R13-014','CUST-SIM-R13-015'
);

-- Verify R13 industrial emails
UPDATE CUSTOMER.CUSTOMER_CONTACT
SET IS_VERIFIED = TRUE, UPDATED_AT = CURRENT_TIMESTAMP()
WHERE CONTACT_ID IN (
    'CC-SIM-R13-021E','CC-SIM-R13-022E','CC-SIM-R13-023E','CC-SIM-R13-024E',
    'CC-SIM-R13-025E','CC-SIM-R13-026E','CC-SIM-R13-027E','CC-SIM-R13-028E',
    'CC-SIM-R13-029E','CC-SIM-R13-030E'
);

-- Surname update
UPDATE CUSTOMER.CUSTOMER
SET LAST_NAME = 'Nakamura-Suzuki', UPDATED_AT = CURRENT_TIMESTAMP()
WHERE CUSTOMER_ID = 'CUST-SIM-R13-021';

-- Reopen R11 closed accounts
UPDATE CUSTOMER.ENERGY_ACCOUNT
SET ACCOUNT_STATUS = 'ACTIVE', CLOSE_DATE = NULL, UPDATED_AT = CURRENT_TIMESTAMP()
WHERE ENERGY_ACCOUNT_ID IN ('EA-SIM-R11-007', 'EA-SIM-R11-008');

-- Verify R12 phones
UPDATE CUSTOMER.CUSTOMER_CONTACT
SET IS_VERIFIED = TRUE, UPDATED_AT = CURRENT_TIMESTAMP()
WHERE CONTACT_ID IN (
    'CC-SIM-R12-001P','CC-SIM-R12-002P','CC-SIM-R12-003P','CC-SIM-R12-004P',
    'CC-SIM-R12-005P','CC-SIM-R12-006P','CC-SIM-R12-007P','CC-SIM-R12-008P',
    'CC-SIM-R12-009P','CC-SIM-R12-010P'
);

-- Verification
SELECT 'R14 customers inserted'      AS label, COUNT(*) AS cnt FROM CUSTOMER.CUSTOMER       WHERE CUSTOMER_ID       LIKE 'CUST-SIM-R14-%'
UNION ALL
SELECT 'R14 energy accounts inserted',          COUNT(*)        FROM CUSTOMER.ENERGY_ACCOUNT WHERE ENERGY_ACCOUNT_ID LIKE 'EA-SIM-R14-%'
UNION ALL
SELECT 'R14 email contacts inserted',           COUNT(*)        FROM CUSTOMER.CUSTOMER_CONTACT WHERE CONTACT_ID      LIKE 'CC-SIM-R14-%'
ORDER BY 1;
