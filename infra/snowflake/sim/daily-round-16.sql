-- =============================================================================
-- Daily Load Simulation — Round 16
-- =============================================================================
-- Run as: CDP_ADMIN_ROLE  |  Database: CDP_UTIL_DB  |  Warehouse: CDP_LOADER_WH
--
-- SCENARIO  Large customer wave — 40 customers across all types
-- REJECTION REJ-D1: blank FIRST_NAME (VR-CUST-001) x 2
--           REJ-D2: invalid email (VR-CONT-001) x 2
-- TRIGGER   POST http://localhost:8080/api/jobs/daily
-- PREREQUISITE  daily-round-15.sql must have been run.
-- CUSTOMERS  40 valid + 2 blank-name rejections
-- ACCOUNTS   44 energy accounts (incl. 4 second accounts)
-- CONTACTS   40 email + 20 phone + 2 invalid email rejections
-- =============================================================================

USE ROLE CDP_ADMIN_ROLE;
USE DATABASE CDP_UTIL_DB;
USE WAREHOUSE CDP_LOADER_WH;

-- ============================================================
-- 16a.  New customers — 40 valid rows
-- ============================================================
INSERT INTO CUSTOMER.CUSTOMER
    (CUSTOMER_ID, FIRST_NAME, LAST_NAME, ACCOUNT_STATUS, CUSTOMER_TYPE,
     PREFERRED_LANGUAGE, CREATED_AT, UPDATED_AT)
SELECT col1, col2, col3, col4, col5, col6, CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()
FROM VALUES
    ('CUST-SIM-R16-001', 'Ananya', 'Krishnaswamy', 'ACTIVE', 'RESIDENTIAL', 'EN'),
    ('CUST-SIM-R16-002', 'Brendan', 'Fitzpatrick', 'ACTIVE', 'RESIDENTIAL', 'EN'),
    ('CUST-SIM-R16-003', 'Layla', 'Nasser', 'ACTIVE', 'COMMERCIAL', 'EN'),
    ('CUST-SIM-R16-004', 'Mikael', 'Lindstrom', 'ACTIVE', 'RESIDENTIAL', 'EN'),
    ('CUST-SIM-R16-005', 'Amara', 'Keita', 'ACTIVE', 'RESIDENTIAL', 'EN'),
    ('CUST-SIM-R16-006', 'Bogdan', 'Popescu', 'ACTIVE', 'COMMERCIAL', 'EN'),
    ('CUST-SIM-R16-007', 'Consuelo', 'Vega', 'ACTIVE', 'RESIDENTIAL', 'EN'),
    ('CUST-SIM-R16-008', 'Daksh', 'Patel', 'ACTIVE', 'COMMERCIAL', 'EN'),
    ('CUST-SIM-R16-009', 'Euphrosyne', 'Stavrou', 'ACTIVE', 'RESIDENTIAL', 'EN'),
    ('CUST-SIM-R16-010', 'Fumito', 'Fujikawa', 'ACTIVE', 'COMMERCIAL', 'EN'),
    ('CUST-SIM-R16-011', 'Gudrun', 'Magnusdottir', 'ACTIVE', 'RESIDENTIAL', 'EN'),
    ('CUST-SIM-R16-012', 'Hussain', 'Al-Taher', 'ACTIVE', 'COMMERCIAL', 'AR'),
    ('CUST-SIM-R16-013', 'Ikaika', 'Makoa', 'ACTIVE', 'RESIDENTIAL', 'EN'),
    ('CUST-SIM-R16-014', 'Jaroslava', 'Horakova', 'ACTIVE', 'COMMERCIAL', 'EN'),
    ('CUST-SIM-R16-015', 'Kelvin', 'Asante-Boateng', 'ACTIVE', 'COMMERCIAL', 'EN'),
    ('CUST-SIM-R16-016', 'Luisa', 'Meier', 'ACTIVE', 'COMMERCIAL', 'DE'),
    ('CUST-SIM-R16-017', 'Mahmoud', 'Barakat', 'ACTIVE', 'COMMERCIAL', 'AR'),
    ('CUST-SIM-R16-018', 'Ngozi', 'Ibe', 'ACTIVE', 'COMMERCIAL', 'EN'),
    ('CUST-SIM-R16-019', 'Oswaldo', 'Fuentes', 'ACTIVE', 'COMMERCIAL', 'EN'),
    ('CUST-SIM-R16-020', 'Petra', 'Schulze', 'ACTIVE', 'COMMERCIAL', 'DE'),
    ('CUST-SIM-R16-021', 'Qadir', 'Sultani', 'ACTIVE', 'INDUSTRIAL', 'EN'),
    ('CUST-SIM-R16-022', 'Ruxandra', 'Ionescu', 'ACTIVE', 'INDUSTRIAL', 'EN'),
    ('CUST-SIM-R16-023', 'Seun', 'Adeyinka', 'ACTIVE', 'INDUSTRIAL', 'EN'),
    ('CUST-SIM-R16-024', 'Takuya', 'Masuda', 'ACTIVE', 'INDUSTRIAL', 'EN'),
    ('CUST-SIM-R16-025', 'Ulrikke', 'Andersen', 'ACTIVE', 'INDUSTRIAL', 'EN'),
    ('CUST-SIM-R16-026', 'Vito', 'Esposito', 'ACTIVE', 'INDUSTRIAL', 'EN'),
    ('CUST-SIM-R16-027', 'Wakako', 'Mori', 'ACTIVE', 'INDUSTRIAL', 'EN'),
    ('CUST-SIM-R16-028', 'Xabier', 'Etxebarria', 'ACTIVE', 'INDUSTRIAL', 'EN'),
    ('CUST-SIM-R16-029', 'Yetunde', 'Bamidele', 'ACTIVE', 'INDUSTRIAL', 'EN'),
    ('CUST-SIM-R16-030', 'Zoran', 'Jovanovic', 'ACTIVE', 'INDUSTRIAL', 'EN'),
    ('CUST-SIM-R16-031', 'Amara', 'Sidibe', 'ACTIVE', 'RESIDENTIAL', 'EN'),
    ('CUST-SIM-R16-032', 'Bartlomiej', 'Ostrowski', 'ACTIVE', 'RESIDENTIAL', 'EN'),
    ('CUST-SIM-R16-033', 'Clotilde', 'Fontaine', 'ACTIVE', 'RESIDENTIAL', 'FR'),
    ('CUST-SIM-R16-034', 'Devraj', 'Singh', 'ACTIVE', 'RESIDENTIAL', 'EN'),
    ('CUST-SIM-R16-035', 'Ebele', 'Nwosu', 'ACTIVE', 'RESIDENTIAL', 'EN'),
    ('CUST-SIM-R16-036', 'Freya', 'Magnusen', 'ACTIVE', 'RESIDENTIAL', 'EN'),
    ('CUST-SIM-R16-037', 'Ghaith', 'Al-Zubairi', 'ACTIVE', 'RESIDENTIAL', 'AR'),
    ('CUST-SIM-R16-038', 'Hiroko', 'Ikeda', 'ACTIVE', 'RESIDENTIAL', 'EN'),
    ('CUST-SIM-R16-039', 'Ionut', 'Munteanu', 'ACTIVE', 'RESIDENTIAL', 'EN'),
    ('CUST-SIM-R16-040', 'Josephina', 'Wachter', 'ACTIVE', 'RESIDENTIAL', 'DE')
    AS v(col1,col2,col3,col4,col5,col6)
WHERE NOT EXISTS (SELECT 1 FROM CUSTOMER.CUSTOMER WHERE CUSTOMER_ID = v.col1);

-- ============================================================
-- 16b.  Rejections: blank FIRST_NAME
-- ============================================================
INSERT INTO CUSTOMER.CUSTOMER
    (CUSTOMER_ID, FIRST_NAME, LAST_NAME, ACCOUNT_STATUS, CUSTOMER_TYPE,
     PREFERRED_LANGUAGE, CREATED_AT, UPDATED_AT)
SELECT col1, col2, col3, col4, col5, col6, CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()
FROM VALUES
    ('CUST-SIM-R16-RJ1', '', 'NoFirstA',  'ACTIVE', 'RESIDENTIAL', 'EN'),
    ('CUST-SIM-R16-RJ2', '', 'NoFirstB',  'ACTIVE', 'COMMERCIAL',  'EN')
    AS v(col1,col2,col3,col4,col5,col6)
WHERE NOT EXISTS (SELECT 1 FROM CUSTOMER.CUSTOMER WHERE CUSTOMER_ID = v.col1);

-- ============================================================
-- 16c.  Primary email contacts — all 40 valid customers
-- ============================================================
INSERT INTO CUSTOMER.CUSTOMER_CONTACT
    (CONTACT_ID, CUSTOMER_ID, CONTACT_TYPE, CONTACT_VALUE,
     IS_PRIMARY, IS_VERIFIED, EFFECTIVE_DATE, CREATED_AT, UPDATED_AT)
SELECT col1, col2, col3, col4, TRUE, TRUE, CURRENT_DATE(), CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()
FROM VALUES
    ('CC-SIM-R16-001E', 'CUST-SIM-R16-001', 'EMAIL', 'ananya.krishnaswamy@demo.com'),
    ('CC-SIM-R16-002E', 'CUST-SIM-R16-002', 'EMAIL', 'brendan.fitzpatrick@demo.com'),
    ('CC-SIM-R16-003E', 'CUST-SIM-R16-003', 'EMAIL', 'layla.nasser@demo.com'),
    ('CC-SIM-R16-004E', 'CUST-SIM-R16-004', 'EMAIL', 'mikael.lindstrom@demo.com'),
    ('CC-SIM-R16-005E', 'CUST-SIM-R16-005', 'EMAIL', 'amara.keita@demo.com'),
    ('CC-SIM-R16-006E', 'CUST-SIM-R16-006', 'EMAIL', 'bogdan.popescu@demo.com'),
    ('CC-SIM-R16-007E', 'CUST-SIM-R16-007', 'EMAIL', 'consuelo.vega@demo.com'),
    ('CC-SIM-R16-008E', 'CUST-SIM-R16-008', 'EMAIL', 'daksh.patel@demo.com'),
    ('CC-SIM-R16-009E', 'CUST-SIM-R16-009', 'EMAIL', 'euphrosyne.stavrou@demo.com'),
    ('CC-SIM-R16-010E', 'CUST-SIM-R16-010', 'EMAIL', 'fumito.fujikawa@demo.com'),
    ('CC-SIM-R16-011E', 'CUST-SIM-R16-011', 'EMAIL', 'gudrun.magnusdottir@demo.com'),
    ('CC-SIM-R16-012E', 'CUST-SIM-R16-012', 'EMAIL', 'hussain.al-taher@demo.com'),
    ('CC-SIM-R16-013E', 'CUST-SIM-R16-013', 'EMAIL', 'ikaika.makoa@demo.com'),
    ('CC-SIM-R16-014E', 'CUST-SIM-R16-014', 'EMAIL', 'jaroslava.horakova@demo.com'),
    ('CC-SIM-R16-015E', 'CUST-SIM-R16-015', 'EMAIL', 'kelvin.asante-boateng@demo.com'),
    ('CC-SIM-R16-016E', 'CUST-SIM-R16-016', 'EMAIL', 'luisa.meier@demo.com'),
    ('CC-SIM-R16-017E', 'CUST-SIM-R16-017', 'EMAIL', 'mahmoud.barakat@demo.com'),
    ('CC-SIM-R16-018E', 'CUST-SIM-R16-018', 'EMAIL', 'ngozi.ibe@demo.com'),
    ('CC-SIM-R16-019E', 'CUST-SIM-R16-019', 'EMAIL', 'oswaldo.fuentes@demo.com'),
    ('CC-SIM-R16-020E', 'CUST-SIM-R16-020', 'EMAIL', 'petra.schulze@demo.com'),
    ('CC-SIM-R16-021E', 'CUST-SIM-R16-021', 'EMAIL', 'qadir.sultani@demo.com'),
    ('CC-SIM-R16-022E', 'CUST-SIM-R16-022', 'EMAIL', 'ruxandra.ionescu@demo.com'),
    ('CC-SIM-R16-023E', 'CUST-SIM-R16-023', 'EMAIL', 'seun.adeyinka@demo.com'),
    ('CC-SIM-R16-024E', 'CUST-SIM-R16-024', 'EMAIL', 'takuya.masuda@demo.com'),
    ('CC-SIM-R16-025E', 'CUST-SIM-R16-025', 'EMAIL', 'ulrikke.andersen@demo.com'),
    ('CC-SIM-R16-026E', 'CUST-SIM-R16-026', 'EMAIL', 'vito.esposito@demo.com'),
    ('CC-SIM-R16-027E', 'CUST-SIM-R16-027', 'EMAIL', 'wakako.mori@demo.com'),
    ('CC-SIM-R16-028E', 'CUST-SIM-R16-028', 'EMAIL', 'xabier.etxebarria@demo.com'),
    ('CC-SIM-R16-029E', 'CUST-SIM-R16-029', 'EMAIL', 'yetunde.bamidele@demo.com'),
    ('CC-SIM-R16-030E', 'CUST-SIM-R16-030', 'EMAIL', 'zoran.jovanovic@demo.com'),
    ('CC-SIM-R16-031E', 'CUST-SIM-R16-031', 'EMAIL', 'amara.sidibe@demo.com'),
    ('CC-SIM-R16-032E', 'CUST-SIM-R16-032', 'EMAIL', 'bartlomiej.ostrowski@demo.com'),
    ('CC-SIM-R16-033E', 'CUST-SIM-R16-033', 'EMAIL', 'clotilde.fontaine@demo.com'),
    ('CC-SIM-R16-034E', 'CUST-SIM-R16-034', 'EMAIL', 'devraj.singh@demo.com'),
    ('CC-SIM-R16-035E', 'CUST-SIM-R16-035', 'EMAIL', 'ebele.nwosu@demo.com'),
    ('CC-SIM-R16-036E', 'CUST-SIM-R16-036', 'EMAIL', 'freya.magnusen@demo.com'),
    ('CC-SIM-R16-037E', 'CUST-SIM-R16-037', 'EMAIL', 'ghaith.al-zubairi@demo.com'),
    ('CC-SIM-R16-038E', 'CUST-SIM-R16-038', 'EMAIL', 'hiroko.ikeda@demo.com'),
    ('CC-SIM-R16-039E', 'CUST-SIM-R16-039', 'EMAIL', 'ionut.munteanu@demo.com'),
    ('CC-SIM-R16-040E', 'CUST-SIM-R16-040', 'EMAIL', 'josephina.wachter@demo.com')
    AS v(col1,col2,col3,col4)
WHERE NOT EXISTS (SELECT 1 FROM CUSTOMER.CUSTOMER_CONTACT WHERE CONTACT_ID = v.col1);

-- ============================================================
-- 16d.  Phone contacts — first 20 customers
-- ============================================================
INSERT INTO CUSTOMER.CUSTOMER_CONTACT
    (CONTACT_ID, CUSTOMER_ID, CONTACT_TYPE, CONTACT_VALUE,
     IS_PRIMARY, IS_VERIFIED, EFFECTIVE_DATE, CREATED_AT, UPDATED_AT)
SELECT col1, col2, col3, col4, TRUE, FALSE, CURRENT_DATE(), CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()
FROM VALUES
    ('CC-SIM-R16-001P', 'CUST-SIM-R16-001', 'PHONE', '555-1601'),
    ('CC-SIM-R16-002P', 'CUST-SIM-R16-002', 'PHONE', '555-1602'),
    ('CC-SIM-R16-003P', 'CUST-SIM-R16-003', 'PHONE', '555-1603'),
    ('CC-SIM-R16-004P', 'CUST-SIM-R16-004', 'PHONE', '555-1604'),
    ('CC-SIM-R16-005P', 'CUST-SIM-R16-005', 'PHONE', '555-1605'),
    ('CC-SIM-R16-006P', 'CUST-SIM-R16-006', 'PHONE', '555-1606'),
    ('CC-SIM-R16-007P', 'CUST-SIM-R16-007', 'PHONE', '555-1607'),
    ('CC-SIM-R16-008P', 'CUST-SIM-R16-008', 'PHONE', '555-1608'),
    ('CC-SIM-R16-009P', 'CUST-SIM-R16-009', 'PHONE', '555-1609'),
    ('CC-SIM-R16-010P', 'CUST-SIM-R16-010', 'PHONE', '555-1610'),
    ('CC-SIM-R16-011P', 'CUST-SIM-R16-011', 'PHONE', '555-1611'),
    ('CC-SIM-R16-012P', 'CUST-SIM-R16-012', 'PHONE', '555-1612'),
    ('CC-SIM-R16-013P', 'CUST-SIM-R16-013', 'PHONE', '555-1613'),
    ('CC-SIM-R16-014P', 'CUST-SIM-R16-014', 'PHONE', '555-1614'),
    ('CC-SIM-R16-015P', 'CUST-SIM-R16-015', 'PHONE', '555-1615'),
    ('CC-SIM-R16-016P', 'CUST-SIM-R16-016', 'PHONE', '555-1616'),
    ('CC-SIM-R16-017P', 'CUST-SIM-R16-017', 'PHONE', '555-1617'),
    ('CC-SIM-R16-018P', 'CUST-SIM-R16-018', 'PHONE', '555-1618'),
    ('CC-SIM-R16-019P', 'CUST-SIM-R16-019', 'PHONE', '555-1619'),
    ('CC-SIM-R16-020P', 'CUST-SIM-R16-020', 'PHONE', '555-1620')
    AS v(col1,col2,col3,col4)
WHERE NOT EXISTS (SELECT 1 FROM CUSTOMER.CUSTOMER_CONTACT WHERE CONTACT_ID = v.col1);

-- ============================================================
-- 16e.  Rejections: invalid email (no @)
-- ============================================================
INSERT INTO CUSTOMER.CUSTOMER_CONTACT
    (CONTACT_ID, CUSTOMER_ID, CONTACT_TYPE, CONTACT_VALUE,
     IS_PRIMARY, IS_VERIFIED, EFFECTIVE_DATE, CREATED_AT, UPDATED_AT)
SELECT col1, col2, col3, col4, TRUE, FALSE, CURRENT_DATE(), CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()
FROM VALUES
    ('CC-SIM-R16-RJE1', 'CUST-SIM-R16-001', 'EMAIL', 'invalid.email.nodomain'),
    ('CC-SIM-R16-RJE2', 'CUST-SIM-R16-002', 'EMAIL', 'also-not-valid-email')
    AS v(col1,col2,col3,col4)
WHERE NOT EXISTS (SELECT 1 FROM CUSTOMER.CUSTOMER_CONTACT WHERE CONTACT_ID = v.col1);

-- ============================================================
-- 16f.  Energy accounts — 40 primary + 4 second accounts
-- ============================================================
INSERT INTO CUSTOMER.ENERGY_ACCOUNT
    (ENERGY_ACCOUNT_ID, CUSTOMER_ID, ACCOUNT_NUMBER, ACCOUNT_STATUS,
     SERVICE_TYPE, RATE_CLASS, OPEN_DATE, CREATED_AT, UPDATED_AT)
SELECT col1, col2, col3, col4, col5, col6, CURRENT_DATE(), CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()
FROM VALUES
    ('EA-SIM-R16-001', 'CUST-SIM-R16-001', 'ACCT-SIM-R16-001', 'ACTIVE', 'ELECTRIC', 'RESIDENTIAL'),
    ('EA-SIM-R16-002', 'CUST-SIM-R16-002', 'ACCT-SIM-R16-002', 'ACTIVE', 'ELECTRIC', 'RESIDENTIAL'),
    ('EA-SIM-R16-003', 'CUST-SIM-R16-003', 'ACCT-SIM-R16-003', 'ACTIVE', 'ELECTRIC', 'SMALL_COMMERCIAL'),
    ('EA-SIM-R16-004', 'CUST-SIM-R16-004', 'ACCT-SIM-R16-004', 'ACTIVE', 'ELECTRIC', 'RESIDENTIAL'),
    ('EA-SIM-R16-005', 'CUST-SIM-R16-005', 'ACCT-SIM-R16-005', 'ACTIVE', 'ELECTRIC', 'RESIDENTIAL'),
    ('EA-SIM-R16-006', 'CUST-SIM-R16-006', 'ACCT-SIM-R16-006', 'ACTIVE', 'ELECTRIC', 'SMALL_COMMERCIAL'),
    ('EA-SIM-R16-007', 'CUST-SIM-R16-007', 'ACCT-SIM-R16-007', 'ACTIVE', 'ELECTRIC', 'RESIDENTIAL'),
    ('EA-SIM-R16-008', 'CUST-SIM-R16-008', 'ACCT-SIM-R16-008', 'ACTIVE', 'ELECTRIC', 'SMALL_COMMERCIAL'),
    ('EA-SIM-R16-009', 'CUST-SIM-R16-009', 'ACCT-SIM-R16-009', 'ACTIVE', 'ELECTRIC', 'RESIDENTIAL'),
    ('EA-SIM-R16-010', 'CUST-SIM-R16-010', 'ACCT-SIM-R16-010', 'ACTIVE', 'ELECTRIC', 'SMALL_COMMERCIAL'),
    ('EA-SIM-R16-011', 'CUST-SIM-R16-011', 'ACCT-SIM-R16-011', 'ACTIVE', 'ELECTRIC', 'RESIDENTIAL'),
    ('EA-SIM-R16-012', 'CUST-SIM-R16-012', 'ACCT-SIM-R16-012', 'ACTIVE', 'ELECTRIC', 'SMALL_COMMERCIAL'),
    ('EA-SIM-R16-013', 'CUST-SIM-R16-013', 'ACCT-SIM-R16-013', 'ACTIVE', 'ELECTRIC', 'RESIDENTIAL'),
    ('EA-SIM-R16-014', 'CUST-SIM-R16-014', 'ACCT-SIM-R16-014', 'ACTIVE', 'ELECTRIC', 'SMALL_COMMERCIAL'),
    ('EA-SIM-R16-015', 'CUST-SIM-R16-015', 'ACCT-SIM-R16-015', 'ACTIVE', 'ELECTRIC', 'SMALL_COMMERCIAL'),
    ('EA-SIM-R16-016', 'CUST-SIM-R16-016', 'ACCT-SIM-R16-016', 'ACTIVE', 'ELECTRIC', 'SMALL_COMMERCIAL'),
    ('EA-SIM-R16-017', 'CUST-SIM-R16-017', 'ACCT-SIM-R16-017', 'ACTIVE', 'ELECTRIC', 'SMALL_COMMERCIAL'),
    ('EA-SIM-R16-018', 'CUST-SIM-R16-018', 'ACCT-SIM-R16-018', 'ACTIVE', 'ELECTRIC', 'SMALL_COMMERCIAL'),
    ('EA-SIM-R16-019', 'CUST-SIM-R16-019', 'ACCT-SIM-R16-019', 'ACTIVE', 'ELECTRIC', 'SMALL_COMMERCIAL'),
    ('EA-SIM-R16-020', 'CUST-SIM-R16-020', 'ACCT-SIM-R16-020', 'ACTIVE', 'ELECTRIC', 'SMALL_COMMERCIAL'),
    ('EA-SIM-R16-021', 'CUST-SIM-R16-021', 'ACCT-SIM-R16-021', 'ACTIVE', 'ELECTRIC', 'LARGE_INDUSTRIAL'),
    ('EA-SIM-R16-022', 'CUST-SIM-R16-022', 'ACCT-SIM-R16-022', 'ACTIVE', 'ELECTRIC', 'LARGE_INDUSTRIAL'),
    ('EA-SIM-R16-023', 'CUST-SIM-R16-023', 'ACCT-SIM-R16-023', 'ACTIVE', 'ELECTRIC', 'LARGE_INDUSTRIAL'),
    ('EA-SIM-R16-024', 'CUST-SIM-R16-024', 'ACCT-SIM-R16-024', 'ACTIVE', 'ELECTRIC', 'LARGE_INDUSTRIAL'),
    ('EA-SIM-R16-025', 'CUST-SIM-R16-025', 'ACCT-SIM-R16-025', 'ACTIVE', 'ELECTRIC', 'LARGE_INDUSTRIAL'),
    ('EA-SIM-R16-026', 'CUST-SIM-R16-026', 'ACCT-SIM-R16-026', 'ACTIVE', 'ELECTRIC', 'LARGE_INDUSTRIAL'),
    ('EA-SIM-R16-027', 'CUST-SIM-R16-027', 'ACCT-SIM-R16-027', 'ACTIVE', 'ELECTRIC', 'LARGE_INDUSTRIAL'),
    ('EA-SIM-R16-028', 'CUST-SIM-R16-028', 'ACCT-SIM-R16-028', 'ACTIVE', 'ELECTRIC', 'LARGE_INDUSTRIAL'),
    ('EA-SIM-R16-029', 'CUST-SIM-R16-029', 'ACCT-SIM-R16-029', 'ACTIVE', 'ELECTRIC', 'LARGE_INDUSTRIAL'),
    ('EA-SIM-R16-030', 'CUST-SIM-R16-030', 'ACCT-SIM-R16-030', 'ACTIVE', 'ELECTRIC', 'LARGE_INDUSTRIAL'),
    ('EA-SIM-R16-031', 'CUST-SIM-R16-031', 'ACCT-SIM-R16-031', 'ACTIVE', 'ELECTRIC', 'RESIDENTIAL'),
    ('EA-SIM-R16-032', 'CUST-SIM-R16-032', 'ACCT-SIM-R16-032', 'ACTIVE', 'ELECTRIC', 'RESIDENTIAL'),
    ('EA-SIM-R16-033', 'CUST-SIM-R16-033', 'ACCT-SIM-R16-033', 'ACTIVE', 'ELECTRIC', 'RESIDENTIAL'),
    ('EA-SIM-R16-034', 'CUST-SIM-R16-034', 'ACCT-SIM-R16-034', 'ACTIVE', 'ELECTRIC', 'RESIDENTIAL'),
    ('EA-SIM-R16-035', 'CUST-SIM-R16-035', 'ACCT-SIM-R16-035', 'ACTIVE', 'ELECTRIC', 'RESIDENTIAL'),
    ('EA-SIM-R16-036', 'CUST-SIM-R16-036', 'ACCT-SIM-R16-036', 'ACTIVE', 'ELECTRIC', 'RESIDENTIAL'),
    ('EA-SIM-R16-037', 'CUST-SIM-R16-037', 'ACCT-SIM-R16-037', 'ACTIVE', 'ELECTRIC', 'RESIDENTIAL'),
    ('EA-SIM-R16-038', 'CUST-SIM-R16-038', 'ACCT-SIM-R16-038', 'ACTIVE', 'ELECTRIC', 'RESIDENTIAL'),
    ('EA-SIM-R16-039', 'CUST-SIM-R16-039', 'ACCT-SIM-R16-039', 'ACTIVE', 'ELECTRIC', 'RESIDENTIAL'),
    ('EA-SIM-R16-040', 'CUST-SIM-R16-040', 'ACCT-SIM-R16-040', 'ACTIVE', 'ELECTRIC', 'RESIDENTIAL'),
    ('EA-SIM-R16-B01', 'CUST-SIM-R16-001', 'ACCT-SIM-R16-B01', 'ACTIVE', 'ELECTRIC', 'RESIDENTIAL'),
    ('EA-SIM-R16-B05', 'CUST-SIM-R16-005', 'ACCT-SIM-R16-B05', 'ACTIVE', 'ELECTRIC', 'RESIDENTIAL'),
    ('EA-SIM-R16-B14', 'CUST-SIM-R16-014', 'ACCT-SIM-R16-B14', 'ACTIVE', 'ELECTRIC', 'SMALL_COMMERCIAL'),
    ('EA-SIM-R16-B31', 'CUST-SIM-R16-031', 'ACCT-SIM-R16-B31', 'ACTIVE', 'ELECTRIC', 'RESIDENTIAL')
    AS v(col1,col2,col3,col4,col5,col6)
WHERE NOT EXISTS (SELECT 1 FROM CUSTOMER.ENERGY_ACCOUNT WHERE ENERGY_ACCOUNT_ID = v.col1);

-- ============================================================
-- 16g.  Cross-round updates — previous cohorts
-- ============================================================
UPDATE CUSTOMER.CUSTOMER
SET PREFERRED_LANGUAGE = 'ES', UPDATED_AT = CURRENT_TIMESTAMP()
WHERE CUSTOMER_ID IN (
    'CUST-SIM-R15-001','CUST-SIM-R15-002','CUST-SIM-R15-003',
    'CUST-SIM-R15-004','CUST-SIM-R15-005'
);

UPDATE CUSTOMER.CUSTOMER_CONTACT
SET IS_VERIFIED = TRUE, UPDATED_AT = CURRENT_TIMESTAMP()
WHERE CONTACT_ID IN (
    'CC-SIM-R15-021E','CC-SIM-R15-022E','CC-SIM-R15-023E',
    'CC-SIM-R15-024E','CC-SIM-R15-025E','CC-SIM-R15-026E',
    'CC-SIM-R15-027E','CC-SIM-R15-028E','CC-SIM-R15-029E',
    'CC-SIM-R15-030E'
);

UPDATE CUSTOMER.CUSTOMER_CONTACT
SET IS_VERIFIED = TRUE, UPDATED_AT = CURRENT_TIMESTAMP()
WHERE CONTACT_ID IN (
    'CC-SIM-R15-001P','CC-SIM-R15-002P','CC-SIM-R15-003P',
    'CC-SIM-R15-004P','CC-SIM-R15-005P','CC-SIM-R15-006P',
    'CC-SIM-R15-007P','CC-SIM-R15-008P','CC-SIM-R15-009P',
    'CC-SIM-R15-010P'
);

UPDATE CUSTOMER.ENERGY_ACCOUNT
SET ACCOUNT_STATUS = 'SUSPENDED', UPDATED_AT = CURRENT_TIMESTAMP()
WHERE ENERGY_ACCOUNT_ID IN ('EA-SIM-R14-005', 'EA-SIM-R14-010');

UPDATE CUSTOMER.ENERGY_ACCOUNT
SET ACCOUNT_STATUS = 'ACTIVE', UPDATED_AT = CURRENT_TIMESTAMP()
WHERE ENERGY_ACCOUNT_ID IN ('EA-SIM-R13-005', 'EA-SIM-R13-010');

-- Verification
SELECT 'R16 customers inserted'      AS label, COUNT(*) AS cnt FROM CUSTOMER.CUSTOMER       WHERE CUSTOMER_ID       LIKE 'CUST-SIM-R16-%'
UNION ALL
SELECT 'R16 energy accounts inserted',          COUNT(*)        FROM CUSTOMER.ENERGY_ACCOUNT WHERE ENERGY_ACCOUNT_ID LIKE 'EA-SIM-R16-%'
UNION ALL
SELECT 'R16 email contacts inserted',           COUNT(*)        FROM CUSTOMER.CUSTOMER_CONTACT WHERE CONTACT_ID      LIKE 'CC-SIM-R16-%'
ORDER BY 1;
