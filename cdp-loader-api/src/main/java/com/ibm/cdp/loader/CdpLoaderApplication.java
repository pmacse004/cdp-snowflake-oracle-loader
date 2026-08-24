package com.ibm.cdp.loader;

import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;
import org.springframework.boot.autoconfigure.jdbc.DataSourceAutoConfiguration;
import org.springframework.boot.autoconfigure.jdbc.DataSourceTransactionManagerAutoConfiguration;
import org.springframework.boot.context.properties.ConfigurationPropertiesScan;

/**
 * CDP Snowflake-to-Oracle Loader — Application Entry Point.
 *
 * <p>Starts the Spring Boot application which includes:
 * <ul>
 *   <li>Spring Batch infrastructure (job repository on Oracle)</li>
 *   <li>REST API controllers for dashboard operations</li>
 *   <li>Spring Boot Actuator health and metrics endpoints</li>
 *   <li>Flyway Oracle schema migrations (runs on startup)</li>
 * </ul>
 *
 * <p>Both datasources ({@code oracleDataSource} and {@code snowflakeDataSource}) are
 * explicitly configured in {@code DataSourceConfig} in the cdp-loader-batch module.
 * Spring Boot's {@code DataSourceAutoConfiguration} and
 * {@code DataSourceTransactionManagerAutoConfiguration} are excluded to prevent a
 * conflicting second datasource bean being created from {@code spring.datasource.*}
 * properties.  The Oracle datasource is built directly from {@code CDP_ORACLE_*}
 * environment variables and carries {@code @Primary}, {@code @BatchDataSource} and
 * {@code @FlywayDataSource} so Batch and Flyway always route to Oracle.
 *
 * <p>Snowflake and Oracle credentials are injected via environment variables.
 * No passwords, tokens or private keys are stored in source control.
 */
@SpringBootApplication(exclude = {
        DataSourceAutoConfiguration.class,
        DataSourceTransactionManagerAutoConfiguration.class
})
@ConfigurationPropertiesScan("com.ibm.cdp.loader")
public class CdpLoaderApplication {

    public static void main(String[] args) {
        SpringApplication.run(CdpLoaderApplication.class, args);
    }
}
