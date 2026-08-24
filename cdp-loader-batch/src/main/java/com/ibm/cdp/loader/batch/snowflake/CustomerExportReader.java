package com.ibm.cdp.loader.batch.snowflake;

import com.ibm.cdp.loader.core.model.CustomerRecord;
import org.springframework.batch.item.database.JdbcCursorItemReader;
import org.springframework.batch.item.database.builder.JdbcCursorItemReaderBuilder;
import org.springframework.jdbc.core.RowMapper;

import javax.sql.DataSource;
import java.sql.ResultSet;
import java.sql.SQLException;
import java.sql.Timestamp;
import java.time.OffsetDateTime;
import java.time.ZoneOffset;

/**
 * Reads rows from VW_DAILY_CUSTOMER_EXPORT.
 * Returns all rows (initial load) or rows newer than the watermark (incremental).
 *
 * <p>Composite watermark condition:
 * RECORD_EFFECTIVE_TS > :lastTimestamp
 * OR (RECORD_EFFECTIVE_TS = :lastTimestamp AND CUSTOMER_ID > :lastSourceId)
 *
 * <p>ORDER BY ensures deterministic cursor and correct watermark advance.
 */
public class CustomerExportReader {

    private static final String SQL_ALL =
        "SELECT CUSTOMER_ID, FIRST_NAME, LAST_NAME, MIDDLE_NAME, NAME_SUFFIX, " +
        "FULL_NAME_NORMALIZED, CUSTOMER_TYPE, CUST_TYPE_LABEL, PREFERRED_LANGUAGE, " +
        "CUSTOMER_STATUS, ACCT_STATUS_LABEL, IS_INACTIVE, STATUS_REASON, " +
        "EMAIL_ADDRESS, EMAIL_VERIFIED, PHONE_NUMBER, " +
        "RECORD_EFFECTIVE_TS, CREATED_AT, UPDATED_AT " +
        "FROM STAGING.VW_DAILY_CUSTOMER_EXPORT " +
        "ORDER BY RECORD_EFFECTIVE_TS, CUSTOMER_ID";

    private static final String SQL_INCREMENTAL =
        "SELECT CUSTOMER_ID, FIRST_NAME, LAST_NAME, MIDDLE_NAME, NAME_SUFFIX, " +
        "FULL_NAME_NORMALIZED, CUSTOMER_TYPE, CUST_TYPE_LABEL, PREFERRED_LANGUAGE, " +
        "CUSTOMER_STATUS, ACCT_STATUS_LABEL, IS_INACTIVE, STATUS_REASON, " +
        "EMAIL_ADDRESS, EMAIL_VERIFIED, PHONE_NUMBER, " +
        "RECORD_EFFECTIVE_TS, CREATED_AT, UPDATED_AT " +
        "FROM STAGING.VW_DAILY_CUSTOMER_EXPORT " +
        "WHERE RECORD_EFFECTIVE_TS > ? " +
        "   OR (RECORD_EFFECTIVE_TS = ? AND CUSTOMER_ID > ?) " +
        "ORDER BY RECORD_EFFECTIVE_TS, CUSTOMER_ID";

    /**
     * Builds a reader for the initial load — all rows.
     */
    public static JdbcCursorItemReader<CustomerRecord> buildInitialReader(
            DataSource snowflakeDs, int fetchSize) {
        return new JdbcCursorItemReaderBuilder<CustomerRecord>()
                .name("customerExportInitialReader")
                .dataSource(snowflakeDs)
                .sql(SQL_ALL)
                .rowMapper(new CustomerRowMapper())
                .fetchSize(fetchSize)
                .build();
    }

    /**
     * Builds a reader for incremental load — rows newer than watermark.
     */
    public static JdbcCursorItemReader<CustomerRecord> buildIncrementalReader(
            DataSource snowflakeDs, int fetchSize,
            java.time.Instant lastTs, String lastSourceId) {
        Timestamp ts = Timestamp.from(lastTs);
        String lastId = lastSourceId != null ? lastSourceId : "";
        return new JdbcCursorItemReaderBuilder<CustomerRecord>()
                .name("customerExportIncrementalReader")
                .dataSource(snowflakeDs)
                .sql(SQL_INCREMENTAL)
                .queryArguments(ts, ts, lastId)
                .rowMapper(new CustomerRowMapper())
                .fetchSize(fetchSize)
                .build();
    }

    static class CustomerRowMapper implements RowMapper<CustomerRecord> {
        @Override
        public CustomerRecord mapRow(ResultSet rs, int rowNum) throws SQLException {
            CustomerRecord r = new CustomerRecord();
            r.setCustomerId(rs.getString("CUSTOMER_ID"));
            r.setFirstName(rs.getString("FIRST_NAME"));
            r.setLastName(rs.getString("LAST_NAME"));
            r.setMiddleName(rs.getString("MIDDLE_NAME"));
            r.setNameSuffix(rs.getString("NAME_SUFFIX"));
            r.setFullNameNormalized(rs.getString("FULL_NAME_NORMALIZED"));
            r.setCustomerType(rs.getString("CUSTOMER_TYPE"));
            r.setCustomerTypeLabel(rs.getString("CUST_TYPE_LABEL"));
            r.setPreferredLanguage(rs.getString("PREFERRED_LANGUAGE"));
            r.setCustomerStatus(rs.getString("CUSTOMER_STATUS"));
            r.setAccountStatusLabel(rs.getString("ACCT_STATUS_LABEL"));
            r.setIsInactive(rs.getBoolean("IS_INACTIVE"));
            r.setStatusReason(rs.getString("STATUS_REASON"));
            r.setEmailAddress(rs.getString("EMAIL_ADDRESS"));
            Boolean emailVerified = rs.getObject("EMAIL_VERIFIED") != null ? rs.getBoolean("EMAIL_VERIFIED") : null;
            r.setEmailVerified(emailVerified);
            r.setPhoneNumber(rs.getString("PHONE_NUMBER"));
            r.setRecordEffectiveTs(toOffsetDateTime(rs.getTimestamp("RECORD_EFFECTIVE_TS")));
            r.setCreatedAt(toOffsetDateTime(rs.getTimestamp("CREATED_AT")));
            r.setUpdatedAt(toOffsetDateTime(rs.getTimestamp("UPDATED_AT")));
            return r;
        }

        private static OffsetDateTime toOffsetDateTime(Timestamp ts) {
            return ts != null ? ts.toInstant().atOffset(ZoneOffset.UTC) : null;
        }
    }
}
