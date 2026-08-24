package com.ibm.cdp.loader.batch.writer;

import com.ibm.cdp.loader.core.model.MonthlyUsageRecord;
import lombok.extern.slf4j.Slf4j;
import org.springframework.batch.core.configuration.annotation.StepScope;
import org.springframework.batch.item.Chunk;
import org.springframework.batch.item.ItemWriter;
import org.springframework.beans.factory.annotation.Qualifier;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Component;

import java.math.BigDecimal;
import java.sql.Date;
import java.sql.PreparedStatement;
import java.sql.SQLException;
import java.sql.Timestamp;
import java.sql.Types;
import java.util.concurrent.atomic.AtomicLong;

/**
 * Writes {@link MonthlyUsageRecord} to TGT_MONTHLY_USAGE using Oracle MERGE.
 * Business key: USAGE_ID (unique). Also enforced by UNIQUE(ENERGY_ACCOUNT_ID, BILLING_MONTH).
 *
 * <p>All nullable columns are bound with explicit JDBC types via
 * {@link PreparedStatement} to avoid ORA-17004 on Oracle JDBC.
 *
 * <p>Declared {@code @StepScope} so that {@code etlRunId} is resolved from
 * {@code JobParameters} at step-execution time.
 */
@Slf4j
@Component
@StepScope
public class MonthlyUsageWriter implements ItemWriter<MonthlyUsageRecord> {

    private static final String MERGE_SQL =
        "MERGE INTO TGT_MONTHLY_USAGE tgt " +
        "USING (SELECT ? AS USAGE_ID FROM DUAL) src " +
        "  ON (tgt.USAGE_ID = src.USAGE_ID) " +
        "WHEN MATCHED THEN UPDATE SET " +
        "  ENERGY_ACCOUNT_ID = ?, PREMISE_ID = ?, METER_ID = ?, " +
        "  BILLING_MONTH = ?, BILL_START_DATE = ?, BILL_END_DATE = ?, BILLING_DAYS = ?, " +
        "  KWH_USAGE = ?, KWH_EFFECTIVE = ?, PEAK_DEMAND_KW = ?, " +
        "  PREV_METER_READING = ?, CURR_METER_READING = ?, READ_TYPE = ?, " +
        "  RATE_PLAN = ?, " +
        "  FIXED_CHARGE = ?, ENERGY_CHARGE = ?, DEMAND_CHARGE = ?, " +
        "  SUBTOTAL_CHARGE = ?, TAX_AMOUNT = ?, TOTAL_BILLED = ?, " +
        "  USAGE_QUALITY_STATUS = ?, IS_CORRECTION = ?, CORRECTION_REASON = ?, " +
        "  SOURCE_UPDATED_AT = ?, ETL_RUN_ID = ?, " +
        "  ETL_LOAD_TS = SYS_EXTRACT_UTC(SYSTIMESTAMP), UPDATED_AT = SYS_EXTRACT_UTC(SYSTIMESTAMP) " +
        "WHEN NOT MATCHED THEN INSERT " +
        "  (USAGE_ID, ENERGY_ACCOUNT_ID, PREMISE_ID, METER_ID, BILLING_MONTH, " +
        "   BILL_START_DATE, BILL_END_DATE, BILLING_DAYS, " +
        "   KWH_USAGE, KWH_EFFECTIVE, PEAK_DEMAND_KW, " +
        "   PREV_METER_READING, CURR_METER_READING, READ_TYPE, RATE_PLAN, " +
        "   FIXED_CHARGE, ENERGY_CHARGE, DEMAND_CHARGE, " +
        "   SUBTOTAL_CHARGE, TAX_AMOUNT, TOTAL_BILLED, " +
        "   USAGE_QUALITY_STATUS, IS_CORRECTION, CORRECTION_REASON, " +
        "   SOURCE_UPDATED_AT, ETL_RUN_ID) " +
        "VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)";

    private final JdbcTemplate oracleJdbc;
    private final long etlRunId;
    private final AtomicLong writeCount = new AtomicLong(0);

    public MonthlyUsageWriter(
            @Qualifier("oracleJdbcTemplate") JdbcTemplate oracleJdbc,
            @Value("#{jobParameters['etlRunId']}") Long etlRunId) {
        this.oracleJdbc = oracleJdbc;
        this.etlRunId   = etlRunId != null ? etlRunId : 0L;
    }

    @Override
    public void write(Chunk<? extends MonthlyUsageRecord> chunk) {
        for (MonthlyUsageRecord r : chunk) {
            merge(r);
            writeCount.incrementAndGet();
        }
        log.debug("MonthlyUsageWriter: flushed {} rows, total={}", chunk.size(), writeCount.get());
    }

    private void merge(MonthlyUsageRecord r) {
        final Date      billStart   = r.getBillStartDate() != null ? Date.valueOf(r.getBillStartDate())  : null;
        final Date      billEnd     = r.getBillEndDate()   != null ? Date.valueOf(r.getBillEndDate())    : null;
        final Timestamp srcUpd      = r.getUpdatedAt()     != null
            ? Timestamp.from(r.getUpdatedAt().toInstant()) : null;
        final int       isCorr      = Boolean.TRUE.equals(r.getIsCorrection()) ? 1 : 0;
        final BigDecimal demandChg  = r.getCalcDemandCharge() != null ? r.getCalcDemandCharge() : BigDecimal.ZERO;
        final String     readType   = r.getReadType()             != null ? r.getReadType()             : "ACTUAL";
        final String     qualStatus = r.getUsageQualityStatus()   != null ? r.getUsageQualityStatus()   : "ACTUAL";

        oracleJdbc.update(MERGE_SQL, (PreparedStatement ps) -> {
            int i = 1;
            // USING clause key
            ps.setString(i++, r.getUsageId());

            // ---- WHEN MATCHED SET (25 params) --------------------------------
            ps.setString(i++, r.getEnergyAccountId());
            ps.setString(i++, r.getPremiseId());
            ps.setString(i++, r.getMeterId());
            ps.setString(i++, r.getBillingMonth());
            bindDate(ps, i++, billStart);                           // NOT NULL in DDL
            bindDate(ps, i++, billEnd);                             // NOT NULL in DDL
            ps.setInt(i++, r.getBillingDays() != null ? r.getBillingDays() : 0);
            ps.setBigDecimal(i++, r.getKwhUsage());
            ps.setBigDecimal(i++, r.getKwhEffective());
            bindDecimal(ps, i++, r.getPeakDemandKw());              // nullable NUMBER
            bindDecimal(ps, i++, r.getPrevMeterReading());          // nullable NUMBER
            bindDecimal(ps, i++, r.getCurrMeterReading());          // nullable NUMBER
            ps.setString(i++, readType);
            ps.setString(i++, r.getRatePlan());
            ps.setBigDecimal(i++, r.getCalcFixedCharge()  != null ? r.getCalcFixedCharge()  : BigDecimal.ZERO);
            ps.setBigDecimal(i++, r.getCalcEnergyCharge() != null ? r.getCalcEnergyCharge() : BigDecimal.ZERO);
            ps.setBigDecimal(i++, demandChg);
            ps.setBigDecimal(i++, r.getCalcSubtotal()    != null ? r.getCalcSubtotal()    : BigDecimal.ZERO);
            ps.setBigDecimal(i++, r.getCalcTaxAmount()   != null ? r.getCalcTaxAmount()   : BigDecimal.ZERO);
            ps.setBigDecimal(i++, r.getCalcTotalBilled() != null ? r.getCalcTotalBilled() : BigDecimal.ZERO);
            ps.setString(i++, qualStatus);
            ps.setInt(i++, isCorr);
            ps.setString(i++, r.getCorrectionReason());             // nullable VARCHAR2
            bindTimestamp(ps, i++, srcUpd);                         // nullable TIMESTAMP
            ps.setLong(i++, etlRunId);

            // ---- WHEN NOT MATCHED INSERT (26 params) -------------------------
            ps.setString(i++, r.getUsageId());
            ps.setString(i++, r.getEnergyAccountId());
            ps.setString(i++, r.getPremiseId());
            ps.setString(i++, r.getMeterId());
            ps.setString(i++, r.getBillingMonth());
            bindDate(ps, i++, billStart);
            bindDate(ps, i++, billEnd);
            ps.setInt(i++, r.getBillingDays() != null ? r.getBillingDays() : 0);
            ps.setBigDecimal(i++, r.getKwhUsage());
            ps.setBigDecimal(i++, r.getKwhEffective());
            bindDecimal(ps, i++, r.getPeakDemandKw());              // nullable NUMBER
            bindDecimal(ps, i++, r.getPrevMeterReading());          // nullable NUMBER
            bindDecimal(ps, i++, r.getCurrMeterReading());          // nullable NUMBER
            ps.setString(i++, readType);
            ps.setString(i++, r.getRatePlan());
            ps.setBigDecimal(i++, r.getCalcFixedCharge()  != null ? r.getCalcFixedCharge()  : BigDecimal.ZERO);
            ps.setBigDecimal(i++, r.getCalcEnergyCharge() != null ? r.getCalcEnergyCharge() : BigDecimal.ZERO);
            ps.setBigDecimal(i++, demandChg);
            ps.setBigDecimal(i++, r.getCalcSubtotal()    != null ? r.getCalcSubtotal()    : BigDecimal.ZERO);
            ps.setBigDecimal(i++, r.getCalcTaxAmount()   != null ? r.getCalcTaxAmount()   : BigDecimal.ZERO);
            ps.setBigDecimal(i++, r.getCalcTotalBilled() != null ? r.getCalcTotalBilled() : BigDecimal.ZERO);
            ps.setString(i++, qualStatus);
            ps.setInt(i++, isCorr);
            ps.setString(i++, r.getCorrectionReason());             // nullable VARCHAR2
            bindTimestamp(ps, i++, srcUpd);                         // nullable TIMESTAMP
            ps.setLong(i,   etlRunId);
        });
    }

    // -------------------------------------------------------------------------
    // Helpers
    // -------------------------------------------------------------------------

    private static void bindDate(PreparedStatement ps, int index, Date value)
            throws SQLException {
        if (value != null) {
            ps.setDate(index, value);
        } else {
            ps.setNull(index, Types.DATE);
        }
    }

    private static void bindDecimal(PreparedStatement ps, int index, BigDecimal value)
            throws SQLException {
        if (value != null) {
            ps.setBigDecimal(index, value);
        } else {
            ps.setNull(index, Types.NUMERIC);
        }
    }

    private static void bindTimestamp(PreparedStatement ps, int index, Timestamp value)
            throws SQLException {
        if (value != null) {
            ps.setTimestamp(index, value);
        } else {
            ps.setNull(index, Types.TIMESTAMP);
        }
    }
}
