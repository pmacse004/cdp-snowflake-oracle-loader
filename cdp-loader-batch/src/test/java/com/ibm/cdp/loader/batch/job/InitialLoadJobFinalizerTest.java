package com.ibm.cdp.loader.batch.job;

import com.ibm.cdp.loader.batch.repository.EtlJobRunRepository;
import com.ibm.cdp.loader.batch.repository.EtlReconciliationRepository;
import com.ibm.cdp.loader.batch.repository.EtlRecordErrorRepository;
import com.ibm.cdp.loader.batch.repository.EtlWatermarkRepository;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.mockito.ArgumentCaptor;
import org.springframework.batch.core.BatchStatus;
import org.springframework.batch.core.JobExecution;
import org.springframework.batch.core.JobExecutionListener;
import org.springframework.batch.core.JobInstance;
import org.springframework.batch.core.JobParameters;
import org.springframework.batch.core.JobParametersBuilder;
import org.springframework.batch.core.StepExecution;
import org.springframework.batch.core.repository.JobRepository;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.transaction.PlatformTransactionManager;

import javax.sql.DataSource;
import java.math.BigDecimal;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyLong;
import static org.mockito.ArgumentMatchers.anyString;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.times;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

/**
 * Unit tests for {@link InitialLoadJobConfig#etlJobRunFinalizer()}.
 *
 * <p>Verifies:
 * <ol>
 *   <li>RECORDS_REJECTED equals the sum of step skipCounts — not a duplicate of skipped.</li>
 *   <li>RECORDS_SKIPPED is written as 0 (skipped records are already counted as rejected).</li>
 *   <li>Reconciliation rows are written for each entity after a COMPLETED run.</li>
 *   <li>Reconciliation is NOT written after a FAILED run.</li>
 * </ol>
 *
 * <p>No Spring context; the listener is extracted from the config bean directly.
 */
class InitialLoadJobFinalizerTest {

    private EtlJobRunRepository jobRunRepo;
    private EtlReconciliationRepository reconRepo;
    private JdbcTemplate oracleJdbc;
    private JobExecutionListener listener;

    @BeforeEach
    void setUp() {
        jobRunRepo  = mock(EtlJobRunRepository.class);
        reconRepo   = mock(EtlReconciliationRepository.class);
        oracleJdbc  = mock(JdbcTemplate.class);

        // Oracle count queries return predictable values
        when(oracleJdbc.queryForObject(eq("SELECT COUNT(*) FROM TGT_CUSTOMER"),       eq(Long.class))).thenReturn(9800L);
        when(oracleJdbc.queryForObject(eq("SELECT COUNT(*) FROM TGT_ENERGY_ACCOUNT"), eq(Long.class))).thenReturn(9750L);
        when(oracleJdbc.queryForObject(eq("SELECT COUNT(*) FROM TGT_MONTHLY_USAGE"),  eq(Long.class))).thenReturn(9700L);

        InitialLoadJobConfig cfg = new InitialLoadJobConfig(
                mock(JobRepository.class),
                jobRunRepo,
                mock(EtlWatermarkRepository.class),
                mock(EtlRecordErrorRepository.class),
                reconRepo,
                mock(DataSource.class),
                mock(PlatformTransactionManager.class),
                oracleJdbc);
        listener = cfg.etlJobRunFinalizer();
    }

    // -------------------------------------------------------------------------
    // Build helpers
    // -------------------------------------------------------------------------

    private JobExecution completedExecution(long etlRunId,
                                             long custRead, int custSkip,
                                             long acctRead, int acctSkip,
                                             long usageRead, int usageSkip) {
        JobParameters params = new JobParametersBuilder()
                .addLong("etlRunId", etlRunId)
                .toJobParameters();
        JobInstance instance = new JobInstance(1L, "INITIAL_LOAD_JOB");
        JobExecution exec = new JobExecution(instance, params);
        exec.setStatus(BatchStatus.COMPLETED);

        addStep(exec, "initialLoadCustomersStep", custRead,  custSkip);
        addStep(exec, "initialLoadAccountsStep",  acctRead,  acctSkip);
        addStep(exec, "initialLoadUsageStep",     usageRead, usageSkip);
        return exec;
    }

    private JobExecution failedExecution(long etlRunId) {
        JobParameters params = new JobParametersBuilder()
                .addLong("etlRunId", etlRunId)
                .toJobParameters();
        JobInstance instance = new JobInstance(2L, "INITIAL_LOAD_JOB");
        JobExecution exec = new JobExecution(instance, params);
        exec.setStatus(BatchStatus.FAILED);
        addStep(exec, "initialLoadCustomersStep", 100L, 5);
        return exec;
    }

    private static void addStep(JobExecution exec, String name, long readCount, int skipCount) {
        StepExecution se = new StepExecution(name, exec);
        se.setReadCount(readCount);
        se.setProcessSkipCount(skipCount);
        exec.addStepExecutions(java.util.List.of(se));
    }

    // =========================================================================
    // A) RECORDS_REJECTED = sum of skipCounts across all steps
    // =========================================================================

    @Test
    void rejected_count_equals_total_step_skip_count() {
        // 200 cust skips + 102 usage skips = 302 total rejected
        JobExecution exec = completedExecution(4L, 10_000L, 200, 8_000L, 0, 30_305L, 102);

        listener.afterJob(exec);

        ArgumentCaptor<Long> rejectedCaptor = ArgumentCaptor.forClass(Long.class);
        // completeRun(runId, status, read, inserted, updated, skipped, rejected, ...)
        verify(jobRunRepo).completeRun(
                eq(4L), anyString(),
                anyLong(), anyLong(), anyLong(),
                anyLong(),            // skipped
                rejectedCaptor.capture(),  // rejected
                any(), any(), any());

        assertThat(rejectedCaptor.getValue())
                .as("RECORDS_REJECTED must equal the sum of all step skip counts")
                .isEqualTo(302L);
    }

    @Test
    void skipped_count_is_written_as_zero() {
        JobExecution exec = completedExecution(4L, 10_000L, 200, 8_000L, 0, 30_305L, 102);

        listener.afterJob(exec);

        ArgumentCaptor<Long> skippedCaptor = ArgumentCaptor.forClass(Long.class);
        verify(jobRunRepo).completeRun(
                eq(4L), anyString(),
                anyLong(), anyLong(), anyLong(),
                skippedCaptor.capture(),  // skipped
                anyLong(),
                any(), any(), any());

        assertThat(skippedCaptor.getValue())
                .as("RECORDS_SKIPPED should be 0 — skipped records are counted as rejected")
                .isEqualTo(0L);
    }

    // =========================================================================
    // B) Reconciliation rows written for each entity after COMPLETED
    // =========================================================================

    @Test
    void reconciliation_rows_written_for_all_three_entities_after_completed() {
        JobExecution exec = completedExecution(4L, 10_000L, 200, 8_000L, 0, 30_305L, 102);

        listener.afterJob(exec);

        // Three reconRepo.insertRecon calls — one per entity
        verify(reconRepo, times(3)).insertRecon(
                anyLong(), anyString(), anyString(), anyString(),
                any(), any(), any(), any());
    }

    @Test
    void reconciliation_customer_source_is_accepted_count_not_raw_read() {
        // 10_000 customers read; 200 rejected → accepted = 9_800 = Oracle COUNT(*)
        JobExecution exec = completedExecution(4L, 10_000L, 200, 8_000L, 0, 30_305L, 102);

        listener.afterJob(exec);

        verify(reconRepo).insertRecon(
                eq(4L),
                eq("INITIAL"),
                eq("TGT_CUSTOMER"),
                eq("COUNT"),
                eq(BigDecimal.valueOf(9_800L)),   // source = accepted = raw - rejected
                eq(BigDecimal.valueOf(9_800L)),   // target = Oracle COUNT(*)
                any(),
                anyString());
    }

    @Test
    void reconciliation_energy_account_source_is_accepted_count() {
        // 8_000 accounts read; 0 rejected → accepted = 8_000; Oracle has 9_750
        JobExecution exec = completedExecution(4L, 10_000L, 0, 8_000L, 0, 30_305L, 102);

        listener.afterJob(exec);

        verify(reconRepo).insertRecon(
                eq(4L),
                eq("INITIAL"),
                eq("TGT_ENERGY_ACCOUNT"),
                eq("COUNT"),
                eq(BigDecimal.valueOf(8_000L)),   // accepted = 8_000 - 0
                eq(BigDecimal.valueOf(9_750L)),
                any(),
                anyString());
    }

    @Test
    void reconciliation_monthly_usage_source_is_accepted_count() {
        // 30_305 usage read; 2 intentional rejects → accepted = 30_303; Oracle has 9_700
        JobExecution exec = completedExecution(4L, 10_000L, 0, 8_000L, 0, 30_305L, 2);

        listener.afterJob(exec);

        verify(reconRepo).insertRecon(
                eq(4L),
                eq("INITIAL"),
                eq("TGT_MONTHLY_USAGE"),
                eq("COUNT"),
                eq(BigDecimal.valueOf(30_303L)),  // accepted = 30_305 - 2
                eq(BigDecimal.valueOf(9_700L)),
                any(),
                anyString());
    }

    @Test
    void reconciliation_notes_contain_raw_rejected_accepted_counts() {
        // 10_472 acct read, 0 rejected → accepted=10_472; Oracle has 10_472
        when(oracleJdbc.queryForObject(eq("SELECT COUNT(*) FROM TGT_ENERGY_ACCOUNT"),
                eq(Long.class))).thenReturn(10_472L);
        JobExecution exec = completedExecution(5L, 10_500L, 0, 10_472L, 0, 30_305L, 2);

        listener.afterJob(exec);

        ArgumentCaptor<String> notesCaptor = ArgumentCaptor.forClass(String.class);
        verify(reconRepo).insertRecon(
                eq(5L), eq("INITIAL"), eq("TGT_ENERGY_ACCOUNT"), eq("COUNT"),
                any(), any(), any(),
                notesCaptor.capture());

        String notes = notesCaptor.getValue();
        assertThat(notes).contains("raw=10472");
        assertThat(notes).contains("rejected=0");
        assertThat(notes).contains("accepted=10472");
    }

    @Test
    void reconciliation_zero_tolerance_means_pass_when_variance_is_zero() {
        // accepted == target → tolerance=0 → variance=0 → PASS
        // Validate by asserting sourceValue == targetValue in the insertRecon call
        when(oracleJdbc.queryForObject(eq("SELECT COUNT(*) FROM TGT_ENERGY_ACCOUNT"),
                eq(Long.class))).thenReturn(10_472L);
        JobExecution exec = completedExecution(5L, 10_500L, 0, 10_472L, 0, 30_305L, 2);

        listener.afterJob(exec);

        verify(reconRepo).insertRecon(
                eq(5L), eq("INITIAL"), eq("TGT_ENERGY_ACCOUNT"), eq("COUNT"),
                eq(BigDecimal.valueOf(10_472L)),   // accepted source
                eq(BigDecimal.valueOf(10_472L)),   // Oracle target — equal → variance=0 → PASS
                eq(BigDecimal.ZERO),               // tolerance=0
                anyString());
    }

    @Test
    void reconciliation_usage_zero_rejects_passes_for_run5_scenario() {
        // Run 5: 30_305 usage read, 2 intentional rejects, usage target = 30_303
        when(oracleJdbc.queryForObject(eq("SELECT COUNT(*) FROM TGT_MONTHLY_USAGE"),
                eq(Long.class))).thenReturn(30_303L);
        JobExecution exec = completedExecution(5L, 10_500L, 0, 10_472L, 0, 30_305L, 2);

        listener.afterJob(exec);

        verify(reconRepo).insertRecon(
                eq(5L), eq("INITIAL"), eq("TGT_MONTHLY_USAGE"), eq("COUNT"),
                eq(BigDecimal.valueOf(30_303L)),   // accepted = 30_305 - 2
                eq(BigDecimal.valueOf(30_303L)),   // target = Oracle COUNT(*)
                eq(BigDecimal.ZERO),
                anyString());
    }

    // =========================================================================
    // C) Reconciliation NOT written after FAILED run
    // =========================================================================

    @Test
    void reconciliation_not_written_after_failed_run() {
        listener.afterJob(failedExecution(5L));

        verify(reconRepo, never()).insertRecon(
                anyLong(), anyString(), anyString(), anyString(),
                any(), any(), any(), any());
    }

    // =========================================================================
    // D) Missing etlRunId is handled gracefully — no NPE, no calls to repos
    // =========================================================================

    @Test
    void missing_etlRunId_skips_all_repo_calls() {
        JobParameters params = new JobParametersBuilder().toJobParameters(); // no etlRunId
        JobInstance instance = new JobInstance(3L, "INITIAL_LOAD_JOB");
        JobExecution exec = new JobExecution(instance, params);
        exec.setStatus(BatchStatus.COMPLETED);

        listener.afterJob(exec); // must not throw

        verify(jobRunRepo, never()).completeRun(
                anyLong(), anyString(), anyLong(), anyLong(), anyLong(),
                anyLong(), anyLong(), any(), any(), any());
        verify(reconRepo, never()).insertRecon(
                anyLong(), anyString(), anyString(), anyString(),
                any(), any(), any(), any());
    }
}
