package com.ibm.cdp.loader.batch.job;

import com.ibm.cdp.loader.batch.processor.MonthlyUsageProcessor;
import com.ibm.cdp.loader.batch.repository.EtlJobRunRepository;
import com.ibm.cdp.loader.batch.repository.EtlReconciliationRepository;
import com.ibm.cdp.loader.batch.repository.EtlRecordErrorRepository;
import com.ibm.cdp.loader.batch.repository.EtlWatermarkRepository;
import com.ibm.cdp.loader.batch.snowflake.MonthlyUsageExportReader;
import com.ibm.cdp.loader.batch.writer.MonthlyUsageWriter;
import com.ibm.cdp.loader.core.exception.RecordValidationException;
import com.ibm.cdp.loader.core.model.MonthlyUsageRecord;
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
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.transaction.PlatformTransactionManager;

import javax.sql.DataSource;
import java.math.BigDecimal;
import java.time.Instant;

/**
 * Spring Batch configuration for the Monthly Usage Load Job.
 *
 * <p>Processor and writer are {@code @StepScope} beans — etlRunId is injected
 * from job parameters at step-execution time.
 */
@Slf4j
@Configuration
public class MonthlyUsageJobConfig {

    private static final String JOB_NAME = "MONTHLY_USAGE_JOB";
    private static final String JOB_TYPE = "MONTHLY";

    private final JobRepository jobRepository;
    private final EtlJobRunRepository jobRunRepo;
    private final EtlWatermarkRepository watermarkRepo;
    private final EtlReconciliationRepository reconRepo;
    private final JdbcTemplate oracleJdbc;
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

    public MonthlyUsageJobConfig(
            JobRepository jobRepository,
            EtlJobRunRepository jobRunRepo,
            EtlWatermarkRepository watermarkRepo,
            EtlRecordErrorRepository errorRepo,
            EtlReconciliationRepository reconRepo,
            @Qualifier("snowflakeDataSource")      DataSource snowflakeDs,
            @Qualifier("oracleTransactionManager") PlatformTransactionManager txManager,
            @Qualifier("oracleJdbcTemplate")       JdbcTemplate oracleJdbc) {
        this.jobRepository = jobRepository;
        this.jobRunRepo    = jobRunRepo;
        this.watermarkRepo = watermarkRepo;
        this.reconRepo     = reconRepo;
        this.oracleJdbc    = oracleJdbc;
        this.txManager     = txManager;
        this.snowflakeDs   = snowflakeDs;
    }

    @Bean("monthlyUsageJob")
    public Job monthlyUsageJob(@Qualifier("monthlyLoadUsageStep") Step usageStep) {
        return new JobBuilder(JOB_NAME, jobRepository)
                .incrementer(new RunIdIncrementer())
                .listener(monthlyJobRunFinalizer())
                .start(usageStep)
                .build();
    }

    @Bean("monthlyJobRunFinalizer")
    public JobExecutionListener monthlyJobRunFinalizer() {
        return new JobExecutionListener() {
            @Override
            public void afterJob(JobExecution jobExecution) {
                Long etlRunId = jobExecution.getJobParameters().getLong("etlRunId");
                if (etlRunId == null || etlRunId <= 0) {
                    log.warn("monthlyJobRunFinalizer: etlRunId missing — ETL_JOB_RUN not updated");
                    return;
                }
                BatchStatus batchStatus = jobExecution.getStatus();
                String status = batchStatus == BatchStatus.COMPLETED ? "COMPLETED" : "FAILED";
                long read    = jobExecution.getStepExecutions().stream().mapToLong(s -> s.getReadCount()).sum();
                long written = jobExecution.getStepExecutions().stream().mapToLong(s -> s.getWriteCount()).sum();
                long skipped = jobExecution.getStepExecutions().stream().mapToLong(s -> s.getSkipCount()).sum();
                String errSummary = jobExecution.getAllFailureExceptions().isEmpty() ? null
                        : jobExecution.getAllFailureExceptions().get(0).getMessage();
                try {
                    jobRunRepo.completeRun(etlRunId, status,
                            read, written, 0L, 0L, skipped,
                            errSummary, null, null);
                    log.info("monthlyJobRunFinalizer: runId={} → {}", etlRunId, status);
                } catch (Exception ex) {
                    log.error("monthlyJobRunFinalizer: failed to update ETL_JOB_RUN runId={}", etlRunId, ex);
                }

                // Write reconciliation only after a fully-successful run.
                // A recon failure must never corrupt completed target data.
                if (batchStatus != BatchStatus.COMPLETED) {
                    return;
                }
                try {
                    long accepted = read - skipped;
                    Long targetCount = oracleJdbc.queryForObject(
                            "SELECT COUNT(*) FROM TGT_MONTHLY_USAGE", Long.class);
                    long target = targetCount != null ? targetCount : 0L;
                    reconRepo.insertRecon(
                            etlRunId, JOB_TYPE, "TGT_MONTHLY_USAGE", "COUNT",
                            BigDecimal.valueOf(accepted),
                            BigDecimal.valueOf(target),
                            BigDecimal.ZERO,
                            "raw=" + read + " rejected=" + skipped + " accepted=" + accepted);
                    log.info("monthlyJobRunFinalizer: reconciliation written for runId={} " +
                             "(read={}, rejected={}, accepted={}, target={})",
                            etlRunId, read, skipped, accepted, target);
                } catch (Exception ex) {
                    log.error("monthlyJobRunFinalizer: failed to write reconciliation for runId={} " +
                              "— target data is unaffected", etlRunId, ex);
                }
            }
        };
    }

    @Bean("monthlyLoadUsageStep")
    public Step monthlyLoadUsageStep(
            MonthlyUsageProcessor monthlyUsageProcessor,
            MonthlyUsageWriter monthlyUsageWriter) {
        Instant lastTs = watermarkRepo.getLastExtractedTs(JOB_TYPE,
                EtlWatermarkRepository.TABLE_MONTHLY_USAGE_EXPORT);
        String lastId = watermarkRepo.getLastMaxSourceId(JOB_TYPE,
                EtlWatermarkRepository.TABLE_MONTHLY_USAGE_EXPORT).orElse("");
        var reader = MonthlyUsageExportReader.buildIncrementalReader(snowflakeDs, fetchSize, lastTs, lastId);
        return new StepBuilder("monthlyLoadUsageStep", jobRepository)
                .<MonthlyUsageRecord, MonthlyUsageRecord>chunk(chunkSize, txManager)
                .reader(reader)
                .processor(monthlyUsageProcessor)
                .writer(monthlyUsageWriter)
                .faultTolerant()
                .skipPolicy(VALIDATION_SKIP_POLICY)
                .skipLimit(skipLimit)
                .build();
    }
}
