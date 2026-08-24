package com.ibm.cdp.loader;

import org.junit.jupiter.api.Test;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.test.context.ActiveProfiles;

/**
 * Smoke test — verifies the Spring application context loads without errors.
 * Uses the 'ci' profile with Testcontainers Oracle and mocked Snowflake.
 *
 * NOTE: This test requires Docker to be running.
 * It is an integration test (runs with maven-failsafe-plugin, not surefire).
 */
@SpringBootTest
@ActiveProfiles("ci")
class CdpLoaderApplicationIT {

    @Test
    void contextLoads() {
        // If the context starts without throwing, the test passes.
        // Validates: Spring Batch auto-config, Flyway migrations, property binding.
    }
}
