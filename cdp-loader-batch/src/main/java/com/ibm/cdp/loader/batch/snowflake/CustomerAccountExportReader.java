package com.ibm.cdp.loader.batch.snowflake;

import com.ibm.cdp.loader.core.model.CustomerAccountRecord;
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
 * Reads rows from VW_DAILY_CUSTOMER_ACCOUNT_EXPORT.
 * One row per ENERGY_ACCOUNT.
 */
public class CustomerAccountExportReader {

    private static final String COLUMNS =
        "ENERGY_ACCOUNT_ID, ACCOUNT_NUMBER, ACCOUNT_STATUS, SERVICE_TYPE, RATE_CLASS, " +
        "OPEN_DATE, CLOSE_DATE, CUSTOMER_ID, FIRST_NAME, LAST_NAME, MIDDLE_NAME, NAME_SUFFIX, " +
        "FULL_NAME_NORMALIZED, CUSTOMER_TYPE, PREFERRED_LANGUAGE, CUSTOMER_STATUS, " +
        "EMAIL_ADDRESS, EMAIL_VERIFIED, PHONE_NUMBER, " +
        "BILLING_ACCOUNT_ID, BILLING_ACCOUNT_NBR, BILLING_CYCLE, PAYMENT_METHOD, " +
        "AUTO_PAY_ENROLLED, PAPERLESS_ENROLLED, " +
        "PREMISE_ID, ADDRESS_LINE1, ADDRESS_LINE2, CITY, STATE_CODE, ZIP_CODE, COUNTY, " +
        "GEO_LATITUDE, GEO_LONGITUDE, PREMISE_TYPE, FULL_ADDRESS, " +
        "METER_ID, METER_NUMBER, METER_TYPE, INSTALL_DATE, " +
        "ACCT_STATUS_LABEL, CUST_TYPE_LABEL, RECORD_EFFECTIVE_TS";

    private static final String SQL_ALL =
        "SELECT " + COLUMNS + " FROM STAGING.VW_DAILY_CUSTOMER_ACCOUNT_EXPORT " +
        "ORDER BY RECORD_EFFECTIVE_TS, ENERGY_ACCOUNT_ID";

    private static final String SQL_INCREMENTAL =
        "SELECT " + COLUMNS + " FROM STAGING.VW_DAILY_CUSTOMER_ACCOUNT_EXPORT " +
        "WHERE RECORD_EFFECTIVE_TS > ? " +
        "   OR (RECORD_EFFECTIVE_TS = ? AND ENERGY_ACCOUNT_ID > ?) " +
        "ORDER BY RECORD_EFFECTIVE_TS, ENERGY_ACCOUNT_ID";

    public static JdbcCursorItemReader<CustomerAccountRecord> buildInitialReader(
            DataSource snowflakeDs, int fetchSize) {
        return new JdbcCursorItemReaderBuilder<CustomerAccountRecord>()
                .name("customerAccountExportInitialReader")
                .dataSource(snowflakeDs)
                .sql(SQL_ALL)
                .rowMapper(new AccountRowMapper())
                .fetchSize(fetchSize)
                .build();
    }

    public static JdbcCursorItemReader<CustomerAccountRecord> buildIncrementalReader(
            DataSource snowflakeDs, int fetchSize,
            java.time.Instant lastTs, String lastSourceId) {
        Timestamp ts = Timestamp.from(lastTs);
        String lastId = lastSourceId != null ? lastSourceId : "";
        return new JdbcCursorItemReaderBuilder<CustomerAccountRecord>()
                .name("customerAccountExportIncrementalReader")
                .dataSource(snowflakeDs)
                .sql(SQL_INCREMENTAL)
                .queryArguments(ts, ts, lastId)
                .rowMapper(new AccountRowMapper())
                .fetchSize(fetchSize)
                .build();
    }

    static class AccountRowMapper implements RowMapper<CustomerAccountRecord> {
        @Override
        public CustomerAccountRecord mapRow(ResultSet rs, int rowNum) throws SQLException {
            CustomerAccountRecord r = new CustomerAccountRecord();
            r.setEnergyAccountId(rs.getString("ENERGY_ACCOUNT_ID"));
            r.setAccountNumber(rs.getString("ACCOUNT_NUMBER"));
            r.setAccountStatus(rs.getString("ACCOUNT_STATUS"));
            r.setServiceType(rs.getString("SERVICE_TYPE"));
            r.setRateClass(rs.getString("RATE_CLASS"));
            r.setOpenDate(rs.getDate("OPEN_DATE") != null ? rs.getDate("OPEN_DATE").toLocalDate() : null);
            r.setCloseDate(rs.getDate("CLOSE_DATE") != null ? rs.getDate("CLOSE_DATE").toLocalDate() : null);
            r.setCustomerId(rs.getString("CUSTOMER_ID"));
            r.setFirstName(rs.getString("FIRST_NAME"));
            r.setLastName(rs.getString("LAST_NAME"));
            r.setMiddleName(rs.getString("MIDDLE_NAME"));
            r.setNameSuffix(rs.getString("NAME_SUFFIX"));
            r.setFullNameNormalized(rs.getString("FULL_NAME_NORMALIZED"));
            r.setCustomerType(rs.getString("CUSTOMER_TYPE"));
            r.setPreferredLanguage(rs.getString("PREFERRED_LANGUAGE"));
            r.setCustomerStatus(rs.getString("CUSTOMER_STATUS"));
            r.setEmailAddress(rs.getString("EMAIL_ADDRESS"));
            r.setEmailVerified(rs.getObject("EMAIL_VERIFIED") != null ? rs.getBoolean("EMAIL_VERIFIED") : null);
            r.setPhoneNumber(rs.getString("PHONE_NUMBER"));
            r.setBillingAccountId(rs.getString("BILLING_ACCOUNT_ID"));
            r.setBillingAccountNbr(rs.getString("BILLING_ACCOUNT_NBR"));
            r.setBillingCycle(rs.getString("BILLING_CYCLE"));
            r.setPaymentMethod(rs.getString("PAYMENT_METHOD"));
            r.setAutoPayEnrolled(rs.getObject("AUTO_PAY_ENROLLED") != null ? rs.getBoolean("AUTO_PAY_ENROLLED") : null);
            r.setPaperlessEnrolled(rs.getObject("PAPERLESS_ENROLLED") != null ? rs.getBoolean("PAPERLESS_ENROLLED") : null);
            r.setPremiseId(rs.getString("PREMISE_ID"));
            r.setAddressLine1(rs.getString("ADDRESS_LINE1"));
            r.setAddressLine2(rs.getString("ADDRESS_LINE2"));
            r.setCity(rs.getString("CITY"));
            r.setStateCode(rs.getString("STATE_CODE"));
            r.setZipCode(rs.getString("ZIP_CODE"));
            r.setCounty(rs.getString("COUNTY"));
            r.setGeoLatitude(rs.getBigDecimal("GEO_LATITUDE"));
            r.setGeoLongitude(rs.getBigDecimal("GEO_LONGITUDE"));
            r.setPremiseType(rs.getString("PREMISE_TYPE"));
            r.setFullAddress(rs.getString("FULL_ADDRESS"));
            r.setMeterId(rs.getString("METER_ID"));
            r.setMeterNumber(rs.getString("METER_NUMBER"));
            r.setMeterType(rs.getString("METER_TYPE"));
            r.setInstallDate(rs.getDate("INSTALL_DATE") != null ? rs.getDate("INSTALL_DATE").toLocalDate() : null);
            r.setAcctStatusLabel(rs.getString("ACCT_STATUS_LABEL"));
            r.setCustTypeLabel(rs.getString("CUST_TYPE_LABEL"));
            r.setRecordEffectiveTs(toOdt(rs.getTimestamp("RECORD_EFFECTIVE_TS")));
            return r;
        }

        private static OffsetDateTime toOdt(Timestamp ts) {
            return ts != null ? ts.toInstant().atOffset(ZoneOffset.UTC) : null;
        }
    }
}
