package com.ibm.cdp.loader.batch.snowflake;

import lombok.extern.slf4j.Slf4j;
import net.snowflake.client.jdbc.SnowflakeBasicDataSource;

import javax.sql.DataSource;
import java.io.IOException;
import java.io.InputStream;
import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.nio.file.Path;
import java.security.KeyFactory;
import java.security.PrivateKey;
import java.security.spec.PKCS8EncodedKeySpec;
import java.util.Base64;

/**
 * Builds a Snowflake {@link DataSource} using PKCS#8 RSA key-pair authentication.
 *
 * <p>Takes individual connection parameters as plain Strings/ints so this
 * class has no dependency on {@code CdpLoaderProperties}, which lives in
 * {@code cdp-loader-api}.
 *
 * <h2>client_config_file parameter</h2>
 * The Snowflake JDBC driver searches for {@code sf_client_config.json} by
 * resolving a path relative to the current working directory when no explicit
 * config file is configured.  Inside a Spring Boot fat JAR the driver is
 * loaded from {@code BOOT-INF/lib/}, and on Windows that nested path cannot be
 * represented as a {@code java.nio.file.Path}, which causes an
 * {@code InvalidPathException} at DataSource construction time.
 *
 * <p>The documented solution is the {@code client_config_file} JDBC URL
 * parameter (Snowflake documentation: "Client Configuration File").  We
 * build the Snowflake JDBC URL with this parameter appended, pointing at
 * an explicit absolute path to {@code config/sf_client_config.json}
 * (a committed, secret-free file containing only log-level settings).
 * The path is supplied by the caller, resolved before the fat JAR launches.
 *
 * <p>Alternative: set the {@code SF_CLIENT_CONFIG_FILE} environment variable
 * to the same absolute path before starting the JVM.  The launch script
 * {@code scripts/start-backend.ps1} sets both the env var and passes it
 * via the {@code cdp.snowflake.client-config-file} property.
 */
@Slf4j
public class SnowflakeKeyPairAuth {

    private SnowflakeKeyPairAuth() { /* utility */ }

    /**
     * Builds and returns a configured Snowflake DataSource.
     *
     * @param account            Snowflake account identifier (e.g. {@code LJPNAFI-RW79936})
     * @param user               Snowflake service user
     * @param role               Snowflake role
     * @param warehouse          Snowflake warehouse
     * @param database           Snowflake database
     * @param schema             Snowflake schema (typically {@code STAGING})
     * @param keyPath            Absolute path to PKCS#8 PEM private key, or
     *                           {@code classpath:...} prefix for tests
     * @param loginTimeoutSecs   Connection timeout in seconds
     * @param clientConfigFile   Absolute path to {@code sf_client_config.json}.
     *                           Must not be null or blank — prevents
     *                           {@code InvalidPathException} inside fat JAR on Windows.
     */
    public static DataSource buildDataSource(
            String account, String user, String role,
            String warehouse, String database, String schema,
            String keyPath, int loginTimeoutSecs,
            String clientConfigFile) throws Exception {

        if (keyPath == null || keyPath.isBlank()) {
            throw new IllegalStateException(
                    "CDP_SNOWFLAKE_PRIVATE_KEY_PATH is not set or empty. " +
                    "Set this environment variable to the absolute path of your " +
                    "PKCS#8 RSA private key file.");
        }
        if (clientConfigFile == null || clientConfigFile.isBlank()) {
            throw new IllegalStateException(
                    "cdp.snowflake.client-config-file (SF_CLIENT_CONFIG_FILE) is not set. " +
                    "Set it to the absolute path of config/sf_client_config.json " +
                    "in the repository root before starting the application.");
        }

        log.info("Loading Snowflake private key (path withheld for security)");
        PrivateKey privateKey = loadPrivateKey(keyPath);
        log.info("Snowflake private key loaded (RSA key-pair auth).");

        // Build the full Snowflake JDBC URL including the client_config_file parameter.
        // This is the documented way to provide an explicit config file path and avoids
        // the driver resolving the path from inside BOOT-INF/lib/ on Windows.
        String jdbcUrl = buildJdbcUrl(account, database, schema, warehouse, role, clientConfigFile);
        log.info("Snowflake JDBC URL (secrets redacted): account={}, db={}, schema={}, " +
                 "warehouse={}, role={}, client_config_file={}",
                 account, database, schema, warehouse, role, clientConfigFile);

        SnowflakeBasicDataSource ds = new SnowflakeBasicDataSource();
        ds.setUrl(jdbcUrl);
        ds.setUser(user);
        ds.setPrivateKey(privateKey);
        ds.setLoginTimeout(loginTimeoutSecs);

        return ds;
    }

    /**
     * Constructs the Snowflake JDBC URL with required connection properties
     * appended as query parameters.
     *
     * <p>Format: {@code jdbc:snowflake://<account>.snowflakecomputing.com/?<params>}
     *
     * <p>Package-private for unit-test verification.
     */
    static String buildJdbcUrl(String account, String database, String schema,
                                String warehouse, String role, String clientConfigFile) {
        return "jdbc:snowflake://" + account + ".snowflakecomputing.com/?" +
               "db=" + database +
               "&schema=" + schema +
               "&warehouse=" + warehouse +
               "&role=" + role +
               "&client_config_file=" + encodePathForUrl(clientConfigFile);
    }

    /**
     * URL-encodes a filesystem path so it is safe inside a JDBC URL query string.
     * Replaces backslashes (Windows paths) with forward slashes before encoding,
     * because the Snowflake JDBC driver accepts both separators.
     *
     * <p>Public so that {@code DataSourceSmokeIT} in {@code cdp-loader-api} can
     * verify the encoded path appears in the built JDBC URL.
     */
    public static String encodePathForUrl(String path) {
        // Replace Windows backslashes with forward slashes.
        // The Snowflake JDBC driver normalises the path on both platforms.
        return path.replace('\\', '/');
    }

    /**
     * Loads a PKCS#8 PEM private key.
     * Supports absolute file paths and {@code classpath:} prefix (for tests).
     */
    private static PrivateKey loadPrivateKey(String keyPath) throws Exception {
        String content;

        if (keyPath.startsWith("classpath:")) {
            String resource = keyPath.substring("classpath:".length());
            try (InputStream is = SnowflakeKeyPairAuth.class
                    .getClassLoader().getResourceAsStream(resource)) {
                if (is == null) {
                    throw new IOException(
                            "Classpath key resource not found: " + resource +
                            ". Ensure the test key is on the test classpath.");
                }
                content = new String(is.readAllBytes(), StandardCharsets.UTF_8);
            }
        } else {
            Path p = Path.of(keyPath);
            if (!Files.exists(p)) {
                throw new IOException(
                        "Snowflake private key file not found. " +
                        "File existence check failed (path withheld for security).");
            }
            if (!Files.isReadable(p)) {
                throw new IOException(
                        "Snowflake private key file is not readable. " +
                        "Check file permissions (path withheld for security).");
            }
            content = Files.readString(p, StandardCharsets.UTF_8);
        }

        String base64 = content
                .replace("-----BEGIN PRIVATE KEY-----", "")
                .replace("-----END PRIVATE KEY-----", "")
                .replace("-----BEGIN RSA PRIVATE KEY-----", "")
                .replace("-----END RSA PRIVATE KEY-----", "")
                .replaceAll("\\s+", "");

        if (base64.isEmpty()) {
            throw new IllegalStateException(
                    "Snowflake private key file appears empty after stripping PEM markers.");
        }

        byte[] keyBytes = Base64.getDecoder().decode(base64);
        PKCS8EncodedKeySpec spec = new PKCS8EncodedKeySpec(keyBytes);
        KeyFactory kf = KeyFactory.getInstance("RSA");
        return kf.generatePrivate(spec);
    }
}
