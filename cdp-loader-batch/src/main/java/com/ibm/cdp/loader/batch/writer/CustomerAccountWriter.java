package com.ibm.cdp.loader.batch.writer;

import com.ibm.cdp.loader.core.model.CustomerAccountRecord;
import lombok.extern.slf4j.Slf4j;
import org.springframework.batch.core.configuration.annotation.StepScope;
import org.springframework.batch.item.Chunk;
import org.springframework.batch.item.ItemWriter;
import org.springframework.beans.factory.annotation.Qualifier;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Component;

import java.sql.Date;
import java.sql.PreparedStatement;
import java.sql.SQLException;
import java.sql.Timestamp;
import java.sql.Types;
import java.util.concurrent.atomic.AtomicLong;

/**
 * Writes {@link CustomerAccountRecord} to four Oracle tables:
 * TGT_ENERGY_ACCOUNT, TGT_BILLING_ACCOUNT, TGT_PREMISE, TGT_METER.
 *
 * <p>Each sub-entity is only written when its primary key is non-null.
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
public class CustomerAccountWriter implements ItemWriter<CustomerAccountRecord> {

    private final JdbcTemplate oracleJdbc;
    private final long etlRunId;
    private final AtomicLong writeCount = new AtomicLong(0);

    public CustomerAccountWriter(
            @Qualifier("oracleJdbcTemplate") JdbcTemplate oracleJdbc,
            @Value("#{jobParameters['etlRunId']}") Long etlRunId) {
        this.oracleJdbc = oracleJdbc;
        this.etlRunId   = etlRunId != null ? etlRunId : 0L;
    }

    @Override
    public void write(Chunk<? extends CustomerAccountRecord> chunk) {
        for (CustomerAccountRecord r : chunk) {
            mergeEnergyAccount(r);
            if (r.getBillingAccountId() != null && !r.getBillingAccountId().isBlank()) {
                mergeBillingAccount(r);
            }
            if (r.getPremiseId() != null && !r.getPremiseId().isBlank()) {
                mergePremise(r);
                if (r.getMeterId() != null && !r.getMeterId().isBlank()) {
                    mergeMeter(r);
                }
            }
            writeCount.incrementAndGet();
        }
        log.debug("CustomerAccountWriter: flushed {} rows, total={}", chunk.size(), writeCount.get());
    }

    // -------------------------------------------------------------------------
    // TGT_ENERGY_ACCOUNT
    // -------------------------------------------------------------------------

    private void mergeEnergyAccount(CustomerAccountRecord r) {
        final String sql =
            "MERGE INTO TGT_ENERGY_ACCOUNT tgt " +
            "USING (SELECT ? AS ENERGY_ACCOUNT_ID FROM DUAL) src " +
            "  ON (tgt.ENERGY_ACCOUNT_ID = src.ENERGY_ACCOUNT_ID) " +
            "WHEN MATCHED THEN UPDATE SET " +
            "  CUSTOMER_ID = ?, ACCOUNT_NUMBER = ?, ACCOUNT_STATUS = ?, " +
            "  SERVICE_TYPE = ?, RATE_CLASS = ?, OPEN_DATE = ?, CLOSE_DATE = ?, " +
            "  IS_ACTIVE = ?, SOURCE_UPDATED_AT = ?, ETL_RUN_ID = ?, " +
            "  ETL_LOAD_TS = SYS_EXTRACT_UTC(SYSTIMESTAMP), UPDATED_AT = SYS_EXTRACT_UTC(SYSTIMESTAMP) " +
            "WHEN NOT MATCHED THEN INSERT " +
            "  (ENERGY_ACCOUNT_ID, CUSTOMER_ID, ACCOUNT_NUMBER, ACCOUNT_STATUS, " +
            "   SERVICE_TYPE, RATE_CLASS, OPEN_DATE, CLOSE_DATE, IS_ACTIVE, SOURCE_UPDATED_AT, ETL_RUN_ID) " +
            "VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)";

        final int    isActive   = "ACTIVE".equals(r.getAccountStatus()) ? 1 : 0;
        final Date   openDate   = r.getOpenDate()  != null ? Date.valueOf(r.getOpenDate())  : null;
        final Date   closeDate  = r.getCloseDate() != null ? Date.valueOf(r.getCloseDate()) : null;
        final Timestamp srcUpd  = r.getRecordEffectiveTs() != null
            ? Timestamp.from(r.getRecordEffectiveTs().toInstant()) : null;
        final String svcType    = r.getServiceType() != null ? r.getServiceType() : "ELECTRIC";

        oracleJdbc.update(sql, (PreparedStatement ps) -> {
            int i = 1;
            // USING clause key
            ps.setString(i++, r.getEnergyAccountId());
            // WHEN MATCHED SET values (10 params)
            ps.setString(i++, r.getCustomerId());
            ps.setString(i++, r.getAccountNumber());
            ps.setString(i++, r.getAccountStatus());
            ps.setString(i++, svcType);
            ps.setString(i++, r.getRateClass());
            bindDate(ps, i++, openDate);                        // NOT NULL in DDL but guard for safety
            bindDate(ps, i++, closeDate);                       // nullable DATE
            ps.setInt(i++, isActive);
            bindTimestamp(ps, i++, srcUpd);                     // nullable TIMESTAMP
            ps.setLong(i++, etlRunId);
            // WHEN NOT MATCHED INSERT values (11 params)
            ps.setString(i++, r.getEnergyAccountId());
            ps.setString(i++, r.getCustomerId());
            ps.setString(i++, r.getAccountNumber());
            ps.setString(i++, r.getAccountStatus());
            ps.setString(i++, svcType);
            ps.setString(i++, r.getRateClass());
            bindDate(ps, i++, openDate);
            bindDate(ps, i++, closeDate);                       // nullable DATE
            ps.setInt(i++, isActive);
            bindTimestamp(ps, i++, srcUpd);                     // nullable TIMESTAMP
            ps.setLong(i,   etlRunId);
        });
    }

    // -------------------------------------------------------------------------
    // TGT_BILLING_ACCOUNT
    // -------------------------------------------------------------------------

    private void mergeBillingAccount(CustomerAccountRecord r) {
        final String sql =
            "MERGE INTO TGT_BILLING_ACCOUNT tgt " +
            "USING (SELECT ? AS BILLING_ACCOUNT_ID FROM DUAL) src " +
            "  ON (tgt.BILLING_ACCOUNT_ID = src.BILLING_ACCOUNT_ID) " +
            "WHEN MATCHED THEN UPDATE SET " +
            "  ENERGY_ACCOUNT_ID = ?, BILLING_ACCOUNT_NBR = ?, BILLING_CYCLE = ?, " +
            "  PAYMENT_METHOD = ?, AUTO_PAY_ENROLLED = ?, PAPERLESS_ENROLLED = ?, " +
            "  IS_CURRENT = 1, SOURCE_UPDATED_AT = ?, ETL_RUN_ID = ?, " +
            "  ETL_LOAD_TS = SYS_EXTRACT_UTC(SYSTIMESTAMP), UPDATED_AT = SYS_EXTRACT_UTC(SYSTIMESTAMP) " +
            "WHEN NOT MATCHED THEN INSERT " +
            "  (BILLING_ACCOUNT_ID, ENERGY_ACCOUNT_ID, BILLING_ACCOUNT_NBR, BILLING_CYCLE, " +
            "   PAYMENT_METHOD, AUTO_PAY_ENROLLED, PAPERLESS_ENROLLED, EFFECTIVE_DATE, IS_CURRENT, " +
            "   SOURCE_UPDATED_AT, ETL_RUN_ID) " +
            "VALUES (?, ?, ?, ?, ?, ?, ?, SYSDATE, 1, ?, ?)";

        final Timestamp srcUpd    = r.getRecordEffectiveTs() != null
            ? Timestamp.from(r.getRecordEffectiveTs().toInstant()) : null;
        final int autoPay   = Boolean.TRUE.equals(r.getAutoPayEnrolled())   ? 1 : 0;
        final int paperless = Boolean.TRUE.equals(r.getPaperlessEnrolled()) ? 1 : 0;
        final String pmtMethod = r.getPaymentMethod() != null ? r.getPaymentMethod() : "PAPER_BILL";

        oracleJdbc.update(sql, (PreparedStatement ps) -> {
            int i = 1;
            // USING clause key
            ps.setString(i++, r.getBillingAccountId());
            // WHEN MATCHED SET values (8 params)
            ps.setString(i++, r.getEnergyAccountId());
            ps.setString(i++, r.getBillingAccountNbr());
            ps.setString(i++, r.getBillingCycle());
            ps.setString(i++, pmtMethod);
            ps.setInt(i++, autoPay);
            ps.setInt(i++, paperless);
            bindTimestamp(ps, i++, srcUpd);                     // nullable TIMESTAMP
            ps.setLong(i++, etlRunId);
            // WHEN NOT MATCHED INSERT values (9 params)
            ps.setString(i++, r.getBillingAccountId());
            ps.setString(i++, r.getEnergyAccountId());
            ps.setString(i++, r.getBillingAccountNbr());
            ps.setString(i++, r.getBillingCycle());
            ps.setString(i++, pmtMethod);
            ps.setInt(i++, autoPay);
            ps.setInt(i++, paperless);
            bindTimestamp(ps, i++, srcUpd);                     // nullable TIMESTAMP
            ps.setLong(i,   etlRunId);
        });
    }

    // -------------------------------------------------------------------------
    // TGT_PREMISE
    // -------------------------------------------------------------------------

    private void mergePremise(CustomerAccountRecord r) {
        final String sql =
            "MERGE INTO TGT_PREMISE tgt " +
            "USING (SELECT ? AS PREMISE_ID FROM DUAL) src " +
            "  ON (tgt.PREMISE_ID = src.PREMISE_ID) " +
            "WHEN MATCHED THEN UPDATE SET " +
            "  ENERGY_ACCOUNT_ID = ?, ADDRESS_LINE1 = ?, ADDRESS_LINE2 = ?, CITY = ?, " +
            "  STATE_CODE = ?, ZIP_CODE = ?, COUNTY = ?, " +
            "  GEO_LATITUDE = ?, GEO_LONGITUDE = ?, PREMISE_TYPE = ?, FULL_ADDRESS = ?, " +
            "  IS_CURRENT = 1, SOURCE_UPDATED_AT = ?, ETL_RUN_ID = ?, " +
            "  ETL_LOAD_TS = SYS_EXTRACT_UTC(SYSTIMESTAMP), UPDATED_AT = SYS_EXTRACT_UTC(SYSTIMESTAMP) " +
            "WHEN NOT MATCHED THEN INSERT " +
            "  (PREMISE_ID, ENERGY_ACCOUNT_ID, ADDRESS_LINE1, ADDRESS_LINE2, CITY, " +
            "   STATE_CODE, ZIP_CODE, COUNTY, GEO_LATITUDE, GEO_LONGITUDE, " +
            "   PREMISE_TYPE, FULL_ADDRESS, EFFECTIVE_DATE, IS_CURRENT, SOURCE_UPDATED_AT, ETL_RUN_ID) " +
            "VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, SYSDATE, 1, ?, ?)";

        final Timestamp srcUpd = r.getRecordEffectiveTs() != null
            ? Timestamp.from(r.getRecordEffectiveTs().toInstant()) : null;

        oracleJdbc.update(sql, (PreparedStatement ps) -> {
            int i = 1;
            // USING clause key
            ps.setString(i++, r.getPremiseId());
            // WHEN MATCHED SET values (13 params)
            ps.setString(i++, r.getEnergyAccountId());
            ps.setString(i++, r.getAddressLine1());
            ps.setString(i++, r.getAddressLine2());             // nullable VARCHAR2
            ps.setString(i++, r.getCity());
            ps.setString(i++, r.getStateCode());
            ps.setString(i++, r.getZipCode());
            ps.setString(i++, r.getCounty());                   // nullable VARCHAR2
            bindDecimal(ps, i++, r.getGeoLatitude());           // nullable NUMBER
            bindDecimal(ps, i++, r.getGeoLongitude());          // nullable NUMBER
            ps.setString(i++, r.getPremiseType());              // nullable VARCHAR2
            ps.setString(i++, r.getFullAddress());              // nullable VARCHAR2
            bindTimestamp(ps, i++, srcUpd);                     // nullable TIMESTAMP
            ps.setLong(i++, etlRunId);
            // WHEN NOT MATCHED INSERT values (15 params)
            ps.setString(i++, r.getPremiseId());
            ps.setString(i++, r.getEnergyAccountId());
            ps.setString(i++, r.getAddressLine1());
            ps.setString(i++, r.getAddressLine2());             // nullable VARCHAR2
            ps.setString(i++, r.getCity());
            ps.setString(i++, r.getStateCode());
            ps.setString(i++, r.getZipCode());
            ps.setString(i++, r.getCounty());                   // nullable VARCHAR2
            bindDecimal(ps, i++, r.getGeoLatitude());           // nullable NUMBER
            bindDecimal(ps, i++, r.getGeoLongitude());          // nullable NUMBER
            ps.setString(i++, r.getPremiseType());              // nullable VARCHAR2
            ps.setString(i++, r.getFullAddress());              // nullable VARCHAR2
            bindTimestamp(ps, i++, srcUpd);                     // nullable TIMESTAMP
            ps.setLong(i,   etlRunId);
        });
    }

    // -------------------------------------------------------------------------
    // TGT_METER
    // -------------------------------------------------------------------------

    private void mergeMeter(CustomerAccountRecord r) {
        final String sql =
            "MERGE INTO TGT_METER tgt " +
            "USING (SELECT ? AS METER_ID FROM DUAL) src " +
            "  ON (tgt.METER_ID = src.METER_ID) " +
            "WHEN MATCHED THEN UPDATE SET " +
            "  PREMISE_ID = ?, METER_NUMBER = ?, METER_TYPE = ?, INSTALL_DATE = ?, " +
            "  IS_ACTIVE = 1, SOURCE_UPDATED_AT = ?, ETL_RUN_ID = ?, " +
            "  ETL_LOAD_TS = SYS_EXTRACT_UTC(SYSTIMESTAMP), UPDATED_AT = SYS_EXTRACT_UTC(SYSTIMESTAMP) " +
            "WHEN NOT MATCHED THEN INSERT " +
            "  (METER_ID, PREMISE_ID, METER_NUMBER, METER_TYPE, INSTALL_DATE, " +
            "   IS_ACTIVE, SOURCE_UPDATED_AT, ETL_RUN_ID) " +
            "VALUES (?, ?, ?, ?, ?, 1, ?, ?)";

        final Timestamp srcUpd      = r.getRecordEffectiveTs() != null
            ? Timestamp.from(r.getRecordEffectiveTs().toInstant()) : null;
        final Date      installDate = r.getInstallDate() != null
            ? Date.valueOf(r.getInstallDate()) : null;
        final String    meterType   = r.getMeterType() != null ? r.getMeterType() : "ANALOG";

        oracleJdbc.update(sql, (PreparedStatement ps) -> {
            int i = 1;
            // USING clause key
            ps.setString(i++, r.getMeterId());
            // WHEN MATCHED SET values (6 params)
            ps.setString(i++, r.getPremiseId());
            ps.setString(i++, r.getMeterNumber());
            ps.setString(i++, meterType);
            bindDate(ps, i++, installDate);                     // NOT NULL in DDL but guard for safety
            bindTimestamp(ps, i++, srcUpd);                     // nullable TIMESTAMP
            ps.setLong(i++, etlRunId);
            // WHEN NOT MATCHED INSERT values (7 params)
            ps.setString(i++, r.getMeterId());
            ps.setString(i++, r.getPremiseId());
            ps.setString(i++, r.getMeterNumber());
            ps.setString(i++, meterType);
            bindDate(ps, i++, installDate);
            bindTimestamp(ps, i++, srcUpd);                     // nullable TIMESTAMP
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

    private static void bindDecimal(PreparedStatement ps, int index, java.math.BigDecimal value)
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
