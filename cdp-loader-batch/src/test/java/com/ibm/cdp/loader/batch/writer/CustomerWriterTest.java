package com.ibm.cdp.loader.batch.writer;

import com.ibm.cdp.loader.core.model.CustomerRecord;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.mockito.ArgumentCaptor;
import org.springframework.batch.item.Chunk;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.jdbc.core.PreparedStatementSetter;

import java.sql.PreparedStatement;
import java.sql.Timestamp;
import java.sql.Types;
import java.time.OffsetDateTime;
import java.time.ZoneOffset;

import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

/**
 * Unit tests for {@link CustomerWriter} null-parameter binding.
 *
 * <p>No Spring context needed — the writer is constructed directly.
 * A mock {@link JdbcTemplate} captures the {@link PreparedStatementSetter}
 * passed to it; the setter is then invoked against a mock {@link PreparedStatement}
 * so we can assert the exact JDBC type supplied for every nullable column.
 *
 * <p>Parameter index layout (1-based):
 * <pre>
 *  1          USING key (CUSTOMER_ID)
 *  UPDATE SET (13 params):
 *  2  FIRST_NAME           setString
 *  3  LAST_NAME            setString
 *  4  MIDDLE_NAME          setString / setNull(VARCHAR)
 *  5  NAME_SUFFIX          setString / setNull(VARCHAR)
 *  6  FULL_NAME_NORMALIZED setString
 *  7  CUSTOMER_TYPE        setString
 *  8  CUSTOMER_TYPE_LABEL  setString / setNull(VARCHAR)
 *  9  PREFERRED_LANGUAGE   setString
 * 10  ACCOUNT_STATUS       setString
 * 11  ACCOUNT_STATUS_LABEL setString / setNull(VARCHAR)
 * 12  IS_ACTIVE            setInt
 * 13  SOURCE_UPDATED_AT    setTimestamp / setNull(TIMESTAMP)
 * 14  ETL_RUN_ID           setLong
 *  INSERT VALUES (14 params):
 * 15  CUSTOMER_ID          setString
 * 16  FIRST_NAME           setString
 * 17  LAST_NAME            setString
 * 18  MIDDLE_NAME          setString / setNull(VARCHAR)
 * 19  NAME_SUFFIX          setString / setNull(VARCHAR)
 * 20  FULL_NAME_NORMALIZED setString
 * 21  CUSTOMER_TYPE        setString
 * 22  CUSTOMER_TYPE_LABEL  setString / setNull(VARCHAR)
 * 23  PREFERRED_LANGUAGE   setString
 * 24  ACCOUNT_STATUS       setString
 * 25  ACCOUNT_STATUS_LABEL setString / setNull(VARCHAR)
 * 26  IS_ACTIVE            setInt
 * 27  SOURCE_UPDATED_AT    setTimestamp / setNull(TIMESTAMP)
 * 28  ETL_RUN_ID           setLong
 * </pre>
 */
class CustomerWriterTest {

    private JdbcTemplate jdbc;
    private CustomerWriter writer;

    @BeforeEach
    void setUp() {
        jdbc   = mock(JdbcTemplate.class);
        writer = new CustomerWriter(jdbc, 7L);
    }

    // -------------------------------------------------------------------------
    // Helpers
    // -------------------------------------------------------------------------

    private CustomerRecord minimalRecord() {
        CustomerRecord r = new CustomerRecord();
        r.setCustomerId("C001");
        r.setFirstName("Alice");
        r.setLastName("Smith");
        r.setFullNameNormalized("ALICE SMITH");
        r.setCustomerType("RESIDENTIAL");
        r.setCustomerStatus("ACTIVE");
        return r;
    }

    /**
     * Invokes the writer, captures the PSS, and fires it against a mock PS.
     * Returns the mock PreparedStatement so callers can verify calls on it.
     */
    private PreparedStatement captureAndInvoke(CustomerRecord record) throws Exception {
        ArgumentCaptor<PreparedStatementSetter> pssCaptor =
            ArgumentCaptor.forClass(PreparedStatementSetter.class);
        when(jdbc.update(any(String.class), pssCaptor.capture())).thenReturn(1);

        writer.write(Chunk.of(record));

        PreparedStatement ps = mock(PreparedStatement.class);
        pssCaptor.getValue().setValues(ps);
        return ps;
    }

    // -------------------------------------------------------------------------
    // A) All nullable string fields null → setString(index, null) (VARCHAR2)
    // -------------------------------------------------------------------------

    @Test
    void null_middleName_is_bound_as_setString_null() throws Exception {
        CustomerRecord r = minimalRecord();
        r.setMiddleName(null);

        PreparedStatement ps = captureAndInvoke(r);

        // UPDATE position 4, INSERT position 18
        verify(ps).setString(4,  null);
        verify(ps).setString(18, null);
    }

    @Test
    void null_nameSuffix_is_bound_as_setString_null() throws Exception {
        CustomerRecord r = minimalRecord();
        r.setNameSuffix(null);

        PreparedStatement ps = captureAndInvoke(r);

        // UPDATE position 5, INSERT position 19
        verify(ps).setString(5,  null);
        verify(ps).setString(19, null);
    }

    @Test
    void null_customerTypeLabel_is_bound_as_setString_null() throws Exception {
        CustomerRecord r = minimalRecord();
        r.setCustomerTypeLabel(null);

        PreparedStatement ps = captureAndInvoke(r);

        // UPDATE position 8, INSERT position 22
        verify(ps).setString(8,  null);
        verify(ps).setString(22, null);
    }

    @Test
    void null_accountStatusLabel_is_bound_as_setString_null() throws Exception {
        CustomerRecord r = minimalRecord();
        r.setAccountStatusLabel(null);

        PreparedStatement ps = captureAndInvoke(r);

        // UPDATE position 11, INSERT position 25
        verify(ps).setString(11, null);
        verify(ps).setString(25, null);
    }

    // -------------------------------------------------------------------------
    // B) Null SOURCE_UPDATED_AT → setNull(index, Types.TIMESTAMP)
    // -------------------------------------------------------------------------

    @Test
    void null_sourceUpdatedAt_binds_setNull_TIMESTAMP() throws Exception {
        CustomerRecord r = minimalRecord();
        r.setUpdatedAt(null);

        PreparedStatement ps = captureAndInvoke(r);

        // UPDATE position 13, INSERT position 27
        verify(ps).setNull(13, Types.TIMESTAMP);
        verify(ps).setNull(27, Types.TIMESTAMP);
    }

    // -------------------------------------------------------------------------
    // C) Non-null SOURCE_UPDATED_AT → setTimestamp
    // -------------------------------------------------------------------------

    @Test
    void non_null_sourceUpdatedAt_binds_setTimestamp() throws Exception {
        CustomerRecord r = minimalRecord();
        OffsetDateTime ts = OffsetDateTime.of(2024, 6, 1, 12, 0, 0, 0, ZoneOffset.UTC);
        r.setUpdatedAt(ts);

        PreparedStatement ps = captureAndInvoke(r);

        Timestamp expected = Timestamp.from(ts.toInstant());
        // UPDATE position 13, INSERT position 27
        verify(ps).setTimestamp(13, expected);
        verify(ps).setTimestamp(27, expected);
    }

    // -------------------------------------------------------------------------
    // D) Non-null optional strings are forwarded correctly
    // -------------------------------------------------------------------------

    @Test
    void non_null_middleName_and_suffix_are_bound_correctly() throws Exception {
        CustomerRecord r = minimalRecord();
        r.setMiddleName("Marie");
        r.setNameSuffix("Jr.");

        PreparedStatement ps = captureAndInvoke(r);

        verify(ps).setString(4,  "Marie");
        verify(ps).setString(5,  "Jr.");
        verify(ps).setString(18, "Marie");
        verify(ps).setString(19, "Jr.");
    }

    // -------------------------------------------------------------------------
    // E) Null preferredLanguage defaults to "EN"
    // -------------------------------------------------------------------------

    @Test
    void null_preferredLanguage_defaults_to_EN() throws Exception {
        CustomerRecord r = minimalRecord();
        r.setPreferredLanguage(null);

        PreparedStatement ps = captureAndInvoke(r);

        // UPDATE position 9, INSERT position 23
        verify(ps).setString(9,  "EN");
        verify(ps).setString(23, "EN");
    }

    // -------------------------------------------------------------------------
    // F) isInactive=true → IS_ACTIVE=0
    // -------------------------------------------------------------------------

    @Test
    void isInactive_true_sets_isActive_to_zero() throws Exception {
        CustomerRecord r = minimalRecord();
        r.setIsInactive(true);

        PreparedStatement ps = captureAndInvoke(r);

        // UPDATE position 12, INSERT position 26
        verify(ps).setInt(12, 0);
        verify(ps).setInt(26, 0);
    }

    // -------------------------------------------------------------------------
    // G) ETL run-id is always bound, not 0
    // -------------------------------------------------------------------------

    @Test
    void etlRunId_is_bound_with_injected_value() throws Exception {
        CustomerRecord r = minimalRecord();

        PreparedStatement ps = captureAndInvoke(r);

        // UPDATE position 14, INSERT position 28
        verify(ps).setLong(14, 7L);
        verify(ps).setLong(28, 7L);
    }
}
