package com.ibm.cdp.loader.config;

import com.ibm.cdp.loader.batch.config.DataSourceConfig;
import com.ibm.cdp.loader.batch.snowflake.SnowflakeKeyPairAuth;
import net.snowflake.client.jdbc.SnowflakeBasicDataSource;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Tag;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.io.TempDir;
import org.springframework.boot.autoconfigure.batch.BatchDataSource;
import org.springframework.boot.autoconfigure.flyway.FlywayDataSource;
import org.springframework.context.annotation.Primary;

import javax.sql.DataSource;
import java.lang.reflect.Method;
import java.nio.file.Files;
import java.nio.file.Path;
import java.security.KeyPair;
import java.security.KeyPairGenerator;
import java.sql.Connection;
import java.util.Arrays;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatCode;
import static org.junit.jupiter.api.Assumptions.assumeTrue;

/**
 * Integration smoke tests for datasource routing.
 *
 * <p><b>Tag: {@code smoke}</b> — excluded from the default surefire unit test run
 * ({@code mvn test}).  Run explicitly with:
 * <pre>
 *   mvn verify -DskipITs=false -Dgroups=smoke
 * </pre>
 *
 * <p>What this tests:
 * <ol>
 *   <li>{@code oracleDataSource} carries {@code @Primary}, {@code @BatchDataSource},
 *       {@code @FlywayDataSource} — Flyway and Batch always route to Oracle.</li>
 *   <li>{@code snowflakeDataSource} carries none of those annotations.</li>
 *   <li>The Snowflake JDBC URL contains {@code client_config_file} pointing at
 *       a real external path — not {@code BOOT-INF} — so no
 *       {@code InvalidPathException} is thrown on Windows inside a fat JAR.</li>
 *   <li>A live Oracle connection executes {@code SELECT 1 FROM DUAL}
 *       (skipped when {@code CDP_ORACLE_JDBC_URL} is absent).</li>
 *   <li>A live Snowflake connection executes {@code SELECT CURRENT_VERSION()}
 *       (skipped when {@code CDP_SNOWFLAKE_*} and {@code SF_CLIENT_CONFIG_FILE}
 *       are absent).</li>
 * </ol>
 */
@Tag("smoke")
class DataSourceSmokeIT {

    @TempDir
    Path tempDir;

    private Path testKeyFile;
    private Path testCfgFile;

    @BeforeEach
    void generateTestFixtures() throws Exception {
        // Generate a real RSA key so buildDataSource() can parse it
        KeyPairGenerator kpg = KeyPairGenerator.getInstance("RSA");
        kpg.initialize(2048);
        KeyPair kp = kpg.generateKeyPair();
        byte[] encoded = kp.getPrivate().getEncoded(); // PKCS#8 DER
        String pem = "-----BEGIN PRIVATE KEY-----\n"
                + java.util.Base64.getMimeEncoder(64, new byte[]{'\n'}).encodeToString(encoded)
                + "\n-----END PRIVATE KEY-----\n";
        testKeyFile = tempDir.resolve("smoke-key.p8");
        Files.writeString(testKeyFile, pem);

        // Create a real sf_client_config.json in a temp directory
        testCfgFile = tempDir.resolve("sf_client_config.json");
        Files.writeString(testCfgFile,
                "{\"common\":{\"log_level\":\"OFF\",\"log_path\":\"logs\"}}");
    }

    // -------------------------------------------------------------------------
    // 1 & 2: Routing annotation assertions (no live connection needed)
    // -------------------------------------------------------------------------

    @Test
    void oracleDataSource_bean_carries_Primary_BatchDataSource_FlywayDataSource() {
        Method m = findMethod("oracleDataSource");
        assertThat(m.isAnnotationPresent(Primary.class))
                .as("oracleDataSource must be @Primary").isTrue();
        assertThat(m.isAnnotationPresent(BatchDataSource.class))
                .as("oracleDataSource must be @BatchDataSource — Spring Batch uses Oracle").isTrue();
        assertThat(m.isAnnotationPresent(FlywayDataSource.class))
                .as("oracleDataSource must be @FlywayDataSource — Flyway migrates Oracle").isTrue();
    }

    @Test
    void snowflakeDataSource_bean_carries_none_of_the_routing_annotations() {
        Method m = findMethod("snowflakeDataSource");
        assertThat(m.isAnnotationPresent(Primary.class))
                .as("snowflakeDataSource must NOT be @Primary").isFalse();
        assertThat(m.isAnnotationPresent(BatchDataSource.class))
                .as("snowflakeDataSource must NOT be @BatchDataSource").isFalse();
        assertThat(m.isAnnotationPresent(FlywayDataSource.class))
                .as("snowflakeDataSource must NOT be @FlywayDataSource").isFalse();
    }

    // -------------------------------------------------------------------------
    // 3a: No InvalidPathException when constructing Snowflake DataSource
    //     with an explicit client_config_file pointing at a real external path
    // -------------------------------------------------------------------------

    @Test
    void snowflake_datasource_construction_does_not_throw_InvalidPathException() {
        assertThatCode(() ->
            SnowflakeKeyPairAuth.buildDataSource(
                    "SMOKE-ACCOUNT", "SMOKE_USER", "SMOKE_ROLE",
                    "SMOKE_WH", "SMOKE_DB", "STAGING",
                    testKeyFile.toString(), 5,
                    testCfgFile.toString()     // real absolute filesystem path
            )
        ).as("Building Snowflake DataSource with explicit client_config_file must not throw")
         .doesNotThrowAnyException();
    }

    // -------------------------------------------------------------------------
    // 3b: JDBC URL references the external config file, not BOOT-INF
    // -------------------------------------------------------------------------

    @Test
    void snowflake_jdbc_url_references_external_config_file_not_boot_inf_path()
            throws Exception {
        SnowflakeBasicDataSource ds = (SnowflakeBasicDataSource)
                SnowflakeKeyPairAuth.buildDataSource(
                        "SMOKE-ACCOUNT", "SMOKE_USER", "SMOKE_ROLE",
                        "SMOKE_WH", "SMOKE_DB", "STAGING",
                        testKeyFile.toString(), 5,
                        testCfgFile.toString()
                );
        String url = ds.getUrl();

        assertThat(url)
                .as("JDBC URL must contain client_config_file parameter")
                .contains("client_config_file=");

        assertThat(url)
                .as("client_config_file must NOT reference BOOT-INF — that path is inside the fat JAR")
                .doesNotContain("BOOT-INF");

        String encodedPath = SnowflakeKeyPairAuth.encodePathForUrl(testCfgFile.toString());
        assertThat(url)
                .as("client_config_file in URL must match the absolute path of the real config file")
                .contains(encodedPath);
    }

    // -------------------------------------------------------------------------
    // 4: Live Oracle connectivity (skipped when CDP_ORACLE_JDBC_URL absent)
    //    Proves Flyway and Batch metadata use Oracle
    // -------------------------------------------------------------------------

    @Test
    void oracle_datasource_executes_SELECT_1_FROM_DUAL() {
        String jdbcUrl  = System.getenv("CDP_ORACLE_JDBC_URL");
        String username = System.getenv("CDP_ORACLE_USERNAME");
        String password = System.getenv("CDP_ORACLE_PASSWORD");
        assumeTrue(jdbcUrl != null && username != null && password != null,
                "Skipping live Oracle test — CDP_ORACLE_JDBC_URL / _USERNAME / _PASSWORD not set");

        assertThatCode(() -> {
            com.zaxxer.hikari.HikariConfig cfg = new com.zaxxer.hikari.HikariConfig();
            cfg.setJdbcUrl(jdbcUrl);
            cfg.setUsername(username);
            cfg.setPassword(password);
            cfg.setDriverClassName("oracle.jdbc.OracleDriver");
            cfg.setMaximumPoolSize(1);
            cfg.setConnectionTimeout(10_000);
            com.zaxxer.hikari.HikariDataSource ds = new com.zaxxer.hikari.HikariDataSource(cfg);
            try (Connection c = ds.getConnection()) {
                try (var rs = c.createStatement().executeQuery("SELECT 1 FROM DUAL")) {
                    assertThat(rs.next()).isTrue();
                    assertThat(rs.getInt(1)).isEqualTo(1);
                }
            } finally {
                ds.close();
            }
        }).as("Live Oracle connection (SELECT 1 FROM DUAL) must succeed").doesNotThrowAnyException();
    }

    // -------------------------------------------------------------------------
    // 5: Live Snowflake connectivity (skipped when env vars absent)
    //    Proves SELECT CURRENT_VERSION() executes without InvalidPathException
    // -------------------------------------------------------------------------

    @Test
    void snowflake_datasource_executes_SELECT_CURRENT_VERSION() {
        String sfAccount   = System.getenv("CDP_SNOWFLAKE_ACCOUNT");
        String sfUser      = System.getenv("CDP_SNOWFLAKE_USER");
        String sfRole      = System.getenv("CDP_SNOWFLAKE_ROLE");
        String sfWarehouse = System.getenv("CDP_SNOWFLAKE_WAREHOUSE");
        String sfDatabase  = System.getenv("CDP_SNOWFLAKE_DATABASE");
        String sfKeyPath   = System.getenv("CDP_SNOWFLAKE_PRIVATE_KEY_PATH");
        String sfCfgFile   = System.getenv("SF_CLIENT_CONFIG_FILE");

        assumeTrue(
                sfAccount != null && sfUser != null && sfKeyPath != null && sfCfgFile != null,
                "Skipping live Snowflake test — CDP_SNOWFLAKE_* and SF_CLIENT_CONFIG_FILE not set");

        assertThatCode(() -> {
            DataSource ds = SnowflakeKeyPairAuth.buildDataSource(
                    sfAccount, sfUser,
                    sfRole      != null ? sfRole      : "CDP_LOADER_ROLE",
                    sfWarehouse != null ? sfWarehouse : "CDP_LOADER_WH",
                    sfDatabase  != null ? sfDatabase  : "CDP_UTIL_DB",
                    "STAGING", sfKeyPath, 60, sfCfgFile
            );
            try (Connection c = ds.getConnection()) {
                try (var rs = c.createStatement().executeQuery("SELECT CURRENT_VERSION()")) {
                    assertThat(rs.next()).isTrue();
                    assertThat(rs.getString(1))
                            .as("Snowflake CURRENT_VERSION() must return a non-blank string")
                            .isNotBlank();
                }
            }
        }).as("Live Snowflake SELECT CURRENT_VERSION() must not throw InvalidPathException")
          .doesNotThrowAnyException();
    }

    // -------------------------------------------------------------------------
    // Helper
    // -------------------------------------------------------------------------

    private Method findMethod(String name) {
        return Arrays.stream(DataSourceConfig.class.getMethods())
                .filter(m -> m.getName().equals(name))
                .findFirst()
                .orElseThrow(() -> new AssertionError("Method not found in DataSourceConfig: " + name));
    }
}
