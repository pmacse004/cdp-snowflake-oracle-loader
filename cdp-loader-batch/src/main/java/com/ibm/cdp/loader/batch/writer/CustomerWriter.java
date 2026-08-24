package com.ibm.cdp.loader.batch.writer;

import com.ibm.cdp.loader.core.model.CustomerRecord;
import lombok.extern.slf4j.Slf4j;
import org.springframework.batch.core.configuration.annotation.StepScope;
import org.springframework.batch.item.Chunk;
import org.springframework.batch.item.ItemWriter;
import org.springframework.beans.factory.annotation.Qualifier;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Component;

import java.sql.PreparedStatement;
import java.sql.SQLException;
import java.sql.Timestamp;
import java.sql.Types;
import java.util.concurrent.atomic.AtomicLong;

/**
 * Writes {@link CustomerRecord} rows to TGT_CUSTOMER using Oracle MERGE.
 *
 * <p>Idempotent — safe to rerun. Preserves CREATED_AT on update.
 * IS_ACTIVE = 1 when ACCOUNT_STATUS is not INACTIVE, else 0.
 *
 * <p>All nullable columns are bound with explicit JDBC types via
 * {@link PreparedStatement} to avoid ORA-17004 on Oracle JDBC.
 *
 * <p>Declared {@code @StepScope} so that {@code etlRunId} is resolved from
 * {@code JobParameters} at step-execution time — never captures {@code 0L}
 * at singleton bean construction.
 */
@Slf4j
@Component
@StepScope
public class CustomerWriter implements ItemWriter<CustomerRecord> {

    private static final String MERGE_SQL =
        "MERGE INTO TGT_CUSTOMER tgt " +
        "USING (SELECT ? AS CUSTOMER_ID FROM DUAL) src " +
        "  ON (tgt.CUSTOMER_ID = src.CUSTOMER_ID) " +
        "WHEN MATCHED THEN UPDATE SET " +
        "  FIRST_NAME           = ?, " +
        "  LAST_NAME            = ?, " +
        "  MIDDLE_NAME          = ?, " +
        "  NAME_SUFFIX          = ?, " +
        "  FULL_NAME_NORMALIZED = ?, " +
        "  CUSTOMER_TYPE        = ?, " +
        "  CUSTOMER_TYPE_LABEL  = ?, " +
        "  PREFERRED_LANGUAGE   = ?, " +
        "  ACCOUNT_STATUS       = ?, " +
        "  ACCOUNT_STATUS_LABEL = ?, " +
        "  IS_ACTIVE            = ?, " +
        "  SOURCE_UPDATED_AT    = ?, " +
        "  ETL_RUN_ID           = ?, " +
        "  ETL_LOAD_TS          = SYS_EXTRACT_UTC(SYSTIMESTAMP), " +
        "  UPDATED_AT           = SYS_EXTRACT_UTC(SYSTIMESTAMP) " +
        "WHEN NOT MATCHED THEN INSERT " +
        "  (CUSTOMER_ID, FIRST_NAME, LAST_NAME, MIDDLE_NAME, NAME_SUFFIX, " +
        "   FULL_NAME_NORMALIZED, CUSTOMER_TYPE, CUSTOMER_TYPE_LABEL, PREFERRED_LANGUAGE, " +
        "   ACCOUNT_STATUS, ACCOUNT_STATUS_LABEL, IS_ACTIVE, SOURCE_UPDATED_AT, ETL_RUN_ID) " +
        "VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)";

    private final JdbcTemplate oracleJdbc;
    private final long etlRunId;
    private final AtomicLong writeCount = new AtomicLong(0);

    public CustomerWriter(
            @Qualifier("oracleJdbcTemplate") JdbcTemplate oracleJdbc,
            @Value("#{jobParameters['etlRunId']}") Long etlRunId) {
        this.oracleJdbc = oracleJdbc;
        this.etlRunId   = etlRunId != null ? etlRunId : 0L;
    }

    @Override
    public void write(Chunk<? extends CustomerRecord> chunk) {
        for (CustomerRecord r : chunk) {
            final int isActive = Boolean.TRUE.equals(r.getIsInactive()) ? 0 : 1;
            final Timestamp srcUpdated = r.getUpdatedAt() != null
                ? Timestamp.from(r.getUpdatedAt().toInstant()) : null;
            final String lang = r.getPreferredLanguage() != null ? r.getPreferredLanguage() : "EN";

            oracleJdbc.update(MERGE_SQL, (PreparedStatement ps) -> {
                int i = 1;
                // USING clause key
                ps.setString(i++, r.getCustomerId());
                // WHEN MATCHED SET values (13 params)
                ps.setString(i++, r.getFirstName());
                ps.setString(i++, r.getLastName());
                ps.setString(i++, r.getMiddleName());           // nullable VARCHAR2
                ps.setString(i++, r.getNameSuffix());           // nullable VARCHAR2
                ps.setString(i++, r.getFullNameNormalized());
                ps.setString(i++, r.getCustomerType());
                ps.setString(i++, r.getCustomerTypeLabel());    // nullable VARCHAR2
                ps.setString(i++, lang);
                ps.setString(i++, r.getCustomerStatus());
                ps.setString(i++, r.getAccountStatusLabel());   // nullable VARCHAR2
                ps.setInt(i++, isActive);
                bindTimestamp(ps, i++, srcUpdated);             // nullable TIMESTAMP
                ps.setLong(i++, etlRunId);
                // WHEN NOT MATCHED INSERT values (14 params)
                ps.setString(i++, r.getCustomerId());
                ps.setString(i++, r.getFirstName());
                ps.setString(i++, r.getLastName());
                ps.setString(i++, r.getMiddleName());           // nullable VARCHAR2
                ps.setString(i++, r.getNameSuffix());           // nullable VARCHAR2
                ps.setString(i++, r.getFullNameNormalized());
                ps.setString(i++, r.getCustomerType());
                ps.setString(i++, r.getCustomerTypeLabel());    // nullable VARCHAR2
                ps.setString(i++, lang);
                ps.setString(i++, r.getCustomerStatus());
                ps.setString(i++, r.getAccountStatusLabel());   // nullable VARCHAR2
                ps.setInt(i++, isActive);
                bindTimestamp(ps, i++, srcUpdated);             // nullable TIMESTAMP
                ps.setLong(i,   etlRunId);
            });
            writeCount.incrementAndGet();
        }
        log.debug("CustomerWriter: flushed {} rows, total={}", chunk.size(), writeCount.get());
    }

    /** Binds a {@link Timestamp} or SQL NULL(TIMESTAMP) at the given parameter index. */
    private static void bindTimestamp(PreparedStatement ps, int index, Timestamp value)
            throws SQLException {
        if (value != null) {
            ps.setTimestamp(index, value);
        } else {
            ps.setNull(index, Types.TIMESTAMP);
        }
    }
}
