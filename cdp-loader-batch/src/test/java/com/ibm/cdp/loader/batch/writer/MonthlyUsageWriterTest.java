package com.ibm.cdp.loader.batch.writer;

import com.ibm.cdp.loader.core.model.MonthlyUsageRecord;
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
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

/**
 * Unit tests for {@link MonthlyUsageWriter} null-parameter binding.
 *
 * <p>Parameter index layout (1-based):
 * <pre>
 * 1  USAGE_ID (key)
 * WHEN MATCHED SET (25 params):
 *  2  ENERGY_ACCOUNT_ID    3  PREMISE_ID           4  METER_ID
 *  5  BILLING_MONTH        6  BILL_START_DATE       7  BILL_END_DATE
 *  8  BILLING_DAYS         9  KWH_USAGE            10  KWH_EFFECTIVE
 * 11  PEAK_DEMAND_KW (nullable NUMBER)
 * 12  PREV_METER_READING (nullable NUMBER)
 * 13  CURR_METER_READING (nullable NUMBER)
 * 14  READ_TYPE            15  RATE_PLAN
 * 16  FIXED_CHARGE         17  ENERGY_CHARGE        18  DEMAND_CHARGE
 * 19  SUBTOTAL_CHARGE      20  TAX_AMOUNT           21  TOTAL_BILLED
 * 22  USAGE_QUALITY_STATUS 23  IS_CORRECTION
 * 24  CORRECTION_REASON (nullable VARCHAR2)
 * 25  SOURCE_UPDATED_AT (nullable TIMESTAMP)
 * 26  ETL_RUN_ID
 * WHEN NOT MATCHED INSERT (26 params):
 * 27  USAGE_ID             28  ENERGY_ACCOUNT_ID    29  PREMISE_ID
 * 30  METER_ID             31  BILLING_MONTH        32  BILL_START_DATE
 * 33  BILL_END_DATE        34  BILLING_DAYS         35  KWH_USAGE
 * 36  KWH_EFFECTIVE
 * 37  PEAK_DEMAND_KW (nullable NUMBER)
 * 38  PREV_METER_READING (nullable NUMBER)
 * 39  CURR_METER_READING (nullable NUMBER)
 * 40  READ_TYPE            41  RATE_PLAN
 * 42  FIXED_CHARGE         43  ENERGY_CHARGE        44  DEMAND_CHARGE
 * 45  SUBTOTAL_CHARGE      46  TAX_AMOUNT           47  TOTAL_BILLED
 * 48  USAGE_QUALITY_STATUS 49  IS_CORRECTION
 * 50  CORRECTION_REASON (nullable VARCHAR2)
 * 51  SOURCE_UPDATED_AT (nullable TIMESTAMP)
 * 52  ETL_RUN_ID
 * </pre>
 */
class MonthlyUsageWriterTest {

    private JdbcTemplate jdbc;
    private MonthlyUsageWriter writer;

    @BeforeEach
    void setUp() {
        jdbc   = mock(JdbcTemplate.class);
        writer = new MonthlyUsageWriter(jdbc, 5L);
    }

    // -------------------------------------------------------------------------
    // Helpers
    // -------------------------------------------------------------------------

    private MonthlyUsageRecord minimalRecord() {
        MonthlyUsageRecord r = new MonthlyUsageRecord();
        r.setUsageId("USG-001");
        r.setEnergyAccountId("EA001");
        r.setPremiseId("P001");
        r.setMeterId("M001");
        r.setBillingMonth("2024-05");
        r.setBillStartDate(LocalDate.of(2024, 5, 1));
        r.setBillEndDate(LocalDate.of(2024, 5, 31));
        r.setBillingDays(31);
        r.setKwhUsage(new BigDecimal("450.000"));
        r.setKwhEffective(new BigDecimal("450.000"));
        r.setRatePlan("R1");
        r.setCalcFixedCharge(new BigDecimal("10.00"));
        r.setCalcEnergyCharge(new BigDecimal("45.00"));
        r.setCalcSubtotal(new BigDecimal("55.00"));
        r.setCalcTaxAmount(new BigDecimal("5.50"));
        r.setCalcTotalBilled(new BigDecimal("60.50"));
        return r;
    }

    private PreparedStatement captureAndInvoke(MonthlyUsageRecord record) throws Exception {
        ArgumentCaptor<PreparedStatementSetter> cap =
            ArgumentCaptor.forClass(PreparedStatementSetter.class);
        when(jdbc.update(any(String.class), cap.capture())).thenReturn(1);

        writer.write(Chunk.of(record));

        PreparedStatement ps = mock(PreparedStatement.class);
        cap.getValue().setValues(ps);
        return ps;
    }

    // -------------------------------------------------------------------------
    // A) Nullable NUMBER fields: PEAK_DEMAND_KW, PREV/CURR_METER_READING
    // -------------------------------------------------------------------------

    @Test
    void null_peakDemandKw_binds_setNull_NUMERIC() throws Exception {
        MonthlyUsageRecord r = minimalRecord();
        r.setPeakDemandKw(null);

        PreparedStatement ps = captureAndInvoke(r);

        verify(ps).setNull(11, Types.NUMERIC);  // UPDATE
        verify(ps).setNull(37, Types.NUMERIC);  // INSERT
    }

    @Test
    void null_prevMeterReading_binds_setNull_NUMERIC() throws Exception {
        MonthlyUsageRecord r = minimalRecord();
        r.setPrevMeterReading(null);

        PreparedStatement ps = captureAndInvoke(r);

        verify(ps).setNull(12, Types.NUMERIC);
        verify(ps).setNull(38, Types.NUMERIC);
    }

    @Test
    void null_currMeterReading_binds_setNull_NUMERIC() throws Exception {
        MonthlyUsageRecord r = minimalRecord();
        r.setCurrMeterReading(null);

        PreparedStatement ps = captureAndInvoke(r);

        verify(ps).setNull(13, Types.NUMERIC);
        verify(ps).setNull(39, Types.NUMERIC);
    }

    @Test
    void non_null_peakDemandKw_binds_setBigDecimal() throws Exception {
        MonthlyUsageRecord r = minimalRecord();
        r.setPeakDemandKw(new BigDecimal("12.500"));

        PreparedStatement ps = captureAndInvoke(r);

        verify(ps).setBigDecimal(11, new BigDecimal("12.500"));
        verify(ps).setBigDecimal(37, new BigDecimal("12.500"));
    }

    // -------------------------------------------------------------------------
    // B) Nullable VARCHAR2: CORRECTION_REASON
    // -------------------------------------------------------------------------

    @Test
    void null_correctionReason_is_bound_as_setString_null() throws Exception {
        MonthlyUsageRecord r = minimalRecord();
        r.setCorrectionReason(null);

        PreparedStatement ps = captureAndInvoke(r);

        verify(ps).setString(24, null);  // UPDATE
        verify(ps).setString(50, null);  // INSERT
    }

    @Test
    void non_null_correctionReason_is_bound_correctly() throws Exception {
        MonthlyUsageRecord r = minimalRecord();
        r.setIsCorrection(true);
        r.setCorrectionReason("Meter re-read");

        PreparedStatement ps = captureAndInvoke(r);

        verify(ps).setString(24, "Meter re-read");
        verify(ps).setString(50, "Meter re-read");
    }

    // -------------------------------------------------------------------------
    // C) Nullable TIMESTAMP: SOURCE_UPDATED_AT
    // -------------------------------------------------------------------------

    @Test
    void null_sourceUpdatedAt_binds_setNull_TIMESTAMP() throws Exception {
        MonthlyUsageRecord r = minimalRecord();
        r.setUpdatedAt(null);

        PreparedStatement ps = captureAndInvoke(r);

        verify(ps).setNull(25, Types.TIMESTAMP);  // UPDATE
        verify(ps).setNull(51, Types.TIMESTAMP);  // INSERT
    }

    @Test
    void non_null_sourceUpdatedAt_binds_setTimestamp() throws Exception {
        MonthlyUsageRecord r = minimalRecord();
        OffsetDateTime ts = OffsetDateTime.of(2024, 5, 31, 23, 59, 0, 0, ZoneOffset.UTC);
        r.setUpdatedAt(ts);

        PreparedStatement ps = captureAndInvoke(r);

        java.sql.Timestamp expected = java.sql.Timestamp.from(ts.toInstant());
        verify(ps).setTimestamp(25, expected);
        verify(ps).setTimestamp(51, expected);
    }

    // -------------------------------------------------------------------------
    // D) IS_CORRECTION flag
    // -------------------------------------------------------------------------

    @Test
    void isCorrection_true_binds_1() throws Exception {
        MonthlyUsageRecord r = minimalRecord();
        r.setIsCorrection(true);

        PreparedStatement ps = captureAndInvoke(r);

        verify(ps).setInt(23, 1);
        verify(ps).setInt(49, 1);
    }

    @Test
    void isCorrection_null_or_false_binds_0() throws Exception {
        MonthlyUsageRecord r = minimalRecord();
        r.setIsCorrection(null);

        PreparedStatement ps = captureAndInvoke(r);

        verify(ps).setInt(23, 0);
        verify(ps).setInt(49, 0);
    }

    // -------------------------------------------------------------------------
    // E) Null demand charge defaults to ZERO
    // -------------------------------------------------------------------------

    @Test
    void null_calcDemandCharge_defaults_to_BigDecimal_ZERO() throws Exception {
        MonthlyUsageRecord r = minimalRecord();
        r.setCalcDemandCharge(null);

        PreparedStatement ps = captureAndInvoke(r);

        verify(ps).setBigDecimal(18, BigDecimal.ZERO);
        verify(ps).setBigDecimal(44, BigDecimal.ZERO);
    }

    // -------------------------------------------------------------------------
    // F) Null readType defaults to "ACTUAL"
    // -------------------------------------------------------------------------

    @Test
    void null_readType_defaults_to_ACTUAL() throws Exception {
        MonthlyUsageRecord r = minimalRecord();
        r.setReadType(null);

        PreparedStatement ps = captureAndInvoke(r);

        verify(ps).setString(14, "ACTUAL");
        verify(ps).setString(40, "ACTUAL");
    }

    // -------------------------------------------------------------------------
    // G) Null usageQualityStatus defaults to "ACTUAL"
    // -------------------------------------------------------------------------

    @Test
    void null_usageQualityStatus_defaults_to_ACTUAL() throws Exception {
        MonthlyUsageRecord r = minimalRecord();
        r.setUsageQualityStatus(null);

        PreparedStatement ps = captureAndInvoke(r);

        verify(ps).setString(22, "ACTUAL");
        verify(ps).setString(48, "ACTUAL");
    }

    // -------------------------------------------------------------------------
    // H) ETL run-id is always bound
    // -------------------------------------------------------------------------

    @Test
    void etlRunId_is_bound_with_injected_value() throws Exception {
        PreparedStatement ps = captureAndInvoke(minimalRecord());

        verify(ps).setLong(26, 5L);
        verify(ps).setLong(52, 5L);
    }
}
