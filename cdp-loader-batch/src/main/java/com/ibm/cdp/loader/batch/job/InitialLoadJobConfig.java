package com.ibm.cdp.loader.batch.job;

import com.ibm.cdp.loader.batch.processor.CustomerAccountProcessor;
import com.ibm.cdp.loader.batch.processor.CustomerProcessor;
import com.ibm.cdp.loader.batch.processor.MonthlyUsageProcessor;
import com.ibm.cdp.loader.batch.repository.EtlJobRunRepository;
import com.ibm.cdp.loader.batch.repository.EtlReconciliationRepository;
import com.ibm.cdp.loader.batch.repository.EtlRecordErrorRepository;
import com.ibm.cdp.loader.batch.repository.EtlWatermarkRepository;
import com.ibm.cdp.loader.batch.snowflake.CustomerAccountExportReader;
import com.ibm.cdp.loader.batch.snowflake.CustomerExportReader;
import com.ibm.cdp.loader.batch.snowflake.MonthlyUsageExportReader;
import com.ibm.cdp.loader.batch.writer.CustomerAccountWriter;
import com.ibm.cdp.loader.batch.writer.CustomerWriter;
import com.ibm.cdp.loader.batch.writer.MonthlyUsageWriter;
import com.ibm.cdp.loader.core.exception.RecordValidationException;
import com.ibm.cdp.loader.core.model.CustomerAccountRecord;
import com.ibm.cdp.loader.core.model.CustomerRecord;
import com.ibm.cdp.loader.core.model.MonthlyUsageRecord;
import lombok.extern.slf4j.Slf4j;
import org.springframework.batch.core.BatchStatus;
import org.springframework.batch.core.Job;
import org.springframework.batch.core.JobExecution;
import org.springframework.batch.core.JobExecutionListener;
import org.springframework.batch.core.Step;
import org.springframework.batch.core.StepExecution;
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

/**
 * Spring Batch configuration for the Initial Load Job.
 * Steps: customers → accounts → usage (parents before children).
 *
 * <p>Processors and writers are {@code @StepScope} Spring beans that receive
 * {@code etlRunId} directly from job parameters at step-execution time —
 * they are never constructed before a real RUN_ID exists.
 */
@Slf4j
@Configuration
public class InitialLoadJobConfig {

    private static final String JOB_NAME = "INITIAL_LOAD_JOB";

    private final JobRepository jobRepository;
    private final EtlJobRunRepository jobRunRepo;
    private final EtlWatermarkRepository watermarkRepo;
    private final EtlRecordErrorRepository errorRepo;
    private final EtlReconciliationRepository reconRepo;
    private final DataSource snowflakeDs;
    private final PlatformTransactionManager txManager;
    private final JdbcTemplate oracleJdbc;

    public InitialLoadJobConfig(
            JobRepository jobRepository,
            EtlJobRunRepository jobRunRepo,
            EtlWatermarkRepository watermarkRepo,
            EtlRecordErrorRepository errorRepo,
            EtlReconciliationRepository reconRepo,
            @Qualifier("snowflakeDataSource")      DataSource snowflakeDs,
            @Qualifier("oracleTransactionManager") PlatformTransactionManager txManager,
            @Qualifier("oracleJdbcTemplate")       JdbcTemplate oracleJdbc) {
        this.jobRepository  = jobRepository;
        this.jobRunRepo     = jobRunRepo;
        this.watermarkRepo  = watermarkRepo;
        this.errorRepo      = errorRepo;
        this.reconRepo      = reconRepo;
        this.snowflakeDs    = snowflakeDs;
        this.txManager      = txManager;
        this.oracleJdbc     = oracleJdbc;
    }

    @Value("${cdp.batch.chunk-size:500}")
    private int chunkSize;

    @Value("${cdp.batch.fetch-size:1000}")
    private int fetchSize;

    @Value("${cdp.batch.fatal-error-threshold:100}")
    private int skipLimit;

    private static final SkipPolicy VALIDATION_SKIP_POLICY =
        (t, count) -> t instanceof RecordValidationException;

    // =========================================================================
    // Job
    // =========================================================================

    @Bean("initialLoadJob")
    public Job initialLoadJob(
            @Qualifier("initialLoadCustomersStep") Step custStep,
            @Qualifier("initialLoadAccountsStep")  Step acctStep,
            @Qualifier("initialLoadUsageStep")     Step usageStep) {
        return new JobBuilder(JOB_NAME, jobRepository)
                .incrementer(new RunIdIncrementer())
                .listener(etlJobRunFinalizer())
                .start(custStep)
                .next(acctStep)
                .next(usageStep)
                .build();
    }

    /**
     * Finalises ETL_JOB_RUN to COMPLETED or FAILED after every job execution.
     * Runs in its own transaction via jobRunRepo — never rolled back by a chunk failure.
     * Also fires when the launch-exception path in JobLaunchService already called
     * completeRun; completeRun is an UPDATE so a duplicate call is harmless.
     *
     * <p>After a COMPLETED run, reconciliation rows are written for each loaded
     * entity using Oracle COUNT(*) as the target value and the step read-count
     * (records attempted from Snowflake) as the source value.
     */
    @Bean("initialLoadJobRunFinalizer")
    public JobExecutionListener etlJobRunFinalizer() {
        return new JobExecutionListener() {
            @Override
            public void afterJob(JobExecution jobExecution) {
                Long etlRunId = jobExecution.getJobParameters().getLong("etlRunId");
                if (etlRunId == null || etlRunId <= 0) {
                    log.warn("etlJobRunFinalizer: etlRunId missing in JobParameters — ETL_JOB_RUN not updated");
                    return;
                }
                String status = jobExecution.getStatus() == BatchStatus.COMPLETED ? "COMPLETED" : "FAILED";

                // Accumulate per-step metrics
                long read     = 0L;
                long written  = 0L;
                long rejected = 0L;
                long custRead = 0L,  acctRead = 0L,  usageRead = 0L;
                long custSkip = 0L,  acctSkip = 0L,  usageSkip = 0L;
                for (StepExecution se : jobExecution.getStepExecutions()) {
                    read     += se.getReadCount();
                    written  += se.getWriteCount();
                    rejected += se.getSkipCount();
                    switch (se.getStepName()) {
                        case "initialLoadCustomersStep" -> {
                            custRead = se.getReadCount();
                            custSkip = se.getSkipCount();
                        }
                        case "initialLoadAccountsStep"  -> {
                            acctRead = se.getReadCount();
                            acctSkip = se.getSkipCount();
                        }
                        case "initialLoadUsageStep"     -> {
                            usageRead = se.getReadCount();
                            usageSkip = se.getSkipCount();
                        }
                        default -> { /* other steps ignored */ }
                    }
                }

                String errSummary = jobExecution.getAllFailureExceptions().isEmpty() ? null
                        : jobExecution.getAllFailureExceptions().get(0).getMessage();
                try {
                    jobRunRepo.completeRun(etlRunId, status,
                            read, written, 0L, 0L, rejected,
                            errSummary, null, null);
                    log.info("etlJobRunFinalizer: runId={} → {}, read={}, written={}, rejected={}",
                            etlRunId, status, read, written, rejected);
                } catch (Exception ex) {
                    log.error("etlJobRunFinalizer: failed to update ETL_JOB_RUN runId={}", etlRunId, ex);
                }

                // Write reconciliation rows only for completed runs
                if (BatchStatus.COMPLETED == jobExecution.getStatus()) {
                    writeRecon(etlRunId,
                            custRead,  custSkip,
                            acctRead,  acctSkip,
                            usageRead, usageSkip);
                }
            }
        };
    }

    /**
     * Queries Oracle for actual loaded row counts and writes one
     * ETL_RECONCILIATION row per entity.
     *
     * <p>Source value = accepted records (rawRead - stepSkipCount) so that
     * intentional validation rejects are not counted as a discrepancy.
     * Target value  = COUNT(*) in the Oracle target table after the load.
     * Tolerance     = 0 — PASS only when acceptedSource == targetCount exactly.
     * Notes include raw source count, reject count and accepted count for audit.
     */
    private void writeRecon(long etlRunId,
                            long custRead,  long custSkip,
                            long acctRead,  long acctSkip,
                            long usageRead, long usageSkip) {
        // Zero tolerance: PASS iff adjustedVariance == 0
        BigDecimal tolerance = BigDecimal.ZERO;
        try {
            long custTarget  = countRows("TGT_CUSTOMER");
            long acctTarget  = countRows("TGT_ENERGY_ACCOUNT");
            long usageTarget = countRows("TGT_MONTHLY_USAGE");

            long custAccepted  = custRead  - custSkip;
            long acctAccepted  = acctRead  - acctSkip;
            long usageAccepted = usageRead - usageSkip;

            reconRepo.insertRecon(etlRunId, "INITIAL", "TGT_CUSTOMER",
                    "COUNT",
                    BigDecimal.valueOf(custAccepted),  BigDecimal.valueOf(custTarget),
                    tolerance,
                    "raw=" + custRead  + " rejected=" + custSkip  + " accepted=" + custAccepted);

            reconRepo.insertRecon(etlRunId, "INITIAL", "TGT_ENERGY_ACCOUNT",
                    "COUNT",
                    BigDecimal.valueOf(acctAccepted),  BigDecimal.valueOf(acctTarget),
                    tolerance,
                    "raw=" + acctRead  + " rejected=" + acctSkip  + " accepted=" + acctAccepted);

            reconRepo.insertRecon(etlRunId, "INITIAL", "TGT_MONTHLY_USAGE",
                    "COUNT",
                    BigDecimal.valueOf(usageAccepted), BigDecimal.valueOf(usageTarget),
                    tolerance,
                    "raw=" + usageRead + " rejected=" + usageSkip + " accepted=" + usageAccepted);

            log.info("etlJobRunFinalizer: reconciliation written for runId={} " +
                     "(cust={}/{}/{}, acct={}/{}/{}, usage={}/{}/{})",
                    etlRunId,
                    custRead, custSkip, custTarget,
                    acctRead, acctSkip, acctTarget,
                    usageRead, usageSkip, usageTarget);
        } catch (Exception ex) {
            log.error("etlJobRunFinalizer: failed to write reconciliation for runId={}", etlRunId, ex);
        }
    }

    private long countRows(String tableName) {
        Long n = oracleJdbc.queryForObject("SELECT COUNT(*) FROM " + tableName, Long.class);
        return n != null ? n : 0L;
    }

    // =========================================================================
    // Steps
    // =========================================================================

    /**
     * Processors and writers are @StepScope beans injected by name.
     * Spring resolves them fresh for each step execution — etlRunId is already
     * in job parameters by the time beforeStep fires.
     */
    @Bean("initialLoadCustomersStep")
    public Step loadCustomersStep(
            CustomerProcessor customerProcessor,
            CustomerWriter customerWriter) {
        var reader = CustomerExportReader.buildInitialReader(snowflakeDs, fetchSize);
        return new StepBuilder("initialLoadCustomersStep", jobRepository)
                .<CustomerRecord, CustomerRecord>chunk(chunkSize, txManager)
                .reader(reader)
                .processor(customerProcessor)
                .writer(customerWriter)
                .faultTolerant()
                .skipPolicy(VALIDATION_SKIP_POLICY)
                .skipLimit(skipLimit)
                .build();
    }

    @Bean("initialLoadAccountsStep")
    public Step loadCustomerAccountsStep(
            CustomerAccountProcessor customerAccountProcessor,
            CustomerAccountWriter customerAccountWriter) {
        var reader = CustomerAccountExportReader.buildInitialReader(snowflakeDs, fetchSize);
        return new StepBuilder("initialLoadAccountsStep", jobRepository)
                .<CustomerAccountRecord, CustomerAccountRecord>chunk(chunkSize, txManager)
                .reader(reader)
                .processor(customerAccountProcessor)
                .writer(customerAccountWriter)
                .faultTolerant()
                .skipPolicy(VALIDATION_SKIP_POLICY)
                .skipLimit(skipLimit)
                .build();
    }

    @Bean("initialLoadUsageStep")
    public Step loadMonthlyUsageStep(
            MonthlyUsageProcessor monthlyUsageProcessor,
            MonthlyUsageWriter monthlyUsageWriter) {
        var reader = MonthlyUsageExportReader.buildInitialReader(snowflakeDs, fetchSize);
        return new StepBuilder("initialLoadUsageStep", jobRepository)
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
