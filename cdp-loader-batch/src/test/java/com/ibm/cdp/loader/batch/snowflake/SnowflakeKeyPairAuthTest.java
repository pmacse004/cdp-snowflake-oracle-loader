package com.ibm.cdp.loader.batch.snowflake;

import net.snowflake.client.jdbc.SnowflakeBasicDataSource;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.io.TempDir;

import java.nio.file.Files;
import java.nio.file.Path;
import java.security.KeyPair;
import java.security.KeyPairGenerator;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

/**
 * Unit tests for {@link SnowflakeKeyPairAuth}.
 *
 * <p>No Snowflake network connection is made.  Tests only exercise:
 * <ul>
 *   <li>JDBC URL construction including {@code client_config_file} parameter</li>
 *   <li>Windows path encoding (backslash → forward slash)</li>
 *   <li>DataSource type returned</li>
 *   <li>Guard conditions for blank/missing key path and config file</li>
 * </ul>
 */
class SnowflakeKeyPairAuthTest {

    @TempDir
    Path tempDir;

    // -------------------------------------------------------------------------
    // Helper: generate a real RSA private key and write PKCS#8 PEM to temp file
    // -------------------------------------------------------------------------
    private Path writeTempKey() throws Exception {
        KeyPairGenerator kpg = KeyPairGenerator.getInstance("RSA");
        kpg.initialize(2048);
        KeyPair kp = kpg.generateKeyPair();
        byte[] encoded = kp.getPrivate().getEncoded(); // PKCS#8 DER
        String pem = "-----BEGIN PRIVATE KEY-----\n"
                + java.util.Base64.getMimeEncoder(64, new byte[]{'\n'}).encodeToString(encoded)
                + "\n-----END PRIVATE KEY-----\n";
        Path keyFile = tempDir.resolve("test-rsa-key.p8");
        Files.writeString(keyFile, pem);
        return keyFile;
    }

    private Path writeTempConfig() throws Exception {
        Path cfg = tempDir.resolve("sf_client_config.json");
        Files.writeString(cfg, "{\"common\":{\"log_level\":\"OFF\",\"log_path\":\"logs\"}}");
        return cfg;
    }

    // -------------------------------------------------------------------------
    // JDBC URL construction — client_config_file parameter
    // -------------------------------------------------------------------------

    @Test
    void buildJdbcUrl_contains_client_config_file_parameter() {
        String url = SnowflakeKeyPairAuth.buildJdbcUrl(
                "TESTACCT", "MYDB", "STAGING",
                "MY_WH", "MY_ROLE", "/absolute/path/sf_client_config.json");

        assertThat(url)
                .startsWith("jdbc:snowflake://TESTACCT.snowflakecomputing.com/?")
                .contains("db=MYDB")
                .contains("schema=STAGING")
                .contains("warehouse=MY_WH")
                .contains("role=MY_ROLE")
                .contains("client_config_file=/absolute/path/sf_client_config.json");
    }

    @Test
    void buildJdbcUrl_encodes_windows_backslashes_to_forward_slashes() {
        String url = SnowflakeKeyPairAuth.buildJdbcUrl(
                "ACCT", "DB", "SCH", "WH", "ROLE",
                "C:\\Users\\cdp\\config\\sf_client_config.json");

        assertThat(url)
                .as("Windows backslashes must be converted to forward slashes in the JDBC URL")
                .contains("client_config_file=C:/Users/cdp/config/sf_client_config.json")
                .doesNotContain("\\");
    }

    @Test
    void encodePathForUrl_replaces_backslash_with_forward_slash() {
        assertThat(SnowflakeKeyPairAuth.encodePathForUrl("C:\\dir\\file.json"))
                .isEqualTo("C:/dir/file.json");
    }

    @Test
    void encodePathForUrl_leaves_forward_slash_path_unchanged() {
        assertThat(SnowflakeKeyPairAuth.encodePathForUrl("/home/user/config.json"))
                .isEqualTo("/home/user/config.json");
    }

    // -------------------------------------------------------------------------
    // DataSource construction
    // -------------------------------------------------------------------------

    @Test
    void buildDataSource_returns_SnowflakeBasicDataSource() throws Exception {
        Path keyFile = writeTempKey();
        Path cfgFile = writeTempConfig();

        javax.sql.DataSource ds = SnowflakeKeyPairAuth.buildDataSource(
                "TEST-ACCOUNT", "TEST_USER", "TEST_ROLE",
                "TEST_WH", "TEST_DB", "STAGING",
                keyFile.toString(), 10,
                cfgFile.toString()
        );

        assertThat(ds).isInstanceOf(SnowflakeBasicDataSource.class);
    }

    @Test
    void buildDataSource_url_contains_client_config_file_path() throws Exception {
        Path keyFile = writeTempKey();
        Path cfgFile = writeTempConfig();

        SnowflakeBasicDataSource ds = (SnowflakeBasicDataSource) SnowflakeKeyPairAuth.buildDataSource(
                "TEST-ACCOUNT", "TEST_USER", "TEST_ROLE",
                "TEST_WH", "TEST_DB", "STAGING",
                keyFile.toString(), 10,
                cfgFile.toString()
        );

        String url = ds.getUrl();
        assertThat(url)
                .as("JDBC URL must contain client_config_file pointing to the external config file")
                .contains("client_config_file=")
                .contains(SnowflakeKeyPairAuth.encodePathForUrl(cfgFile.toString()));
    }

    // -------------------------------------------------------------------------
    // Guard conditions
    // -------------------------------------------------------------------------

    @Test
    void buildDataSource_throws_when_keyPath_null() {
        assertThatThrownBy(() -> SnowflakeKeyPairAuth.buildDataSource(
                "ACCT", "USER", "ROLE", "WH", "DB", "STAGING", null, 10, "/tmp/cfg.json"))
                .isInstanceOf(IllegalStateException.class)
                .hasMessageContaining("CDP_SNOWFLAKE_PRIVATE_KEY_PATH");
    }

    @Test
    void buildDataSource_throws_when_keyPath_blank() {
        assertThatThrownBy(() -> SnowflakeKeyPairAuth.buildDataSource(
                "ACCT", "USER", "ROLE", "WH", "DB", "STAGING", "   ", 10, "/tmp/cfg.json"))
                .isInstanceOf(IllegalStateException.class)
                .hasMessageContaining("CDP_SNOWFLAKE_PRIVATE_KEY_PATH");
    }

    @Test
    void buildDataSource_throws_when_clientConfigFile_null() {
        assertThatThrownBy(() -> SnowflakeKeyPairAuth.buildDataSource(
                "ACCT", "USER", "ROLE", "WH", "DB", "STAGING", "/tmp/key.p8", 10, null))
                .isInstanceOf(IllegalStateException.class)
                .hasMessageContaining("SF_CLIENT_CONFIG_FILE");
    }

    @Test
    void buildDataSource_throws_when_clientConfigFile_blank() {
        assertThatThrownBy(() -> SnowflakeKeyPairAuth.buildDataSource(
                "ACCT", "USER", "ROLE", "WH", "DB", "STAGING", "/tmp/key.p8", 10, "  "))
                .isInstanceOf(IllegalStateException.class)
                .hasMessageContaining("SF_CLIENT_CONFIG_FILE");
    }

    @Test
    void buildDataSource_throws_when_keyFile_missing() {
        assertThatThrownBy(() -> SnowflakeKeyPairAuth.buildDataSource(
                "ACCT", "USER", "ROLE", "WH", "DB", "STAGING",
                "/nonexistent/path/key.p8", 10, "/tmp/cfg.json"))
                .isInstanceOf(java.io.IOException.class);
    }
}
