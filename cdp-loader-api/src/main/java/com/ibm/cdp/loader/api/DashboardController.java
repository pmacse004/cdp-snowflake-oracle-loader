package com.ibm.cdp.loader.api;

import com.ibm.cdp.loader.batch.repository.EtlJobRunRepository;
import com.ibm.cdp.loader.batch.repository.EtlReconciliationRepository;
import com.ibm.cdp.loader.batch.repository.EtlWatermarkRepository;
import org.springframework.beans.factory.annotation.Qualifier;
import org.springframework.http.ResponseEntity;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;

/**
 * Health check and dashboard summary endpoints.
 *
 * <p>Uses an explicit constructor rather than {@code @RequiredArgsConstructor} because
 * Lombok does not copy field-level {@code @Qualifier} annotations onto constructor
 * parameters — Spring would then find two {@link JdbcTemplate} candidates and fail.
 */
@RestController
@RequestMapping("/api")
public class DashboardController {

    private final JdbcTemplate oracleJdbc;
    private final JdbcTemplate snowflakeJdbc;
    private final EtlJobRunRepository jobRunRepo;
    private final EtlReconciliationRepository reconRepo;
    private final EtlWatermarkRepository watermarkRepo;

    public DashboardController(
            @Qualifier("oracleJdbcTemplate")    JdbcTemplate oracleJdbc,
            @Qualifier("snowflakeJdbcTemplate") JdbcTemplate snowflakeJdbc,
            EtlJobRunRepository jobRunRepo,
            EtlReconciliationRepository reconRepo,
            EtlWatermarkRepository watermarkRepo) {
        this.oracleJdbc    = oracleJdbc;
        this.snowflakeJdbc = snowflakeJdbc;
        this.jobRunRepo    = jobRunRepo;
        this.reconRepo     = reconRepo;
        this.watermarkRepo = watermarkRepo;
    }

    /**
     * Lightweight database health check.
     * Oracle: SELECT 1 FROM DUAL
     * Snowflake: SELECT CURRENT_USER(), CURRENT_ROLE(), CURRENT_WAREHOUSE()
     */
    @GetMapping("/health/databases")
    public ResponseEntity<?> databaseHealth() {
        Map<String, Object> oracle  = checkOracle();
        Map<String, Object> snowflake = checkSnowflake();

        boolean healthy = "UP".equals(oracle.get("status")) && "UP".equals(snowflake.get("status"));
        return ResponseEntity
                .status(healthy ? 200 : 503)
                .body(Map.of("oracle", oracle, "snowflake", snowflake));
    }

    /**
     * Dashboard summary — one call for the overview panel.
     */
    @GetMapping("/dashboard/summary")
    public ResponseEntity<?> dashboardSummary() {
        var lastInitial = jobRunRepo.findLatestByJobType("INITIAL");
        var lastDaily   = jobRunRepo.findLatestByJobType("DAILY");
        var lastMonthly = jobRunRepo.findLatestByJobType("MONTHLY");

        var latestReconInitial  = reconRepo.findLatestByJobType("INITIAL");
        var latestReconMonthly  = reconRepo.findLatestByJobType("MONTHLY");

        return ResponseEntity.ok(Map.of(
            "lastInitialRun",  lastInitial  != null ? lastInitial  : Map.of(),
            "lastDailyRun",    lastDaily    != null ? lastDaily    : Map.of(),
            "lastMonthlyRun",  lastMonthly  != null ? lastMonthly  : Map.of(),
            "reconInitial",    latestReconInitial,
            "reconMonthly",    latestReconMonthly
        ));
    }

    /**
     * Read-only diagnostic endpoint — shows the current ETL_WATERMARK state.
     *
     * <p>Returns every active watermark row with:
     * <ul>
     *   <li>{@code watermarkName} — "{JOB_TYPE}/{TABLE_NAME}"</li>
     *   <li>{@code watermarkTimestamp} — last successfully extracted RECORD_EFFECTIVE_TS</li>
     *   <li>{@code watermarkKey} — stable tie-breaker ID at that timestamp</li>
     *   <li>{@code updatedAt} — when the row was last updated in Oracle</li>
     * </ul>
     *
     * <p>This endpoint is strictly read-only; it never modifies ETL_WATERMARK.
     */
    @GetMapping("/watermarks")
    public ResponseEntity<?> getWatermarks() {
        List<EtlWatermarkRepository.WatermarkEntry> entries = watermarkRepo.findAll();
        return ResponseEntity.ok(Map.of("watermarks", entries));
    }

    @GetMapping("/reconciliation/latest")
    public ResponseEntity<?> latestReconciliation() {
        return ResponseEntity.ok(Map.of(
            "initial",  reconRepo.findLatestByJobType("INITIAL"),
            "monthly",  reconRepo.findLatestByJobType("MONTHLY")
        ));
    }

    /**
     * Lists all user tables visible to the current Snowflake role.
     * Queries INFORMATION_SCHEMA.TABLES where TABLE_TYPE = 'BASE TABLE',
     * ordered by schema then table name.
     */
    @GetMapping("/snowflake/tables")
    public ResponseEntity<?> snowflakeTables() {
        try {
            List<Map<String, Object>> tables = snowflakeJdbc.query(
                "SELECT TABLE_CATALOG, TABLE_SCHEMA, TABLE_NAME, ROW_COUNT, BYTES, CREATED, LAST_ALTERED " +
                "FROM INFORMATION_SCHEMA.TABLES " +
                "WHERE TABLE_TYPE = 'BASE TABLE' " +
                "ORDER BY TABLE_SCHEMA, TABLE_NAME",
                (rs, rowNum) -> {
                    Map<String, Object> row = new LinkedHashMap<>();
                    row.put("catalog",      rs.getString("TABLE_CATALOG"));
                    row.put("schema",       rs.getString("TABLE_SCHEMA"));
                    row.put("table",        rs.getString("TABLE_NAME"));
                    row.put("rowCount",     rs.getObject("ROW_COUNT"));
                    row.put("bytes",        rs.getObject("BYTES"));
                    row.put("created",      rs.getString("CREATED"));
                    row.put("lastAltered",  rs.getString("LAST_ALTERED"));
                    return row;
                }
            );
            return ResponseEntity.ok(Map.of("tables", tables, "count", tables.size()));
        } catch (Exception e) {
            return ResponseEntity.status(503)
                    .body(Map.of("error", "Failed to query Snowflake tables: " + e.getMessage()));
        }
    }

    // =========================================================================

    private Map<String, Object> checkOracle() {
        try {
            oracleJdbc.queryForObject("SELECT 1 FROM DUAL", Integer.class);
            return Map.of("status", "UP", "database", "Oracle 23ai");
        } catch (Exception e) {
            return Map.of("status", "DOWN", "error", "Oracle connectivity check failed");
        }
    }

    private Map<String, Object> checkSnowflake() {
        try {
            return snowflakeJdbc.queryForObject(
                "SELECT CURRENT_USER() AS U, CURRENT_ROLE() AS R, CURRENT_WAREHOUSE() AS W",
                (rs, n) -> Map.of(
                    "status",    "UP",
                    "user",      rs.getString("U"),
                    "role",      rs.getString("R"),
                    "warehouse", rs.getString("W")
                )
            );
        } catch (Exception e) {
            return Map.of("status", "DOWN", "error", "Snowflake connectivity check failed");
        }
    }
}
