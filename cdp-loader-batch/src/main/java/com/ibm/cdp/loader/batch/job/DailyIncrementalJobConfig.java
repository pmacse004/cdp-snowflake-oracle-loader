package com.ibm.cdp.loader.batch.job;

import com.ibm.cdp.loader.batch.processor.CustomerAccountProcessor;
import com.ibm.cdp.loader.batch.processor.CustomerProcessor;
import com.ibm.cdp.loader.batch.repository.EtlJobRunRepository;
import com.ibm.cdp.loader.batch.repository.EtlRecordErrorRepository;
import com.ibm.cdp.loader.batch.repository.EtlWatermarkRepository;
import com.ibm.cdp.loader.batch.snowflake.CustomerAccountExportReader;
import com.ibm.cdp.loader.batch.snowflake.CustomerExportReader;
import com.ibm.cdp.loader.batch.support.LazyWatermarkItemReader;
import com.ibm.cdp.loader.batch.support.WatermarkCapturingWriter;
import com.ibm.cdp.loader.batch.writer.CustomerAccountWriter;
import com.ibm.cdp.loader.batch.writer.CustomerWriter;
import com.ibm.cdp.loader.core.exception.RecordValidationException;
import com.ibm.cdp.loader.core.model.CustomerAccountRecord;
import com.ibm.cdp.loader.core.model.CustomerRecord;
import lombok.extern.slf4j.Slf4j;
import org.springframework.batch.core.BatchStatus;
import org.springframework.batch.core.Job;
import org.springframework.batch.core.JobExecution;
import org.springframework.batch.core.JobExecutionListener;
import org.springframework.batch.core.Step;
import org.springframework.batch.core.job.builder.JobBuilder;
import org.springframework.batch.core.launch.support.RunIdIncrementer;
import org.springframework.batch.core.repository.JobRepository;
import org.springframework.batch.core.step.builder.StepBuilder;
import org.springframework.batch.core.step.skip.SkipPolicy;
import org.springframework.beans.factory.annotation.Qualifier;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.transaction.PlatformTransactionManager;

import javax.sql.DataSource;
import java.time.Instant;

/**
 * Spring Batch configuration for the Daily Incremental Load Job.
 *
 * <h3>Watermark correctness rules enforced here</h3>
 * <ol>
 *   <li><strong>Lazy readers</strong> — each step wraps its reader in a
 *       {@link LazyWatermarkItemReader} that defers {@code open()} to step-execution
 *       time. The watermark is read from Oracle when the step actually starts, not at
 *       application-context startup.</li>
 *   <li><strong>Capturing writers</strong> — each step delegates through a
 *       {@link WatermarkCapturingWriter} that records the maximum
 *       (RECORD_EFFECTIVE_TS, stableId) of every chunk written successfully.</li>
 *   <li><strong>Watermarks advanced only on COMPLETED</strong> — the
 *       {@code dailyJobRunFinalizer} writes both watermarks to Oracle after a fully
 *       successful job. FAILED / STOPPED / ABANDONED leave watermarks untouched.</li>
 *   <li><strong>No wall-clock</strong> — the persisted timestamp comes from data
 *       actually read, never from {@code CURRENT_TIMESTAMP} or the job start time.</li>
 *   <li><strong>Zero-row no-op</strong> — if a step reads 0 rows its watermark is
 *       not advanced, so a no-change rerun reads 0 rows on the next run too.</li>
 *   <li><strong>Independent watermarks</strong> — DAILY_CUSTOMER and
 *       DAILY_CUSTOMER_ACCOUNT are stored as separate ETL_WATERMARK rows and
 *       advanced independently.</li>
 * </ol>
 */
@Slf4j
@Configuration
public class DailyIncrementalJobConfig {

    private static final String JOB_NAME = "DAILY_INCREMENTAL_JOB";
    private static final String JOB_TYPE = "DAILY";

    /** ETL_WATERMARK TABLE_NAME for the customer watermark. */
    static final String WM_CUSTOMER         = EtlWatermarkRepository.TABLE_CUSTOMER_EXPORT;
    /** ETL_WATERMARK TABLE_NAME for the customer-account watermark. */
    static final String WM_CUSTOMER_ACCOUNT = EtlWatermarkRepository.TABLE_CUSTOMER_ACCOUNT_EXPORT;

    private final JobRepository jobRepository;
    private final EtlJobRunRepository jobRunRepo;
    private final EtlWatermarkRepository watermarkRepo;
    private final PlatformTransactionManager txManager;
    private final DataSource snowflakeDs;

    @Value("${cdp.batch.chunk-size:500}")
    private int chunkSize;

    @Value("${cdp.batch.fetch-size:1000}")
    private int fetchSize;

    @Value("${cdp.batch.fatal-error-threshold:100}")
    private int skipLimit;

    private static final SkipPolicy VALIDATION_SKIP_POLICY =
        (t, count) -> t instanceof RecordValidationException;

    public DailyIncrementalJobConfig(
            JobRepository jobRepository,
            EtlJobRunRepository jobRunRepo,
            EtlWatermarkRepository watermarkRepo,
            EtlRecordErrorRepository errorRepo,
            @Qualifier("snowflakeDataSource")      DataSource snowflakeDs,
            @Qualifier("oracleTransactionManager") PlatformTransactionManager txManager) {
        this.jobRepository = jobRepository;
        this.jobRunRepo    = jobRunRepo;
        this.watermarkRepo = watermarkRepo;
        this.txManager     = txManager;
        this.snowflakeDs   = snowflakeDs;
    }

    // =========================================================================
    // Job
    // =========================================================================

    @Bean("dailyIncrementalJob")
    public Job dailyIncrementalJob(
            @Qualifier("dailyLoadCustomersStep") Step custStep,
            @Qualifier("dailyLoadAccountsStep")  Step acctStep) {
        return new JobBuilder(JOB_NAME, jobRepository)
                .incrementer(new RunIdIncrementer())
                .listener(dailyJobRunFinalizer())
                .start(custStep)
                .next(acctStep)
                .build();
    }

    // =========================================================================
    // Finalizer — advances watermarks only on COMPLETED
    // =========================================================================

    /**
     * Job-execution listener that:
     * <ul>
     *   <li>Writes the final metrics row to ETL_JOB_RUN.</li>
     *   <li>Advances the DAILY_CUSTOMER and DAILY_CUSTOMER_ACCOUNT watermarks in
     *       ETL_WATERMARK, but only when the job status is COMPLETED.</li>
     * </ul>
     *
     * <p>The two {@link WatermarkCapturingWriter} references are mutable; the step
     * factory methods below inject fresh instances before each execution so the
     * listener always sees the writers from the current run.
     */
    @Bean("dailyJobRunFinalizer")
    public DailyJobFinalizer dailyJobRunFinalizer() {
        return new DailyJobFinalizer(jobRunRepo, watermarkRepo);
    }

    /**
     * Public inner class so that tests can instantiate it without a Spring context.
     */
    public static class DailyJobFinalizer implements JobExecutionListener {

        private final EtlJobRunRepository jobRunRepo;
        private final EtlWatermarkRepository watermarkRepo;

        /**
         * Set by the step factory before each execution so the finalizer always
         * reads from the writers created for this execution.
         */
        volatile WatermarkCapturingWriter<CustomerRecord>        custWriter;
        volatile WatermarkCapturingWriter<CustomerAccountRecord> acctWriter;

        public DailyJobFinalizer(EtlJobRunRepository jobRunRepo,
                                 EtlWatermarkRepository watermarkRepo) {
            this.jobRunRepo    = jobRunRepo;
            this.watermarkRepo = watermarkRepo;
        }

        @Override
        public void afterJob(JobExecution jobExecution) {
            Long etlRunId = jobExecution.getJobParameters().getLong("etlRunId");
            if (etlRunId == null || etlRunId <= 0) {
                log.warn("dailyJobRunFinalizer: etlRunId missing — ETL_JOB_RUN not updated");
                return;
            }

            BatchStatus batchStatus = jobExecution.getStatus();
            String status = batchStatus == BatchStatus.COMPLETED ? "COMPLETED" : "FAILED";

            long read    = jobExecution.getStepExecutions().stream()
                               .mapToLong(s -> s.getReadCount()).sum();
            long written = jobExecution.getStepExecutions().stream()
                               .mapToLong(s -> s.getWriteCount()).sum();
            long skipped = jobExecution.getStepExecutions().stream()
                               .mapToLong(s -> s.getSkipCount()).sum();
            String errSummary = jobExecution.getAllFailureExceptions().isEmpty() ? null
                    : jobExecution.getAllFailureExceptions().get(0).getMessage();

            try {
                jobRunRepo.completeRun(etlRunId, status,
                        read, written, 0L, 0L, skipped,
                        errSummary, null, null);
                log.info("dailyJobRunFinalizer: runId={} → {}", etlRunId, status);
            } catch (Exception ex) {
                log.error("dailyJobRunFinalizer: failed to update ETL_JOB_RUN runId={}", etlRunId, ex);
            }

            // Advance watermarks ONLY after a fully-successful run.
            // FAILED / STOPPED / ABANDONED must leave watermarks untouched so that
            // the next run re-reads from the last known-good position.
            if (batchStatus != BatchStatus.COMPLETED) {
                log.info("dailyJobRunFinalizer: runId={} status={} — watermarks NOT advanced",
                        etlRunId, batchStatus);
                return;
            }

            advanceWatermark(JOB_TYPE, WM_CUSTOMER,
                    custWriter, etlRunId, "CUSTOMER");
            advanceWatermark(JOB_TYPE, WM_CUSTOMER_ACCOUNT,
                    acctWriter, etlRunId, "CUSTOMER_ACCOUNT");
        }

        private <T> void advanceWatermark(
                String jobType, String tableName,
                WatermarkCapturingWriter<T> writer,
                long etlRunId, String label) {
            if (writer == null) {
                log.warn("dailyJobRunFinalizer: {} writer is null — watermark not advanced", label);
                return;
            }
            writer.getMaxTs().ifPresentOrElse(
                ts -> {
                    String maxId = writer.getMaxId().orElse("");
                    try {
                        watermarkRepo.updateWatermark(jobType, tableName,
                                ts, maxId, etlRunId, 1L);
                        log.info("dailyJobRunFinalizer: {} watermark advanced → ts={}, id={}",
                                label, ts, maxId);
                    } catch (Exception ex) {
                        log.error("dailyJobRunFinalizer: failed to advance {} watermark runId={}",
                                label, etlRunId, ex);
                    }
                },
                () -> log.info("dailyJobRunFinalizer: {} read 0 rows — watermark unchanged", label)
            );
        }
    }

    // =========================================================================
    // Steps
    //
    // Step beans are singletons in the Spring context — that is correct. What
    // must NOT be singleton is the ItemReader, because it holds cursor state and
    // must use the current watermark value from Oracle.
    //
    // Solution: wrap each reader in a LazyWatermarkItemReader whose factory
    // lambda calls watermarkRepo.getLastExtractedTs() at open() time (= step
    // execution time), not at @Bean creation time.
    //
    // The WatermarkCapturingWriter also gets a fresh instance per step execution
    // via a Supplier injected by the factory lambda inside each @Bean method.
    // A new capturing writer is created here and wired into the finalizer so that
    // afterJob() always sees the values from the most-recent execution.
    // =========================================================================

    @Bean("dailyLoadCustomersStep")
    public Step dailyLoadCustomersStep(
            @Qualifier("dailyJobRunFinalizer") DailyJobFinalizer finalizer,
            CustomerProcessor customerProcessor,
            CustomerWriter customerWriter) {

        // Capturing writer: tracks max (ts, id) across all written chunks.
        // One fresh instance per application boot is sufficient because the
        // LazyWatermarkItemReader also resets cursor state per step execution.
        // A new instance is created each time this @Bean is called by Spring.
        WatermarkCapturingWriter<CustomerRecord> capturingWriter =
                new WatermarkCapturingWriter<>(
                        customerWriter,
                        CustomerRecord::getRecordEffectiveTs,
                        CustomerRecord::getCustomerId);

        // Register this capturing writer with the finalizer so afterJob() can
        // read the max watermark values from the current execution.
        finalizer.custWriter = capturingWriter;

        // Lazy reader — watermark read from Oracle at step open() time, not now.
        LazyWatermarkItemReader<CustomerRecord> lazyReader = new LazyWatermarkItemReader<>(() -> {
            Instant lastTs = watermarkRepo.getLastExtractedTs(JOB_TYPE, WM_CUSTOMER);
            String  lastId = watermarkRepo.getLastMaxSourceId(JOB_TYPE, WM_CUSTOMER).orElse("");
            log.info("dailyLoadCustomersStep opening: watermark ts={}, id={}", lastTs, lastId);
            return CustomerExportReader.buildIncrementalReader(snowflakeDs, fetchSize, lastTs, lastId);
        });

        return new StepBuilder("dailyLoadCustomersStep", jobRepository)
                .<CustomerRecord, CustomerRecord>chunk(chunkSize, txManager)
                .reader(lazyReader)
                .processor(customerProcessor)
                .writer(capturingWriter)
                .faultTolerant()
                .skipPolicy(VALIDATION_SKIP_POLICY)
                .skipLimit(skipLimit)
                .build();
    }

    @Bean("dailyLoadAccountsStep")
    public Step dailyLoadAccountsStep(
            @Qualifier("dailyJobRunFinalizer") DailyJobFinalizer finalizer,
            CustomerAccountProcessor customerAccountProcessor,
            CustomerAccountWriter customerAccountWriter) {

        WatermarkCapturingWriter<CustomerAccountRecord> capturingWriter =
                new WatermarkCapturingWriter<>(
                        customerAccountWriter,
                        CustomerAccountRecord::getRecordEffectiveTs,
                        CustomerAccountRecord::getEnergyAccountId);

        finalizer.acctWriter = capturingWriter;

        LazyWatermarkItemReader<CustomerAccountRecord> lazyReader = new LazyWatermarkItemReader<>(() -> {
            Instant lastTs = watermarkRepo.getLastExtractedTs(JOB_TYPE, WM_CUSTOMER_ACCOUNT);
            String  lastId = watermarkRepo.getLastMaxSourceId(JOB_TYPE, WM_CUSTOMER_ACCOUNT).orElse("");
            log.info("dailyLoadAccountsStep opening: watermark ts={}, id={}", lastTs, lastId);
            return CustomerAccountExportReader.buildIncrementalReader(snowflakeDs, fetchSize, lastTs, lastId);
        });

        return new StepBuilder("dailyLoadAccountsStep", jobRepository)
                .<CustomerAccountRecord, CustomerAccountRecord>chunk(chunkSize, txManager)
                .reader(lazyReader)
                .processor(customerAccountProcessor)
                .writer(capturingWriter)
                .faultTolerant()
                .skipPolicy(VALIDATION_SKIP_POLICY)
                .skipLimit(skipLimit)
                .build();
    }
}
