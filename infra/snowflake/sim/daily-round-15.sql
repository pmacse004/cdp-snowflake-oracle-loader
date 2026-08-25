-- =============================================================================
-- Daily Load Simulation — Round 15
-- =============================================================================
-- Run as: CDP_ADMIN_ROLE  |  Database: CDP_UTIL_DB  |  Warehouse: CDP_LOADER_WH
--
-- SCENARIO  Large customer wave — 40 customers across all types
-- REJECTION REJ-D1: blank FIRST_NAME (VR-CUST-001) x 2
--           REJ-D2: invalid email (VR-CONT-001) x 2
-- TRIGGER   POST http://localhost:8080/api/jobs/daily
-- PREREQUISITE  daily-round-14.sql must have been run.
-- CUSTOMERS  40 valid + 2 blank-name rejections
-- ACCOUNTS   44 energy accounts (incl. 4 second accounts)
-- CONTACTS   40 email + 20 phone + 2 invalid email rejections
-- =============================================================================

USE ROLE CDP_ADMIN_ROLE;
USE DATABASE CDP_UTIL_DB;
USE WAREHOUSE CDP_LOADER_WH;

-- ============================================================
-- 15a.  New customers — 40 valid rows
-- ============================================================
INSERT INTO CUSTOMER.CUSTOMER
    (CUSTOMER_ID, FIRST_NAME, LAST_NAME, ACCOUNT_STATUS, CUSTOMER_TYPE,
     PREFERRED_LANGUAGE, CREATED_AT, UPDATED_AT)
SELECT col1, col2, col3, col4, col5, col6, CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()
FROM VALUES
    ('CUST-SIM-R15-001', 'Zara', 'Hussain', 'ACTIVE', 'RESIDENTIAL', 'EN'),
    ('CUST-SIM-R15-002', 'Eduardo', 'Castillo', 'ACTIVE', 'RESIDENTIAL', 'EN'),
    ('CUST-SIM-R15-003', 'Miriam', 'Goldstein', 'ACTIVE', 'COMMERCIAL', 'EN'),
    ('CUST-SIM-R15-004', 'Tomasz', 'Kowalski', 'ACTIVE', 'RESIDENTIAL', 'EN'),
    ('CUST-SIM-R15-005', 'Aiko', 'Watanabe', 'ACTIVE', 'RESIDENTIAL', 'EN'),
    ('CUST-SIM-R15-006', 'Baptiste', 'Leclerc', 'ACTIVE', 'RESIDENTIAL', 'FR'),
    ('CUST-SIM-R15-007', 'Chinonso', 'Udeze', 'ACTIVE', 'COMMERCIAL', 'EN'),
    ('CUST-SIM-R15-008', 'Despina', 'Papadimitriou', 'ACTIVE', 'RESIDENTIAL', 'EN'),
    ('CUST-SIM-R15-009', 'Ezra', 'Abramowitz', 'ACTIVE', 'COMMERCIAL', 'EN'),
    ('CUST-SIM-R15-010', 'Florentin', 'Ionescu', 'ACTIVE', 'RESIDENTIAL', 'EN'),
    ('CUST-SIM-R15-011', 'Gladys', 'Abubakar', 'ACTIVE', 'COMMERCIAL', 'EN'),
    ('CUST-SIM-R15-012', 'Hanno', 'Richter', 'ACTIVE', 'COMMERCIAL', 'DE'),
    ('CUST-SIM-R15-013', 'Imelda', 'Reyes', 'ACTIVE', 'RESIDENTIAL', 'EN'),
    ('CUST-SIM-R15-014', 'Jovan', 'Markovic', 'ACTIVE', 'COMMERCIAL', 'EN'),
    ('CUST-SIM-R15-015', 'Kamila', 'Nowak', 'ACTIVE', 'RESIDENTIAL', 'EN'),
    ('CUST-SIM-R15-016', 'Lamin', 'Jallow', 'ACTIVE', 'COMMERCIAL', 'EN'),
    ('CUST-SIM-R15-017', 'Maelis', 'Girard', 'ACTIVE', 'RESIDENTIAL', 'FR'),
    ('CUST-SIM-R15-018', 'Nnamdi', 'Okafor', 'ACTIVE', 'COMMERCIAL', 'EN'),
    ('CUST-SIM-R15-019', 'Ondrej', 'Blaha', 'ACTIVE', 'RESIDENTIAL', 'EN'),
    ('CUST-SIM-R15-020', 'Philomena', 'Achike', 'ACTIVE', 'COMMERCIAL', 'EN'),
    ('CUST-SIM-R15-021', 'Quinton', 'Dlamini', 'ACTIVE', 'INDUSTRIAL', 'EN'),
    ('CUST-SIM-R15-022', 'Roksana', 'Pavlova', 'ACTIVE', 'INDUSTRIAL', 'EN'),
    ('CUST-SIM-R15-023', 'Salome', 'Bedane', 'ACTIVE', 'INDUSTRIAL', 'EN'),
    ('CUST-SIM-R15-024', 'Tetsuro', 'Kishi', 'ACTIVE', 'INDUSTRIAL', 'EN'),
    ('CUST-SIM-R15-025', 'Umaimah', 'Rashid', 'ACTIVE', 'INDUSTRIAL', 'EN'),
    ('CUST-SIM-R15-026', 'Ignacio', 'Dominguez', 'ACTIVE', 'INDUSTRIAL', 'EN'),
    ('CUST-SIM-R15-027', 'Wanjiku', 'Njoroge', 'ACTIVE', 'INDUSTRIAL', 'EN'),
    ('CUST-SIM-R15-028', 'Xiumei', 'Pan', 'ACTIVE', 'INDUSTRIAL', 'EN'),
    ('CUST-SIM-R15-029', 'Yoel', 'Ashkenazi', 'ACTIVE', 'INDUSTRIAL', 'EN'),
    ('CUST-SIM-R15-030', 'Zanele', 'Zulu', 'ACTIVE', 'INDUSTRIAL', 'EN'),
    ('CUST-SIM-R15-031', 'Abiodun', 'Falola', 'ACTIVE', 'RESIDENTIAL', 'EN'),
    ('CUST-SIM-R15-032', 'Bjarne', 'Pedersen', 'ACTIVE', 'RESIDENTIAL', 'EN'),
    ('CUST-SIM-R15-033', 'Consolata', 'Nyaboke', 'ACTIVE', 'RESIDENTIAL', 'EN'),
    ('CUST-SIM-R15-034', 'Dariusz', 'Wieczorek', 'ACTIVE', 'RESIDENTIAL', 'EN'),
    ('CUST-SIM-R15-035', 'Estelle', 'Tremblay', 'ACTIVE', 'RESIDENTIAL', 'FR'),
    ('CUST-SIM-R15-036', 'Fikile', 'Mthembu', 'ACTIVE', 'RESIDENTIAL', 'EN'),
    ('CUST-SIM-R15-037', 'Grigor', 'Petrosyan', 'ACTIVE', 'RESIDENTIAL', 'EN'),
    ('CUST-SIM-R15-038', 'Hatice', 'Demir', 'ACTIVE', 'RESIDENTIAL', 'EN'),
    ('CUST-SIM-R15-039', 'Iordan', 'Stoyanov', 'ACTIVE', 'RESIDENTIAL', 'EN'),
    ('CUST-SIM-R15-040', 'Jubilee', 'Kimani', 'ACTIVE', 'RESIDENTIAL', 'EN')
    AS v(col1,col2,col3,col4,col5,col6)
WHERE NOT EXISTS (SELECT 1 FROM CUSTOMER.CUSTOMER WHERE CUSTOMER_ID = v.col1);

-- ============================================================
-- 15b.  Rejections: blank FIRST_NAME
-- ============================================================
INSERT INTO CUSTOMER.CUSTOMER
    (CUSTOMER_ID, FIRST_NAME, LAST_NAME, ACCOUNT_STATUS, CUSTOMER_TYPE,
     PREFERRED_LANGUAGE, CREATED_AT, UPDATED_AT)
SELECT col1, col2, col3, col4, col5, col6, CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()
FROM VALUES
    ('CUST-SIM-R15-RJ1', '', 'NoFirstA',  'ACTIVE', 'RESIDENTIAL', 'EN'),
    ('CUST-SIM-R15-RJ2', '', 'NoFirstB',  'ACTIVE', 'COMMERCIAL',  'EN')
    AS v(col1,col2,col3,col4,col5,col6)
WHERE NOT EXISTS (SELECT 1 FROM CUSTOMER.CUSTOMER WHERE CUSTOMER_ID = v.col1);

-- ============================================================
-- 15c.  Primary email contacts — all 40 valid customers
-- ============================================================
INSERT INTO CUSTOMER.CUSTOMER_CONTACT
    (CONTACT_ID, CUSTOMER_ID, CONTACT_TYPE, CONTACT_VALUE,
     IS_PRIMARY, IS_VERIFIED, EFFECTIVE_DATE, CREATED_AT, UPDATED_AT)
SELECT col1, col2, col3, col4, TRUE, TRUE, CURRENT_DATE(), CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()
FROM VALUES
    ('CC-SIM-R15-001E', 'CUST-SIM-R15-001', 'EMAIL', 'zara.hussain@demo.com'),
    ('CC-SIM-R15-002E', 'CUST-SIM-R15-002', 'EMAIL', 'eduardo.castillo@demo.com'),
    ('CC-SIM-R15-003E', 'CUST-SIM-R15-003', 'EMAIL', 'miriam.goldstein@demo.com'),
    ('CC-SIM-R15-004E', 'CUST-SIM-R15-004', 'EMAIL', 'tomasz.kowalski@demo.com'),
    ('CC-SIM-R15-005E', 'CUST-SIM-R15-005', 'EMAIL', 'aiko.watanabe@demo.com'),
    ('CC-SIM-R15-006E', 'CUST-SIM-R15-006', 'EMAIL', 'baptiste.leclerc@demo.com'),
    ('CC-SIM-R15-007E', 'CUST-SIM-R15-007', 'EMAIL', 'chinonso.udeze@demo.com'),
    ('CC-SIM-R15-008E', 'CUST-SIM-R15-008', 'EMAIL', 'despina.papadimitriou@demo.com'),
    ('CC-SIM-R15-009E', 'CUST-SIM-R15-009', 'EMAIL', 'ezra.abramowitz@demo.com'),
    ('CC-SIM-R15-010E', 'CUST-SIM-R15-010', 'EMAIL', 'florentin.ionescu@demo.com'),
    ('CC-SIM-R15-011E', 'CUST-SIM-R15-011', 'EMAIL', 'gladys.abubakar@demo.com'),
    ('CC-SIM-R15-012E', 'CUST-SIM-R15-012', 'EMAIL', 'hanno.richter@demo.com'),
    ('CC-SIM-R15-013E', 'CUST-SIM-R15-013', 'EMAIL', 'imelda.reyes@demo.com'),
    ('CC-SIM-R15-014E', 'CUST-SIM-R15-014', 'EMAIL', 'jovan.markovic@demo.com'),
    ('CC-SIM-R15-015E', 'CUST-SIM-R15-015', 'EMAIL', 'kamila.nowak@demo.com'),
    ('CC-SIM-R15-016E', 'CUST-SIM-R15-016', 'EMAIL', 'lamin.jallow@demo.com'),
    ('CC-SIM-R15-017E', 'CUST-SIM-R15-017', 'EMAIL', 'maelis.girard@demo.com'),
    ('CC-SIM-R15-018E', 'CUST-SIM-R15-018', 'EMAIL', 'nnamdi.okafor@demo.com'),
    ('CC-SIM-R15-019E', 'CUST-SIM-R15-019', 'EMAIL', 'ondrej.blaha@demo.com'),
    ('CC-SIM-R15-020E', 'CUST-SIM-R15-020', 'EMAIL', 'philomena.achike@demo.com'),
    ('CC-SIM-R15-021E', 'CUST-SIM-R15-021', 'EMAIL', 'quinton.dlamini@demo.com'),
    ('CC-SIM-R15-022E', 'CUST-SIM-R15-022', 'EMAIL', 'roksana.pavlova@demo.com'),
    ('CC-SIM-R15-023E', 'CUST-SIM-R15-023', 'EMAIL', 'salome.bedane@demo.com'),
    ('CC-SIM-R15-024E', 'CUST-SIM-R15-024', 'EMAIL', 'tetsuro.kishi@demo.com'),
    ('CC-SIM-R15-025E', 'CUST-SIM-R15-025', 'EMAIL', 'umaimah.rashid@demo.com'),
    ('CC-SIM-R15-026E', 'CUST-SIM-R15-026', 'EMAIL', 'ignacio.dominguez@demo.com'),
    ('CC-SIM-R15-027E', 'CUST-SIM-R15-027', 'EMAIL', 'wanjiku.njoroge@demo.com'),
    ('CC-SIM-R15-028E', 'CUST-SIM-R15-028', 'EMAIL', 'xiumei.pan@demo.com'),
    ('CC-SIM-R15-029E', 'CUST-SIM-R15-029', 'EMAIL', 'yoel.ashkenazi@demo.com'),
    ('CC-SIM-R15-030E', 'CUST-SIM-R15-030', 'EMAIL', 'zanele.zulu@demo.com'),
    ('CC-SIM-R15-031E', 'CUST-SIM-R15-031', 'EMAIL', 'abiodun.falola@demo.com'),
    ('CC-SIM-R15-032E', 'CUST-SIM-R15-032', 'EMAIL', 'bjarne.pedersen@demo.com'),
    ('CC-SIM-R15-033E', 'CUST-SIM-R15-033', 'EMAIL', 'consolata.nyaboke@demo.com'),
    ('CC-SIM-R15-034E', 'CUST-SIM-R15-034', 'EMAIL', 'dariusz.wieczorek@demo.com'),
    ('CC-SIM-R15-035E', 'CUST-SIM-R15-035', 'EMAIL', 'estelle.tremblay@demo.com'),
    ('CC-SIM-R15-036E', 'CUST-SIM-R15-036', 'EMAIL', 'fikile.mthembu@demo.com'),
    ('CC-SIM-R15-037E', 'CUST-SIM-R15-037', 'EMAIL', 'grigor.petrosyan@demo.com'),
    ('CC-SIM-R15-038E', 'CUST-SIM-R15-038', 'EMAIL', 'hatice.demir@demo.com'),
    ('CC-SIM-R15-039E', 'CUST-SIM-R15-039', 'EMAIL', 'iordan.stoyanov@demo.com'),
    ('CC-SIM-R15-040E', 'CUST-SIM-R15-040', 'EMAIL', 'jubilee.kimani@demo.com')
    AS v(col1,col2,col3,col4)
WHERE NOT EXISTS (SELECT 1 FROM CUSTOMER.CUSTOMER_CONTACT WHERE CONTACT_ID = v.col1);

-- ============================================================
-- 15d.  Phone contacts — first 20 customers
-- ============================================================
INSERT INTO CUSTOMER.CUSTOMER_CONTACT
    (CONTACT_ID, CUSTOMER_ID, CONTACT_TYPE, CONTACT_VALUE,
     IS_PRIMARY, IS_VERIFIED, EFFECTIVE_DATE, CREATED_AT, UPDATED_AT)
SELECT col1, col2, col3, col4, TRUE, FALSE, CURRENT_DATE(), CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()
FROM VALUES
    ('CC-SIM-R15-001P', 'CUST-SIM-R15-001', 'PHONE', '555-1501'),
    ('CC-SIM-R15-002P', 'CUST-SIM-R15-002', 'PHONE', '555-1502'),
    ('CC-SIM-R15-003P', 'CUST-SIM-R15-003', 'PHONE', '555-1503'),
    ('CC-SIM-R15-004P', 'CUST-SIM-R15-004', 'PHONE', '555-1504'),
    ('CC-SIM-R15-005P', 'CUST-SIM-R15-005', 'PHONE', '555-1505'),
    ('CC-SIM-R15-006P', 'CUST-SIM-R15-006', 'PHONE', '555-1506'),
    ('CC-SIM-R15-007P', 'CUST-SIM-R15-007', 'PHONE', '555-1507'),
    ('CC-SIM-R15-008P', 'CUST-SIM-R15-008', 'PHONE', '555-1508'),
    ('CC-SIM-R15-009P', 'CUST-SIM-R15-009', 'PHONE', '555-1509'),
    ('CC-SIM-R15-010P', 'CUST-SIM-R15-010', 'PHONE', '555-1510'),
    ('CC-SIM-R15-011P', 'CUST-SIM-R15-011', 'PHONE', '555-1511'),
    ('CC-SIM-R15-012P', 'CUST-SIM-R15-012', 'PHONE', '555-1512'),
    ('CC-SIM-R15-013P', 'CUST-SIM-R15-013', 'PHONE', '555-1513'),
    ('CC-SIM-R15-014P', 'CUST-SIM-R15-014', 'PHONE', '555-1514'),
    ('CC-SIM-R15-015P', 'CUST-SIM-R15-015', 'PHONE', '555-1515'),
    ('CC-SIM-R15-016P', 'CUST-SIM-R15-016', 'PHONE', '555-1516'),
    ('CC-SIM-R15-017P', 'CUST-SIM-R15-017', 'PHONE', '555-1517'),
    ('CC-SIM-R15-018P', 'CUST-SIM-R15-018', 'PHONE', '555-1518'),
    ('CC-SIM-R15-019P', 'CUST-SIM-R15-019', 'PHONE', '555-1519'),
    ('CC-SIM-R15-020P', 'CUST-SIM-R15-020', 'PHONE', '555-1520')
    AS v(col1,col2,col3,col4)
WHERE NOT EXISTS (SELECT 1 FROM CUSTOMER.CUSTOMER_CONTACT WHERE CONTACT_ID = v.col1);

-- ============================================================
-- 15e.  Rejections: invalid email (no @)
-- ============================================================
INSERT INTO CUSTOMER.CUSTOMER_CONTACT
    (CONTACT_ID, CUSTOMER_ID, CONTACT_TYPE, CONTACT_VALUE,
     IS_PRIMARY, IS_VERIFIED, EFFECTIVE_DATE, CREATED_AT, UPDATED_AT)
SELECT col1, col2, col3, col4, TRUE, FALSE, CURRENT_DATE(), CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()
FROM VALUES
    ('CC-SIM-R15-RJE1', 'CUST-SIM-R15-001', 'EMAIL', 'invalid.email.nodomain'),
    ('CC-SIM-R15-RJE2', 'CUST-SIM-R15-002', 'EMAIL', 'also-not-valid-email')
    AS v(col1,col2,col3,col4)
WHERE NOT EXISTS (SELECT 1 FROM CUSTOMER.CUSTOMER_CONTACT WHERE CONTACT_ID = v.col1);

-- ============================================================
-- 15f.  Energy accounts — 40 primary + 4 second accounts
-- ============================================================
INSERT INTO CUSTOMER.ENERGY_ACCOUNT
    (ENERGY_ACCOUNT_ID, CUSTOMER_ID, ACCOUNT_NUMBER, ACCOUNT_STATUS,
     SERVICE_TYPE, RATE_CLASS, OPEN_DATE, CREATED_AT, UPDATED_AT)
SELECT col1, col2, col3, col4, col5, col6, CURRENT_DATE(), CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()
FROM VALUES
    ('EA-SIM-R15-001', 'CUST-SIM-R15-001', 'ACCT-SIM-R15-001', 'ACTIVE', 'ELECTRIC', 'RESIDENTIAL'),
    ('EA-SIM-R15-002', 'CUST-SIM-R15-002', 'ACCT-SIM-R15-002', 'ACTIVE', 'ELECTRIC', 'RESIDENTIAL'),
    ('EA-SIM-R15-003', 'CUST-SIM-R15-003', 'ACCT-SIM-R15-003', 'ACTIVE', 'ELECTRIC', 'SMALL_COMMERCIAL'),
    ('EA-SIM-R15-004', 'CUST-SIM-R15-004', 'ACCT-SIM-R15-004', 'ACTIVE', 'ELECTRIC', 'RESIDENTIAL'),
    ('EA-SIM-R15-005', 'CUST-SIM-R15-005', 'ACCT-SIM-R15-005', 'ACTIVE', 'ELECTRIC', 'RESIDENTIAL'),
    ('EA-SIM-R15-006', 'CUST-SIM-R15-006', 'ACCT-SIM-R15-006', 'ACTIVE', 'ELECTRIC', 'RESIDENTIAL'),
    ('EA-SIM-R15-007', 'CUST-SIM-R15-007', 'ACCT-SIM-R15-007', 'ACTIVE', 'ELECTRIC', 'SMALL_COMMERCIAL'),
    ('EA-SIM-R15-008', 'CUST-SIM-R15-008', 'ACCT-SIM-R15-008', 'ACTIVE', 'ELECTRIC', 'RESIDENTIAL'),
    ('EA-SIM-R15-009', 'CUST-SIM-R15-009', 'ACCT-SIM-R15-009', 'ACTIVE', 'ELECTRIC', 'SMALL_COMMERCIAL'),
    ('EA-SIM-R15-010', 'CUST-SIM-R15-010', 'ACCT-SIM-R15-010', 'ACTIVE', 'ELECTRIC', 'RESIDENTIAL'),
    ('EA-SIM-R15-011', 'CUST-SIM-R15-011', 'ACCT-SIM-R15-011', 'ACTIVE', 'ELECTRIC', 'SMALL_COMMERCIAL'),
    ('EA-SIM-R15-012', 'CUST-SIM-R15-012', 'ACCT-SIM-R15-012', 'ACTIVE', 'ELECTRIC', 'SMALL_COMMERCIAL'),
    ('EA-SIM-R15-013', 'CUST-SIM-R15-013', 'ACCT-SIM-R15-013', 'ACTIVE', 'ELECTRIC', 'RESIDENTIAL'),
    ('EA-SIM-R15-014', 'CUST-SIM-R15-014', 'ACCT-SIM-R15-014', 'ACTIVE', 'ELECTRIC', 'SMALL_COMMERCIAL'),
    ('EA-SIM-R15-015', 'CUST-SIM-R15-015', 'ACCT-SIM-R15-015', 'ACTIVE', 'ELECTRIC', 'RESIDENTIAL'),
    ('EA-SIM-R15-016', 'CUST-SIM-R15-016', 'ACCT-SIM-R15-016', 'ACTIVE', 'ELECTRIC', 'SMALL_COMMERCIAL'),
    ('EA-SIM-R15-017', 'CUST-SIM-R15-017', 'ACCT-SIM-R15-017', 'ACTIVE', 'ELECTRIC', 'RESIDENTIAL'),
    ('EA-SIM-R15-018', 'CUST-SIM-R15-018', 'ACCT-SIM-R15-018', 'ACTIVE', 'ELECTRIC', 'SMALL_COMMERCIAL'),
    ('EA-SIM-R15-019', 'CUST-SIM-R15-019', 'ACCT-SIM-R15-019', 'ACTIVE', 'ELECTRIC', 'RESIDENTIAL'),
    ('EA-SIM-R15-020', 'CUST-SIM-R15-020', 'ACCT-SIM-R15-020', 'ACTIVE', 'ELECTRIC', 'SMALL_COMMERCIAL'),
    ('EA-SIM-R15-021', 'CUST-SIM-R15-021', 'ACCT-SIM-R15-021', 'ACTIVE', 'ELECTRIC', 'LARGE_INDUSTRIAL'),
    ('EA-SIM-R15-022', 'CUST-SIM-R15-022', 'ACCT-SIM-R15-022', 'ACTIVE', 'ELECTRIC', 'LARGE_INDUSTRIAL'),
    ('EA-SIM-R15-023', 'CUST-SIM-R15-023', 'ACCT-SIM-R15-023', 'ACTIVE', 'ELECTRIC', 'LARGE_INDUSTRIAL'),
    ('EA-SIM-R15-024', 'CUST-SIM-R15-024', 'ACCT-SIM-R15-024', 'ACTIVE', 'ELECTRIC', 'LARGE_INDUSTRIAL'),
    ('EA-SIM-R15-025', 'CUST-SIM-R15-025', 'ACCT-SIM-R15-025', 'ACTIVE', 'ELECTRIC', 'LARGE_INDUSTRIAL'),
    ('EA-SIM-R15-026', 'CUST-SIM-R15-026', 'ACCT-SIM-R15-026', 'ACTIVE', 'ELECTRIC', 'LARGE_INDUSTRIAL'),
    ('EA-SIM-R15-027', 'CUST-SIM-R15-027', 'ACCT-SIM-R15-027', 'ACTIVE', 'ELECTRIC', 'LARGE_INDUSTRIAL'),
    ('EA-SIM-R15-028', 'CUST-SIM-R15-028', 'ACCT-SIM-R15-028', 'ACTIVE', 'ELECTRIC', 'LARGE_INDUSTRIAL'),
    ('EA-SIM-R15-029', 'CUST-SIM-R15-029', 'ACCT-SIM-R15-029', 'ACTIVE', 'ELECTRIC', 'LARGE_INDUSTRIAL'),
    ('EA-SIM-R15-030', 'CUST-SIM-R15-030', 'ACCT-SIM-R15-030', 'ACTIVE', 'ELECTRIC', 'LARGE_INDUSTRIAL'),
    ('EA-SIM-R15-031', 'CUST-SIM-R15-031', 'ACCT-SIM-R15-031', 'ACTIVE', 'ELECTRIC', 'RESIDENTIAL'),
    ('EA-SIM-R15-032', 'CUST-SIM-R15-032', 'ACCT-SIM-R15-032', 'ACTIVE', 'ELECTRIC', 'RESIDENTIAL'),
    ('EA-SIM-R15-033', 'CUST-SIM-R15-033', 'ACCT-SIM-R15-033', 'ACTIVE', 'ELECTRIC', 'RESIDENTIAL'),
    ('EA-SIM-R15-034', 'CUST-SIM-R15-034', 'ACCT-SIM-R15-034', 'ACTIVE', 'ELECTRIC', 'RESIDENTIAL'),
    ('EA-SIM-R15-035', 'CUST-SIM-R15-035', 'ACCT-SIM-R15-035', 'ACTIVE', 'ELECTRIC', 'RESIDENTIAL'),
    ('EA-SIM-R15-036', 'CUST-SIM-R15-036', 'ACCT-SIM-R15-036', 'ACTIVE', 'ELECTRIC', 'RESIDENTIAL'),
    ('EA-SIM-R15-037', 'CUST-SIM-R15-037', 'ACCT-SIM-R15-037', 'ACTIVE', 'ELECTRIC', 'RESIDENTIAL'),
    ('EA-SIM-R15-038', 'CUST-SIM-R15-038', 'ACCT-SIM-R15-038', 'ACTIVE', 'ELECTRIC', 'RESIDENTIAL'),
    ('EA-SIM-R15-039', 'CUST-SIM-R15-039', 'ACCT-SIM-R15-039', 'ACTIVE', 'ELECTRIC', 'RESIDENTIAL'),
    ('EA-SIM-R15-040', 'CUST-SIM-R15-040', 'ACCT-SIM-R15-040', 'ACTIVE', 'ELECTRIC', 'RESIDENTIAL'),
    ('EA-SIM-R15-B01', 'CUST-SIM-R15-001', 'ACCT-SIM-R15-B01', 'ACTIVE', 'ELECTRIC', 'RESIDENTIAL'),
    ('EA-SIM-R15-B05', 'CUST-SIM-R15-005', 'ACCT-SIM-R15-B05', 'ACTIVE', 'ELECTRIC', 'RESIDENTIAL'),
    ('EA-SIM-R15-B14', 'CUST-SIM-R15-014', 'ACCT-SIM-R15-B14', 'ACTIVE', 'ELECTRIC', 'SMALL_COMMERCIAL'),
    ('EA-SIM-R15-B31', 'CUST-SIM-R15-031', 'ACCT-SIM-R15-B31', 'ACTIVE', 'ELECTRIC', 'RESIDENTIAL')
    AS v(col1,col2,col3,col4,col5,col6)
WHERE NOT EXISTS (SELECT 1 FROM CUSTOMER.ENERGY_ACCOUNT WHERE ENERGY_ACCOUNT_ID = v.col1);

-- ============================================================
-- 15g.  Cross-round updates — previous cohorts
-- ============================================================
UPDATE CUSTOMER.CUSTOMER
SET PREFERRED_LANGUAGE = 'ES', UPDATED_AT = CURRENT_TIMESTAMP()
WHERE CUSTOMER_ID IN (
    'CUST-SIM-R14-001','CUST-SIM-R14-002','CUST-SIM-R14-003',
    'CUST-SIM-R14-004','CUST-SIM-R14-005'
);

UPDATE CUSTOMER.CUSTOMER_CONTACT
SET IS_VERIFIED = TRUE, UPDATED_AT = CURRENT_TIMESTAMP()
WHERE CONTACT_ID IN (
    'CC-SIM-R14-021E','CC-SIM-R14-022E','CC-SIM-R14-023E',
    'CC-SIM-R14-024E','CC-SIM-R14-025E','CC-SIM-R14-026E',
    'CC-SIM-R14-027E','CC-SIM-R14-028E','CC-SIM-R14-029E',
    'CC-SIM-R14-030E'
);

UPDATE CUSTOMER.CUSTOMER_CONTACT
SET IS_VERIFIED = TRUE, UPDATED_AT = CURRENT_TIMESTAMP()
WHERE CONTACT_ID IN (
    'CC-SIM-R14-001P','CC-SIM-R14-002P','CC-SIM-R14-003P',
    'CC-SIM-R14-004P','CC-SIM-R14-005P','CC-SIM-R14-006P',
    'CC-SIM-R14-007P','CC-SIM-R14-008P','CC-SIM-R14-009P',
    'CC-SIM-R14-010P'
);

UPDATE CUSTOMER.ENERGY_ACCOUNT
SET ACCOUNT_STATUS = 'SUSPENDED', UPDATED_AT = CURRENT_TIMESTAMP()
WHERE ENERGY_ACCOUNT_ID IN ('EA-SIM-R13-005', 'EA-SIM-R13-010');

UPDATE CUSTOMER.ENERGY_ACCOUNT
SET ACCOUNT_STATUS = 'ACTIVE', UPDATED_AT = CURRENT_TIMESTAMP()
WHERE ENERGY_ACCOUNT_ID IN ('EA-SIM-R12-005', 'EA-SIM-R12-010');

-- Verification
SELECT 'R15 customers inserted'      AS label, COUNT(*) AS cnt FROM CUSTOMER.CUSTOMER       WHERE CUSTOMER_ID       LIKE 'CUST-SIM-R15-%'
UNION ALL
SELECT 'R15 energy accounts inserted',          COUNT(*)        FROM CUSTOMER.ENERGY_ACCOUNT WHERE ENERGY_ACCOUNT_ID LIKE 'EA-SIM-R15-%'
UNION ALL
SELECT 'R15 email contacts inserted',           COUNT(*)        FROM CUSTOMER.CUSTOMER_CONTACT WHERE CONTACT_ID      LIKE 'CC-SIM-R15-%'
ORDER BY 1;
