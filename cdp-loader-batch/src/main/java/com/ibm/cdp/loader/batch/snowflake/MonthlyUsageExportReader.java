package com.ibm.cdp.loader.batch.snowflake;

import com.ibm.cdp.loader.core.model.MonthlyUsageRecord;
import org.springframework.batch.item.database.JdbcCursorItemReader;
import org.springframework.batch.item.database.builder.JdbcCursorItemReaderBuilder;
import org.springframework.jdbc.core.RowMapper;

import javax.sql.DataSource;
import java.math.BigDecimal;
import java.sql.ResultSet;
import java.sql.SQLException;
import java.sql.Timestamp;
import java.time.OffsetDateTime;
import java.time.ZoneOffset;

/**
 * Reads rows from VW_MONTHLY_USAGE_BILLING_EXPORT.
 * One row per USAGE_ID (business key).
 *
 * <p>The view already performs charge calculations in Snowflake (Layer 1).
 * The processor validates and maps these values to Oracle.
 */
public class MonthlyUsageExportReader {

    private static final String COLUMNS =
        "USAGE_ID, ENERGY_ACCOUNT_ID, PREMISE_ID, METER_ID, BILLING_MONTH, " +
        "BILL_START_DATE, BILL_END_DATE, BILLING_DAYS, " +
        "KWH_USAGE, KWH_EFFECTIVE, PEAK_DEMAND_KW, PREV_METER_READING, CURR_METER_READING, READ_TYPE, " +
        "RATE_PLAN, FIXED_RATE, ENERGY_RATE_PER_KWH, DEMAND_RATE_PER_KW, TAX_RATE, " +
        "CALC_FIXED_CHARGE, CALC_ENERGY_CHARGE, CALC_DEMAND_CHARGE, CALC_SUBTOTAL, " +
        "CALC_TAX_AMOUNT, CALC_TOTAL_BILLED, " +
        "USAGE_QUALITY_STATUS, IS_CORRECTION, CORRECTION_REASON, " +
        "CREATED_AT, UPDATED_AT";

    private static final String SQL_ALL =
        "SELECT " + COLUMNS + " FROM STAGING.VW_MONTHLY_USAGE_BILLING_EXPORT " +
        "ORDER BY UPDATED_AT, USAGE_ID";

    private static final String SQL_INCREMENTAL =
        "SELECT " + COLUMNS + " FROM STAGING.VW_MONTHLY_USAGE_BILLING_EXPORT " +
        "WHERE UPDATED_AT > ? OR (UPDATED_AT = ? AND USAGE_ID > ?) " +
        "ORDER BY UPDATED_AT, USAGE_ID";

    public static JdbcCursorItemReader<MonthlyUsageRecord> buildInitialReader(
            DataSource snowflakeDs, int fetchSize) {
        return new JdbcCursorItemReaderBuilder<MonthlyUsageRecord>()
                .name("monthlyUsageExportInitialReader")
                .dataSource(snowflakeDs)
                .sql(SQL_ALL)
                .rowMapper(new UsageRowMapper())
                .fetchSize(fetchSize)
                .build();
    }

    public static JdbcCursorItemReader<MonthlyUsageRecord> buildIncrementalReader(
            DataSource snowflakeDs, int fetchSize,
            java.time.Instant lastTs, String lastSourceId) {
        Timestamp ts = Timestamp.from(lastTs);
        String lastId = lastSourceId != null ? lastSourceId : "";
        return new JdbcCursorItemReaderBuilder<MonthlyUsageRecord>()
                .name("monthlyUsageExportIncrementalReader")
                .dataSource(snowflakeDs)
                .sql(SQL_INCREMENTAL)
                .queryArguments(ts, ts, lastId)
                .rowMapper(new UsageRowMapper())
                .fetchSize(fetchSize)
                .build();
    }

    static class UsageRowMapper implements RowMapper<MonthlyUsageRecord> {
        @Override
        public MonthlyUsageRecord mapRow(ResultSet rs, int rowNum) throws SQLException {
            MonthlyUsageRecord r = new MonthlyUsageRecord();
            r.setUsageId(rs.getString("USAGE_ID"));
            r.setEnergyAccountId(rs.getString("ENERGY_ACCOUNT_ID"));
            r.setPremiseId(rs.getString("PREMISE_ID"));
            r.setMeterId(rs.getString("METER_ID"));
            r.setBillingMonth(rs.getString("BILLING_MONTH"));
            r.setBillStartDate(rs.getDate("BILL_START_DATE") != null ? rs.getDate("BILL_START_DATE").toLocalDate() : null);
            r.setBillEndDate(rs.getDate("BILL_END_DATE") != null ? rs.getDate("BILL_END_DATE").toLocalDate() : null);
            r.setBillingDays(rs.getObject("BILLING_DAYS") != null ? rs.getInt("BILLING_DAYS") : null);
            r.setKwhUsage(rs.getBigDecimal("KWH_USAGE"));
            r.setKwhEffective(rs.getBigDecimal("KWH_EFFECTIVE"));
            r.setPeakDemandKw(rs.getBigDecimal("PEAK_DEMAND_KW"));
            r.setPrevMeterReading(rs.getBigDecimal("PREV_METER_READING"));
            r.setCurrMeterReading(rs.getBigDecimal("CURR_METER_READING"));
            r.setReadType(rs.getString("READ_TYPE"));
            r.setRatePlan(rs.getString("RATE_PLAN"));
            r.setFixedRate(rs.getBigDecimal("FIXED_RATE"));
            r.setEnergyRatePerKwh(rs.getBigDecimal("ENERGY_RATE_PER_KWH"));
            r.setDemandRatePerKw(rs.getBigDecimal("DEMAND_RATE_PER_KW"));
            r.setTaxRate(rs.getBigDecimal("TAX_RATE"));
            r.setCalcFixedCharge(rs.getBigDecimal("CALC_FIXED_CHARGE"));
            r.setCalcEnergyCharge(rs.getBigDecimal("CALC_ENERGY_CHARGE"));
            r.setCalcDemandCharge(rs.getBigDecimal("CALC_DEMAND_CHARGE"));
            r.setCalcSubtotal(rs.getBigDecimal("CALC_SUBTOTAL"));
            r.setCalcTaxAmount(rs.getBigDecimal("CALC_TAX_AMOUNT"));
            r.setCalcTotalBilled(rs.getBigDecimal("CALC_TOTAL_BILLED"));
            r.setUsageQualityStatus(rs.getString("USAGE_QUALITY_STATUS"));
            r.setIsCorrection(rs.getObject("IS_CORRECTION") != null ? rs.getBoolean("IS_CORRECTION") : false);
            r.setCorrectionReason(rs.getString("CORRECTION_REASON"));
            r.setCreatedAt(toOdt(rs.getTimestamp("CREATED_AT")));
            r.setUpdatedAt(toOdt(rs.getTimestamp("UPDATED_AT")));
            return r;
        }

        private static OffsetDateTime toOdt(Timestamp ts) {
            return ts != null ? ts.toInstant().atOffset(ZoneOffset.UTC) : null;
        }
    }
}
