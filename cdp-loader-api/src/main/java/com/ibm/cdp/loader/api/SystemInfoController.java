package com.ibm.cdp.loader.config;

import com.ibm.cdp.loader.config.CdpLoaderProperties;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import java.util.Map;

/**
 * Health and info endpoint supplement — exposes non-secret configuration
 * metadata for the dashboard "System Info" panel.
 *
 * <p>Real health checks are provided by Spring Boot Actuator
 * ({@code /actuator/health}). This endpoint adds application-specific context.
 */
@RestController
@RequestMapping("/api/v1/system")
public class SystemInfoController {

    private final CdpLoaderProperties props;

    public SystemInfoController(CdpLoaderProperties props) {
        this.props = props;
    }

    /**
     * Returns non-secret system info for the dashboard.
     * Credentials and key paths are never returned.
     */
    @GetMapping("/info")
    public Map<String, Object> info() {
        return Map.of(
            "application",   "CDP Snowflake Oracle Loader",
            "version",       "0.1.0-SNAPSHOT",
            "snowflakeAccount",  props.getSnowflake().getAccount(),
            "snowflakeWarehouse", props.getSnowflake().getWarehouse(),
            "snowflakeDatabase",  props.getSnowflake().getDatabase(),
            "oracleSchema",   props.getOracle().getSchema(),
            "chunkSize",      props.getBatch().getChunkSize(),
            "fatalErrorThreshold", props.getBatch().getFatalErrorThreshold()
        );
    }
}
