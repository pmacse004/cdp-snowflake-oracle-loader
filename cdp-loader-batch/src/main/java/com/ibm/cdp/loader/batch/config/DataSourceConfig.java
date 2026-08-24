package com.ibm.cdp.loader.batch.config;

import com.ibm.cdp.loader.batch.snowflake.SnowflakeKeyPairAuth;
import com.zaxxer.hikari.HikariConfig;
import com.zaxxer.hikari.HikariDataSource;
import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Qualifier;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.boot.autoconfigure.batch.BatchDataSource;
import org.springframework.boot.autoconfigure.flyway.FlywayDataSource;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.context.annotation.Primary;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.jdbc.datasource.DataSourceTransactionManager;
import org.springframework.transaction.PlatformTransactionManager;

import javax.sql.DataSource;

/**
 * Explicit two-datasource configuration.
 *
 * <h2>Routing contract</h2>
 * <pre>
 *  oracleDataSource    — @Primary, @BatchDataSource, @FlywayDataSource
 *                        Spring Batch JobRepository and Flyway always route here.
 *                        Built from CDP_ORACLE_JDBC_URL / _USERNAME / _PASSWORD.
 *
 *  snowflakeDataSource — named only, never @Primary / @BatchDataSource / @FlywayDataSource
 *                        Used exclusively by Snowflake readers and health checks.
 *                        Built from CDP_SNOWFLAKE_* env vars with key-pair auth.
 * </pre>
 *
 * <p>Both datasources are declared here rather than relying on Spring Boot
 * auto-configuration back-off, so that {@code @BatchDataSource} and
 * {@code @FlywayDataSource} can be applied to exactly the Oracle bean and
 * Flyway/Batch can never accidentally acquire the Snowflake connection.
 *
 * <h2>sf_client_config.json</h2>
 * Snowflake JDBC resolves {@code sf_client_config.json} relative to the
 * working directory.  Inside a packaged fat JAR that resolves to a path
 * inside {@code BOOT-INF/lib/}, which is not a valid filesystem path on
 * Windows and causes an {@code InvalidPathException}.  The fix is to pass an
 * explicit absolute path to a real, safe config file via the documented
 * {@code client_config_file} JDBC URL parameter (or the environment variable
 * {@code SF_CLIENT_CONFIG_FILE} set in the launch script).  The file
 * {@code config/sf_client_config.json} in the repository root carries only
 * log-level settings and contains no secrets.
 */
@Slf4j
@Configuration
public class DataSourceConfig {

    // =========================================================================
    // Oracle connection parameters — from CDP_ORACLE_* env vars
    // =========================================================================

    @Value("${CDP_ORACLE_JDBC_URL:jdbc:oracle:thin:@//localhost:1521/FREEPDB1}")
    private String oracleJdbcUrl;

    @Value("${CDP_ORACLE_USERNAME:CDP_LOADER}")
    private String oracleUsername;

    @Value("${CDP_ORACLE_PASSWORD}")
    private String oraclePassword;

    // =========================================================================
    // Snowflake connection parameters — from cdp.snowflake.* in application.yml
    // =========================================================================

    @Value("${cdp.snowflake.account}")
    private String sfAccount;

    @Value("${cdp.snowflake.user}")
    private String sfUser;

    @Value("${cdp.snowflake.role}")
    private String sfRole;

    @Value("${cdp.snowflake.warehouse}")
    private String sfWarehouse;

    @Value("${cdp.snowflake.database}")
    private String sfDatabase;

    @Value("${cdp.snowflake.private-key-path}")
    private String sfKeyPath;

    @Value("${cdp.snowflake.pool.login-timeout:60}")
    private int sfLoginTimeout;

    /**
     * Absolute path to the Snowflake client config file.
     * Passed as {@code client_config_file} in the JDBC URL.
     * Set via {@code cdp.snowflake.client-config-file} in application.yml,
     * which is populated from the {@code SF_CLIENT_CONFIG_FILE} env var.
     */
    @Value("${cdp.snowflake.client-config-file}")
    private String sfClientConfigFile;

    // =========================================================================
    // Oracle DataSource — @Primary, @BatchDataSource, @FlywayDataSource
    // =========================================================================

    /**
     * Oracle HikariCP DataSource built explicitly from {@code CDP_ORACLE_*}
     * environment variables.
     *
     * <ul>
     *   <li>{@code @Primary} — default injection target for unqualified DataSource.</li>
     *   <li>{@code @BatchDataSource} — Spring Batch JobRepository uses this source.</li>
     *   <li>{@code @FlywayDataSource} — Flyway runs migrations against this source.</li>
     * </ul>
     */
    @Bean(name = "oracleDataSource")
    @Primary
    @BatchDataSource
    @FlywayDataSource
    public DataSource oracleDataSource() {
        HikariConfig cfg = new HikariConfig();
        cfg.setJdbcUrl(oracleJdbcUrl);
        cfg.setUsername(oracleUsername);
        cfg.setPassword(oraclePassword);
        // Do NOT call setDriverClassName — HikariCP resolves oracle.jdbc.OracleDriver
        // from the thread context classloader via the JDBC URL prefix.
        // Calling setDriverClassName(oracle.jdbc.OracleDriver) from inside a Spring Boot
        // fat JAR fails because HikariConfig's own classloader cannot see BOOT-INF/lib/.
        cfg.setPoolName("CdpOraclePool");
        cfg.setMaximumPoolSize(10);
        cfg.setMinimumIdle(2);
        cfg.setConnectionTimeout(30_000);
        cfg.setIdleTimeout(600_000);
        cfg.setMaxLifetime(1_800_000);
        cfg.setConnectionTestQuery("SELECT 1 FROM DUAL");
        DataSource ds = new HikariDataSource(cfg);
        log.info("Oracle DataSource initialised — url={} (@Primary @BatchDataSource @FlywayDataSource)",
                 oracleJdbcUrl);
        return ds;
    }

    // =========================================================================
    // Snowflake DataSource — named only
    // =========================================================================

    /**
     * Snowflake DataSource using RSA key-pair authentication (PKCS#8 PEM).
     *
     * <p>NOT annotated with {@code @Primary}, {@code @BatchDataSource} or
     * {@code @FlywayDataSource}.  Used exclusively by Snowflake JDBC cursor
     * readers and the connectivity health check.
     *
     * <p>The documented {@code client_config_file} JDBC URL parameter is set
     * to the absolute path of {@code config/sf_client_config.json} from the
     * working directory.  This prevents the driver from searching for the file
     * inside {@code BOOT-INF/lib/} when running from a fat JAR, which would
     * produce an {@code InvalidPathException} on Windows.
     */
    @Bean(name = "snowflakeDataSource")
    public DataSource snowflakeDataSource() throws Exception {
        return SnowflakeKeyPairAuth.buildDataSource(
                sfAccount, sfUser, sfRole,
                sfWarehouse, sfDatabase, "STAGING",
                sfKeyPath, sfLoginTimeout, sfClientConfigFile
        );
    }

    // =========================================================================
    // Named JdbcTemplates — every injection is explicitly qualified
    // =========================================================================

    @Bean(name = "oracleJdbcTemplate")
    public JdbcTemplate oracleJdbcTemplate(
            @Qualifier("oracleDataSource") DataSource dataSource) {
        return new JdbcTemplate(dataSource);
    }

    @Bean(name = "snowflakeJdbcTemplate")
    public JdbcTemplate snowflakeJdbcTemplate(
            @Qualifier("snowflakeDataSource") DataSource ds) {
        return new JdbcTemplate(ds);
    }

    // =========================================================================
    // Transaction manager — Oracle only
    // =========================================================================

    @Bean(name = "oracleTransactionManager")
    @Primary
    public PlatformTransactionManager oracleTransactionManager(
            @Qualifier("oracleDataSource") DataSource dataSource) {
        log.info("Oracle PlatformTransactionManager initialised");
        return new DataSourceTransactionManager(dataSource);
    }
}
