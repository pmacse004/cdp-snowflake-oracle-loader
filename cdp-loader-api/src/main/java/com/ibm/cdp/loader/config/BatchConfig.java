package com.ibm.cdp.loader.config;

import org.springframework.context.annotation.Configuration;
import org.springframework.scheduling.annotation.EnableScheduling;

/**
 * Top-level Spring Batch and scheduling configuration.
 *
 * <p><strong>@EnableBatchProcessing is intentionally ABSENT.</strong>
 * Spring Boot 3.x auto-configures the JobRepository, JobLauncher and
 * JobExplorer against the {@code @Primary} Oracle DataSource automatically
 * when {@code spring-boot-starter-batch} is on the classpath.
 * Adding {@code @EnableBatchProcessing} in Boot 3.x <em>opts out</em> of that
 * auto-configuration and requires manual wiring of the infrastructure beans —
 * an unnecessary complication for this project.
 * See Spring Batch 5.0 migration guide: "Spring Boot auto-configuration now
 * takes precedence over @EnableBatchProcessing".
 *
 * <p>{@code @EnableScheduling} is required to activate the
 * {@code @Scheduled} cron triggers used by the daily and monthly load jobs.
 * These triggers only fire when {@code cdp.batch.*.schedule-enabled=true}.
 * Jobs are otherwise triggered via REST API.
 *
 * <p>Jobs are NOT launched on startup: {@code spring.batch.job.enabled=false}.
 */
@Configuration
@EnableScheduling
public class BatchConfig {
    // Intentionally empty.
    // Spring Boot auto-configures JobRepository, JobLauncher and JobExplorer.
    // Job definitions are in cdp-loader-batch module and are loaded as Spring beans.
}
