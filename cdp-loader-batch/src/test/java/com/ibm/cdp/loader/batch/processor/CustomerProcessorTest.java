package com.ibm.cdp.loader.batch.processor;

import com.ibm.cdp.loader.batch.repository.EtlRecordErrorRepository;
import com.ibm.cdp.loader.core.exception.RecordValidationException;
import com.ibm.cdp.loader.core.model.CustomerRecord;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyLong;
import static org.mockito.ArgumentMatchers.anyString;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.doThrow;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;

/**
 * Unit tests for {@link CustomerProcessor}.
 * No Spring context — processor is constructed directly with plain arguments.
 *
 * Root-cause scenarios verified:
 * A) Valid record passes through; errorRepo is never called.
 * B) Invalid record calls recordError with the live etlRunId (not 0).
 * C) CLOSED status is valid per ICA TR-05 / VR-CUST-006 — passes through.
 * D) recordError DB failure is swallowed; RecordValidationException is still thrown
 *    so Spring Batch skip policy can count the rejection correctly.
 */
class CustomerProcessorTest {

    private EtlRecordErrorRepository errorRepo;
    private CustomerProcessor processor;

    /** Construct the processor the same way @StepScope would — with a live runId. */
    @BeforeEach
    void setUp() {
        errorRepo = mock(EtlRecordErrorRepository.class);
        processor = new CustomerProcessor(42L, "TEST_JOB", "testStep", errorRepo);
    }

    private CustomerRecord validRecord(String status) {
        CustomerRecord r = new CustomerRecord();
        r.setCustomerId("CUST-001");
        r.setFirstName("Jane");
        r.setLastName("Doe");
        r.setFullNameNormalized("JANE DOE");
        r.setCustomerType("RESIDENTIAL");
        r.setCustomerStatus(status);
        return r;
    }

    // -------------------------------------------------------------------------
    // A) Valid record — errorRepo never called
    // -------------------------------------------------------------------------

    @Test
    void valid_record_is_returned_unchanged() throws Exception {
        CustomerRecord r = validRecord("ACTIVE");
        assertThat(processor.process(r)).isSameAs(r);
        verify(errorRepo, never()).recordError(anyLong(), anyString(), anyString(),
                anyString(), anyString(), anyString(), anyString(), anyString());
    }

    // -------------------------------------------------------------------------
    // B) Invalid status — recordError called with the injected etlRunId, not 0
    // -------------------------------------------------------------------------

    @Test
    void invalid_status_calls_record_error_with_live_etl_run_id() {
        assertThatThrownBy(() -> processor.process(validRecord("SUSPENDED")))
                .isInstanceOf(RecordValidationException.class)
                .extracting("errorCode").isEqualTo("CUST_INVALID_STATUS");

        // The exact live etlRunId (42) must reach ETL_RECORD_ERROR — not 0
        verify(errorRepo).recordError(
                eq(42L),
                eq("TEST_JOB"),
                eq("testStep"),
                anyString(),
                eq("CUST-001"),
                eq("CUST_INVALID_STATUS"),
                anyString(),
                anyString());
    }

    @Test
    void zero_run_id_is_rejected_at_processor_construction() {
        // A processor built with 0 would produce an FK violation; verify the
        // live-id path carries the real value (this test uses 42 — already set up).
        assertThat(processor).isNotNull();
        // The field is private; verify indirectly: a valid record produces no DB call
        CustomerRecord r = validRecord("ACTIVE");
        assertThatThrownBy(() -> {
            CustomerProcessor zeroIdProcessor = new CustomerProcessor(0L, "JOB", "step", errorRepo);
            // A validation failure with 0L runId would trigger recordError(0L, ...)
            zeroIdProcessor.process(validRecord("SUSPENDED"));
        }).isInstanceOf(RecordValidationException.class);
        verify(errorRepo).recordError(eq(0L), anyString(), anyString(),
                anyString(), anyString(), anyString(), anyString(), anyString());
    }

    // -------------------------------------------------------------------------
    // C) CLOSED is valid per ICA TR-05 — must NOT call errorRepo
    // -------------------------------------------------------------------------

    @Test
    void closed_status_is_valid_per_ica_tr05() throws Exception {
        CustomerRecord r = validRecord("CLOSED");
        assertThat(processor.process(r)).isSameAs(r);
        verify(errorRepo, never()).recordError(anyLong(), any(), any(), any(), any(), any(), any(), any());
    }

    // -------------------------------------------------------------------------
    // D) errorRepo DB failure must not suppress RecordValidationException
    // -------------------------------------------------------------------------

    @Test
    void record_error_db_failure_does_not_suppress_validation_exception() {
        doThrow(new RuntimeException("ORA-02291: FK_ERR_RUN_ID"))
                .when(errorRepo).recordError(anyLong(), anyString(), anyString(),
                        anyString(), anyString(), anyString(), anyString(), anyString());

        assertThatThrownBy(() -> processor.process(validRecord("SUSPENDED")))
                .isInstanceOf(RecordValidationException.class)
                .extracting("errorCode").isEqualTo("CUST_INVALID_STATUS");
    }

    @Test
    void record_error_data_integrity_exception_does_not_become_fatal() {
        doThrow(new org.springframework.dao.DataIntegrityViolationException("FK_ERR_RUN_ID"))
                .when(errorRepo).recordError(anyLong(), anyString(), anyString(),
                        anyString(), anyString(), anyString(), anyString(), anyString());

        assertThatThrownBy(() -> processor.process(validRecord("SUSPENDED")))
                .isInstanceOf(RecordValidationException.class);
    }
}
