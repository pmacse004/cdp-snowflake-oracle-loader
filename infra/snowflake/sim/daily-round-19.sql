-- =============================================================================
-- Daily Load Simulation — Round 19
-- =============================================================================
-- Run as: CDP_ADMIN_ROLE  |  Database: CDP_UTIL_DB  |  Warehouse: CDP_LOADER_WH
--
-- SCENARIO  Large customer wave — 40 customers across all types
-- REJECTION REJ-D1: blank FIRST_NAME (VR-CUST-001) x 2
--           REJ-D2: invalid email (VR-CONT-001) x 2
-- TRIGGER   POST http://localhost:8080/api/jobs/daily
-- PREREQUISITE  daily-round-18.sql must have been run.
-- CUSTOMERS  40 valid + 2 blank-name rejections
-- ACCOUNTS   44 energy accounts (incl. 4 second accounts)
-- CONTACTS   40 email + 20 phone + 2 invalid email rejections
-- =============================================================================

USE ROLE CDP_ADMIN_ROLE;
USE DATABASE CDP_UTIL_DB;
USE WAREHOUSE CDP_LOADER_WH;

-- ============================================================
-- 19a.  New customers — 40 valid rows
-- ============================================================
INSERT INTO CUSTOMER.CUSTOMER
    (CUSTOMER_ID, FIRST_NAME, LAST_NAME, ACCOUNT_STATUS, CUSTOMER_TYPE,
     PREFERRED_LANGUAGE, CREATED_AT, UPDATED_AT)
SELECT col1, col2, col3, col4, col5, col6, CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()
FROM VALUES
    ('CUST-SIM-R19-001', 'Sabrina', 'Fontaine', 'ACTIVE', 'RESIDENTIAL', 'FR'),
    ('CUST-SIM-R19-002', 'Oluwaseun', 'Adebayo', 'ACTIVE', 'RESIDENTIAL', 'EN'),
    ('CUST-SIM-R19-003', 'Henrik', 'Magnusson', 'ACTIVE', 'RESIDENTIAL', 'EN'),
    ('CUST-SIM-R19-004', 'Zhen', 'Liu', 'ACTIVE', 'COMMERCIAL', 'EN'),
    ('CUST-SIM-R19-005', 'Abimbola', 'Oyelaran', 'ACTIVE', 'RESIDENTIAL', 'EN'),
    ('CUST-SIM-R19-006', 'Bodil', 'Kjaergaard', 'ACTIVE', 'RESIDENTIAL', 'EN'),
    ('CUST-SIM-R19-007', 'Cisse', 'Ouedraogo', 'ACTIVE', 'COMMERCIAL', 'FR'),
    ('CUST-SIM-R19-008', 'Dang', 'Nguyen', 'ACTIVE', 'COMMERCIAL', 'EN'),
    ('CUST-SIM-R19-009', 'Efua', 'Asiedu', 'ACTIVE', 'COMMERCIAL', 'EN'),
    ('CUST-SIM-R19-010', 'Fernand', 'Lefebvre', 'ACTIVE', 'COMMERCIAL', 'FR'),
    ('CUST-SIM-R19-011', 'Gudmundur', 'Sigurdsson', 'ACTIVE', 'COMMERCIAL', 'EN'),
    ('CUST-SIM-R19-012', 'Hadil', 'Al-Khatib', 'ACTIVE', 'COMMERCIAL', 'AR'),
    ('CUST-SIM-R19-013', 'Ikaika', 'Lono', 'ACTIVE', 'COMMERCIAL', 'EN'),
    ('CUST-SIM-R19-014', 'Jadwiga', 'Krawczyk', 'ACTIVE', 'COMMERCIAL', 'EN'),
    ('CUST-SIM-R19-015', 'Kenji', 'Kobayashi', 'ACTIVE', 'COMMERCIAL', 'EN'),
    ('CUST-SIM-R19-016', 'Linh', 'Vo', 'ACTIVE', 'COMMERCIAL', 'EN'),
    ('CUST-SIM-R19-017', 'Mouhamadou', 'Thiam', 'ACTIVE', 'COMMERCIAL', 'FR'),
    ('CUST-SIM-R19-018', 'Nkechi', 'Chukwu', 'ACTIVE', 'COMMERCIAL', 'EN'),
    ('CUST-SIM-R19-019', 'Obinna', 'Anyanwu', 'ACTIVE', 'COMMERCIAL', 'EN'),
    ('CUST-SIM-R19-020', 'Piotr', 'Lewandowski', 'ACTIVE', 'COMMERCIAL', 'EN'),
    ('CUST-SIM-R19-021', 'Qudsiya', 'Rizwan', 'ACTIVE', 'INDUSTRIAL', 'EN'),
    ('CUST-SIM-R19-022', 'Ragnheidur', 'Sigurdardottir', 'ACTIVE', 'INDUSTRIAL', 'EN'),
    ('CUST-SIM-R19-023', 'Sirine', 'Benali', 'ACTIVE', 'INDUSTRIAL', 'FR'),
    ('CUST-SIM-R19-024', 'Tomohiro', 'Nakata', 'ACTIVE', 'INDUSTRIAL', 'EN'),
    ('CUST-SIM-R19-025', 'Uche', 'Nwosu', 'ACTIVE', 'INDUSTRIAL', 'EN'),
    ('CUST-SIM-R19-026', 'Vigdis', 'Kristjansdottir', 'ACTIVE', 'INDUSTRIAL', 'EN'),
    ('CUST-SIM-R19-027', 'Wycliffe', 'Odhiambo', 'ACTIVE', 'INDUSTRIAL', 'EN'),
    ('CUST-SIM-R19-028', 'Xiulan', 'Wu', 'ACTIVE', 'INDUSTRIAL', 'EN'),
    ('CUST-SIM-R19-029', 'Yosef', 'Goldenberg', 'ACTIVE', 'INDUSTRIAL', 'EN'),
    ('CUST-SIM-R19-030', 'Zahraa', 'Al-Hakim', 'ACTIVE', 'INDUSTRIAL', 'AR'),
    ('CUST-SIM-R19-031', 'Andile', 'Mthembu', 'ACTIVE', 'RESIDENTIAL', 'EN'),
    ('CUST-SIM-R19-032', 'Bohdan', 'Kovalenko', 'ACTIVE', 'RESIDENTIAL', 'EN'),
    ('CUST-SIM-R19-033', 'Chahat', 'Sharma', 'ACTIVE', 'RESIDENTIAL', 'EN'),
    ('CUST-SIM-R19-034', 'Dawoud', 'Ibrahim', 'ACTIVE', 'RESIDENTIAL', 'AR'),
    ('CUST-SIM-R19-035', 'Evita', 'Palacio', 'ACTIVE', 'RESIDENTIAL', 'EN'),
    ('CUST-SIM-R19-036', 'Funmilayo', 'Okonkwo', 'ACTIVE', 'RESIDENTIAL', 'EN'),
    ('CUST-SIM-R19-037', 'Gabor', 'Toth', 'ACTIVE', 'RESIDENTIAL', 'EN'),
    ('CUST-SIM-R19-038', 'Haneen', 'Khouri', 'ACTIVE', 'RESIDENTIAL', 'AR'),
    ('CUST-SIM-R19-039', 'Indira', 'Chakrabarti', 'ACTIVE', 'RESIDENTIAL', 'EN'),
    ('CUST-SIM-R19-040', 'Jordi', 'Puigdomenech', 'ACTIVE', 'RESIDENTIAL', 'EN')
    AS v(col1,col2,col3,col4,col5,col6)
WHERE NOT EXISTS (SELECT 1 FROM CUSTOMER.CUSTOMER WHERE CUSTOMER_ID = v.col1);

-- ============================================================
-- 19b.  Rejections: blank FIRST_NAME
-- ============================================================
INSERT INTO CUSTOMER.CUSTOMER
    (CUSTOMER_ID, FIRST_NAME, LAST_NAME, ACCOUNT_STATUS, CUSTOMER_TYPE,
     PREFERRED_LANGUAGE, CREATED_AT, UPDATED_AT)
SELECT col1, col2, col3, col4, col5, col6, CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()
FROM VALUES
    ('CUST-SIM-R19-RJ1', '', 'NoFirstA',  'ACTIVE', 'RESIDENTIAL', 'EN'),
    ('CUST-SIM-R19-RJ2', '', 'NoFirstB',  'ACTIVE', 'COMMERCIAL',  'EN')
    AS v(col1,col2,col3,col4,col5,col6)
WHERE NOT EXISTS (SELECT 1 FROM CUSTOMER.CUSTOMER WHERE CUSTOMER_ID = v.col1);

-- ============================================================
-- 19c.  Primary email contacts — all 40 valid customers
-- ============================================================
INSERT INTO CUSTOMER.CUSTOMER_CONTACT
    (CONTACT_ID, CUSTOMER_ID, CONTACT_TYPE, CONTACT_VALUE,
     IS_PRIMARY, IS_VERIFIED, EFFECTIVE_DATE, CREATED_AT, UPDATED_AT)
SELECT col1, col2, col3, col4, TRUE, TRUE, CURRENT_DATE(), CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()
FROM VALUES
    ('CC-SIM-R19-001E', 'CUST-SIM-R19-001', 'EMAIL', 'sabrina.fontaine@demo.com'),
    ('CC-SIM-R19-002E', 'CUST-SIM-R19-002', 'EMAIL', 'oluwaseun.adebayo@demo.com'),
    ('CC-SIM-R19-003E', 'CUST-SIM-R19-003', 'EMAIL', 'henrik.magnusson@demo.com'),
    ('CC-SIM-R19-004E', 'CUST-SIM-R19-004', 'EMAIL', 'zhen.liu@demo.com'),
    ('CC-SIM-R19-005E', 'CUST-SIM-R19-005', 'EMAIL', 'abimbola.oyelaran@demo.com'),
    ('CC-SIM-R19-006E', 'CUST-SIM-R19-006', 'EMAIL', 'bodil.kjaergaard@demo.com'),
    ('CC-SIM-R19-007E', 'CUST-SIM-R19-007', 'EMAIL', 'cisse.ouedraogo@demo.com'),
    ('CC-SIM-R19-008E', 'CUST-SIM-R19-008', 'EMAIL', 'dang.nguyen@demo.com'),
    ('CC-SIM-R19-009E', 'CUST-SIM-R19-009', 'EMAIL', 'efua.asiedu@demo.com'),
    ('CC-SIM-R19-010E', 'CUST-SIM-R19-010', 'EMAIL', 'fernand.lefebvre@demo.com'),
    ('CC-SIM-R19-011E', 'CUST-SIM-R19-011', 'EMAIL', 'gudmundur.sigurdsson@demo.com'),
    ('CC-SIM-R19-012E', 'CUST-SIM-R19-012', 'EMAIL', 'hadil.al-khatib@demo.com'),
    ('CC-SIM-R19-013E', 'CUST-SIM-R19-013', 'EMAIL', 'ikaika.lono@demo.com'),
    ('CC-SIM-R19-014E', 'CUST-SIM-R19-014', 'EMAIL', 'jadwiga.krawczyk@demo.com'),
    ('CC-SIM-R19-015E', 'CUST-SIM-R19-015', 'EMAIL', 'kenji.kobayashi@demo.com'),
    ('CC-SIM-R19-016E', 'CUST-SIM-R19-016', 'EMAIL', 'linh.vo@demo.com'),
    ('CC-SIM-R19-017E', 'CUST-SIM-R19-017', 'EMAIL', 'mouhamadou.thiam@demo.com'),
    ('CC-SIM-R19-018E', 'CUST-SIM-R19-018', 'EMAIL', 'nkechi.chukwu@demo.com'),
    ('CC-SIM-R19-019E', 'CUST-SIM-R19-019', 'EMAIL', 'obinna.anyanwu@demo.com'),
    ('CC-SIM-R19-020E', 'CUST-SIM-R19-020', 'EMAIL', 'piotr.lewandowski@demo.com'),
    ('CC-SIM-R19-021E', 'CUST-SIM-R19-021', 'EMAIL', 'qudsiya.rizwan@demo.com'),
    ('CC-SIM-R19-022E', 'CUST-SIM-R19-022', 'EMAIL', 'ragnheidur.sigurdardottir@demo.com'),
    ('CC-SIM-R19-023E', 'CUST-SIM-R19-023', 'EMAIL', 'sirine.benali@demo.com'),
    ('CC-SIM-R19-024E', 'CUST-SIM-R19-024', 'EMAIL', 'tomohiro.nakata@demo.com'),
    ('CC-SIM-R19-025E', 'CUST-SIM-R19-025', 'EMAIL', 'uche.nwosu@demo.com'),
    ('CC-SIM-R19-026E', 'CUST-SIM-R19-026', 'EMAIL', 'vigdis.kristjansdottir@demo.com'),
    ('CC-SIM-R19-027E', 'CUST-SIM-R19-027', 'EMAIL', 'wycliffe.odhiambo@demo.com'),
    ('CC-SIM-R19-028E', 'CUST-SIM-R19-028', 'EMAIL', 'xiulan.wu@demo.com'),
    ('CC-SIM-R19-029E', 'CUST-SIM-R19-029', 'EMAIL', 'yosef.goldenberg@demo.com'),
    ('CC-SIM-R19-030E', 'CUST-SIM-R19-030', 'EMAIL', 'zahraa.al-hakim@demo.com'),
    ('CC-SIM-R19-031E', 'CUST-SIM-R19-031', 'EMAIL', 'andile.mthembu@demo.com'),
    ('CC-SIM-R19-032E', 'CUST-SIM-R19-032', 'EMAIL', 'bohdan.kovalenko@demo.com'),
    ('CC-SIM-R19-033E', 'CUST-SIM-R19-033', 'EMAIL', 'chahat.sharma@demo.com'),
    ('CC-SIM-R19-034E', 'CUST-SIM-R19-034', 'EMAIL', 'dawoud.ibrahim@demo.com'),
    ('CC-SIM-R19-035E', 'CUST-SIM-R19-035', 'EMAIL', 'evita.palacio@demo.com'),
    ('CC-SIM-R19-036E', 'CUST-SIM-R19-036', 'EMAIL', 'funmilayo.okonkwo@demo.com'),
    ('CC-SIM-R19-037E', 'CUST-SIM-R19-037', 'EMAIL', 'gabor.toth@demo.com'),
    ('CC-SIM-R19-038E', 'CUST-SIM-R19-038', 'EMAIL', 'haneen.khouri@demo.com'),
    ('CC-SIM-R19-039E', 'CUST-SIM-R19-039', 'EMAIL', 'indira.chakrabarti@demo.com'),
    ('CC-SIM-R19-040E', 'CUST-SIM-R19-040', 'EMAIL', 'jordi.puigdomenech@demo.com')
    AS v(col1,col2,col3,col4)
WHERE NOT EXISTS (SELECT 1 FROM CUSTOMER.CUSTOMER_CONTACT WHERE CONTACT_ID = v.col1);

-- ============================================================
-- 19d.  Phone contacts — first 20 customers
-- ============================================================
INSERT INTO CUSTOMER.CUSTOMER_CONTACT
    (CONTACT_ID, CUSTOMER_ID, CONTACT_TYPE, CONTACT_VALUE,
     IS_PRIMARY, IS_VERIFIED, EFFECTIVE_DATE, CREATED_AT, UPDATED_AT)
SELECT col1, col2, col3, col4, TRUE, FALSE, CURRENT_DATE(), CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()
FROM VALUES
    ('CC-SIM-R19-001P', 'CUST-SIM-R19-001', 'PHONE', '555-1901'),
    ('CC-SIM-R19-002P', 'CUST-SIM-R19-002', 'PHONE', '555-1902'),
    ('CC-SIM-R19-003P', 'CUST-SIM-R19-003', 'PHONE', '555-1903'),
    ('CC-SIM-R19-004P', 'CUST-SIM-R19-004', 'PHONE', '555-1904'),
    ('CC-SIM-R19-005P', 'CUST-SIM-R19-005', 'PHONE', '555-1905'),
    ('CC-SIM-R19-006P', 'CUST-SIM-R19-006', 'PHONE', '555-1906'),
    ('CC-SIM-R19-007P', 'CUST-SIM-R19-007', 'PHONE', '555-1907'),
    ('CC-SIM-R19-008P', 'CUST-SIM-R19-008', 'PHONE', '555-1908'),
    ('CC-SIM-R19-009P', 'CUST-SIM-R19-009', 'PHONE', '555-1909'),
    ('CC-SIM-R19-010P', 'CUST-SIM-R19-010', 'PHONE', '555-1910'),
    ('CC-SIM-R19-011P', 'CUST-SIM-R19-011', 'PHONE', '555-1911'),
    ('CC-SIM-R19-012P', 'CUST-SIM-R19-012', 'PHONE', '555-1912'),
    ('CC-SIM-R19-013P', 'CUST-SIM-R19-013', 'PHONE', '555-1913'),
    ('CC-SIM-R19-014P', 'CUST-SIM-R19-014', 'PHONE', '555-1914'),
    ('CC-SIM-R19-015P', 'CUST-SIM-R19-015', 'PHONE', '555-1915'),
    ('CC-SIM-R19-016P', 'CUST-SIM-R19-016', 'PHONE', '555-1916'),
    ('CC-SIM-R19-017P', 'CUST-SIM-R19-017', 'PHONE', '555-1917'),
    ('CC-SIM-R19-018P', 'CUST-SIM-R19-018', 'PHONE', '555-1918'),
    ('CC-SIM-R19-019P', 'CUST-SIM-R19-019', 'PHONE', '555-1919'),
    ('CC-SIM-R19-020P', 'CUST-SIM-R19-020', 'PHONE', '555-1920')
    AS v(col1,col2,col3,col4)
WHERE NOT EXISTS (SELECT 1 FROM CUSTOMER.CUSTOMER_CONTACT WHERE CONTACT_ID = v.col1);

-- ============================================================
-- 19e.  Rejections: invalid email (no @)
-- ============================================================
INSERT INTO CUSTOMER.CUSTOMER_CONTACT
    (CONTACT_ID, CUSTOMER_ID, CONTACT_TYPE, CONTACT_VALUE,
     IS_PRIMARY, IS_VERIFIED, EFFECTIVE_DATE, CREATED_AT, UPDATED_AT)
SELECT col1, col2, col3, col4, TRUE, FALSE, CURRENT_DATE(), CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()
FROM VALUES
    ('CC-SIM-R19-RJE1', 'CUST-SIM-R19-001', 'EMAIL', 'invalid.email.nodomain'),
    ('CC-SIM-R19-RJE2', 'CUST-SIM-R19-002', 'EMAIL', 'also-not-valid-email')
    AS v(col1,col2,col3,col4)
WHERE NOT EXISTS (SELECT 1 FROM CUSTOMER.CUSTOMER_CONTACT WHERE CONTACT_ID = v.col1);

-- ============================================================
-- 19f.  Energy accounts — 40 primary + 4 second accounts
-- ============================================================
INSERT INTO CUSTOMER.ENERGY_ACCOUNT
    (ENERGY_ACCOUNT_ID, CUSTOMER_ID, ACCOUNT_NUMBER, ACCOUNT_STATUS,
     SERVICE_TYPE, RATE_CLASS, OPEN_DATE, CREATED_AT, UPDATED_AT)
SELECT col1, col2, col3, col4, col5, col6, CURRENT_DATE(), CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()
FROM VALUES
    ('EA-SIM-R19-001', 'CUST-SIM-R19-001', 'ACCT-SIM-R19-001', 'ACTIVE', 'ELECTRIC', 'RESIDENTIAL'),
    ('EA-SIM-R19-002', 'CUST-SIM-R19-002', 'ACCT-SIM-R19-002', 'ACTIVE', 'ELECTRIC', 'RESIDENTIAL'),
    ('EA-SIM-R19-003', 'CUST-SIM-R19-003', 'ACCT-SIM-R19-003', 'ACTIVE', 'ELECTRIC', 'RESIDENTIAL'),
    ('EA-SIM-R19-004', 'CUST-SIM-R19-004', 'ACCT-SIM-R19-004', 'ACTIVE', 'ELECTRIC', 'SMALL_COMMERCIAL'),
    ('EA-SIM-R19-005', 'CUST-SIM-R19-005', 'ACCT-SIM-R19-005', 'ACTIVE', 'ELECTRIC', 'RESIDENTIAL'),
    ('EA-SIM-R19-006', 'CUST-SIM-R19-006', 'ACCT-SIM-R19-006', 'ACTIVE', 'ELECTRIC', 'RESIDENTIAL'),
    ('EA-SIM-R19-007', 'CUST-SIM-R19-007', 'ACCT-SIM-R19-007', 'ACTIVE', 'ELECTRIC', 'SMALL_COMMERCIAL'),
    ('EA-SIM-R19-008', 'CUST-SIM-R19-008', 'ACCT-SIM-R19-008', 'ACTIVE', 'ELECTRIC', 'SMALL_COMMERCIAL'),
    ('EA-SIM-R19-009', 'CUST-SIM-R19-009', 'ACCT-SIM-R19-009', 'ACTIVE', 'ELECTRIC', 'SMALL_COMMERCIAL'),
    ('EA-SIM-R19-010', 'CUST-SIM-R19-010', 'ACCT-SIM-R19-010', 'ACTIVE', 'ELECTRIC', 'SMALL_COMMERCIAL'),
    ('EA-SIM-R19-011', 'CUST-SIM-R19-011', 'ACCT-SIM-R19-011', 'ACTIVE', 'ELECTRIC', 'SMALL_COMMERCIAL'),
    ('EA-SIM-R19-012', 'CUST-SIM-R19-012', 'ACCT-SIM-R19-012', 'ACTIVE', 'ELECTRIC', 'SMALL_COMMERCIAL'),
    ('EA-SIM-R19-013', 'CUST-SIM-R19-013', 'ACCT-SIM-R19-013', 'ACTIVE', 'ELECTRIC', 'SMALL_COMMERCIAL'),
    ('EA-SIM-R19-014', 'CUST-SIM-R19-014', 'ACCT-SIM-R19-014', 'ACTIVE', 'ELECTRIC', 'SMALL_COMMERCIAL'),
    ('EA-SIM-R19-015', 'CUST-SIM-R19-015', 'ACCT-SIM-R19-015', 'ACTIVE', 'ELECTRIC', 'SMALL_COMMERCIAL'),
    ('EA-SIM-R19-016', 'CUST-SIM-R19-016', 'ACCT-SIM-R19-016', 'ACTIVE', 'ELECTRIC', 'SMALL_COMMERCIAL'),
    ('EA-SIM-R19-017', 'CUST-SIM-R19-017', 'ACCT-SIM-R19-017', 'ACTIVE', 'ELECTRIC', 'SMALL_COMMERCIAL'),
    ('EA-SIM-R19-018', 'CUST-SIM-R19-018', 'ACCT-SIM-R19-018', 'ACTIVE', 'ELECTRIC', 'SMALL_COMMERCIAL'),
    ('EA-SIM-R19-019', 'CUST-SIM-R19-019', 'ACCT-SIM-R19-019', 'ACTIVE', 'ELECTRIC', 'SMALL_COMMERCIAL'),
    ('EA-SIM-R19-020', 'CUST-SIM-R19-020', 'ACCT-SIM-R19-020', 'ACTIVE', 'ELECTRIC', 'SMALL_COMMERCIAL'),
    ('EA-SIM-R19-021', 'CUST-SIM-R19-021', 'ACCT-SIM-R19-021', 'ACTIVE', 'ELECTRIC', 'LARGE_INDUSTRIAL'),
    ('EA-SIM-R19-022', 'CUST-SIM-R19-022', 'ACCT-SIM-R19-022', 'ACTIVE', 'ELECTRIC', 'LARGE_INDUSTRIAL'),
    ('EA-SIM-R19-023', 'CUST-SIM-R19-023', 'ACCT-SIM-R19-023', 'ACTIVE', 'ELECTRIC', 'LARGE_INDUSTRIAL'),
    ('EA-SIM-R19-024', 'CUST-SIM-R19-024', 'ACCT-SIM-R19-024', 'ACTIVE', 'ELECTRIC', 'LARGE_INDUSTRIAL'),
    ('EA-SIM-R19-025', 'CUST-SIM-R19-025', 'ACCT-SIM-R19-025', 'ACTIVE', 'ELECTRIC', 'LARGE_INDUSTRIAL'),
    ('EA-SIM-R19-026', 'CUST-SIM-R19-026', 'ACCT-SIM-R19-026', 'ACTIVE', 'ELECTRIC', 'LARGE_INDUSTRIAL'),
    ('EA-SIM-R19-027', 'CUST-SIM-R19-027', 'ACCT-SIM-R19-027', 'ACTIVE', 'ELECTRIC', 'LARGE_INDUSTRIAL'),
    ('EA-SIM-R19-028', 'CUST-SIM-R19-028', 'ACCT-SIM-R19-028', 'ACTIVE', 'ELECTRIC', 'LARGE_INDUSTRIAL'),
    ('EA-SIM-R19-029', 'CUST-SIM-R19-029', 'ACCT-SIM-R19-029', 'ACTIVE', 'ELECTRIC', 'LARGE_INDUSTRIAL'),
    ('EA-SIM-R19-030', 'CUST-SIM-R19-030', 'ACCT-SIM-R19-030', 'ACTIVE', 'ELECTRIC', 'LARGE_INDUSTRIAL'),
    ('EA-SIM-R19-031', 'CUST-SIM-R19-031', 'ACCT-SIM-R19-031', 'ACTIVE', 'ELECTRIC', 'RESIDENTIAL'),
    ('EA-SIM-R19-032', 'CUST-SIM-R19-032', 'ACCT-SIM-R19-032', 'ACTIVE', 'ELECTRIC', 'RESIDENTIAL'),
    ('EA-SIM-R19-033', 'CUST-SIM-R19-033', 'ACCT-SIM-R19-033', 'ACTIVE', 'ELECTRIC', 'RESIDENTIAL'),
    ('EA-SIM-R19-034', 'CUST-SIM-R19-034', 'ACCT-SIM-R19-034', 'ACTIVE', 'ELECTRIC', 'RESIDENTIAL'),
    ('EA-SIM-R19-035', 'CUST-SIM-R19-035', 'ACCT-SIM-R19-035', 'ACTIVE', 'ELECTRIC', 'RESIDENTIAL'),
    ('EA-SIM-R19-036', 'CUST-SIM-R19-036', 'ACCT-SIM-R19-036', 'ACTIVE', 'ELECTRIC', 'RESIDENTIAL'),
    ('EA-SIM-R19-037', 'CUST-SIM-R19-037', 'ACCT-SIM-R19-037', 'ACTIVE', 'ELECTRIC', 'RESIDENTIAL'),
    ('EA-SIM-R19-038', 'CUST-SIM-R19-038', 'ACCT-SIM-R19-038', 'ACTIVE', 'ELECTRIC', 'RESIDENTIAL'),
    ('EA-SIM-R19-039', 'CUST-SIM-R19-039', 'ACCT-SIM-R19-039', 'ACTIVE', 'ELECTRIC', 'RESIDENTIAL'),
    ('EA-SIM-R19-040', 'CUST-SIM-R19-040', 'ACCT-SIM-R19-040', 'ACTIVE', 'ELECTRIC', 'RESIDENTIAL'),
    ('EA-SIM-R19-B01', 'CUST-SIM-R19-001', 'ACCT-SIM-R19-B01', 'ACTIVE', 'ELECTRIC', 'RESIDENTIAL'),
    ('EA-SIM-R19-B05', 'CUST-SIM-R19-005', 'ACCT-SIM-R19-B05', 'ACTIVE', 'ELECTRIC', 'RESIDENTIAL'),
    ('EA-SIM-R19-B14', 'CUST-SIM-R19-014', 'ACCT-SIM-R19-B14', 'ACTIVE', 'ELECTRIC', 'SMALL_COMMERCIAL'),
    ('EA-SIM-R19-B31', 'CUST-SIM-R19-031', 'ACCT-SIM-R19-B31', 'ACTIVE', 'ELECTRIC', 'RESIDENTIAL')
    AS v(col1,col2,col3,col4,col5,col6)
WHERE NOT EXISTS (SELECT 1 FROM CUSTOMER.ENERGY_ACCOUNT WHERE ENERGY_ACCOUNT_ID = v.col1);

-- ============================================================
-- 19g.  Cross-round updates — previous cohorts
-- ============================================================
UPDATE CUSTOMER.CUSTOMER
SET PREFERRED_LANGUAGE = 'ES', UPDATED_AT = CURRENT_TIMESTAMP()
WHERE CUSTOMER_ID IN (
    'CUST-SIM-R18-001','CUST-SIM-R18-002','CUST-SIM-R18-003',
    'CUST-SIM-R18-004','CUST-SIM-R18-005'
);

UPDATE CUSTOMER.CUSTOMER_CONTACT
SET IS_VERIFIED = TRUE, UPDATED_AT = CURRENT_TIMESTAMP()
WHERE CONTACT_ID IN (
    'CC-SIM-R18-021E','CC-SIM-R18-022E','CC-SIM-R18-023E',
    'CC-SIM-R18-024E','CC-SIM-R18-025E','CC-SIM-R18-026E',
    'CC-SIM-R18-027E','CC-SIM-R18-028E','CC-SIM-R18-029E',
    'CC-SIM-R18-030E'
);

UPDATE CUSTOMER.CUSTOMER_CONTACT
SET IS_VERIFIED = TRUE, UPDATED_AT = CURRENT_TIMESTAMP()
WHERE CONTACT_ID IN (
    'CC-SIM-R18-001P','CC-SIM-R18-002P','CC-SIM-R18-003P',
    'CC-SIM-R18-004P','CC-SIM-R18-005P','CC-SIM-R18-006P',
    'CC-SIM-R18-007P','CC-SIM-R18-008P','CC-SIM-R18-009P',
    'CC-SIM-R18-010P'
);

UPDATE CUSTOMER.ENERGY_ACCOUNT
SET ACCOUNT_STATUS = 'SUSPENDED', UPDATED_AT = CURRENT_TIMESTAMP()
WHERE ENERGY_ACCOUNT_ID IN ('EA-SIM-R17-005', 'EA-SIM-R17-010');

UPDATE CUSTOMER.ENERGY_ACCOUNT
SET ACCOUNT_STATUS = 'ACTIVE', UPDATED_AT = CURRENT_TIMESTAMP()
WHERE ENERGY_ACCOUNT_ID IN ('EA-SIM-R16-005', 'EA-SIM-R16-010');

-- Verification
SELECT 'R19 customers inserted'      AS label, COUNT(*) AS cnt FROM CUSTOMER.CUSTOMER       WHERE CUSTOMER_ID       LIKE 'CUST-SIM-R19-%'
UNION ALL
SELECT 'R19 energy accounts inserted',          COUNT(*)        FROM CUSTOMER.ENERGY_ACCOUNT WHERE ENERGY_ACCOUNT_ID LIKE 'EA-SIM-R19-%'
UNION ALL
SELECT 'R19 email contacts inserted',           COUNT(*)        FROM CUSTOMER.CUSTOMER_CONTACT WHERE CONTACT_ID      LIKE 'CC-SIM-R19-%'
ORDER BY 1;
