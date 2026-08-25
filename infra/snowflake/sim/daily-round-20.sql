-- =============================================================================
-- Daily Load Simulation — Round 20
-- =============================================================================
-- Run as: CDP_ADMIN_ROLE  |  Database: CDP_UTIL_DB  |  Warehouse: CDP_LOADER_WH
--
-- SCENARIO  Large customer wave — 40 customers across all types
-- REJECTION REJ-D1: blank FIRST_NAME (VR-CUST-001) x 2
--           REJ-D2: invalid email (VR-CONT-001) x 2
-- TRIGGER   POST http://localhost:8080/api/jobs/daily
-- PREREQUISITE  daily-round-19.sql must have been run.
-- CUSTOMERS  40 valid + 2 blank-name rejections
-- ACCOUNTS   44 energy accounts (incl. 4 second accounts)
-- CONTACTS   40 email + 20 phone + 2 invalid email rejections
-- =============================================================================

USE ROLE CDP_ADMIN_ROLE;
USE DATABASE CDP_UTIL_DB;
USE WAREHOUSE CDP_LOADER_WH;

-- ============================================================
-- 20a.  New customers — 40 valid rows
-- ============================================================
INSERT INTO CUSTOMER.CUSTOMER
    (CUSTOMER_ID, FIRST_NAME, LAST_NAME, ACCOUNT_STATUS, CUSTOMER_TYPE,
     PREFERRED_LANGUAGE, CREATED_AT, UPDATED_AT)
SELECT col1, col2, col3, col4, col5, col6, CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()
FROM VALUES
    ('CUST-SIM-R20-001', 'Apex', 'Logistics', 'ACTIVE', 'COMMERCIAL', 'EN'),
    ('CUST-SIM-R20-002', 'Brightway', 'Hotels', 'ACTIVE', 'COMMERCIAL', 'EN'),
    ('CUST-SIM-R20-003', 'Clearview', 'Tech', 'ACTIVE', 'INDUSTRIAL', 'EN'),
    ('CUST-SIM-R20-004', 'Dawnfield', 'Farms', 'ACTIVE', 'COMMERCIAL', 'EN'),
    ('CUST-SIM-R20-005', 'Everest', 'Publishing', 'ACTIVE', 'COMMERCIAL', 'EN'),
    ('CUST-SIM-R20-006', 'Falconridge', 'Energy', 'ACTIVE', 'INDUSTRIAL', 'EN'),
    ('CUST-SIM-R20-007', 'Greystone', 'Finance', 'ACTIVE', 'COMMERCIAL', 'EN'),
    ('CUST-SIM-R20-008', 'Horizon', 'Shipping', 'ACTIVE', 'INDUSTRIAL', 'EN'),
    ('CUST-SIM-R20-009', 'Ironclad', 'Manufacturing', 'ACTIVE', 'INDUSTRIAL', 'EN'),
    ('CUST-SIM-R20-010', 'Jubilee', 'Healthcare', 'ACTIVE', 'COMMERCIAL', 'EN'),
    ('CUST-SIM-R20-011', 'Kinetic', 'Solutions', 'ACTIVE', 'COMMERCIAL', 'EN'),
    ('CUST-SIM-R20-012', 'Lighthouse', 'Media', 'ACTIVE', 'COMMERCIAL', 'EN'),
    ('CUST-SIM-R20-013', 'Meridian', 'Retail', 'ACTIVE', 'COMMERCIAL', 'EN'),
    ('CUST-SIM-R20-014', 'Nexus', 'Biotech', 'ACTIVE', 'INDUSTRIAL', 'EN'),
    ('CUST-SIM-R20-015', 'Orion', 'Logistics', 'ACTIVE', 'INDUSTRIAL', 'EN'),
    ('CUST-SIM-R20-016', 'Pinnacle', 'Hospitality', 'ACTIVE', 'COMMERCIAL', 'EN'),
    ('CUST-SIM-R20-017', 'Quantum', 'Research', 'ACTIVE', 'INDUSTRIAL', 'EN'),
    ('CUST-SIM-R20-018', 'Radiance', 'Solar', 'ACTIVE', 'INDUSTRIAL', 'EN'),
    ('CUST-SIM-R20-019', 'Summit', 'Consulting', 'ACTIVE', 'COMMERCIAL', 'EN'),
    ('CUST-SIM-R20-020', 'Titan', 'Steel', 'ACTIVE', 'INDUSTRIAL', 'EN'),
    ('CUST-SIM-R20-021', 'Uluru', 'Resources', 'ACTIVE', 'INDUSTRIAL', 'EN'),
    ('CUST-SIM-R20-022', 'Vanguard', 'Capital', 'ACTIVE', 'COMMERCIAL', 'EN'),
    ('CUST-SIM-R20-023', 'Westbridge', 'Retail', 'ACTIVE', 'COMMERCIAL', 'EN'),
    ('CUST-SIM-R20-024', 'Xtreme', 'Fitness', 'ACTIVE', 'COMMERCIAL', 'EN'),
    ('CUST-SIM-R20-025', 'Yellowstone', 'Agri', 'ACTIVE', 'COMMERCIAL', 'EN'),
    ('CUST-SIM-R20-026', 'Zenith', 'Aviation', 'ACTIVE', 'INDUSTRIAL', 'EN'),
    ('CUST-SIM-R20-027', 'Atlas', 'Distribution', 'ACTIVE', 'INDUSTRIAL', 'EN'),
    ('CUST-SIM-R20-028', 'Beacon', 'Infrastructure', 'ACTIVE', 'INDUSTRIAL', 'EN'),
    ('CUST-SIM-R20-029', 'Cascade', 'Water', 'ACTIVE', 'INDUSTRIAL', 'EN'),
    ('CUST-SIM-R20-030', 'Delta', 'Transport', 'ACTIVE', 'INDUSTRIAL', 'EN'),
    ('CUST-SIM-R20-031', 'Echo', 'Electronics', 'ACTIVE', 'INDUSTRIAL', 'EN'),
    ('CUST-SIM-R20-032', 'Frontier', 'Pharma', 'ACTIVE', 'COMMERCIAL', 'EN'),
    ('CUST-SIM-R20-033', 'Galaxy', 'Foods', 'ACTIVE', 'COMMERCIAL', 'EN'),
    ('CUST-SIM-R20-034', 'Harbor', 'Freight', 'ACTIVE', 'INDUSTRIAL', 'EN'),
    ('CUST-SIM-R20-035', 'Infinity', 'Networks', 'ACTIVE', 'COMMERCIAL', 'EN'),
    ('CUST-SIM-R20-036', 'Jetstream', 'Air', 'ACTIVE', 'INDUSTRIAL', 'EN'),
    ('CUST-SIM-R20-037', 'Kingfisher', 'Marine', 'ACTIVE', 'INDUSTRIAL', 'EN'),
    ('CUST-SIM-R20-038', 'Lodestar', 'Energy', 'ACTIVE', 'INDUSTRIAL', 'EN'),
    ('CUST-SIM-R20-039', 'Maple', 'Finance', 'ACTIVE', 'COMMERCIAL', 'EN'),
    ('CUST-SIM-R20-040', 'Neptune', 'Resources', 'ACTIVE', 'INDUSTRIAL', 'EN')
    AS v(col1,col2,col3,col4,col5,col6)
WHERE NOT EXISTS (SELECT 1 FROM CUSTOMER.CUSTOMER WHERE CUSTOMER_ID = v.col1);

-- ============================================================
-- 20b.  Rejections: blank FIRST_NAME
-- ============================================================
INSERT INTO CUSTOMER.CUSTOMER
    (CUSTOMER_ID, FIRST_NAME, LAST_NAME, ACCOUNT_STATUS, CUSTOMER_TYPE,
     PREFERRED_LANGUAGE, CREATED_AT, UPDATED_AT)
SELECT col1, col2, col3, col4, col5, col6, CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()
FROM VALUES
    ('CUST-SIM-R20-RJ1', '', 'NoFirstA',  'ACTIVE', 'RESIDENTIAL', 'EN'),
    ('CUST-SIM-R20-RJ2', '', 'NoFirstB',  'ACTIVE', 'COMMERCIAL',  'EN')
    AS v(col1,col2,col3,col4,col5,col6)
WHERE NOT EXISTS (SELECT 1 FROM CUSTOMER.CUSTOMER WHERE CUSTOMER_ID = v.col1);

-- ============================================================
-- 20c.  Primary email contacts — all 40 valid customers
-- ============================================================
INSERT INTO CUSTOMER.CUSTOMER_CONTACT
    (CONTACT_ID, CUSTOMER_ID, CONTACT_TYPE, CONTACT_VALUE,
     IS_PRIMARY, IS_VERIFIED, EFFECTIVE_DATE, CREATED_AT, UPDATED_AT)
SELECT col1, col2, col3, col4, TRUE, TRUE, CURRENT_DATE(), CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()
FROM VALUES
    ('CC-SIM-R20-001E', 'CUST-SIM-R20-001', 'EMAIL', 'apex.logistics@demo.com'),
    ('CC-SIM-R20-002E', 'CUST-SIM-R20-002', 'EMAIL', 'brightway.hotels@demo.com'),
    ('CC-SIM-R20-003E', 'CUST-SIM-R20-003', 'EMAIL', 'clearview.tech@demo.com'),
    ('CC-SIM-R20-004E', 'CUST-SIM-R20-004', 'EMAIL', 'dawnfield.farms@demo.com'),
    ('CC-SIM-R20-005E', 'CUST-SIM-R20-005', 'EMAIL', 'everest.publishing@demo.com'),
    ('CC-SIM-R20-006E', 'CUST-SIM-R20-006', 'EMAIL', 'falconridge.energy@demo.com'),
    ('CC-SIM-R20-007E', 'CUST-SIM-R20-007', 'EMAIL', 'greystone.finance@demo.com'),
    ('CC-SIM-R20-008E', 'CUST-SIM-R20-008', 'EMAIL', 'horizon.shipping@demo.com'),
    ('CC-SIM-R20-009E', 'CUST-SIM-R20-009', 'EMAIL', 'ironclad.manufacturing@demo.com'),
    ('CC-SIM-R20-010E', 'CUST-SIM-R20-010', 'EMAIL', 'jubilee.healthcare@demo.com'),
    ('CC-SIM-R20-011E', 'CUST-SIM-R20-011', 'EMAIL', 'kinetic.solutions@demo.com'),
    ('CC-SIM-R20-012E', 'CUST-SIM-R20-012', 'EMAIL', 'lighthouse.media@demo.com'),
    ('CC-SIM-R20-013E', 'CUST-SIM-R20-013', 'EMAIL', 'meridian.retail@demo.com'),
    ('CC-SIM-R20-014E', 'CUST-SIM-R20-014', 'EMAIL', 'nexus.biotech@demo.com'),
    ('CC-SIM-R20-015E', 'CUST-SIM-R20-015', 'EMAIL', 'orion.logistics@demo.com'),
    ('CC-SIM-R20-016E', 'CUST-SIM-R20-016', 'EMAIL', 'pinnacle.hospitality@demo.com'),
    ('CC-SIM-R20-017E', 'CUST-SIM-R20-017', 'EMAIL', 'quantum.research@demo.com'),
    ('CC-SIM-R20-018E', 'CUST-SIM-R20-018', 'EMAIL', 'radiance.solar@demo.com'),
    ('CC-SIM-R20-019E', 'CUST-SIM-R20-019', 'EMAIL', 'summit.consulting@demo.com'),
    ('CC-SIM-R20-020E', 'CUST-SIM-R20-020', 'EMAIL', 'titan.steel@demo.com'),
    ('CC-SIM-R20-021E', 'CUST-SIM-R20-021', 'EMAIL', 'uluru.resources@demo.com'),
    ('CC-SIM-R20-022E', 'CUST-SIM-R20-022', 'EMAIL', 'vanguard.capital@demo.com'),
    ('CC-SIM-R20-023E', 'CUST-SIM-R20-023', 'EMAIL', 'westbridge.retail@demo.com'),
    ('CC-SIM-R20-024E', 'CUST-SIM-R20-024', 'EMAIL', 'xtreme.fitness@demo.com'),
    ('CC-SIM-R20-025E', 'CUST-SIM-R20-025', 'EMAIL', 'yellowstone.agri@demo.com'),
    ('CC-SIM-R20-026E', 'CUST-SIM-R20-026', 'EMAIL', 'zenith.aviation@demo.com'),
    ('CC-SIM-R20-027E', 'CUST-SIM-R20-027', 'EMAIL', 'atlas.distribution@demo.com'),
    ('CC-SIM-R20-028E', 'CUST-SIM-R20-028', 'EMAIL', 'beacon.infrastructure@demo.com'),
    ('CC-SIM-R20-029E', 'CUST-SIM-R20-029', 'EMAIL', 'cascade.water@demo.com'),
    ('CC-SIM-R20-030E', 'CUST-SIM-R20-030', 'EMAIL', 'delta.transport@demo.com'),
    ('CC-SIM-R20-031E', 'CUST-SIM-R20-031', 'EMAIL', 'echo.electronics@demo.com'),
    ('CC-SIM-R20-032E', 'CUST-SIM-R20-032', 'EMAIL', 'frontier.pharma@demo.com'),
    ('CC-SIM-R20-033E', 'CUST-SIM-R20-033', 'EMAIL', 'galaxy.foods@demo.com'),
    ('CC-SIM-R20-034E', 'CUST-SIM-R20-034', 'EMAIL', 'harbor.freight@demo.com'),
    ('CC-SIM-R20-035E', 'CUST-SIM-R20-035', 'EMAIL', 'infinity.networks@demo.com'),
    ('CC-SIM-R20-036E', 'CUST-SIM-R20-036', 'EMAIL', 'jetstream.air@demo.com'),
    ('CC-SIM-R20-037E', 'CUST-SIM-R20-037', 'EMAIL', 'kingfisher.marine@demo.com'),
    ('CC-SIM-R20-038E', 'CUST-SIM-R20-038', 'EMAIL', 'lodestar.energy@demo.com'),
    ('CC-SIM-R20-039E', 'CUST-SIM-R20-039', 'EMAIL', 'maple.finance@demo.com'),
    ('CC-SIM-R20-040E', 'CUST-SIM-R20-040', 'EMAIL', 'neptune.resources@demo.com')
    AS v(col1,col2,col3,col4)
WHERE NOT EXISTS (SELECT 1 FROM CUSTOMER.CUSTOMER_CONTACT WHERE CONTACT_ID = v.col1);

-- ============================================================
-- 20d.  Phone contacts — first 20 customers
-- ============================================================
INSERT INTO CUSTOMER.CUSTOMER_CONTACT
    (CONTACT_ID, CUSTOMER_ID, CONTACT_TYPE, CONTACT_VALUE,
     IS_PRIMARY, IS_VERIFIED, EFFECTIVE_DATE, CREATED_AT, UPDATED_AT)
SELECT col1, col2, col3, col4, TRUE, FALSE, CURRENT_DATE(), CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()
FROM VALUES
    ('CC-SIM-R20-001P', 'CUST-SIM-R20-001', 'PHONE', '555-2001'),
    ('CC-SIM-R20-002P', 'CUST-SIM-R20-002', 'PHONE', '555-2002'),
    ('CC-SIM-R20-003P', 'CUST-SIM-R20-003', 'PHONE', '555-2003'),
    ('CC-SIM-R20-004P', 'CUST-SIM-R20-004', 'PHONE', '555-2004'),
    ('CC-SIM-R20-005P', 'CUST-SIM-R20-005', 'PHONE', '555-2005'),
    ('CC-SIM-R20-006P', 'CUST-SIM-R20-006', 'PHONE', '555-2006'),
    ('CC-SIM-R20-007P', 'CUST-SIM-R20-007', 'PHONE', '555-2007'),
    ('CC-SIM-R20-008P', 'CUST-SIM-R20-008', 'PHONE', '555-2008'),
    ('CC-SIM-R20-009P', 'CUST-SIM-R20-009', 'PHONE', '555-2009'),
    ('CC-SIM-R20-010P', 'CUST-SIM-R20-010', 'PHONE', '555-2010'),
    ('CC-SIM-R20-011P', 'CUST-SIM-R20-011', 'PHONE', '555-2011'),
    ('CC-SIM-R20-012P', 'CUST-SIM-R20-012', 'PHONE', '555-2012'),
    ('CC-SIM-R20-013P', 'CUST-SIM-R20-013', 'PHONE', '555-2013'),
    ('CC-SIM-R20-014P', 'CUST-SIM-R20-014', 'PHONE', '555-2014'),
    ('CC-SIM-R20-015P', 'CUST-SIM-R20-015', 'PHONE', '555-2015'),
    ('CC-SIM-R20-016P', 'CUST-SIM-R20-016', 'PHONE', '555-2016'),
    ('CC-SIM-R20-017P', 'CUST-SIM-R20-017', 'PHONE', '555-2017'),
    ('CC-SIM-R20-018P', 'CUST-SIM-R20-018', 'PHONE', '555-2018'),
    ('CC-SIM-R20-019P', 'CUST-SIM-R20-019', 'PHONE', '555-2019'),
    ('CC-SIM-R20-020P', 'CUST-SIM-R20-020', 'PHONE', '555-2020')
    AS v(col1,col2,col3,col4)
WHERE NOT EXISTS (SELECT 1 FROM CUSTOMER.CUSTOMER_CONTACT WHERE CONTACT_ID = v.col1);

-- ============================================================
-- 20e.  Rejections: invalid email (no @)
-- ============================================================
INSERT INTO CUSTOMER.CUSTOMER_CONTACT
    (CONTACT_ID, CUSTOMER_ID, CONTACT_TYPE, CONTACT_VALUE,
     IS_PRIMARY, IS_VERIFIED, EFFECTIVE_DATE, CREATED_AT, UPDATED_AT)
SELECT col1, col2, col3, col4, TRUE, FALSE, CURRENT_DATE(), CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()
FROM VALUES
    ('CC-SIM-R20-RJE1', 'CUST-SIM-R20-001', 'EMAIL', 'invalid.email.nodomain'),
    ('CC-SIM-R20-RJE2', 'CUST-SIM-R20-002', 'EMAIL', 'also-not-valid-email')
    AS v(col1,col2,col3,col4)
WHERE NOT EXISTS (SELECT 1 FROM CUSTOMER.CUSTOMER_CONTACT WHERE CONTACT_ID = v.col1);

-- ============================================================
-- 20f.  Energy accounts — 40 primary + 4 second accounts
-- ============================================================
INSERT INTO CUSTOMER.ENERGY_ACCOUNT
    (ENERGY_ACCOUNT_ID, CUSTOMER_ID, ACCOUNT_NUMBER, ACCOUNT_STATUS,
     SERVICE_TYPE, RATE_CLASS, OPEN_DATE, CREATED_AT, UPDATED_AT)
SELECT col1, col2, col3, col4, col5, col6, CURRENT_DATE(), CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()
FROM VALUES
    ('EA-SIM-R20-001', 'CUST-SIM-R20-001', 'ACCT-SIM-R20-001', 'ACTIVE', 'ELECTRIC', 'SMALL_COMMERCIAL'),
    ('EA-SIM-R20-002', 'CUST-SIM-R20-002', 'ACCT-SIM-R20-002', 'ACTIVE', 'ELECTRIC', 'SMALL_COMMERCIAL'),
    ('EA-SIM-R20-003', 'CUST-SIM-R20-003', 'ACCT-SIM-R20-003', 'ACTIVE', 'ELECTRIC', 'LARGE_INDUSTRIAL'),
    ('EA-SIM-R20-004', 'CUST-SIM-R20-004', 'ACCT-SIM-R20-004', 'ACTIVE', 'ELECTRIC', 'SMALL_COMMERCIAL'),
    ('EA-SIM-R20-005', 'CUST-SIM-R20-005', 'ACCT-SIM-R20-005', 'ACTIVE', 'ELECTRIC', 'SMALL_COMMERCIAL'),
    ('EA-SIM-R20-006', 'CUST-SIM-R20-006', 'ACCT-SIM-R20-006', 'ACTIVE', 'ELECTRIC', 'LARGE_INDUSTRIAL'),
    ('EA-SIM-R20-007', 'CUST-SIM-R20-007', 'ACCT-SIM-R20-007', 'ACTIVE', 'ELECTRIC', 'SMALL_COMMERCIAL'),
    ('EA-SIM-R20-008', 'CUST-SIM-R20-008', 'ACCT-SIM-R20-008', 'ACTIVE', 'ELECTRIC', 'LARGE_INDUSTRIAL'),
    ('EA-SIM-R20-009', 'CUST-SIM-R20-009', 'ACCT-SIM-R20-009', 'ACTIVE', 'ELECTRIC', 'LARGE_INDUSTRIAL'),
    ('EA-SIM-R20-010', 'CUST-SIM-R20-010', 'ACCT-SIM-R20-010', 'ACTIVE', 'ELECTRIC', 'SMALL_COMMERCIAL'),
    ('EA-SIM-R20-011', 'CUST-SIM-R20-011', 'ACCT-SIM-R20-011', 'ACTIVE', 'ELECTRIC', 'SMALL_COMMERCIAL'),
    ('EA-SIM-R20-012', 'CUST-SIM-R20-012', 'ACCT-SIM-R20-012', 'ACTIVE', 'ELECTRIC', 'SMALL_COMMERCIAL'),
    ('EA-SIM-R20-013', 'CUST-SIM-R20-013', 'ACCT-SIM-R20-013', 'ACTIVE', 'ELECTRIC', 'SMALL_COMMERCIAL'),
    ('EA-SIM-R20-014', 'CUST-SIM-R20-014', 'ACCT-SIM-R20-014', 'ACTIVE', 'ELECTRIC', 'LARGE_INDUSTRIAL'),
    ('EA-SIM-R20-015', 'CUST-SIM-R20-015', 'ACCT-SIM-R20-015', 'ACTIVE', 'ELECTRIC', 'LARGE_INDUSTRIAL'),
    ('EA-SIM-R20-016', 'CUST-SIM-R20-016', 'ACCT-SIM-R20-016', 'ACTIVE', 'ELECTRIC', 'SMALL_COMMERCIAL'),
    ('EA-SIM-R20-017', 'CUST-SIM-R20-017', 'ACCT-SIM-R20-017', 'ACTIVE', 'ELECTRIC', 'LARGE_INDUSTRIAL'),
    ('EA-SIM-R20-018', 'CUST-SIM-R20-018', 'ACCT-SIM-R20-018', 'ACTIVE', 'ELECTRIC', 'LARGE_INDUSTRIAL'),
    ('EA-SIM-R20-019', 'CUST-SIM-R20-019', 'ACCT-SIM-R20-019', 'ACTIVE', 'ELECTRIC', 'SMALL_COMMERCIAL'),
    ('EA-SIM-R20-020', 'CUST-SIM-R20-020', 'ACCT-SIM-R20-020', 'ACTIVE', 'ELECTRIC', 'LARGE_INDUSTRIAL'),
    ('EA-SIM-R20-021', 'CUST-SIM-R20-021', 'ACCT-SIM-R20-021', 'ACTIVE', 'ELECTRIC', 'LARGE_INDUSTRIAL'),
    ('EA-SIM-R20-022', 'CUST-SIM-R20-022', 'ACCT-SIM-R20-022', 'ACTIVE', 'ELECTRIC', 'SMALL_COMMERCIAL'),
    ('EA-SIM-R20-023', 'CUST-SIM-R20-023', 'ACCT-SIM-R20-023', 'ACTIVE', 'ELECTRIC', 'SMALL_COMMERCIAL'),
    ('EA-SIM-R20-024', 'CUST-SIM-R20-024', 'ACCT-SIM-R20-024', 'ACTIVE', 'ELECTRIC', 'SMALL_COMMERCIAL'),
    ('EA-SIM-R20-025', 'CUST-SIM-R20-025', 'ACCT-SIM-R20-025', 'ACTIVE', 'ELECTRIC', 'SMALL_COMMERCIAL'),
    ('EA-SIM-R20-026', 'CUST-SIM-R20-026', 'ACCT-SIM-R20-026', 'ACTIVE', 'ELECTRIC', 'LARGE_INDUSTRIAL'),
    ('EA-SIM-R20-027', 'CUST-SIM-R20-027', 'ACCT-SIM-R20-027', 'ACTIVE', 'ELECTRIC', 'LARGE_INDUSTRIAL'),
    ('EA-SIM-R20-028', 'CUST-SIM-R20-028', 'ACCT-SIM-R20-028', 'ACTIVE', 'ELECTRIC', 'LARGE_INDUSTRIAL'),
    ('EA-SIM-R20-029', 'CUST-SIM-R20-029', 'ACCT-SIM-R20-029', 'ACTIVE', 'ELECTRIC', 'LARGE_INDUSTRIAL'),
    ('EA-SIM-R20-030', 'CUST-SIM-R20-030', 'ACCT-SIM-R20-030', 'ACTIVE', 'ELECTRIC', 'LARGE_INDUSTRIAL'),
    ('EA-SIM-R20-031', 'CUST-SIM-R20-031', 'ACCT-SIM-R20-031', 'ACTIVE', 'ELECTRIC', 'LARGE_INDUSTRIAL'),
    ('EA-SIM-R20-032', 'CUST-SIM-R20-032', 'ACCT-SIM-R20-032', 'ACTIVE', 'ELECTRIC', 'SMALL_COMMERCIAL'),
    ('EA-SIM-R20-033', 'CUST-SIM-R20-033', 'ACCT-SIM-R20-033', 'ACTIVE', 'ELECTRIC', 'SMALL_COMMERCIAL'),
    ('EA-SIM-R20-034', 'CUST-SIM-R20-034', 'ACCT-SIM-R20-034', 'ACTIVE', 'ELECTRIC', 'LARGE_INDUSTRIAL'),
    ('EA-SIM-R20-035', 'CUST-SIM-R20-035', 'ACCT-SIM-R20-035', 'ACTIVE', 'ELECTRIC', 'SMALL_COMMERCIAL'),
    ('EA-SIM-R20-036', 'CUST-SIM-R20-036', 'ACCT-SIM-R20-036', 'ACTIVE', 'ELECTRIC', 'LARGE_INDUSTRIAL'),
    ('EA-SIM-R20-037', 'CUST-SIM-R20-037', 'ACCT-SIM-R20-037', 'ACTIVE', 'ELECTRIC', 'LARGE_INDUSTRIAL'),
    ('EA-SIM-R20-038', 'CUST-SIM-R20-038', 'ACCT-SIM-R20-038', 'ACTIVE', 'ELECTRIC', 'LARGE_INDUSTRIAL'),
    ('EA-SIM-R20-039', 'CUST-SIM-R20-039', 'ACCT-SIM-R20-039', 'ACTIVE', 'ELECTRIC', 'SMALL_COMMERCIAL'),
    ('EA-SIM-R20-040', 'CUST-SIM-R20-040', 'ACCT-SIM-R20-040', 'ACTIVE', 'ELECTRIC', 'LARGE_INDUSTRIAL'),
    ('EA-SIM-R20-B01', 'CUST-SIM-R20-001', 'ACCT-SIM-R20-B01', 'ACTIVE', 'ELECTRIC', 'SMALL_COMMERCIAL'),
    ('EA-SIM-R20-B05', 'CUST-SIM-R20-005', 'ACCT-SIM-R20-B05', 'ACTIVE', 'ELECTRIC', 'SMALL_COMMERCIAL'),
    ('EA-SIM-R20-B14', 'CUST-SIM-R20-014', 'ACCT-SIM-R20-B14', 'ACTIVE', 'ELECTRIC', 'LARGE_INDUSTRIAL'),
    ('EA-SIM-R20-B31', 'CUST-SIM-R20-031', 'ACCT-SIM-R20-B31', 'ACTIVE', 'ELECTRIC', 'LARGE_INDUSTRIAL')
    AS v(col1,col2,col3,col4,col5,col6)
WHERE NOT EXISTS (SELECT 1 FROM CUSTOMER.ENERGY_ACCOUNT WHERE ENERGY_ACCOUNT_ID = v.col1);

-- ============================================================
-- 20g.  Cross-round updates — previous cohorts
-- ============================================================
UPDATE CUSTOMER.CUSTOMER
SET PREFERRED_LANGUAGE = 'ES', UPDATED_AT = CURRENT_TIMESTAMP()
WHERE CUSTOMER_ID IN (
    'CUST-SIM-R19-001','CUST-SIM-R19-002','CUST-SIM-R19-003',
    'CUST-SIM-R19-004','CUST-SIM-R19-005'
);

UPDATE CUSTOMER.CUSTOMER_CONTACT
SET IS_VERIFIED = TRUE, UPDATED_AT = CURRENT_TIMESTAMP()
WHERE CONTACT_ID IN (
    'CC-SIM-R19-021E','CC-SIM-R19-022E','CC-SIM-R19-023E',
    'CC-SIM-R19-024E','CC-SIM-R19-025E','CC-SIM-R19-026E',
    'CC-SIM-R19-027E','CC-SIM-R19-028E','CC-SIM-R19-029E',
    'CC-SIM-R19-030E'
);

UPDATE CUSTOMER.CUSTOMER_CONTACT
SET IS_VERIFIED = TRUE, UPDATED_AT = CURRENT_TIMESTAMP()
WHERE CONTACT_ID IN (
    'CC-SIM-R19-001P','CC-SIM-R19-002P','CC-SIM-R19-003P',
    'CC-SIM-R19-004P','CC-SIM-R19-005P','CC-SIM-R19-006P',
    'CC-SIM-R19-007P','CC-SIM-R19-008P','CC-SIM-R19-009P',
    'CC-SIM-R19-010P'
);

UPDATE CUSTOMER.ENERGY_ACCOUNT
SET ACCOUNT_STATUS = 'SUSPENDED', UPDATED_AT = CURRENT_TIMESTAMP()
WHERE ENERGY_ACCOUNT_ID IN ('EA-SIM-R18-005', 'EA-SIM-R18-010');

UPDATE CUSTOMER.ENERGY_ACCOUNT
SET ACCOUNT_STATUS = 'ACTIVE', UPDATED_AT = CURRENT_TIMESTAMP()
WHERE ENERGY_ACCOUNT_ID IN ('EA-SIM-R17-005', 'EA-SIM-R17-010');

-- Verification
SELECT 'R20 customers inserted'      AS label, COUNT(*) AS cnt FROM CUSTOMER.CUSTOMER       WHERE CUSTOMER_ID       LIKE 'CUST-SIM-R20-%'
UNION ALL
SELECT 'R20 energy accounts inserted',          COUNT(*)        FROM CUSTOMER.ENERGY_ACCOUNT WHERE ENERGY_ACCOUNT_ID LIKE 'EA-SIM-R20-%'
UNION ALL
SELECT 'R20 email contacts inserted',           COUNT(*)        FROM CUSTOMER.CUSTOMER_CONTACT WHERE CONTACT_ID      LIKE 'CC-SIM-R20-%'
ORDER BY 1;
