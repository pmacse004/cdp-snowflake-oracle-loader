package com.ibm.cdp.loader.batch.service;

import com.ibm.cdp.loader.batch.repository.EtlJobRunRepository;
import com.ibm.cdp.loader.batch.repository.EtlJobRunRepository.JobRunSummary;
import lombok.extern.slf4j.Slf4j;
import org.springframework.batch.core.Job;
import org.springframework.batch.core.JobParameters;
import org.springframework.batch.core.JobParametersBuilder;
import org.springframework.batch.core.launch.JobLauncher;
import org.springframework.beans.factory.annotation.Qualifier;
import org.springframework.stereotype.Service;

import java.time.Instant;
import java.util.List;

/**
 * Service layer for triggering and monitoring ETL jobs.
 *
 * <p>Enforces concurrency rules:
 * <ul>
 *   <li>Only one job of each type at a time</li>
 *   <li>Initial load must not overlap daily or monthly load</li>
 * </ul>
 *
 * <p>Jobs are launched asynchronously via Spring Batch's async JobLauncher.
 * Returns RUN_ID immediately without waiting for job completion.
 */
@Slf4j
@Service
public class JobLaunchService {

    private final JobLauncher jobLauncher;
    private final EtlJobRunRepository jobRunRepo;
    private final Job initialLoadJob;
    private final Job dailyIncrementalJob;
    private final Job monthlyUsageJob;

    public JobLaunchService(
            JobLauncher jobLauncher,
            EtlJobRunRepository jobRunRepo,
            @Qualifier("initialLoadJob")      Job initialLoadJob,
            @Qualifier("dailyIncrementalJob") Job dailyIncrementalJob,
            @Qualifier("monthlyUsageJob")     Job monthlyUsageJob) {
        this.jobLauncher        = jobLauncher;
        this.jobRunRepo         = jobRunRepo;
        this.initialLoadJob     = initialLoadJob;
        this.dailyIncrementalJob = dailyIncrementalJob;
        this.monthlyUsageJob    = monthlyUsageJob;
    }

    // =========================================================================
    // Launch methods
    // =========================================================================

    public LaunchResult launchInitialLoad() {
        checkConflict("INITIAL");
        checkConflict("DAILY");
        checkConflict("MONTHLY");
        long runId = jobRunRepo.startRun("INITIAL_LOAD_JOB", "INITIAL", null, "API");
        launchAsync(initialLoadJob, "INITIAL_LOAD_JOB", runId);
        return LaunchResult.of(runId, "INITIAL_LOAD_JOB");
    }

    public LaunchResult launchDailyLoad() {
        checkConflict("DAILY");
        checkConflict("INITIAL");
        long runId = jobRunRepo.startRun("DAILY_INCREMENTAL_JOB", "DAILY", null, "API");
        launchAsync(dailyIncrementalJob, "DAILY_INCREMENTAL_JOB", runId);
        return LaunchResult.of(runId, "DAILY_INCREMENTAL_JOB");
    }

    public LaunchResult launchMonthlyLoad() {
        checkConflict("MONTHLY");
        checkConflict("INITIAL");
        long runId = jobRunRepo.startRun("MONTHLY_USAGE_JOB", "MONTHLY", null, "API");
        launchAsync(monthlyUsageJob, "MONTHLY_USAGE_JOB", runId);
        return LaunchResult.of(runId, "MONTHLY_USAGE_JOB");
    }

    // =========================================================================
    // Query methods
    // =========================================================================

    public List<JobRunSummary> getHistory(int page, int size) {
        return jobRunRepo.findAll(page, size);
    }

    public JobRunSummary getByRunId(long runId) {
        return jobRunRepo.findByRunId(runId);
    }

    // =========================================================================
    // Internal
    // =========================================================================

    private void checkConflict(String jobType) {
        if (jobRunRepo.isRunning(jobType)) {
            throw new JobConflictException(
                "A " + jobType + " job is already running. " +
                "Wait for it to complete before launching another.");
        }
    }

    private void launchAsync(Job job, String jobName, long runId) {
        JobParameters params = new JobParametersBuilder()
                .addLong("etlRunId", runId)
                .addLong("launchTime", Instant.now().toEpochMilli())
                .toJobParameters();
        // Launch in background thread — do not block the HTTP request
        Thread.ofVirtual().name("etl-launcher-" + runId).start(() -> {
            try {
                log.info("Launching {} (etlRunId={})", jobName, runId);
                jobLauncher.run(job, params);
                log.info("Job {} (etlRunId={}) finished via Spring Batch execution.", jobName, runId);
            } catch (Exception e) {
                log.error("Job {} (etlRunId={}) failed during launch: {}", jobName, runId, e.getMessage(), e);
                try {
                    jobRunRepo.completeRun(runId, "FAILED", 0, 0, 0, 0, 0,
                            "Launch failure: " + e.getMessage(), null, null);
                } catch (Exception ex) {
                    log.error("Failed to update ETL_JOB_RUN for runId={}", runId, ex);
                }
            }
        });
    }

    // =========================================================================
    // DTO
    // =========================================================================

    public record LaunchResult(long runId, String jobName, String status, Instant submittedAt) {
        static LaunchResult of(long runId, String jobName) {
            return new LaunchResult(runId, jobName, "STARTED", Instant.now());
        }
    }

    public static class JobConflictException extends RuntimeException {
        public JobConflictException(String message) {
            super(message);
        }
    }
}
