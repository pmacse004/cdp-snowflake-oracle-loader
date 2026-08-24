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
import java.util.List;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyLong;
import static org.mockito.ArgumentMatchers.anyString;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

/**
 * Unit tests for the {@code monthlyJobRunFinalizer} listener in
 * {@link MonthlyUsageJobConfig}.
 *
 * <ol>
 *   <li>Completed run writes exactly one MONTHLY reconciliation row.</li>
 *   <li>SOURCE_VALUE = raw read count − rejected (skip) count.</li>
 *   <li>TARGET_VALUE is queried from Oracle {@code TGT_MONTHLY_USAGE}.</li>
 *   <li>Failed run writes no reconciliation row.</li>
 * </ol>
 */
class MonthlyUsageJobFinalizerTest {

    private EtlJobRunRepository    jobRunRepo;
    private EtlReconciliationRepository reconRepo;
    private JdbcTemplate           oracleJdbc;
    private JobExecutionListener   listener;

    @BeforeEach
    void setUp() {
        jobRunRepo  = mock(EtlJobRunRepository.class);
        reconRepo   = mock(EtlReconciliationRepository.class);
        oracleJdbc  = mock(JdbcTemplate.class);

        when(oracleJdbc.queryForObject(
                eq("SELECT COUNT(*) FROM TGT_MONTHLY_USAGE"), eq(Long.class)))
                .thenReturn(27_731L);

        MonthlyUsageJobConfig cfg = new MonthlyUsageJobConfig(
                mock(JobRepository.class),
                jobRunRepo,
                mock(EtlWatermarkRepository.class),
                mock(EtlRecordErrorRepository.class),
                reconRepo,
                mock(DataSource.class),
                mock(PlatformTransactionManager.class),
                oracleJdbc);

        listener = cfg.monthlyJobRunFinalizer();
    }

    // =========================================================================
    // 1. Completed run writes exactly one MONTHLY reconciliation row
    // =========================================================================

    @Test
    void completed_run_writes_one_monthly_reconciliation_row() {
        listener.afterJob(completedExecution(13L, 27_743L, 12));

        verify(reconRepo).insertRecon(
                eq(13L),
                eq("MONTHLY"),
                eq("TGT_MONTHLY_USAGE"),
                eq("COUNT"),
                any(), any(), any(), anyString());
    }

    // =========================================================================
    // 2. SOURCE_VALUE = read - rejected
    // =========================================================================

    @Test
    void source_value_equals_read_minus_rejected() {
        // 27,743 read - 12 rejected = 27,731 accepted
        listener.afterJob(completedExecution(13L, 27_743L, 12));

        ArgumentCaptor<BigDecimal> sourceCaptor = ArgumentCaptor.forClass(BigDecimal.class);
        verify(reconRepo).insertRecon(
                anyLong(), anyString(), anyString(), anyString(),
                sourceCaptor.capture(), any(), any(), anyString());

        assertThat(sourceCaptor.getValue())
                .isEqualByComparingTo(BigDecimal.valueOf(27_731L));
    }

    // =========================================================================
    // 3. TARGET_VALUE is queried from Oracle TGT_MONTHLY_USAGE
    // =========================================================================

    @Test
    void target_value_is_oracle_count_of_tgt_monthly_usage() {
        listener.afterJob(completedExecution(13L, 27_743L, 12));

        ArgumentCaptor<BigDecimal> targetCaptor = ArgumentCaptor.forClass(BigDecimal.class);
        verify(reconRepo).insertRecon(
                anyLong(), anyString(), anyString(), anyString(),
                any(), targetCaptor.capture(), any(), anyString());

        assertThat(targetCaptor.getValue())
                .isEqualByComparingTo(BigDecimal.valueOf(27_731L));
    }

    // =========================================================================
    // 4. Failed run writes no reconciliation row
    // =========================================================================

    @Test
    void failed_run_writes_no_reconciliation_row() {
        listener.afterJob(failedExecution(13L, 1_000L, 5));

        verify(reconRepo, never()).insertRecon(
                anyLong(), anyString(), anyString(), anyString(),
                any(), any(), any(), anyString());
    }

    // =========================================================================
    // 5. Notes contain raw / rejected / accepted breakdown
    // =========================================================================

    @Test
    void notes_contain_raw_rejected_accepted() {
        listener.afterJob(completedExecution(13L, 27_743L, 12));

        ArgumentCaptor<String> notesCaptor = ArgumentCaptor.forClass(String.class);
        verify(reconRepo).insertRecon(
                anyLong(), anyString(), anyString(), anyString(),
                any(), any(), any(), notesCaptor.capture());

        assertThat(notesCaptor.getValue())
                .contains("raw=27743")
                .contains("rejected=12")
                .contains("accepted=27731");
    }

    // =========================================================================
    // 6. Missing etlRunId is handled gracefully — no NPE, no repo calls
    // =========================================================================

    @Test
    void missing_etlRunId_skips_all_repo_calls() {
        JobParameters params = new JobParametersBuilder().toJobParameters();
        JobInstance instance = new JobInstance(99L, "MONTHLY_USAGE_JOB");
        JobExecution exec = new JobExecution(instance, params);
        exec.setStatus(BatchStatus.COMPLETED);

        listener.afterJob(exec); // must not throw

        verify(jobRunRepo, never()).completeRun(
                anyLong(), anyString(), anyLong(), anyLong(), anyLong(),
                anyLong(), anyLong(), any(), any(), any());
        verify(reconRepo, never()).insertRecon(
                anyLong(), anyString(), anyString(), anyString(),
                any(), any(), any(), anyString());
    }

    // =========================================================================
    // Helpers
    // =========================================================================

    private static JobExecution completedExecution(long etlRunId, long readCount, int skipCount) {
        return buildExecution(etlRunId, BatchStatus.COMPLETED, readCount, skipCount);
    }

    private static JobExecution failedExecution(long etlRunId, long readCount, int skipCount) {
        return buildExecution(etlRunId, BatchStatus.FAILED, readCount, skipCount);
    }

    private static JobExecution buildExecution(long etlRunId, BatchStatus status,
                                               long readCount, int skipCount) {
        JobParameters params = new JobParametersBuilder()
                .addLong("etlRunId", etlRunId)
                .toJobParameters();
        JobInstance instance = new JobInstance(1L, "MONTHLY_USAGE_JOB");
        JobExecution exec = new JobExecution(instance, params);
        exec.setStatus(status);
        StepExecution se = new StepExecution("monthlyLoadUsageStep", exec);
        se.setReadCount(readCount);
        se.setProcessSkipCount(skipCount);
        exec.addStepExecutions(List.of(se));
        return exec;
    }
}
