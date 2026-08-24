package com.ibm.cdp.loader.config;

import lombok.extern.slf4j.Slf4j;
import org.springframework.context.annotation.Configuration;

/**
 * Snowflake DataSource configuration is handled in
 * {@code com.ibm.cdp.loader.batch.config.DataSourceConfig} in the cdp-loader-batch module.
 *
 * <p>This stub exists to avoid removing the file that's referenced in existing compiled output.
 * The actual bean wiring happens in cdp-loader-batch/DataSourceConfig.java.
 */
@Slf4j
@Configuration
public class SnowflakeDataSourceConfig {
    // Actual Snowflake DataSource bean is in DataSourceConfig in cdp-loader-batch module.
    // That class uses SnowflakeKeyPairAuth.buildDataSource() with CDP_SNOWFLAKE_* env vars.
}
