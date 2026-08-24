package com.ibm.cdp.loader.batch.config;

import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Qualifier;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.boot.autoconfigure.batch.BatchDataSource;
import org.springframework.boot.autoconfigure.flyway.FlywayDataSource;
import org.springframework.context.annotation.Primary;

import java.lang.reflect.Field;
import java.lang.reflect.Method;
import java.util.Arrays;

import static org.assertj.core.api.Assertions.assertThat;

/**
 * Unit tests proving the datasource routing annotations are correct on
 * {@link DataSourceConfig}.
 *
 * <p>These tests use pure reflection — no Spring context is started, no Oracle
 * or Snowflake connection is required.  They verify the static structure that
 * governs routing at application startup.
 *
 * <p>Routing rules under test:
 * <ul>
 *   <li>{@code oracleDataSource} must be {@code @Primary}, {@code @BatchDataSource},
 *       {@code @FlywayDataSource}</li>
 *   <li>{@code snowflakeDataSource} must NOT be {@code @Primary}, NOT
 *       {@code @BatchDataSource}, NOT {@code @FlywayDataSource}</li>
 *   <li>{@code oracleTransactionManager} must be {@code @Primary} and accept
 *       an {@code @Qualifier("oracleDataSource")} parameter</li>
 *   <li>{@code oracleJdbcTemplate} must accept an
 *       {@code @Qualifier("oracleDataSource")} parameter</li>
 *   <li>{@code snowflakeJdbcTemplate} must accept an
 *       {@code @Qualifier("snowflakeDataSource")} parameter</li>
 * </ul>
 */
class DataSourceRoutingTest {

    // -------------------------------------------------------------------------
    // Oracle DataSource routing
    // -------------------------------------------------------------------------

    @Test
    void oracleDataSource_method_is_annotated_Primary() throws NoSuchMethodException {
        Method m = DataSourceConfig.class.getMethod("oracleDataSource");
        assertThat(m.isAnnotationPresent(Primary.class))
                .as("oracleDataSource must be @Primary so it is the default injection target")
                .isTrue();
    }

    @Test
    void oracleDataSource_method_is_annotated_BatchDataSource() throws NoSuchMethodException {
        Method m = DataSourceConfig.class.getMethod("oracleDataSource");
        assertThat(m.isAnnotationPresent(BatchDataSource.class))
                .as("oracleDataSource must be @BatchDataSource so Spring Batch JobRepository uses Oracle")
                .isTrue();
    }

    @Test
    void oracleDataSource_method_is_annotated_FlywayDataSource() throws NoSuchMethodException {
        Method m = DataSourceConfig.class.getMethod("oracleDataSource");
        assertThat(m.isAnnotationPresent(FlywayDataSource.class))
                .as("oracleDataSource must be @FlywayDataSource so Flyway runs migrations against Oracle")
                .isTrue();
    }

    // -------------------------------------------------------------------------
    // Snowflake DataSource must NOT carry Oracle routing annotations
    // -------------------------------------------------------------------------

    @Test
    void snowflakeDataSource_method_is_NOT_annotated_Primary() throws NoSuchMethodException {
        Method m = DataSourceConfig.class.getMethod("snowflakeDataSource");
        assertThat(m.isAnnotationPresent(Primary.class))
                .as("snowflakeDataSource must NOT be @Primary — it must never be the default injection target")
                .isFalse();
    }

    @Test
    void snowflakeDataSource_method_is_NOT_annotated_BatchDataSource() throws NoSuchMethodException {
        Method m = DataSourceConfig.class.getMethod("snowflakeDataSource");
        assertThat(m.isAnnotationPresent(BatchDataSource.class))
                .as("snowflakeDataSource must NOT be @BatchDataSource")
                .isFalse();
    }

    @Test
    void snowflakeDataSource_method_is_NOT_annotated_FlywayDataSource() throws NoSuchMethodException {
        Method m = DataSourceConfig.class.getMethod("snowflakeDataSource");
        assertThat(m.isAnnotationPresent(FlywayDataSource.class))
                .as("snowflakeDataSource must NOT be @FlywayDataSource — Flyway must never touch Snowflake")
                .isFalse();
    }

    // -------------------------------------------------------------------------
    // Oracle transaction manager
    // -------------------------------------------------------------------------

    @Test
    void oracleTransactionManager_method_is_annotated_Primary() throws Exception {
        Method m = findTransactionManagerMethod();
        assertThat(m.isAnnotationPresent(Primary.class))
                .as("oracleTransactionManager must be @Primary")
                .isTrue();
    }

    @Test
    void oracleTransactionManager_receives_oracleDataSource_parameter() throws Exception {
        Method m = findTransactionManagerMethod();
        Qualifier q = m.getParameters()[0].getAnnotation(Qualifier.class);
        assertThat(q)
                .as("oracleTransactionManager parameter must be @Qualifier(\"oracleDataSource\")")
                .isNotNull();
        assertThat(q.value()).isEqualTo("oracleDataSource");
    }

    // -------------------------------------------------------------------------
    // JdbcTemplate routing
    // -------------------------------------------------------------------------

    @Test
    void oracleJdbcTemplate_receives_oracleDataSource_parameter() throws Exception {
        Method m = findSingleParamMethod("oracleJdbcTemplate");
        Qualifier q = m.getParameters()[0].getAnnotation(Qualifier.class);
        assertThat(q)
                .as("oracleJdbcTemplate must inject @Qualifier(\"oracleDataSource\")")
                .isNotNull();
        assertThat(q.value()).isEqualTo("oracleDataSource");
    }

    @Test
    void snowflakeJdbcTemplate_receives_snowflakeDataSource_parameter() throws Exception {
        Method m = findSingleParamMethod("snowflakeJdbcTemplate");
        Qualifier q = m.getParameters()[0].getAnnotation(Qualifier.class);
        assertThat(q)
                .as("snowflakeJdbcTemplate must inject @Qualifier(\"snowflakeDataSource\")")
                .isNotNull();
        assertThat(q.value()).isEqualTo("snowflakeDataSource");
    }

    // -------------------------------------------------------------------------
    // Oracle DataSource construction source — env vars, not DataSourceProperties
    // -------------------------------------------------------------------------

    @Test
    void oracleDataSource_reads_jdbc_url_from_CDP_ORACLE_JDBC_URL_env_var() throws Exception {
        // Verify the @Value annotation on oracleJdbcUrl binds to ${CDP_ORACLE_JDBC_URL}
        Field f = DataSourceConfig.class.getDeclaredField("oracleJdbcUrl");
        Value v = f.getAnnotation(Value.class);
        assertThat(v).as("oracleJdbcUrl field must be @Value-injected").isNotNull();
        assertThat(v.value())
                .as("Must bind to CDP_ORACLE_JDBC_URL env var (not spring.datasource.url)")
                .contains("CDP_ORACLE_JDBC_URL");
    }

    @Test
    void oracleDataSource_reads_password_from_CDP_ORACLE_PASSWORD_env_var() throws Exception {
        Field f = DataSourceConfig.class.getDeclaredField("oraclePassword");
        Value v = f.getAnnotation(Value.class);
        assertThat(v).isNotNull();
        assertThat(v.value()).contains("CDP_ORACLE_PASSWORD");
    }

    // -------------------------------------------------------------------------
    // Snowflake DataSource — clientConfigFile wired through DataSourceConfig
    // -------------------------------------------------------------------------

    @Test
    void dataSourceConfig_has_sfClientConfigFile_field_bound_to_cdp_property() throws Exception {
        Field f = DataSourceConfig.class.getDeclaredField("sfClientConfigFile");
        Value v = f.getAnnotation(Value.class);
        assertThat(v).as("sfClientConfigFile must be @Value-injected").isNotNull();
        assertThat(v.value())
                .as("Must bind to cdp.snowflake.client-config-file")
                .contains("cdp.snowflake.client-config-file");
    }

    // -------------------------------------------------------------------------
    // Helpers
    // -------------------------------------------------------------------------

    private Method findTransactionManagerMethod() {
        return Arrays.stream(DataSourceConfig.class.getMethods())
                .filter(m -> m.getName().equals("oracleTransactionManager"))
                .findFirst()
                .orElseThrow(() -> new AssertionError("oracleTransactionManager method not found"));
    }

    private Method findSingleParamMethod(String name) {
        return Arrays.stream(DataSourceConfig.class.getMethods())
                .filter(m -> m.getName().equals(name) && m.getParameterCount() == 1)
                .findFirst()
                .orElseThrow(() -> new AssertionError(name + " single-param method not found"));
    }
}
