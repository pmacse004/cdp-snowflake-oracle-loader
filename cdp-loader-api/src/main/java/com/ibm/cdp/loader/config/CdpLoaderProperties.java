package com.ibm.cdp.loader.config;

import jakarta.validation.constraints.Min;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import lombok.Getter;
import lombok.Setter;
import org.springframework.boot.context.properties.ConfigurationProperties;
import org.springframework.validation.annotation.Validated;

import java.math.BigDecimal;

/**
 * Strongly-typed binding for the {@code cdp.*} configuration namespace.
 * Validated at startup — application will fail fast if required values are missing.
 */
@Getter
@Setter
@Validated
@ConfigurationProperties(prefix = "cdp")
public class CdpLoaderProperties {

    @NotNull
    private Snowflake snowflake = new Snowflake();

    @NotNull
    private Oracle oracle = new Oracle();

    @NotNull
    private Batch batch = new Batch();

    @NotNull
    private Reconciliation reconciliation = new Reconciliation();

    @NotNull
    private MappingCatalogue mappingCatalogue = new MappingCatalogue();

    // =========================================================================

    @Getter
    @Setter
    public static class Snowflake {
        @NotBlank private String account;
        @NotBlank private String user;
        @NotBlank private String warehouse;
        @NotBlank private String database;
        @NotBlank private String role;
        @NotBlank private String privateKeyPath;
        /** Absolute path to sf_client_config.json — supplied by SF_CLIENT_CONFIG_FILE env var. */
        @NotBlank private String clientConfigFile;

        @NotNull
        private Pool pool = new Pool();

        @Getter @Setter
        public static class Pool {
            @Min(1) private int minConnections = 1;
            @Min(1) private int maxConnections = 5;
            @Min(10) private int loginTimeout   = 60;
        }
    }

    @Getter
    @Setter
    public static class Oracle {
        @NotBlank private String schema = "CDP_LOADER";
    }

    @Getter
    @Setter
    public static class Batch {
        @Min(1)  private int chunkSize             = 500;
        @Min(1)  private int fatalErrorThreshold   = 100;
        @Min(1)  private int fetchSize             = 1000;

        @NotNull private InitialLoad  initialLoad  = new InitialLoad();
        @NotNull private DailyLoad    dailyLoad    = new DailyLoad();
        @NotNull private MonthlyLoad  monthlyLoad  = new MonthlyLoad();

        @Getter @Setter
        public static class InitialLoad {
            private boolean enabled     = true;
            @Min(1) private int parallelism = 1;
        }

        @Getter @Setter
        public static class DailyLoad {
            private boolean enabled          = true;
            private String  schedule         = "0 0 2 * * ?";
            private boolean scheduleEnabled  = false;
        }

        @Getter @Setter
        public static class MonthlyLoad {
            private boolean enabled          = true;
            private String  schedule         = "0 0 3 1 * ?";
            private boolean scheduleEnabled  = false;
        }
    }

    @Getter
    @Setter
    public static class Reconciliation {
        private BigDecimal countTolerancePct  = BigDecimal.ZERO;
        private BigDecimal kwhTolerancePct    = new BigDecimal("0.001");
        private BigDecimal amountTolerancePct = new BigDecimal("0.001");
    }

    @Getter
    @Setter
    public static class MappingCatalogue {
        @NotBlank private String location = "classpath:ica/mapping-catalogue.yaml";
    }
}
