package com.ibm.cdp.loader;

import org.junit.jupiter.api.Test;

/**
 * Placeholder smoke test that does NOT require Oracle, Snowflake, or Docker.
 * Full context load (with live credentials) is a MANUAL/PENDING test.
 *
 * MANUAL/PENDING: CdpLoaderApplicationIT — requires Oracle + Snowflake credentials.
 * Run manually after setting all CDP_* environment variables:
 *   mvn verify -P integration
 */
class CdpLoaderApplicationTest {

    @Test
    void placeholder_always_passes() {
        // This test confirms the test infrastructure compiles.
        // Live context-load test requires real credentials — see CdpLoaderApplicationIT.
    }
}
