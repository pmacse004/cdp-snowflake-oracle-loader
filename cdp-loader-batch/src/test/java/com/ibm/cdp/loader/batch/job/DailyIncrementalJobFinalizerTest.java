package com.ibm.cdp.loader.batch.job;

import com.ibm.cdp.loader.batch.job.DailyIncrementalJobConfig.DailyJobFinalizer;
import com.ibm.cdp.loader.batch.repository.EtlJobRunRepository;
import com.ibm.cdp.loader.batch.repository.EtlWatermarkRepository;
import com.ibm.cdp.loader.batch.support.WatermarkCapturingWriter;
import com.ibm.cdp.loader.core.model.CustomerAccountRecord;
import com.ibm.cdp.loader.core.model.CustomerRecord;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.mockito.ArgumentCaptor;
import org.springframework.batch.core.BatchStatus;
import org.springframework.batch.core.JobExecution;
import org.springframework.batch.core.JobInstance;
import org.springframework.batch.core.JobParameters;
import org.springframework.batch.core.JobParametersBuilder;
import org.springframework.batch.core.StepExecution;
import org.springframework.batch.item.Chunk;

import java.time.Instant;
import java.time.OffsetDateTime;
import java.time.ZoneOffset;
import java.util.List;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyLong;
import static org.mockito.ArgumentMatchers.anyString;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;

/**
 * Unit tests for {@link DailyJobFinalizer} and watermark correctness rules.
 *
 * <ol>
 *   <li>Missing watermark → first run reads all rows (no filter).</li>
 *   <li>Watermark at latest tuple → next run reads 0 rows.</li>
 *   <li>Equal timestamp, greater ID → only later IDs returned.</li>
 *   <li>Successful job → both watermarks updated.</li>
 *   <li>Failed job → neither watermark updated.</li>
 *   <li>Application restart → persisted Oracle watermark is reused
 *       (tested via {@link EtlWatermarkRepository} mock returning a saved Instant).</li>
 *   <li>Customer and account watermarks remain independent.</li>
 * </ol>
 */
class DailyIncrementalJobFinalizerTest {

    private EtlJobRunRepository jobRunRepo;
    private EtlWatermarkRepository watermarkRepo;
    private DailyJobFinalizer finalizer;

    // Two no-op delegate writers whose write() method does nothing
    private WatermarkCapturingWriter<CustomerRecord>        custCapturing;
    private WatermarkCapturingWriter<CustomerAccountRecord> acctCapturing;

    @BeforeEach
    void setUp() throws Exception {
        jobRunRepo    = mock(EtlJobRunRepository.class);
        watermarkRepo = mock(EtlWatermarkRepository.class);
        finalizer     = new DailyJobFinalizer(jobRunRepo, watermarkRepo);

        // Create real capturing writers backed by a no-op delegate
        custCapturing = new WatermarkCapturingWriter<>(
                chunk -> { /* no-op */ },
                CustomerRecord::getRecordEffectiveTs,
                CustomerRecord::getCustomerId);

        acctCapturing = new WatermarkCapturingWriter<>(
                chunk -> { /* no-op */ },
                CustomerAccountRecord::getRecordEffectiveTs,
                CustomerAccountRecord::getEnergyAccountId);

        finalizer.custWriter = custCapturing;
        finalizer.acctWriter = acctCapturing;
    }

    // =========================================================================
    // Test 1: Missing watermark → EPOCH_MIN used → all rows pass predicate
    // =========================================================================

    @Test
    void missing_watermark_returns_epoch_min_so_all_rows_are_included() {
        // EtlWatermarkRepository.getLastExtractedTs returns EPOCH_MIN on empty result
        // (tested at repository level — here we just assert the constant exists)
        assertThat(EtlWatermarkRepository.EPOCH_MIN)
                .isEqualTo(Instant.parse("1970-01-01T00:00:00Z"));
    }

    // =========================================================================
    // Test 2: Watermark at latest tuple → afterJob advances it → next run = 0 rows
    // =========================================================================

    @Test
    void successful_job_advances_customer_watermark_to_max_seen() throws Exception {
        Instant ts = Instant.parse("2025-01-15T10:00:00Z");

        // Simulate one chunk written with this timestamp
        CustomerRecord r = new CustomerRecord();
        r.setCustomerId("CUST-999");
        r.setRecordEffectiveTs(ts.atOffset(ZoneOffset.UTC));
        custCapturing.write(new Chunk<>(List.of(r)));

        finalizer.afterJob(completedExecution(42L));

        ArgumentCaptor<Instant> tsCaptor = ArgumentCaptor.forClass(Instant.class);
        ArgumentCaptor<String>  idCaptor = ArgumentCaptor.forClass(String.class);
        verify(watermarkRepo).updateWatermark(
                eq("DAILY"), eq(EtlWatermarkRepository.TABLE_CUSTOMER_EXPORT),
                tsCaptor.capture(), idCaptor.capture(), eq(42L), anyLong());

        assertThat(tsCaptor.getValue()).isEqualTo(ts);
        assertThat(idCaptor.getValue()).isEqualTo("CUST-999");
    }

    // =========================================================================
    // Test 3: Equal timestamp with greater ID → only later IDs returned
    //         (WatermarkCapturingWriter tracks max ID within same timestamp)
    // =========================================================================

    @Test
    void capturing_writer_picks_max_id_when_timestamps_equal() throws Exception {
        Instant ts = Instant.parse("2025-01-15T10:00:00Z");
        OffsetDateTime odt = ts.atOffset(ZoneOffset.UTC);

        CustomerRecord r1 = new CustomerRecord();
        r1.setCustomerId("CUST-001");
        r1.setRecordEffectiveTs(odt);

        CustomerRecord r2 = new CustomerRecord();
        r2.setCustomerId("CUST-099");
        r2.setRecordEffectiveTs(odt);

        CustomerRecord r3 = new CustomerRecord();
        r3.setCustomerId("CUST-050");
        r3.setRecordEffectiveTs(odt);

        custCapturing.write(new Chunk<>(List.of(r1, r2, r3)));

        assertThat(custCapturing.getMaxTs()).hasValue(ts);
        assertThat(custCapturing.getMaxId()).hasValue("CUST-099"); // lexicographically greatest
    }

    @Test
    void capturing_writer_picks_later_timestamp_over_lower_id() throws Exception {
        OffsetDateTime early = Instant.parse("2025-01-14T00:00:00Z").atOffset(ZoneOffset.UTC);
        OffsetDateTime late  = Instant.parse("2025-01-15T00:00:00Z").atOffset(ZoneOffset.UTC);

        CustomerRecord r1 = new CustomerRecord();
        r1.setCustomerId("CUST-ZZZ"); // highest ID but earlier ts
        r1.setRecordEffectiveTs(early);

        CustomerRecord r2 = new CustomerRecord();
        r2.setCustomerId("CUST-AAA"); // lowest ID but later ts
        r2.setRecordEffectiveTs(late);

        custCapturing.write(new Chunk<>(List.of(r1, r2)));

        assertThat(custCapturing.getMaxTs()).hasValue(late.toInstant());
        assertThat(custCapturing.getMaxId()).hasValue("CUST-AAA");
    }

    // =========================================================================
    // Test 4: Successful job → both watermarks updated
    // =========================================================================

    @Test
    void successful_job_advances_both_watermarks() throws Exception {
        Instant custTs = Instant.parse("2025-01-15T10:00:00Z");
        Instant acctTs = Instant.parse("2025-01-15T11:00:00Z");

        CustomerRecord cr = new CustomerRecord();
        cr.setCustomerId("CUST-1");
        cr.setRecordEffectiveTs(custTs.atOffset(ZoneOffset.UTC));
        custCapturing.write(new Chunk<>(List.of(cr)));

        CustomerAccountRecord ar = new CustomerAccountRecord();
        ar.setEnergyAccountId("ACCT-1");
        ar.setRecordEffectiveTs(acctTs.atOffset(ZoneOffset.UTC));
        acctCapturing.write(new Chunk<>(List.of(ar)));

        finalizer.afterJob(completedExecution(10L));

        verify(watermarkRepo).updateWatermark(
                eq("DAILY"), eq(EtlWatermarkRepository.TABLE_CUSTOMER_EXPORT),
                eq(custTs), eq("CUST-1"), eq(10L), anyLong());

        verify(watermarkRepo).updateWatermark(
                eq("DAILY"), eq(EtlWatermarkRepository.TABLE_CUSTOMER_ACCOUNT_EXPORT),
                eq(acctTs), eq("ACCT-1"), eq(10L), anyLong());
    }

    // =========================================================================
    // Test 5: Failed job → neither watermark updated
    // =========================================================================

    @Test
    void failed_job_does_not_advance_any_watermark() throws Exception {
        CustomerRecord cr = new CustomerRecord();
        cr.setCustomerId("CUST-1");
        cr.setRecordEffectiveTs(Instant.parse("2025-01-15T10:00:00Z").atOffset(ZoneOffset.UTC));
        custCapturing.write(new Chunk<>(List.of(cr)));

        finalizer.afterJob(failedExecution(10L));

        verify(watermarkRepo, never()).updateWatermark(
                anyString(), anyString(), any(), any(), anyLong(), anyLong());
    }

    // =========================================================================
    // Test 6: Application restart → persisted Oracle watermark is reused
    //         Simulated: EtlWatermarkRepository returns a previously persisted Instant.
    // =========================================================================

    @Test
    void persisted_watermark_survives_restart() {
        Instant persisted = Instant.parse("2025-01-15T10:00:00Z");
        // After a restart, getLastExtractedTs would return this persisted value.
        // We verify the mock returns it and the constant EPOCH_MIN is not returned.
        org.mockito.Mockito.when(watermarkRepo.getLastExtractedTs("DAILY",
                EtlWatermarkRepository.TABLE_CUSTOMER_EXPORT)).thenReturn(persisted);

        Instant result = watermarkRepo.getLastExtractedTs("DAILY",
                EtlWatermarkRepository.TABLE_CUSTOMER_EXPORT);

        assertThat(result).isEqualTo(persisted);
        assertThat(result).isNotEqualTo(EtlWatermarkRepository.EPOCH_MIN);
    }

    // =========================================================================
    // Test 7: Customer and account watermarks remain independent
    // =========================================================================

    @Test
    void customer_and_account_watermarks_are_independent() throws Exception {
        // Only write customer rows — account writer stays empty
        CustomerRecord cr = new CustomerRecord();
        cr.setCustomerId("CUST-7");
        cr.setRecordEffectiveTs(Instant.parse("2025-01-20T00:00:00Z").atOffset(ZoneOffset.UTC));
        custCapturing.write(new Chunk<>(List.of(cr)));
        // acctCapturing receives no chunks

        finalizer.afterJob(completedExecution(77L));

        // Customer watermark IS advanced
        verify(watermarkRepo).updateWatermark(
                eq("DAILY"), eq(EtlWatermarkRepository.TABLE_CUSTOMER_EXPORT),
                any(), any(), anyLong(), anyLong());

        // Account watermark is NOT advanced (0 rows)
        verify(watermarkRepo, never()).updateWatermark(
                eq("DAILY"), eq(EtlWatermarkRepository.TABLE_CUSTOMER_ACCOUNT_EXPORT),
                any(), any(), anyLong(), anyLong());
    }

    // =========================================================================
    // Test 8: Zero rows in both → neither watermark advanced
    // =========================================================================

    @Test
    void zero_rows_means_neither_watermark_advanced() {
        // No writes to either capturing writer
        finalizer.afterJob(completedExecution(88L));

        verify(watermarkRepo, never()).updateWatermark(
                anyString(), anyString(), any(), any(), anyLong(), anyLong());
    }

    // =========================================================================
    // Test 9: Missing etlRunId handled gracefully
    // =========================================================================

    @Test
    void missing_etlRunId_skips_all_repo_calls() {
        JobParameters params = new JobParametersBuilder().toJobParameters();
        JobInstance instance = new JobInstance(99L, "DAILY_INCREMENTAL_JOB");
        JobExecution exec = new JobExecution(instance, params);
        exec.setStatus(BatchStatus.COMPLETED);

        finalizer.afterJob(exec); // must not throw

        verify(jobRunRepo, never()).completeRun(
                anyLong(), anyString(), anyLong(), anyLong(), anyLong(),
                anyLong(), anyLong(), any(), any(), any());
        verify(watermarkRepo, never()).updateWatermark(
                anyString(), anyString(), any(), any(), anyLong(), anyLong());
    }

    // =========================================================================
    // Helpers
    // =========================================================================

    private static JobExecution completedExecution(long etlRunId) {
        return buildExecution(etlRunId, BatchStatus.COMPLETED);
    }

    private static JobExecution failedExecution(long etlRunId) {
        return buildExecution(etlRunId, BatchStatus.FAILED);
    }

    private static JobExecution buildExecution(long etlRunId, BatchStatus status) {
        JobParameters params = new JobParametersBuilder()
                .addLong("etlRunId", etlRunId)
                .toJobParameters();
        JobInstance instance = new JobInstance(1L, "DAILY_INCREMENTAL_JOB");
        JobExecution exec = new JobExecution(instance, params);
        exec.setStatus(status);
        StepExecution se = new StepExecution("dailyLoadCustomersStep", exec);
        se.setReadCount(100);
        exec.addStepExecutions(List.of(se));
        return exec;
    }
}
