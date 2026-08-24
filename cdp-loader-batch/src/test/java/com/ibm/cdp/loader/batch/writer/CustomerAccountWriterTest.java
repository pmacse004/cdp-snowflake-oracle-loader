package com.ibm.cdp.loader.batch.writer;

import com.ibm.cdp.loader.core.model.CustomerAccountRecord;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.mockito.ArgumentCaptor;
import org.springframework.batch.item.Chunk;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.jdbc.core.PreparedStatementSetter;

import java.math.BigDecimal;
import java.sql.PreparedStatement;
import java.sql.Types;
import java.time.LocalDate;
import java.time.OffsetDateTime;
import java.time.ZoneOffset;

import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.atLeastOnce;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

/**
 * Unit tests for {@link CustomerAccountWriter} null-parameter binding.
 *
 * <p>Each {@code mergeXxx} method is exercised by constructing a record that
 * triggers exactly that MERGE.  The PSS is captured and fired against a mock
 * {@link PreparedStatement} so that explicit JDBC types for nullable columns
 * can be asserted, proving ORA-17004 cannot occur.
 *
 * <p>Sub-merges triggered by record content:
 * <ul>
 *   <li>energyAccount  — always (ENERGY_ACCOUNT_ID always present)
 *   <li>billingAccount — when BILLING_ACCOUNT_ID non-blank
 *   <li>premise        — when PREMISE_ID non-blank
 *   <li>meter          — when PREMISE_ID AND METER_ID both non-blank
 * </ul>
 */
class CustomerAccountWriterTest {

    private JdbcTemplate jdbc;
    private CustomerAccountWriter writer;

    @BeforeEach
    void setUp() {
        jdbc   = mock(JdbcTemplate.class);
        writer = new CustomerAccountWriter(jdbc, 9L);
    }

    // -------------------------------------------------------------------------
    // Helpers
    // -------------------------------------------------------------------------

    /**
     * Captures ALL PSS instances passed to jdbc.update() and returns the one
     * at {@code callIndex} (0-based in the order they were captured).
     */
    private PreparedStatement captureCall(CustomerAccountRecord record, int callIndex)
            throws Exception {
        ArgumentCaptor<PreparedStatementSetter> cap =
            ArgumentCaptor.forClass(PreparedStatementSetter.class);
        when(jdbc.update(any(String.class), cap.capture())).thenReturn(1);

        writer.write(Chunk.of(record));

        PreparedStatement ps = mock(PreparedStatement.class);
        cap.getAllValues().get(callIndex).setValues(ps);
        return ps;
    }

    private CustomerAccountRecord energyOnlyRecord() {
        CustomerAccountRecord r = new CustomerAccountRecord();
        r.setEnergyAccountId("EA001");
        r.setCustomerId("C001");
        r.setAccountNumber("ACC-001");
        r.setAccountStatus("ACTIVE");
        r.setRateClass("R1");
        r.setOpenDate(LocalDate.of(2020, 1, 1));
        return r;
    }

    // =========================================================================
    // TGT_ENERGY_ACCOUNT
    // =========================================================================

    /**
     * Parameter layout for mergeEnergyAccount (1-based):
     * 1  ENERGY_ACCOUNT_ID (key)
     * UPDATE SET (10):
     * 2  CUSTOMER_ID     3  ACCOUNT_NUMBER  4  ACCOUNT_STATUS
     * 5  SERVICE_TYPE    6  RATE_CLASS      7  OPEN_DATE (DATE)
     * 8  CLOSE_DATE (DATE, nullable)        9  IS_ACTIVE
     * 10 SOURCE_UPDATED_AT (TIMESTAMP, nullable)  11 ETL_RUN_ID
     * INSERT VALUES (11):
     * 12 ENERGY_ACCOUNT_ID  13 CUSTOMER_ID  14 ACCOUNT_NUMBER  15 ACCOUNT_STATUS
     * 16 SERVICE_TYPE  17 RATE_CLASS  18 OPEN_DATE  19 CLOSE_DATE  20 IS_ACTIVE
     * 21 SOURCE_UPDATED_AT  22 ETL_RUN_ID
     */
    @Test
    void energyAccount_null_closeDate_binds_setNull_DATE() throws Exception {
        CustomerAccountRecord r = energyOnlyRecord();
        r.setCloseDate(null);           // nullable CLOSE_DATE

        PreparedStatement ps = captureCall(r, 0);

        verify(ps).setNull(8,  Types.DATE);     // UPDATE
        verify(ps).setNull(19, Types.DATE);     // INSERT
    }

    @Test
    void energyAccount_null_sourceUpdatedAt_binds_setNull_TIMESTAMP() throws Exception {
        CustomerAccountRecord r = energyOnlyRecord();
        r.setRecordEffectiveTs(null);   // nullable SOURCE_UPDATED_AT

        PreparedStatement ps = captureCall(r, 0);

        verify(ps).setNull(10, Types.TIMESTAMP);    // UPDATE
        verify(ps).setNull(21, Types.TIMESTAMP);    // INSERT
    }

    @Test
    void energyAccount_null_serviceType_defaults_to_ELECTRIC() throws Exception {
        CustomerAccountRecord r = energyOnlyRecord();
        r.setServiceType(null);

        PreparedStatement ps = captureCall(r, 0);

        verify(ps).setString(5,  "ELECTRIC");
        verify(ps).setString(16, "ELECTRIC");
    }

    @Test
    void energyAccount_etlRunId_bound_with_injected_value() throws Exception {
        PreparedStatement ps = captureCall(energyOnlyRecord(), 0);

        verify(ps).setLong(11, 9L);
        verify(ps).setLong(22, 9L);
    }

    // =========================================================================
    // TGT_BILLING_ACCOUNT
    // =========================================================================

    private CustomerAccountRecord withBillingAccount() {
        CustomerAccountRecord r = energyOnlyRecord();
        r.setBillingAccountId("BA001");
        r.setBillingAccountNbr("BAN-001");
        r.setBillingCycle("MONTHLY");
        return r;
    }

    /**
     * Parameter layout for mergeBillingAccount (1-based):
     * 1  BILLING_ACCOUNT_ID (key)
     * UPDATE SET (8):
     * 2  ENERGY_ACCOUNT_ID  3  BILLING_ACCOUNT_NBR  4  BILLING_CYCLE
     * 5  PAYMENT_METHOD     6  AUTO_PAY_ENROLLED    7  PAPERLESS_ENROLLED
     * 8  SOURCE_UPDATED_AT (TIMESTAMP, nullable)    9  ETL_RUN_ID
     * INSERT VALUES (9):
     * 10 BILLING_ACCOUNT_ID  11 ENERGY_ACCOUNT_ID  12 BILLING_ACCOUNT_NBR
     * 13 BILLING_CYCLE  14 PAYMENT_METHOD  15 AUTO_PAY_ENROLLED
     * 16 PAPERLESS_ENROLLED  17 SOURCE_UPDATED_AT  18 ETL_RUN_ID
     */
    @Test
    void billingAccount_null_sourceUpdatedAt_binds_setNull_TIMESTAMP() throws Exception {
        CustomerAccountRecord r = withBillingAccount();
        r.setRecordEffectiveTs(null);

        // call index 1 = billing account merge (after energy account at index 0)
        PreparedStatement ps = captureCall(r, 1);

        verify(ps).setNull(8,  Types.TIMESTAMP);
        verify(ps).setNull(17, Types.TIMESTAMP);
    }

    @Test
    void billingAccount_null_paymentMethod_defaults_to_PAPER_BILL() throws Exception {
        CustomerAccountRecord r = withBillingAccount();
        r.setPaymentMethod(null);

        PreparedStatement ps = captureCall(r, 1);

        verify(ps).setString(5,  "PAPER_BILL");
        verify(ps).setString(14, "PAPER_BILL");
    }

    @Test
    void billingAccount_null_booleans_treated_as_false() throws Exception {
        CustomerAccountRecord r = withBillingAccount();
        r.setAutoPayEnrolled(null);
        r.setPaperlessEnrolled(null);

        PreparedStatement ps = captureCall(r, 1);

        verify(ps).setInt(6,  0);   // AUTO_PAY_ENROLLED UPDATE
        verify(ps).setInt(7,  0);   // PAPERLESS_ENROLLED UPDATE
        verify(ps).setInt(15, 0);   // AUTO_PAY_ENROLLED INSERT
        verify(ps).setInt(16, 0);   // PAPERLESS_ENROLLED INSERT
    }

    // =========================================================================
    // TGT_PREMISE
    // =========================================================================

    private CustomerAccountRecord withPremise() {
        CustomerAccountRecord r = withBillingAccount();
        r.setPremiseId("P001");
        r.setAddressLine1("123 Main St");
        r.setCity("Springfield");
        r.setStateCode("IL");
        r.setZipCode("62701");
        return r;
    }

    /**
     * Parameter layout for mergePremise (1-based):
     * 1  PREMISE_ID (key)
     * UPDATE SET (13):
     * 2  ENERGY_ACCOUNT_ID  3  ADDRESS_LINE1  4  ADDRESS_LINE2 (nullable)
     * 5  CITY  6  STATE_CODE  7  ZIP_CODE  8  COUNTY (nullable)
     * 9  GEO_LATITUDE (nullable NUMBER)  10 GEO_LONGITUDE (nullable NUMBER)
     * 11 PREMISE_TYPE (nullable VARCHAR2)  12 FULL_ADDRESS (nullable VARCHAR2)
     * 13 SOURCE_UPDATED_AT (nullable TIMESTAMP)  14 ETL_RUN_ID
     * INSERT VALUES (15):
     * 15 PREMISE_ID  16 ENERGY_ACCOUNT_ID  17 ADDRESS_LINE1  18 ADDRESS_LINE2
     * 19 CITY  20 STATE_CODE  21 ZIP_CODE  22 COUNTY
     * 23 GEO_LATITUDE  24 GEO_LONGITUDE  25 PREMISE_TYPE  26 FULL_ADDRESS
     * 27 SOURCE_UPDATED_AT  28 ETL_RUN_ID
     */
    @Test
    void premise_null_addressLine2_is_bound_as_setString_null() throws Exception {
        CustomerAccountRecord r = withPremise();
        r.setAddressLine2(null);

        // call index 2 = premise (energy=0, billing=1, premise=2)
        PreparedStatement ps = captureCall(r, 2);

        verify(ps).setString(4,  null);
        verify(ps).setString(18, null);
    }

    @Test
    void premise_null_county_is_bound_as_setString_null() throws Exception {
        CustomerAccountRecord r = withPremise();
        r.setCounty(null);

        PreparedStatement ps = captureCall(r, 2);

        verify(ps).setString(8,  null);
        verify(ps).setString(22, null);
    }

    @Test
    void premise_null_geoLatitude_binds_setNull_NUMERIC() throws Exception {
        CustomerAccountRecord r = withPremise();
        r.setGeoLatitude(null);

        PreparedStatement ps = captureCall(r, 2);

        verify(ps).setNull(9,  Types.NUMERIC);
        verify(ps).setNull(23, Types.NUMERIC);
    }

    @Test
    void premise_null_geoLongitude_binds_setNull_NUMERIC() throws Exception {
        CustomerAccountRecord r = withPremise();
        r.setGeoLongitude(null);

        PreparedStatement ps = captureCall(r, 2);

        verify(ps).setNull(10, Types.NUMERIC);
        verify(ps).setNull(24, Types.NUMERIC);
    }

    @Test
    void premise_non_null_geo_binds_setBigDecimal() throws Exception {
        CustomerAccountRecord r = withPremise();
        r.setGeoLatitude(new BigDecimal("39.7817"));
        r.setGeoLongitude(new BigDecimal("-89.6501"));

        PreparedStatement ps = captureCall(r, 2);

        verify(ps).setBigDecimal(9,  new BigDecimal("39.7817"));
        verify(ps).setBigDecimal(10, new BigDecimal("-89.6501"));
        verify(ps).setBigDecimal(23, new BigDecimal("39.7817"));
        verify(ps).setBigDecimal(24, new BigDecimal("-89.6501"));
    }

    @Test
    void premise_null_premiseType_and_fullAddress_bound_as_setString_null() throws Exception {
        CustomerAccountRecord r = withPremise();
        r.setPremiseType(null);
        r.setFullAddress(null);

        PreparedStatement ps = captureCall(r, 2);

        verify(ps).setString(11, null);  // PREMISE_TYPE UPDATE
        verify(ps).setString(12, null);  // FULL_ADDRESS UPDATE
        verify(ps).setString(25, null);  // PREMISE_TYPE INSERT
        verify(ps).setString(26, null);  // FULL_ADDRESS INSERT
    }

    @Test
    void premise_null_sourceUpdatedAt_binds_setNull_TIMESTAMP() throws Exception {
        CustomerAccountRecord r = withPremise();
        r.setRecordEffectiveTs(null);

        PreparedStatement ps = captureCall(r, 2);

        verify(ps).setNull(13, Types.TIMESTAMP);
        verify(ps).setNull(27, Types.TIMESTAMP);
    }

    // =========================================================================
    // TGT_METER
    // =========================================================================

    private CustomerAccountRecord withMeter() {
        CustomerAccountRecord r = withPremise();
        r.setMeterId("M001");
        r.setMeterNumber("MTR-001");
        r.setInstallDate(LocalDate.of(2021, 3, 15));
        return r;
    }

    /**
     * Parameter layout for mergeMeter (1-based):
     * 1  METER_ID (key)
     * UPDATE SET (6):
     * 2  PREMISE_ID  3  METER_NUMBER  4  METER_TYPE  5  INSTALL_DATE (DATE)
     * 6  SOURCE_UPDATED_AT (nullable TIMESTAMP)  7  ETL_RUN_ID
     * INSERT VALUES (7):
     * 8  METER_ID  9  PREMISE_ID  10 METER_NUMBER  11 METER_TYPE  12 INSTALL_DATE
     * 13 SOURCE_UPDATED_AT  14 ETL_RUN_ID
     */
    @Test
    void meter_null_sourceUpdatedAt_binds_setNull_TIMESTAMP() throws Exception {
        CustomerAccountRecord r = withMeter();
        r.setRecordEffectiveTs(null);

        // call index 3 = meter (energy=0, billing=1, premise=2, meter=3)
        PreparedStatement ps = captureCall(r, 3);

        verify(ps).setNull(6,  Types.TIMESTAMP);
        verify(ps).setNull(13, Types.TIMESTAMP);
    }

    @Test
    void meter_null_meterType_defaults_to_ANALOG() throws Exception {
        CustomerAccountRecord r = withMeter();
        r.setMeterType(null);

        PreparedStatement ps = captureCall(r, 3);

        verify(ps).setString(4,  "ANALOG");
        verify(ps).setString(11, "ANALOG");
    }

    @Test
    void meter_non_null_recordEffectiveTs_binds_setTimestamp() throws Exception {
        CustomerAccountRecord r = withMeter();
        OffsetDateTime ts = OffsetDateTime.of(2024, 4, 10, 8, 0, 0, 0, ZoneOffset.UTC);
        r.setRecordEffectiveTs(ts);

        PreparedStatement ps = captureCall(r, 3);

        java.sql.Timestamp expected = java.sql.Timestamp.from(ts.toInstant());
        verify(ps).setTimestamp(6,  expected);
        verify(ps).setTimestamp(13, expected);
    }

    // =========================================================================
    // Skipping sub-merges when primary key absent
    // =========================================================================

    @Test
    void billingAccount_skipped_when_billingAccountId_null() throws Exception {
        CustomerAccountRecord r = energyOnlyRecord();
        r.setBillingAccountId(null);

        when(jdbc.update(any(String.class), any(PreparedStatementSetter.class))).thenReturn(1);
        writer.write(Chunk.of(r));

        // Only one update call — the energy account MERGE
        verify(jdbc, atLeastOnce()).update(any(String.class), any(PreparedStatementSetter.class));
        // Exactly one call total
        ArgumentCaptor<PreparedStatementSetter> cap =
            ArgumentCaptor.forClass(PreparedStatementSetter.class);
        verify(jdbc, org.mockito.Mockito.times(1))
            .update(any(String.class), cap.capture());
    }
}
