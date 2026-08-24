package com.ibm.cdp.loader.batch.config;

import org.springframework.context.annotation.ComponentScan;
import org.springframework.context.annotation.Configuration;

/**
 * Root configuration for the batch module.
 * Components are discovered via @ComponentScan set on the parent app.
 */
@Configuration
public class BatchModuleConfig {
    // Configuration beans live in DataSourceConfig, and job beans
    // are in the job package (InitialLoadJobConfig, DailyIncrementalJobConfig,
    // MonthlyUsageJobConfig). They are all picked up by Spring Boot
    // component scanning from CdpLoaderApplication.
}
