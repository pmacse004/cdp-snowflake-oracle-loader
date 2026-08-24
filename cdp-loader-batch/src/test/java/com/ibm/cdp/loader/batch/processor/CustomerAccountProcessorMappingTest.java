package com.ibm.cdp.loader.batch.processor;

import com.ibm.cdp.loader.batch.repository.EtlRecordErrorRepository;
import com.ibm.cdp.loader.core.exception.RecordValidationException;
import com.ibm.cdp.loader.core.model.CustomerAccountRecord;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.params.ParameterizedTest;
import org.junit.jupiter.params.provider.ValueSource;

import java.time.LocalDate;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.ArgumentMatchers.anyLong;
import static org.mockito.ArgumentMatchers.anyString;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;

/**
 * Unit tests for {@link CustomerAccountProcessor} ICA CLOSED account mapping.
 *
 * <p>No Spring context — processor constructed directly.
 *
 * <h2>Scenarios verified</h2>
 * <ol>
 *   <li>Source CLOSED → accountStatus mutated to INACTIVE → record passes validation and
 *       is returned (IS_ACTIVE=0 because the writer maps any non-ACTIVE to 0).</li>
 *   <li>After translation, the returned record carries accountStatus="INACTIVE"
 *       so the writer will persist ACCOUNT_STATUS='INACTIVE' and IS_ACTIVE=0.</li>
 *   <li>A truly unsupported status ("DELINQUENT") still triggers
 *       RecordValidationException and a recordError call.</li>
 *   <li>Valid statuses (ACTIVE, INACTIVE, SUSPENDED, PENDING) pass unchanged.</li>
 * </ol>
 */
class CustomerAccountProcessorMappingTest {

    private EtlRecordErrorRepository errorRepo;
    private CustomerAccountProcessor processor;

    @BeforeEach
    void setUp() {
        errorRepo = mock(EtlRecordErrorRepository.class);
        processor = new CustomerAccountProcessor(11L, "INITIAL_LOAD_JOB", "initialLoadAccountsStep", errorRepo);
    }

    private CustomerAccountRecord minimalValid(String status) {
        CustomerAccountRecord r = new CustomerAccountRecord();
        r.setEnergyAccountId("EA-001");
        r.setCustomerId("C-001");
        r.setAccountNumber("ACCT-001");
        r.setAccountStatus(status);
        r.setRateClass("R1");
        r.setOpenDate(LocalDate.of(2020, 1, 1));
        return r;
    }

    // -------------------------------------------------------------------------
    // A) CLOSED → INACTIVE translation
    // -------------------------------------------------------------------------

    @Test
    void closed_account_is_translated_to_inactive_and_returned() throws Exception {
        CustomerAccountRecord r = minimalValid("CLOSED");

        CustomerAccountRecord result = processor.process(r);

        assertThat(result).isNotNull()
                .as("CLOSED account must not be rejected — it should be returned after translation");
        assertThat(result.getAccountStatus())
                .as("accountStatus must be INACTIVE after ICA soft-delete translation")
                .isEqualTo("INACTIVE");
    }

    @Test
    void closed_account_translation_never_calls_errorRepo() throws Exception {
        CustomerAccountRecord r = minimalValid("CLOSED");

        processor.process(r);

        verify(errorRepo, never()).recordError(
                anyLong(), anyString(), anyString(),
                anyString(), anyString(), anyString(), anyString(), anyString());
    }

    @Test
    void closed_account_result_has_inactive_status_so_writer_sets_isActive_zero() throws Exception {
        // The writer computes: isActive = "ACTIVE".equals(r.getAccountStatus()) ? 1 : 0
        // After translation accountStatus=="INACTIVE" → isActive == 0
        CustomerAccountRecord r = minimalValid("CLOSED");

        CustomerAccountRecord result = processor.process(r);

        boolean writerWouldSetActive = "ACTIVE".equals(result.getAccountStatus());
        assertThat(writerWouldSetActive)
                .as("Writer IS_ACTIVE computation must yield 0 for a formerly-CLOSED account")
                .isFalse();
    }

    // -------------------------------------------------------------------------
    // B) Truly unsupported status still rejected
    // -------------------------------------------------------------------------

    @Test
    void unsupported_status_is_rejected_with_ACCT_INVALID_STATUS() {
        CustomerAccountRecord r = minimalValid("DELINQUENT");

        assertThatThrownBy(() -> processor.process(r))
                .isInstanceOf(RecordValidationException.class)
                .extracting("errorCode").isEqualTo("ACCT_INVALID_STATUS");
    }

    @Test
    void unsupported_status_calls_errorRepo() {
        CustomerAccountRecord r = minimalValid("DELINQUENT");

        try { processor.process(r); } catch (RecordValidationException ignored) {}

        verify(errorRepo).recordError(
                anyLong(), anyString(), anyString(),
                anyString(), anyString(), anyString(), anyString(), anyString());
    }

    // -------------------------------------------------------------------------
    // C) Natively valid statuses pass through unchanged
    // -------------------------------------------------------------------------

    @ParameterizedTest
    @ValueSource(strings = {"ACTIVE", "INACTIVE", "SUSPENDED", "PENDING"})
    void native_valid_statuses_pass_unchanged(String status) throws Exception {
        CustomerAccountRecord r = minimalValid(status);

        CustomerAccountRecord result = processor.process(r);

        assertThat(result).isNotNull();
        assertThat(result.getAccountStatus()).isEqualTo(status);
    }
}
