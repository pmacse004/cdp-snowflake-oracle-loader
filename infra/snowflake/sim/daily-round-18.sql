-- =============================================================================
-- Daily Load Simulation — Round 18
-- =============================================================================
-- Run as: CDP_ADMIN_ROLE  |  Database: CDP_UTIL_DB  |  Warehouse: CDP_LOADER_WH
--
-- SCENARIO  Large customer wave — 40 customers across all types
-- REJECTION REJ-D1: blank FIRST_NAME (VR-CUST-001) x 2
--           REJ-D2: invalid email (VR-CONT-001) x 2
-- TRIGGER   POST http://localhost:8080/api/jobs/daily
-- PREREQUISITE  daily-round-17.sql must have been run.
-- CUSTOMERS  40 valid + 2 blank-name rejections
-- ACCOUNTS   44 energy accounts (incl. 4 second accounts)
-- CONTACTS   40 email + 20 phone + 2 invalid email rejections
-- =============================================================================

USE ROLE CDP_ADMIN_ROLE;
USE DATABASE CDP_UTIL_DB;
USE WAREHOUSE CDP_LOADER_WH;

-- ============================================================
-- 18a.  New customers — 40 valid rows
-- ============================================================
INSERT INTO CUSTOMER.CUSTOMER
    (CUSTOMER_ID, FIRST_NAME, LAST_NAME, ACCOUNT_STATUS, CUSTOMER_TYPE,
     PREFERRED_LANGUAGE, CREATED_AT, UPDATED_AT)
SELECT col1, col2, col3, col4, col5, col6, CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()
FROM VALUES
    ('CUST-SIM-R18-001', 'Aaliya', 'Kapoor', 'ACTIVE', 'RESIDENTIAL', 'EN'),
    ('CUST-SIM-R18-002', 'Fabio', 'Santini', 'ACTIVE', 'RESIDENTIAL', 'EN'),
    ('CUST-SIM-R18-003', 'Grace', 'Wanjiku', 'ACTIVE', 'RESIDENTIAL', 'EN'),
    ('CUST-SIM-R18-004', 'Hamza', 'Bouazizi', 'ACTIVE', 'COMMERCIAL', 'EN'),
    ('CUST-SIM-R18-005', 'Abdurahman', 'Nuur', 'ACTIVE', 'RESIDENTIAL', 'EN'),
    ('CUST-SIM-R18-006', 'Benedikta', 'Jungbluth', 'ACTIVE', 'RESIDENTIAL', 'DE'),
    ('CUST-SIM-R18-007', 'Celestino', 'Reyes', 'ACTIVE', 'COMMERCIAL', 'EN'),
    ('CUST-SIM-R18-008', 'Dagmara', 'Wisniewska', 'ACTIVE', 'COMMERCIAL', 'EN'),
    ('CUST-SIM-R18-009', 'Eleazar', 'Ben-Ami', 'ACTIVE', 'COMMERCIAL', 'EN'),
    ('CUST-SIM-R18-010', 'Francesca', 'Costa', 'ACTIVE', 'COMMERCIAL', 'EN'),
    ('CUST-SIM-R18-011', 'Gildas', 'Kabore', 'ACTIVE', 'COMMERCIAL', 'FR'),
    ('CUST-SIM-R18-012', 'Hanan', 'Al-Masri', 'ACTIVE', 'COMMERCIAL', 'AR'),
    ('CUST-SIM-R18-013', 'Imelda', 'Quirino', 'ACTIVE', 'COMMERCIAL', 'EN'),
    ('CUST-SIM-R18-014', 'Jasper', 'Vermeulen', 'ACTIVE', 'COMMERCIAL', 'EN'),
    ('CUST-SIM-R18-015', 'Kolade', 'Ademola', 'ACTIVE', 'COMMERCIAL', 'EN'),
    ('CUST-SIM-R18-016', 'Liene', 'Ozola', 'ACTIVE', 'COMMERCIAL', 'EN'),
    ('CUST-SIM-R18-017', 'Mamadou', 'Balde', 'ACTIVE', 'COMMERCIAL', 'FR'),
    ('CUST-SIM-R18-018', 'Nanako', 'Hayakawa', 'ACTIVE', 'COMMERCIAL', 'EN'),
    ('CUST-SIM-R18-019', 'Okafor', 'Chukwuemeka', 'ACTIVE', 'COMMERCIAL', 'EN'),
    ('CUST-SIM-R18-020', 'Petros', 'Georgiou', 'ACTIVE', 'COMMERCIAL', 'EN'),
    ('CUST-SIM-R18-021', 'Qasim', 'Al-Jabri', 'ACTIVE', 'INDUSTRIAL', 'AR'),
    ('CUST-SIM-R18-022', 'Roberta', 'De-Angelis', 'ACTIVE', 'INDUSTRIAL', 'EN'),
    ('CUST-SIM-R18-023', 'Seydou', 'Diarra', 'ACTIVE', 'INDUSTRIAL', 'FR'),
    ('CUST-SIM-R18-024', 'Takahide', 'Kitagawa', 'ACTIVE', 'INDUSTRIAL', 'EN'),
    ('CUST-SIM-R18-025', 'Umayya', 'Farouk', 'ACTIVE', 'INDUSTRIAL', 'AR'),
    ('CUST-SIM-R18-026', 'Veerle', 'Peeters', 'ACTIVE', 'INDUSTRIAL', 'EN'),
    ('CUST-SIM-R18-027', 'Wainui', 'Tuhoe', 'ACTIVE', 'INDUSTRIAL', 'EN'),
    ('CUST-SIM-R18-028', 'Ximena', 'Herrera', 'ACTIVE', 'INDUSTRIAL', 'EN'),
    ('CUST-SIM-R18-029', 'Yewande', 'Akin', 'ACTIVE', 'INDUSTRIAL', 'EN'),
    ('CUST-SIM-R18-030', 'Zdravko', 'Milic', 'ACTIVE', 'INDUSTRIAL', 'EN'),
    ('CUST-SIM-R18-031', 'Amahle', 'Dube', 'ACTIVE', 'RESIDENTIAL', 'EN'),
    ('CUST-SIM-R18-032', 'Bartok', 'Vasarhelyi', 'ACTIVE', 'RESIDENTIAL', 'EN'),
    ('CUST-SIM-R18-033', 'Coralie', 'Lebrun', 'ACTIVE', 'RESIDENTIAL', 'FR'),
    ('CUST-SIM-R18-034', 'Damilola', 'Oni', 'ACTIVE', 'RESIDENTIAL', 'EN'),
    ('CUST-SIM-R18-035', 'Erling', 'Thorvaldsen', 'ACTIVE', 'RESIDENTIAL', 'EN'),
    ('CUST-SIM-R18-036', 'Funmi', 'Alade', 'ACTIVE', 'RESIDENTIAL', 'EN'),
    ('CUST-SIM-R18-037', 'Giorgos', 'Papadopoulos', 'ACTIVE', 'RESIDENTIAL', 'EN'),
    ('CUST-SIM-R18-038', 'Hilde', 'Berntsen', 'ACTIVE', 'RESIDENTIAL', 'EN'),
    ('CUST-SIM-R18-039', 'Itzel', 'Dominguez', 'ACTIVE', 'RESIDENTIAL', 'EN'),
    ('CUST-SIM-R18-040', 'Jakub', 'Horvatovic', 'ACTIVE', 'RESIDENTIAL', 'EN')
    AS v(col1,col2,col3,col4,col5,col6)
WHERE NOT EXISTS (SELECT 1 FROM CUSTOMER.CUSTOMER WHERE CUSTOMER_ID = v.col1);

-- ============================================================
-- 18b.  Rejections: blank FIRST_NAME
-- ============================================================
INSERT INTO CUSTOMER.CUSTOMER
    (CUSTOMER_ID, FIRST_NAME, LAST_NAME, ACCOUNT_STATUS, CUSTOMER_TYPE,
     PREFERRED_LANGUAGE, CREATED_AT, UPDATED_AT)
SELECT col1, col2, col3, col4, col5, col6, CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()
FROM VALUES
    ('CUST-SIM-R18-RJ1', '', 'NoFirstA',  'ACTIVE', 'RESIDENTIAL', 'EN'),
    ('CUST-SIM-R18-RJ2', '', 'NoFirstB',  'ACTIVE', 'COMMERCIAL',  'EN')
    AS v(col1,col2,col3,col4,col5,col6)
WHERE NOT EXISTS (SELECT 1 FROM CUSTOMER.CUSTOMER WHERE CUSTOMER_ID = v.col1);

-- ============================================================
-- 18c.  Primary email contacts — all 40 valid customers
-- ============================================================
INSERT INTO CUSTOMER.CUSTOMER_CONTACT
    (CONTACT_ID, CUSTOMER_ID, CONTACT_TYPE, CONTACT_VALUE,
     IS_PRIMARY, IS_VERIFIED, EFFECTIVE_DATE, CREATED_AT, UPDATED_AT)
SELECT col1, col2, col3, col4, TRUE, TRUE, CURRENT_DATE(), CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()
FROM VALUES
    ('CC-SIM-R18-001E', 'CUST-SIM-R18-001', 'EMAIL', 'aaliya.kapoor@demo.com'),
    ('CC-SIM-R18-002E', 'CUST-SIM-R18-002', 'EMAIL', 'fabio.santini@demo.com'),
    ('CC-SIM-R18-003E', 'CUST-SIM-R18-003', 'EMAIL', 'grace.wanjiku@demo.com'),
    ('CC-SIM-R18-004E', 'CUST-SIM-R18-004', 'EMAIL', 'hamza.bouazizi@demo.com'),
    ('CC-SIM-R18-005E', 'CUST-SIM-R18-005', 'EMAIL', 'abdurahman.nuur@demo.com'),
    ('CC-SIM-R18-006E', 'CUST-SIM-R18-006', 'EMAIL', 'benedikta.jungbluth@demo.com'),
    ('CC-SIM-R18-007E', 'CUST-SIM-R18-007', 'EMAIL', 'celestino.reyes@demo.com'),
    ('CC-SIM-R18-008E', 'CUST-SIM-R18-008', 'EMAIL', 'dagmara.wisniewska@demo.com'),
    ('CC-SIM-R18-009E', 'CUST-SIM-R18-009', 'EMAIL', 'eleazar.ben-ami@demo.com'),
    ('CC-SIM-R18-010E', 'CUST-SIM-R18-010', 'EMAIL', 'francesca.costa@demo.com'),
    ('CC-SIM-R18-011E', 'CUST-SIM-R18-011', 'EMAIL', 'gildas.kabore@demo.com'),
    ('CC-SIM-R18-012E', 'CUST-SIM-R18-012', 'EMAIL', 'hanan.al-masri@demo.com'),
    ('CC-SIM-R18-013E', 'CUST-SIM-R18-013', 'EMAIL', 'imelda.quirino@demo.com'),
    ('CC-SIM-R18-014E', 'CUST-SIM-R18-014', 'EMAIL', 'jasper.vermeulen@demo.com'),
    ('CC-SIM-R18-015E', 'CUST-SIM-R18-015', 'EMAIL', 'kolade.ademola@demo.com'),
    ('CC-SIM-R18-016E', 'CUST-SIM-R18-016', 'EMAIL', 'liene.ozola@demo.com'),
    ('CC-SIM-R18-017E', 'CUST-SIM-R18-017', 'EMAIL', 'mamadou.balde@demo.com'),
    ('CC-SIM-R18-018E', 'CUST-SIM-R18-018', 'EMAIL', 'nanako.hayakawa@demo.com'),
    ('CC-SIM-R18-019E', 'CUST-SIM-R18-019', 'EMAIL', 'okafor.chukwuemeka@demo.com'),
    ('CC-SIM-R18-020E', 'CUST-SIM-R18-020', 'EMAIL', 'petros.georgiou@demo.com'),
    ('CC-SIM-R18-021E', 'CUST-SIM-R18-021', 'EMAIL', 'qasim.al-jabri@demo.com'),
    ('CC-SIM-R18-022E', 'CUST-SIM-R18-022', 'EMAIL', 'roberta.de-angelis@demo.com'),
    ('CC-SIM-R18-023E', 'CUST-SIM-R18-023', 'EMAIL', 'seydou.diarra@demo.com'),
    ('CC-SIM-R18-024E', 'CUST-SIM-R18-024', 'EMAIL', 'takahide.kitagawa@demo.com'),
    ('CC-SIM-R18-025E', 'CUST-SIM-R18-025', 'EMAIL', 'umayya.farouk@demo.com'),
    ('CC-SIM-R18-026E', 'CUST-SIM-R18-026', 'EMAIL', 'veerle.peeters@demo.com'),
    ('CC-SIM-R18-027E', 'CUST-SIM-R18-027', 'EMAIL', 'wainui.tuhoe@demo.com'),
    ('CC-SIM-R18-028E', 'CUST-SIM-R18-028', 'EMAIL', 'ximena.herrera@demo.com'),
    ('CC-SIM-R18-029E', 'CUST-SIM-R18-029', 'EMAIL', 'yewande.akin@demo.com'),
    ('CC-SIM-R18-030E', 'CUST-SIM-R18-030', 'EMAIL', 'zdravko.milic@demo.com'),
    ('CC-SIM-R18-031E', 'CUST-SIM-R18-031', 'EMAIL', 'amahle.dube@demo.com'),
    ('CC-SIM-R18-032E', 'CUST-SIM-R18-032', 'EMAIL', 'bartok.vasarhelyi@demo.com'),
    ('CC-SIM-R18-033E', 'CUST-SIM-R18-033', 'EMAIL', 'coralie.lebrun@demo.com'),
    ('CC-SIM-R18-034E', 'CUST-SIM-R18-034', 'EMAIL', 'damilola.oni@demo.com'),
    ('CC-SIM-R18-035E', 'CUST-SIM-R18-035', 'EMAIL', 'erling.thorvaldsen@demo.com'),
    ('CC-SIM-R18-036E', 'CUST-SIM-R18-036', 'EMAIL', 'funmi.alade@demo.com'),
    ('CC-SIM-R18-037E', 'CUST-SIM-R18-037', 'EMAIL', 'giorgos.papadopoulos@demo.com'),
    ('CC-SIM-R18-038E', 'CUST-SIM-R18-038', 'EMAIL', 'hilde.berntsen@demo.com'),
    ('CC-SIM-R18-039E', 'CUST-SIM-R18-039', 'EMAIL', 'itzel.dominguez@demo.com'),
    ('CC-SIM-R18-040E', 'CUST-SIM-R18-040', 'EMAIL', 'jakub.horvatovic@demo.com')
    AS v(col1,col2,col3,col4)
WHERE NOT EXISTS (SELECT 1 FROM CUSTOMER.CUSTOMER_CONTACT WHERE CONTACT_ID = v.col1);

-- ============================================================
-- 18d.  Phone contacts — first 20 customers
-- ============================================================
INSERT INTO CUSTOMER.CUSTOMER_CONTACT
    (CONTACT_ID, CUSTOMER_ID, CONTACT_TYPE, CONTACT_VALUE,
     IS_PRIMARY, IS_VERIFIED, EFFECTIVE_DATE, CREATED_AT, UPDATED_AT)
SELECT col1, col2, col3, col4, TRUE, FALSE, CURRENT_DATE(), CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()
FROM VALUES
    ('CC-SIM-R18-001P', 'CUST-SIM-R18-001', 'PHONE', '555-1801'),
    ('CC-SIM-R18-002P', 'CUST-SIM-R18-002', 'PHONE', '555-1802'),
    ('CC-SIM-R18-003P', 'CUST-SIM-R18-003', 'PHONE', '555-1803'),
    ('CC-SIM-R18-004P', 'CUST-SIM-R18-004', 'PHONE', '555-1804'),
    ('CC-SIM-R18-005P', 'CUST-SIM-R18-005', 'PHONE', '555-1805'),
    ('CC-SIM-R18-006P', 'CUST-SIM-R18-006', 'PHONE', '555-1806'),
    ('CC-SIM-R18-007P', 'CUST-SIM-R18-007', 'PHONE', '555-1807'),
    ('CC-SIM-R18-008P', 'CUST-SIM-R18-008', 'PHONE', '555-1808'),
    ('CC-SIM-R18-009P', 'CUST-SIM-R18-009', 'PHONE', '555-1809'),
    ('CC-SIM-R18-010P', 'CUST-SIM-R18-010', 'PHONE', '555-1810'),
    ('CC-SIM-R18-011P', 'CUST-SIM-R18-011', 'PHONE', '555-1811'),
    ('CC-SIM-R18-012P', 'CUST-SIM-R18-012', 'PHONE', '555-1812'),
    ('CC-SIM-R18-013P', 'CUST-SIM-R18-013', 'PHONE', '555-1813'),
    ('CC-SIM-R18-014P', 'CUST-SIM-R18-014', 'PHONE', '555-1814'),
    ('CC-SIM-R18-015P', 'CUST-SIM-R18-015', 'PHONE', '555-1815'),
    ('CC-SIM-R18-016P', 'CUST-SIM-R18-016', 'PHONE', '555-1816'),
    ('CC-SIM-R18-017P', 'CUST-SIM-R18-017', 'PHONE', '555-1817'),
    ('CC-SIM-R18-018P', 'CUST-SIM-R18-018', 'PHONE', '555-1818'),
    ('CC-SIM-R18-019P', 'CUST-SIM-R18-019', 'PHONE', '555-1819'),
    ('CC-SIM-R18-020P', 'CUST-SIM-R18-020', 'PHONE', '555-1820')
    AS v(col1,col2,col3,col4)
WHERE NOT EXISTS (SELECT 1 FROM CUSTOMER.CUSTOMER_CONTACT WHERE CONTACT_ID = v.col1);

-- ============================================================
-- 18e.  Rejections: invalid email (no @)
-- ============================================================
INSERT INTO CUSTOMER.CUSTOMER_CONTACT
    (CONTACT_ID, CUSTOMER_ID, CONTACT_TYPE, CONTACT_VALUE,
     IS_PRIMARY, IS_VERIFIED, EFFECTIVE_DATE, CREATED_AT, UPDATED_AT)
SELECT col1, col2, col3, col4, TRUE, FALSE, CURRENT_DATE(), CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()
FROM VALUES
    ('CC-SIM-R18-RJE1', 'CUST-SIM-R18-001', 'EMAIL', 'invalid.email.nodomain'),
    ('CC-SIM-R18-RJE2', 'CUST-SIM-R18-002', 'EMAIL', 'also-not-valid-email')
    AS v(col1,col2,col3,col4)
WHERE NOT EXISTS (SELECT 1 FROM CUSTOMER.CUSTOMER_CONTACT WHERE CONTACT_ID = v.col1);

-- ============================================================
-- 18f.  Energy accounts — 40 primary + 4 second accounts
-- ============================================================
INSERT INTO CUSTOMER.ENERGY_ACCOUNT
    (ENERGY_ACCOUNT_ID, CUSTOMER_ID, ACCOUNT_NUMBER, ACCOUNT_STATUS,
     SERVICE_TYPE, RATE_CLASS, OPEN_DATE, CREATED_AT, UPDATED_AT)
SELECT col1, col2, col3, col4, col5, col6, CURRENT_DATE(), CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()
FROM VALUES
    ('EA-SIM-R18-001', 'CUST-SIM-R18-001', 'ACCT-SIM-R18-001', 'ACTIVE', 'ELECTRIC', 'RESIDENTIAL'),
    ('EA-SIM-R18-002', 'CUST-SIM-R18-002', 'ACCT-SIM-R18-002', 'ACTIVE', 'ELECTRIC', 'RESIDENTIAL'),
    ('EA-SIM-R18-003', 'CUST-SIM-R18-003', 'ACCT-SIM-R18-003', 'ACTIVE', 'ELECTRIC', 'RESIDENTIAL'),
    ('EA-SIM-R18-004', 'CUST-SIM-R18-004', 'ACCT-SIM-R18-004', 'ACTIVE', 'ELECTRIC', 'SMALL_COMMERCIAL'),
    ('EA-SIM-R18-005', 'CUST-SIM-R18-005', 'ACCT-SIM-R18-005', 'ACTIVE', 'ELECTRIC', 'RESIDENTIAL'),
    ('EA-SIM-R18-006', 'CUST-SIM-R18-006', 'ACCT-SIM-R18-006', 'ACTIVE', 'ELECTRIC', 'RESIDENTIAL'),
    ('EA-SIM-R18-007', 'CUST-SIM-R18-007', 'ACCT-SIM-R18-007', 'ACTIVE', 'ELECTRIC', 'SMALL_COMMERCIAL'),
    ('EA-SIM-R18-008', 'CUST-SIM-R18-008', 'ACCT-SIM-R18-008', 'ACTIVE', 'ELECTRIC', 'SMALL_COMMERCIAL'),
    ('EA-SIM-R18-009', 'CUST-SIM-R18-009', 'ACCT-SIM-R18-009', 'ACTIVE', 'ELECTRIC', 'SMALL_COMMERCIAL'),
    ('EA-SIM-R18-010', 'CUST-SIM-R18-010', 'ACCT-SIM-R18-010', 'ACTIVE', 'ELECTRIC', 'SMALL_COMMERCIAL'),
    ('EA-SIM-R18-011', 'CUST-SIM-R18-011', 'ACCT-SIM-R18-011', 'ACTIVE', 'ELECTRIC', 'SMALL_COMMERCIAL'),
    ('EA-SIM-R18-012', 'CUST-SIM-R18-012', 'ACCT-SIM-R18-012', 'ACTIVE', 'ELECTRIC', 'SMALL_COMMERCIAL'),
    ('EA-SIM-R18-013', 'CUST-SIM-R18-013', 'ACCT-SIM-R18-013', 'ACTIVE', 'ELECTRIC', 'SMALL_COMMERCIAL'),
    ('EA-SIM-R18-014', 'CUST-SIM-R18-014', 'ACCT-SIM-R18-014', 'ACTIVE', 'ELECTRIC', 'SMALL_COMMERCIAL'),
    ('EA-SIM-R18-015', 'CUST-SIM-R18-015', 'ACCT-SIM-R18-015', 'ACTIVE', 'ELECTRIC', 'SMALL_COMMERCIAL'),
    ('EA-SIM-R18-016', 'CUST-SIM-R18-016', 'ACCT-SIM-R18-016', 'ACTIVE', 'ELECTRIC', 'SMALL_COMMERCIAL'),
    ('EA-SIM-R18-017', 'CUST-SIM-R18-017', 'ACCT-SIM-R18-017', 'ACTIVE', 'ELECTRIC', 'SMALL_COMMERCIAL'),
    ('EA-SIM-R18-018', 'CUST-SIM-R18-018', 'ACCT-SIM-R18-018', 'ACTIVE', 'ELECTRIC', 'SMALL_COMMERCIAL'),
    ('EA-SIM-R18-019', 'CUST-SIM-R18-019', 'ACCT-SIM-R18-019', 'ACTIVE', 'ELECTRIC', 'SMALL_COMMERCIAL'),
    ('EA-SIM-R18-020', 'CUST-SIM-R18-020', 'ACCT-SIM-R18-020', 'ACTIVE', 'ELECTRIC', 'SMALL_COMMERCIAL'),
    ('EA-SIM-R18-021', 'CUST-SIM-R18-021', 'ACCT-SIM-R18-021', 'ACTIVE', 'ELECTRIC', 'LARGE_INDUSTRIAL'),
    ('EA-SIM-R18-022', 'CUST-SIM-R18-022', 'ACCT-SIM-R18-022', 'ACTIVE', 'ELECTRIC', 'LARGE_INDUSTRIAL'),
    ('EA-SIM-R18-023', 'CUST-SIM-R18-023', 'ACCT-SIM-R18-023', 'ACTIVE', 'ELECTRIC', 'LARGE_INDUSTRIAL'),
    ('EA-SIM-R18-024', 'CUST-SIM-R18-024', 'ACCT-SIM-R18-024', 'ACTIVE', 'ELECTRIC', 'LARGE_INDUSTRIAL'),
    ('EA-SIM-R18-025', 'CUST-SIM-R18-025', 'ACCT-SIM-R18-025', 'ACTIVE', 'ELECTRIC', 'LARGE_INDUSTRIAL'),
    ('EA-SIM-R18-026', 'CUST-SIM-R18-026', 'ACCT-SIM-R18-026', 'ACTIVE', 'ELECTRIC', 'LARGE_INDUSTRIAL'),
    ('EA-SIM-R18-027', 'CUST-SIM-R18-027', 'ACCT-SIM-R18-027', 'ACTIVE', 'ELECTRIC', 'LARGE_INDUSTRIAL'),
    ('EA-SIM-R18-028', 'CUST-SIM-R18-028', 'ACCT-SIM-R18-028', 'ACTIVE', 'ELECTRIC', 'LARGE_INDUSTRIAL'),
    ('EA-SIM-R18-029', 'CUST-SIM-R18-029', 'ACCT-SIM-R18-029', 'ACTIVE', 'ELECTRIC', 'LARGE_INDUSTRIAL'),
    ('EA-SIM-R18-030', 'CUST-SIM-R18-030', 'ACCT-SIM-R18-030', 'ACTIVE', 'ELECTRIC', 'LARGE_INDUSTRIAL'),
    ('EA-SIM-R18-031', 'CUST-SIM-R18-031', 'ACCT-SIM-R18-031', 'ACTIVE', 'ELECTRIC', 'RESIDENTIAL'),
    ('EA-SIM-R18-032', 'CUST-SIM-R18-032', 'ACCT-SIM-R18-032', 'ACTIVE', 'ELECTRIC', 'RESIDENTIAL'),
    ('EA-SIM-R18-033', 'CUST-SIM-R18-033', 'ACCT-SIM-R18-033', 'ACTIVE', 'ELECTRIC', 'RESIDENTIAL'),
    ('EA-SIM-R18-034', 'CUST-SIM-R18-034', 'ACCT-SIM-R18-034', 'ACTIVE', 'ELECTRIC', 'RESIDENTIAL'),
    ('EA-SIM-R18-035', 'CUST-SIM-R18-035', 'ACCT-SIM-R18-035', 'ACTIVE', 'ELECTRIC', 'RESIDENTIAL'),
    ('EA-SIM-R18-036', 'CUST-SIM-R18-036', 'ACCT-SIM-R18-036', 'ACTIVE', 'ELECTRIC', 'RESIDENTIAL'),
    ('EA-SIM-R18-037', 'CUST-SIM-R18-037', 'ACCT-SIM-R18-037', 'ACTIVE', 'ELECTRIC', 'RESIDENTIAL'),
    ('EA-SIM-R18-038', 'CUST-SIM-R18-038', 'ACCT-SIM-R18-038', 'ACTIVE', 'ELECTRIC', 'RESIDENTIAL'),
    ('EA-SIM-R18-039', 'CUST-SIM-R18-039', 'ACCT-SIM-R18-039', 'ACTIVE', 'ELECTRIC', 'RESIDENTIAL'),
    ('EA-SIM-R18-040', 'CUST-SIM-R18-040', 'ACCT-SIM-R18-040', 'ACTIVE', 'ELECTRIC', 'RESIDENTIAL'),
    ('EA-SIM-R18-B01', 'CUST-SIM-R18-001', 'ACCT-SIM-R18-B01', 'ACTIVE', 'ELECTRIC', 'RESIDENTIAL'),
    ('EA-SIM-R18-B05', 'CUST-SIM-R18-005', 'ACCT-SIM-R18-B05', 'ACTIVE', 'ELECTRIC', 'RESIDENTIAL'),
    ('EA-SIM-R18-B14', 'CUST-SIM-R18-014', 'ACCT-SIM-R18-B14', 'ACTIVE', 'ELECTRIC', 'SMALL_COMMERCIAL'),
    ('EA-SIM-R18-B31', 'CUST-SIM-R18-031', 'ACCT-SIM-R18-B31', 'ACTIVE', 'ELECTRIC', 'RESIDENTIAL')
    AS v(col1,col2,col3,col4,col5,col6)
WHERE NOT EXISTS (SELECT 1 FROM CUSTOMER.ENERGY_ACCOUNT WHERE ENERGY_ACCOUNT_ID = v.col1);

-- ============================================================
-- 18g.  Cross-round updates — previous cohorts
-- ============================================================
UPDATE CUSTOMER.CUSTOMER
SET PREFERRED_LANGUAGE = 'ES', UPDATED_AT = CURRENT_TIMESTAMP()
WHERE CUSTOMER_ID IN (
    'CUST-SIM-R17-001','CUST-SIM-R17-002','CUST-SIM-R17-003',
    'CUST-SIM-R17-004','CUST-SIM-R17-005'
);

UPDATE CUSTOMER.CUSTOMER_CONTACT
SET IS_VERIFIED = TRUE, UPDATED_AT = CURRENT_TIMESTAMP()
WHERE CONTACT_ID IN (
    'CC-SIM-R17-021E','CC-SIM-R17-022E','CC-SIM-R17-023E',
    'CC-SIM-R17-024E','CC-SIM-R17-025E','CC-SIM-R17-026E',
    'CC-SIM-R17-027E','CC-SIM-R17-028E','CC-SIM-R17-029E',
    'CC-SIM-R17-030E'
);

UPDATE CUSTOMER.CUSTOMER_CONTACT
SET IS_VERIFIED = TRUE, UPDATED_AT = CURRENT_TIMESTAMP()
WHERE CONTACT_ID IN (
    'CC-SIM-R17-001P','CC-SIM-R17-002P','CC-SIM-R17-003P',
    'CC-SIM-R17-004P','CC-SIM-R17-005P','CC-SIM-R17-006P',
    'CC-SIM-R17-007P','CC-SIM-R17-008P','CC-SIM-R17-009P',
    'CC-SIM-R17-010P'
);

UPDATE CUSTOMER.ENERGY_ACCOUNT
SET ACCOUNT_STATUS = 'SUSPENDED', UPDATED_AT = CURRENT_TIMESTAMP()
WHERE ENERGY_ACCOUNT_ID IN ('EA-SIM-R16-005', 'EA-SIM-R16-010');

UPDATE CUSTOMER.ENERGY_ACCOUNT
SET ACCOUNT_STATUS = 'ACTIVE', UPDATED_AT = CURRENT_TIMESTAMP()
WHERE ENERGY_ACCOUNT_ID IN ('EA-SIM-R15-005', 'EA-SIM-R15-010');

-- Verification
SELECT 'R18 customers inserted'      AS label, COUNT(*) AS cnt FROM CUSTOMER.CUSTOMER       WHERE CUSTOMER_ID       LIKE 'CUST-SIM-R18-%'
UNION ALL
SELECT 'R18 energy accounts inserted',          COUNT(*)        FROM CUSTOMER.ENERGY_ACCOUNT WHERE ENERGY_ACCOUNT_ID LIKE 'EA-SIM-R18-%'
UNION ALL
SELECT 'R18 email contacts inserted',           COUNT(*)        FROM CUSTOMER.CUSTOMER_CONTACT WHERE CONTACT_ID      LIKE 'CC-SIM-R18-%'
ORDER BY 1;
