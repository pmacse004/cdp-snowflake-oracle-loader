-- =============================================================================
-- Daily Load Simulation — Round 17
-- =============================================================================
-- Run as: CDP_ADMIN_ROLE  |  Database: CDP_UTIL_DB  |  Warehouse: CDP_LOADER_WH
--
-- SCENARIO  Large customer wave — 40 customers across all types
-- REJECTION REJ-D1: blank FIRST_NAME (VR-CUST-001) x 2
--           REJ-D2: invalid email (VR-CONT-001) x 2
-- TRIGGER   POST http://localhost:8080/api/jobs/daily
-- PREREQUISITE  daily-round-16.sql must have been run.
-- CUSTOMERS  40 valid + 2 blank-name rejections
-- ACCOUNTS   44 energy accounts (incl. 4 second accounts)
-- CONTACTS   40 email + 20 phone + 2 invalid email rejections
-- =============================================================================

USE ROLE CDP_ADMIN_ROLE;
USE DATABASE CDP_UTIL_DB;
USE WAREHOUSE CDP_LOADER_WH;

-- ============================================================
-- 17a.  New customers — 40 valid rows
-- ============================================================
INSERT INTO CUSTOMER.CUSTOMER
    (CUSTOMER_ID, FIRST_NAME, LAST_NAME, ACCOUNT_STATUS, CUSTOMER_TYPE,
     PREFERRED_LANGUAGE, CREATED_AT, UPDATED_AT)
SELECT col1, col2, col3, col4, col5, col6, CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()
FROM VALUES
    ('CUST-SIM-R17-001', 'Priscilla', 'Nakamura', 'ACTIVE', 'RESIDENTIAL', 'EN'),
    ('CUST-SIM-R17-002', 'Emeka', 'Obi-Nwosu', 'ACTIVE', 'RESIDENTIAL', 'EN'),
    ('CUST-SIM-R17-003', 'Greta', 'Svensson', 'ACTIVE', 'RESIDENTIAL', 'EN'),
    ('CUST-SIM-R17-004', 'Rustam', 'Nazarov', 'ACTIVE', 'INDUSTRIAL', 'EN'),
    ('CUST-SIM-R17-005', 'Adelina', 'Gheorghiu', 'ACTIVE', 'RESIDENTIAL', 'EN'),
    ('CUST-SIM-R17-006', 'Baraka', 'Mwamba', 'ACTIVE', 'RESIDENTIAL', 'EN'),
    ('CUST-SIM-R17-007', 'Chayton', 'Eagleheart', 'ACTIVE', 'COMMERCIAL', 'EN'),
    ('CUST-SIM-R17-008', 'Divya', 'Mehta', 'ACTIVE', 'COMMERCIAL', 'EN'),
    ('CUST-SIM-R17-009', 'Emine', 'Yildirim', 'ACTIVE', 'COMMERCIAL', 'EN'),
    ('CUST-SIM-R17-010', 'Faustin', 'Kabila', 'ACTIVE', 'COMMERCIAL', 'EN'),
    ('CUST-SIM-R17-011', 'Gunnhild', 'Bergstrom', 'ACTIVE', 'COMMERCIAL', 'EN'),
    ('CUST-SIM-R17-012', 'Habibou', 'Moussa', 'ACTIVE', 'COMMERCIAL', 'FR'),
    ('CUST-SIM-R17-013', 'Iryna', 'Savchuk', 'ACTIVE', 'COMMERCIAL', 'EN'),
    ('CUST-SIM-R17-014', 'Jebediah', 'Kosz', 'ACTIVE', 'COMMERCIAL', 'EN'),
    ('CUST-SIM-R17-015', 'Kokulan', 'Ravi', 'ACTIVE', 'COMMERCIAL', 'EN'),
    ('CUST-SIM-R17-016', 'Liliana', 'Fernandez', 'ACTIVE', 'COMMERCIAL', 'EN'),
    ('CUST-SIM-R17-017', 'Modou', 'Fall', 'ACTIVE', 'COMMERCIAL', 'FR'),
    ('CUST-SIM-R17-018', 'Naira', 'Gevorgyan', 'ACTIVE', 'COMMERCIAL', 'EN'),
    ('CUST-SIM-R17-019', 'Obafemi', 'Fashola', 'ACTIVE', 'COMMERCIAL', 'EN'),
    ('CUST-SIM-R17-020', 'Ping', 'Wang', 'ACTIVE', 'COMMERCIAL', 'EN'),
    ('CUST-SIM-R17-021', 'Quirino', 'Matos', 'ACTIVE', 'INDUSTRIAL', 'EN'),
    ('CUST-SIM-R17-022', 'Rimma', 'Karimova', 'ACTIVE', 'INDUSTRIAL', 'EN'),
    ('CUST-SIM-R17-023', 'Selim', 'Ozkan', 'ACTIVE', 'INDUSTRIAL', 'EN'),
    ('CUST-SIM-R17-024', 'Takeshi', 'Ogawa', 'ACTIVE', 'INDUSTRIAL', 'EN'),
    ('CUST-SIM-R17-025', 'Udochi', 'Anigbo', 'ACTIVE', 'INDUSTRIAL', 'EN'),
    ('CUST-SIM-R17-026', 'Valentijn', 'Bakker', 'ACTIVE', 'INDUSTRIAL', 'EN'),
    ('CUST-SIM-R17-027', 'Wigstan', 'Mwangi', 'ACTIVE', 'INDUSTRIAL', 'EN'),
    ('CUST-SIM-R17-028', 'Xue', 'Li', 'ACTIVE', 'INDUSTRIAL', 'EN'),
    ('CUST-SIM-R17-029', 'Yuki', 'Oda', 'ACTIVE', 'INDUSTRIAL', 'EN'),
    ('CUST-SIM-R17-030', 'Zahra', 'Mousavi', 'ACTIVE', 'INDUSTRIAL', 'EN'),
    ('CUST-SIM-R17-031', 'Abebe', 'Tadesse', 'ACTIVE', 'RESIDENTIAL', 'EN'),
    ('CUST-SIM-R17-032', 'Bozena', 'Kaminska', 'ACTIVE', 'RESIDENTIAL', 'EN'),
    ('CUST-SIM-R17-033', 'Corazon', 'Santos', 'ACTIVE', 'RESIDENTIAL', 'EN'),
    ('CUST-SIM-R17-034', 'Dieudonne', 'Mukeba', 'ACTIVE', 'RESIDENTIAL', 'FR'),
    ('CUST-SIM-R17-035', 'Eszter', 'Kovacs', 'ACTIVE', 'RESIDENTIAL', 'EN'),
    ('CUST-SIM-R17-036', 'Faisal', 'Al-Zahrani', 'ACTIVE', 'RESIDENTIAL', 'AR'),
    ('CUST-SIM-R17-037', 'Giuliana', 'Moretti', 'ACTIVE', 'RESIDENTIAL', 'EN'),
    ('CUST-SIM-R17-038', 'Haci', 'Altuntas', 'ACTIVE', 'RESIDENTIAL', 'EN'),
    ('CUST-SIM-R17-039', 'Ingvild', 'Haugen', 'ACTIVE', 'RESIDENTIAL', 'EN'),
    ('CUST-SIM-R17-040', 'Jumoke', 'Adeyemi-Bello', 'ACTIVE', 'RESIDENTIAL', 'EN')
    AS v(col1,col2,col3,col4,col5,col6)
WHERE NOT EXISTS (SELECT 1 FROM CUSTOMER.CUSTOMER WHERE CUSTOMER_ID = v.col1);

-- ============================================================
-- 17b.  Rejections: blank FIRST_NAME
-- ============================================================
INSERT INTO CUSTOMER.CUSTOMER
    (CUSTOMER_ID, FIRST_NAME, LAST_NAME, ACCOUNT_STATUS, CUSTOMER_TYPE,
     PREFERRED_LANGUAGE, CREATED_AT, UPDATED_AT)
SELECT col1, col2, col3, col4, col5, col6, CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()
FROM VALUES
    ('CUST-SIM-R17-RJ1', '', 'NoFirstA',  'ACTIVE', 'RESIDENTIAL', 'EN'),
    ('CUST-SIM-R17-RJ2', '', 'NoFirstB',  'ACTIVE', 'COMMERCIAL',  'EN')
    AS v(col1,col2,col3,col4,col5,col6)
WHERE NOT EXISTS (SELECT 1 FROM CUSTOMER.CUSTOMER WHERE CUSTOMER_ID = v.col1);

-- ============================================================
-- 17c.  Primary email contacts — all 40 valid customers
-- ============================================================
INSERT INTO CUSTOMER.CUSTOMER_CONTACT
    (CONTACT_ID, CUSTOMER_ID, CONTACT_TYPE, CONTACT_VALUE,
     IS_PRIMARY, IS_VERIFIED, EFFECTIVE_DATE, CREATED_AT, UPDATED_AT)
SELECT col1, col2, col3, col4, TRUE, TRUE, CURRENT_DATE(), CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()
FROM VALUES
    ('CC-SIM-R17-001E', 'CUST-SIM-R17-001', 'EMAIL', 'priscilla.nakamura@demo.com'),
    ('CC-SIM-R17-002E', 'CUST-SIM-R17-002', 'EMAIL', 'emeka.obi-nwosu@demo.com'),
    ('CC-SIM-R17-003E', 'CUST-SIM-R17-003', 'EMAIL', 'greta.svensson@demo.com'),
    ('CC-SIM-R17-004E', 'CUST-SIM-R17-004', 'EMAIL', 'rustam.nazarov@demo.com'),
    ('CC-SIM-R17-005E', 'CUST-SIM-R17-005', 'EMAIL', 'adelina.gheorghiu@demo.com'),
    ('CC-SIM-R17-006E', 'CUST-SIM-R17-006', 'EMAIL', 'baraka.mwamba@demo.com'),
    ('CC-SIM-R17-007E', 'CUST-SIM-R17-007', 'EMAIL', 'chayton.eagleheart@demo.com'),
    ('CC-SIM-R17-008E', 'CUST-SIM-R17-008', 'EMAIL', 'divya.mehta@demo.com'),
    ('CC-SIM-R17-009E', 'CUST-SIM-R17-009', 'EMAIL', 'emine.yildirim@demo.com'),
    ('CC-SIM-R17-010E', 'CUST-SIM-R17-010', 'EMAIL', 'faustin.kabila@demo.com'),
    ('CC-SIM-R17-011E', 'CUST-SIM-R17-011', 'EMAIL', 'gunnhild.bergstrom@demo.com'),
    ('CC-SIM-R17-012E', 'CUST-SIM-R17-012', 'EMAIL', 'habibou.moussa@demo.com'),
    ('CC-SIM-R17-013E', 'CUST-SIM-R17-013', 'EMAIL', 'iryna.savchuk@demo.com'),
    ('CC-SIM-R17-014E', 'CUST-SIM-R17-014', 'EMAIL', 'jebediah.kosz@demo.com'),
    ('CC-SIM-R17-015E', 'CUST-SIM-R17-015', 'EMAIL', 'kokulan.ravi@demo.com'),
    ('CC-SIM-R17-016E', 'CUST-SIM-R17-016', 'EMAIL', 'liliana.fernandez@demo.com'),
    ('CC-SIM-R17-017E', 'CUST-SIM-R17-017', 'EMAIL', 'modou.fall@demo.com'),
    ('CC-SIM-R17-018E', 'CUST-SIM-R17-018', 'EMAIL', 'naira.gevorgyan@demo.com'),
    ('CC-SIM-R17-019E', 'CUST-SIM-R17-019', 'EMAIL', 'obafemi.fashola@demo.com'),
    ('CC-SIM-R17-020E', 'CUST-SIM-R17-020', 'EMAIL', 'ping.wang@demo.com'),
    ('CC-SIM-R17-021E', 'CUST-SIM-R17-021', 'EMAIL', 'quirino.matos@demo.com'),
    ('CC-SIM-R17-022E', 'CUST-SIM-R17-022', 'EMAIL', 'rimma.karimova@demo.com'),
    ('CC-SIM-R17-023E', 'CUST-SIM-R17-023', 'EMAIL', 'selim.ozkan@demo.com'),
    ('CC-SIM-R17-024E', 'CUST-SIM-R17-024', 'EMAIL', 'takeshi.ogawa@demo.com'),
    ('CC-SIM-R17-025E', 'CUST-SIM-R17-025', 'EMAIL', 'udochi.anigbo@demo.com'),
    ('CC-SIM-R17-026E', 'CUST-SIM-R17-026', 'EMAIL', 'valentijn.bakker@demo.com'),
    ('CC-SIM-R17-027E', 'CUST-SIM-R17-027', 'EMAIL', 'wigstan.mwangi@demo.com'),
    ('CC-SIM-R17-028E', 'CUST-SIM-R17-028', 'EMAIL', 'xue.li@demo.com'),
    ('CC-SIM-R17-029E', 'CUST-SIM-R17-029', 'EMAIL', 'yuki.oda@demo.com'),
    ('CC-SIM-R17-030E', 'CUST-SIM-R17-030', 'EMAIL', 'zahra.mousavi@demo.com'),
    ('CC-SIM-R17-031E', 'CUST-SIM-R17-031', 'EMAIL', 'abebe.tadesse@demo.com'),
    ('CC-SIM-R17-032E', 'CUST-SIM-R17-032', 'EMAIL', 'bozena.kaminska@demo.com'),
    ('CC-SIM-R17-033E', 'CUST-SIM-R17-033', 'EMAIL', 'corazon.santos@demo.com'),
    ('CC-SIM-R17-034E', 'CUST-SIM-R17-034', 'EMAIL', 'dieudonne.mukeba@demo.com'),
    ('CC-SIM-R17-035E', 'CUST-SIM-R17-035', 'EMAIL', 'eszter.kovacs@demo.com'),
    ('CC-SIM-R17-036E', 'CUST-SIM-R17-036', 'EMAIL', 'faisal.al-zahrani@demo.com'),
    ('CC-SIM-R17-037E', 'CUST-SIM-R17-037', 'EMAIL', 'giuliana.moretti@demo.com'),
    ('CC-SIM-R17-038E', 'CUST-SIM-R17-038', 'EMAIL', 'haci.altuntas@demo.com'),
    ('CC-SIM-R17-039E', 'CUST-SIM-R17-039', 'EMAIL', 'ingvild.haugen@demo.com'),
    ('CC-SIM-R17-040E', 'CUST-SIM-R17-040', 'EMAIL', 'jumoke.adeyemi-bello@demo.com')
    AS v(col1,col2,col3,col4)
WHERE NOT EXISTS (SELECT 1 FROM CUSTOMER.CUSTOMER_CONTACT WHERE CONTACT_ID = v.col1);

-- ============================================================
-- 17d.  Phone contacts — first 20 customers
-- ============================================================
INSERT INTO CUSTOMER.CUSTOMER_CONTACT
    (CONTACT_ID, CUSTOMER_ID, CONTACT_TYPE, CONTACT_VALUE,
     IS_PRIMARY, IS_VERIFIED, EFFECTIVE_DATE, CREATED_AT, UPDATED_AT)
SELECT col1, col2, col3, col4, TRUE, FALSE, CURRENT_DATE(), CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()
FROM VALUES
    ('CC-SIM-R17-001P', 'CUST-SIM-R17-001', 'PHONE', '555-1701'),
    ('CC-SIM-R17-002P', 'CUST-SIM-R17-002', 'PHONE', '555-1702'),
    ('CC-SIM-R17-003P', 'CUST-SIM-R17-003', 'PHONE', '555-1703'),
    ('CC-SIM-R17-004P', 'CUST-SIM-R17-004', 'PHONE', '555-1704'),
    ('CC-SIM-R17-005P', 'CUST-SIM-R17-005', 'PHONE', '555-1705'),
    ('CC-SIM-R17-006P', 'CUST-SIM-R17-006', 'PHONE', '555-1706'),
    ('CC-SIM-R17-007P', 'CUST-SIM-R17-007', 'PHONE', '555-1707'),
    ('CC-SIM-R17-008P', 'CUST-SIM-R17-008', 'PHONE', '555-1708'),
    ('CC-SIM-R17-009P', 'CUST-SIM-R17-009', 'PHONE', '555-1709'),
    ('CC-SIM-R17-010P', 'CUST-SIM-R17-010', 'PHONE', '555-1710'),
    ('CC-SIM-R17-011P', 'CUST-SIM-R17-011', 'PHONE', '555-1711'),
    ('CC-SIM-R17-012P', 'CUST-SIM-R17-012', 'PHONE', '555-1712'),
    ('CC-SIM-R17-013P', 'CUST-SIM-R17-013', 'PHONE', '555-1713'),
    ('CC-SIM-R17-014P', 'CUST-SIM-R17-014', 'PHONE', '555-1714'),
    ('CC-SIM-R17-015P', 'CUST-SIM-R17-015', 'PHONE', '555-1715'),
    ('CC-SIM-R17-016P', 'CUST-SIM-R17-016', 'PHONE', '555-1716'),
    ('CC-SIM-R17-017P', 'CUST-SIM-R17-017', 'PHONE', '555-1717'),
    ('CC-SIM-R17-018P', 'CUST-SIM-R17-018', 'PHONE', '555-1718'),
    ('CC-SIM-R17-019P', 'CUST-SIM-R17-019', 'PHONE', '555-1719'),
    ('CC-SIM-R17-020P', 'CUST-SIM-R17-020', 'PHONE', '555-1720')
    AS v(col1,col2,col3,col4)
WHERE NOT EXISTS (SELECT 1 FROM CUSTOMER.CUSTOMER_CONTACT WHERE CONTACT_ID = v.col1);

-- ============================================================
-- 17e.  Rejections: invalid email (no @)
-- ============================================================
INSERT INTO CUSTOMER.CUSTOMER_CONTACT
    (CONTACT_ID, CUSTOMER_ID, CONTACT_TYPE, CONTACT_VALUE,
     IS_PRIMARY, IS_VERIFIED, EFFECTIVE_DATE, CREATED_AT, UPDATED_AT)
SELECT col1, col2, col3, col4, TRUE, FALSE, CURRENT_DATE(), CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()
FROM VALUES
    ('CC-SIM-R17-RJE1', 'CUST-SIM-R17-001', 'EMAIL', 'invalid.email.nodomain'),
    ('CC-SIM-R17-RJE2', 'CUST-SIM-R17-002', 'EMAIL', 'also-not-valid-email')
    AS v(col1,col2,col3,col4)
WHERE NOT EXISTS (SELECT 1 FROM CUSTOMER.CUSTOMER_CONTACT WHERE CONTACT_ID = v.col1);

-- ============================================================
-- 17f.  Energy accounts — 40 primary + 4 second accounts
-- ============================================================
INSERT INTO CUSTOMER.ENERGY_ACCOUNT
    (ENERGY_ACCOUNT_ID, CUSTOMER_ID, ACCOUNT_NUMBER, ACCOUNT_STATUS,
     SERVICE_TYPE, RATE_CLASS, OPEN_DATE, CREATED_AT, UPDATED_AT)
SELECT col1, col2, col3, col4, col5, col6, CURRENT_DATE(), CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()
FROM VALUES
    ('EA-SIM-R17-001', 'CUST-SIM-R17-001', 'ACCT-SIM-R17-001', 'ACTIVE', 'ELECTRIC', 'RESIDENTIAL'),
    ('EA-SIM-R17-002', 'CUST-SIM-R17-002', 'ACCT-SIM-R17-002', 'ACTIVE', 'ELECTRIC', 'RESIDENTIAL'),
    ('EA-SIM-R17-003', 'CUST-SIM-R17-003', 'ACCT-SIM-R17-003', 'ACTIVE', 'ELECTRIC', 'RESIDENTIAL'),
    ('EA-SIM-R17-004', 'CUST-SIM-R17-004', 'ACCT-SIM-R17-004', 'ACTIVE', 'ELECTRIC', 'LARGE_INDUSTRIAL'),
    ('EA-SIM-R17-005', 'CUST-SIM-R17-005', 'ACCT-SIM-R17-005', 'ACTIVE', 'ELECTRIC', 'RESIDENTIAL'),
    ('EA-SIM-R17-006', 'CUST-SIM-R17-006', 'ACCT-SIM-R17-006', 'ACTIVE', 'ELECTRIC', 'RESIDENTIAL'),
    ('EA-SIM-R17-007', 'CUST-SIM-R17-007', 'ACCT-SIM-R17-007', 'ACTIVE', 'ELECTRIC', 'SMALL_COMMERCIAL'),
    ('EA-SIM-R17-008', 'CUST-SIM-R17-008', 'ACCT-SIM-R17-008', 'ACTIVE', 'ELECTRIC', 'SMALL_COMMERCIAL'),
    ('EA-SIM-R17-009', 'CUST-SIM-R17-009', 'ACCT-SIM-R17-009', 'ACTIVE', 'ELECTRIC', 'SMALL_COMMERCIAL'),
    ('EA-SIM-R17-010', 'CUST-SIM-R17-010', 'ACCT-SIM-R17-010', 'ACTIVE', 'ELECTRIC', 'SMALL_COMMERCIAL'),
    ('EA-SIM-R17-011', 'CUST-SIM-R17-011', 'ACCT-SIM-R17-011', 'ACTIVE', 'ELECTRIC', 'SMALL_COMMERCIAL'),
    ('EA-SIM-R17-012', 'CUST-SIM-R17-012', 'ACCT-SIM-R17-012', 'ACTIVE', 'ELECTRIC', 'SMALL_COMMERCIAL'),
    ('EA-SIM-R17-013', 'CUST-SIM-R17-013', 'ACCT-SIM-R17-013', 'ACTIVE', 'ELECTRIC', 'SMALL_COMMERCIAL'),
    ('EA-SIM-R17-014', 'CUST-SIM-R17-014', 'ACCT-SIM-R17-014', 'ACTIVE', 'ELECTRIC', 'SMALL_COMMERCIAL'),
    ('EA-SIM-R17-015', 'CUST-SIM-R17-015', 'ACCT-SIM-R17-015', 'ACTIVE', 'ELECTRIC', 'SMALL_COMMERCIAL'),
    ('EA-SIM-R17-016', 'CUST-SIM-R17-016', 'ACCT-SIM-R17-016', 'ACTIVE', 'ELECTRIC', 'SMALL_COMMERCIAL'),
    ('EA-SIM-R17-017', 'CUST-SIM-R17-017', 'ACCT-SIM-R17-017', 'ACTIVE', 'ELECTRIC', 'SMALL_COMMERCIAL'),
    ('EA-SIM-R17-018', 'CUST-SIM-R17-018', 'ACCT-SIM-R17-018', 'ACTIVE', 'ELECTRIC', 'SMALL_COMMERCIAL'),
    ('EA-SIM-R17-019', 'CUST-SIM-R17-019', 'ACCT-SIM-R17-019', 'ACTIVE', 'ELECTRIC', 'SMALL_COMMERCIAL'),
    ('EA-SIM-R17-020', 'CUST-SIM-R17-020', 'ACCT-SIM-R17-020', 'ACTIVE', 'ELECTRIC', 'SMALL_COMMERCIAL'),
    ('EA-SIM-R17-021', 'CUST-SIM-R17-021', 'ACCT-SIM-R17-021', 'ACTIVE', 'ELECTRIC', 'LARGE_INDUSTRIAL'),
    ('EA-SIM-R17-022', 'CUST-SIM-R17-022', 'ACCT-SIM-R17-022', 'ACTIVE', 'ELECTRIC', 'LARGE_INDUSTRIAL'),
    ('EA-SIM-R17-023', 'CUST-SIM-R17-023', 'ACCT-SIM-R17-023', 'ACTIVE', 'ELECTRIC', 'LARGE_INDUSTRIAL'),
    ('EA-SIM-R17-024', 'CUST-SIM-R17-024', 'ACCT-SIM-R17-024', 'ACTIVE', 'ELECTRIC', 'LARGE_INDUSTRIAL'),
    ('EA-SIM-R17-025', 'CUST-SIM-R17-025', 'ACCT-SIM-R17-025', 'ACTIVE', 'ELECTRIC', 'LARGE_INDUSTRIAL'),
    ('EA-SIM-R17-026', 'CUST-SIM-R17-026', 'ACCT-SIM-R17-026', 'ACTIVE', 'ELECTRIC', 'LARGE_INDUSTRIAL'),
    ('EA-SIM-R17-027', 'CUST-SIM-R17-027', 'ACCT-SIM-R17-027', 'ACTIVE', 'ELECTRIC', 'LARGE_INDUSTRIAL'),
    ('EA-SIM-R17-028', 'CUST-SIM-R17-028', 'ACCT-SIM-R17-028', 'ACTIVE', 'ELECTRIC', 'LARGE_INDUSTRIAL'),
    ('EA-SIM-R17-029', 'CUST-SIM-R17-029', 'ACCT-SIM-R17-029', 'ACTIVE', 'ELECTRIC', 'LARGE_INDUSTRIAL'),
    ('EA-SIM-R17-030', 'CUST-SIM-R17-030', 'ACCT-SIM-R17-030', 'ACTIVE', 'ELECTRIC', 'LARGE_INDUSTRIAL'),
    ('EA-SIM-R17-031', 'CUST-SIM-R17-031', 'ACCT-SIM-R17-031', 'ACTIVE', 'ELECTRIC', 'RESIDENTIAL'),
    ('EA-SIM-R17-032', 'CUST-SIM-R17-032', 'ACCT-SIM-R17-032', 'ACTIVE', 'ELECTRIC', 'RESIDENTIAL'),
    ('EA-SIM-R17-033', 'CUST-SIM-R17-033', 'ACCT-SIM-R17-033', 'ACTIVE', 'ELECTRIC', 'RESIDENTIAL'),
    ('EA-SIM-R17-034', 'CUST-SIM-R17-034', 'ACCT-SIM-R17-034', 'ACTIVE', 'ELECTRIC', 'RESIDENTIAL'),
    ('EA-SIM-R17-035', 'CUST-SIM-R17-035', 'ACCT-SIM-R17-035', 'ACTIVE', 'ELECTRIC', 'RESIDENTIAL'),
    ('EA-SIM-R17-036', 'CUST-SIM-R17-036', 'ACCT-SIM-R17-036', 'ACTIVE', 'ELECTRIC', 'RESIDENTIAL'),
    ('EA-SIM-R17-037', 'CUST-SIM-R17-037', 'ACCT-SIM-R17-037', 'ACTIVE', 'ELECTRIC', 'RESIDENTIAL'),
    ('EA-SIM-R17-038', 'CUST-SIM-R17-038', 'ACCT-SIM-R17-038', 'ACTIVE', 'ELECTRIC', 'RESIDENTIAL'),
    ('EA-SIM-R17-039', 'CUST-SIM-R17-039', 'ACCT-SIM-R17-039', 'ACTIVE', 'ELECTRIC', 'RESIDENTIAL'),
    ('EA-SIM-R17-040', 'CUST-SIM-R17-040', 'ACCT-SIM-R17-040', 'ACTIVE', 'ELECTRIC', 'RESIDENTIAL'),
    ('EA-SIM-R17-B01', 'CUST-SIM-R17-001', 'ACCT-SIM-R17-B01', 'ACTIVE', 'ELECTRIC', 'RESIDENTIAL'),
    ('EA-SIM-R17-B05', 'CUST-SIM-R17-005', 'ACCT-SIM-R17-B05', 'ACTIVE', 'ELECTRIC', 'RESIDENTIAL'),
    ('EA-SIM-R17-B14', 'CUST-SIM-R17-014', 'ACCT-SIM-R17-B14', 'ACTIVE', 'ELECTRIC', 'SMALL_COMMERCIAL'),
    ('EA-SIM-R17-B31', 'CUST-SIM-R17-031', 'ACCT-SIM-R17-B31', 'ACTIVE', 'ELECTRIC', 'RESIDENTIAL')
    AS v(col1,col2,col3,col4,col5,col6)
WHERE NOT EXISTS (SELECT 1 FROM CUSTOMER.ENERGY_ACCOUNT WHERE ENERGY_ACCOUNT_ID = v.col1);

-- ============================================================
-- 17g.  Cross-round updates — previous cohorts
-- ============================================================
UPDATE CUSTOMER.CUSTOMER
SET PREFERRED_LANGUAGE = 'ES', UPDATED_AT = CURRENT_TIMESTAMP()
WHERE CUSTOMER_ID IN (
    'CUST-SIM-R16-001','CUST-SIM-R16-002','CUST-SIM-R16-003',
    'CUST-SIM-R16-004','CUST-SIM-R16-005'
);

UPDATE CUSTOMER.CUSTOMER_CONTACT
SET IS_VERIFIED = TRUE, UPDATED_AT = CURRENT_TIMESTAMP()
WHERE CONTACT_ID IN (
    'CC-SIM-R16-021E','CC-SIM-R16-022E','CC-SIM-R16-023E',
    'CC-SIM-R16-024E','CC-SIM-R16-025E','CC-SIM-R16-026E',
    'CC-SIM-R16-027E','CC-SIM-R16-028E','CC-SIM-R16-029E',
    'CC-SIM-R16-030E'
);

UPDATE CUSTOMER.CUSTOMER_CONTACT
SET IS_VERIFIED = TRUE, UPDATED_AT = CURRENT_TIMESTAMP()
WHERE CONTACT_ID IN (
    'CC-SIM-R16-001P','CC-SIM-R16-002P','CC-SIM-R16-003P',
    'CC-SIM-R16-004P','CC-SIM-R16-005P','CC-SIM-R16-006P',
    'CC-SIM-R16-007P','CC-SIM-R16-008P','CC-SIM-R16-009P',
    'CC-SIM-R16-010P'
);

UPDATE CUSTOMER.ENERGY_ACCOUNT
SET ACCOUNT_STATUS = 'SUSPENDED', UPDATED_AT = CURRENT_TIMESTAMP()
WHERE ENERGY_ACCOUNT_ID IN ('EA-SIM-R15-005', 'EA-SIM-R15-010');

UPDATE CUSTOMER.ENERGY_ACCOUNT
SET ACCOUNT_STATUS = 'ACTIVE', UPDATED_AT = CURRENT_TIMESTAMP()
WHERE ENERGY_ACCOUNT_ID IN ('EA-SIM-R14-005', 'EA-SIM-R14-010');

-- Verification
SELECT 'R17 customers inserted'      AS label, COUNT(*) AS cnt FROM CUSTOMER.CUSTOMER       WHERE CUSTOMER_ID       LIKE 'CUST-SIM-R17-%'
UNION ALL
SELECT 'R17 energy accounts inserted',          COUNT(*)        FROM CUSTOMER.ENERGY_ACCOUNT WHERE ENERGY_ACCOUNT_ID LIKE 'EA-SIM-R17-%'
UNION ALL
SELECT 'R17 email contacts inserted',           COUNT(*)        FROM CUSTOMER.CUSTOMER_CONTACT WHERE CONTACT_ID      LIKE 'CC-SIM-R17-%'
ORDER BY 1;
