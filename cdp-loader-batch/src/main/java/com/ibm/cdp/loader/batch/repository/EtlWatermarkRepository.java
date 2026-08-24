package com.ibm.cdp.loader.batch.repository;

import lombok.Builder;
import lombok.Data;
import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Qualifier;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Repository;
import org.springframework.transaction.annotation.Transactional;

import java.sql.Timestamp;
import java.time.Instant;
import java.util.List;
import java.util.Optional;

/**
 * Repository for ETL_WATERMARK table — per-table incremental load watermarks.
 *
 * <p>Uses separate watermark records for each source dataset:
 * <ul>
 *   <li>CUSTOMER_EXPORT</li>
 *   <li>CUSTOMER_ACCOUNT_EXPORT</li>
 *   <li>MONTHLY_USAGE_EXPORT</li>
 * </ul>
 */
@Slf4j
@Repository
public class EtlWatermarkRepository {

    /** Minimum timestamp used on first run — before any synthetic data. */
    public static final Instant EPOCH_MIN = Instant.parse("1970-01-01T00:00:00Z");

    public static final String TABLE_CUSTOMER_EXPORT        = "CUSTOMER_EXPORT";
    public static final String TABLE_CUSTOMER_ACCOUNT_EXPORT = "CUSTOMER_ACCOUNT_EXPORT";
    public static final String TABLE_MONTHLY_USAGE_EXPORT   = "MONTHLY_USAGE_EXPORT";

    private final JdbcTemplate jdbc;

    public EtlWatermarkRepository(@Qualifier("oracleJdbcTemplate") JdbcTemplate jdbc) {
        this.jdbc = jdbc;
    }

    /**
     * Returns the last extracted timestamp for the given jobType/tableName pair.
     * Returns EPOCH_MIN if no watermark record exists (first run).
     */
    public Instant getLastExtractedTs(String jobType, String tableName) {
        String sql = "SELECT LAST_EXTRACTED_TS FROM ETL_WATERMARK " +
                     "WHERE JOB_TYPE = ? AND TABLE_NAME = ? AND IS_ACTIVE = 1";
        try {
            Timestamp ts = jdbc.queryForObject(sql, Timestamp.class, jobType, tableName);
            return ts != null ? ts.toInstant() : EPOCH_MIN;
        } catch (org.springframework.dao.EmptyResultDataAccessException e) {
            log.info("No watermark found for {}/{} — using epoch minimum for first run.", jobType, tableName);
            return EPOCH_MIN;
        }
    }

    /**
     * Returns the last max source ID (tie-break for equal timestamps).
     */
    public Optional<String> getLastMaxSourceId(String jobType, String tableName) {
        String sql = "SELECT LAST_MAX_SOURCE_ID FROM ETL_WATERMARK " +
                     "WHERE JOB_TYPE = ? AND TABLE_NAME = ? AND IS_ACTIVE = 1";
        try {
            String id = jdbc.queryForObject(sql, String.class, jobType, tableName);
            return Optional.ofNullable(id);
        } catch (org.springframework.dao.EmptyResultDataAccessException e) {
            return Optional.empty();
        }
    }

    /**
     * Upserts the watermark after a successful commit.
     * Must only be called after the target commit succeeds.
     */
    @Transactional("oracleTransactionManager")
    public void updateWatermark(String jobType, String tableName,
                                Instant lastExtractedTs, String lastMaxSourceId,
                                long runId, long recordCount) {
        // Oracle MERGE — upsert by (JOB_TYPE, TABLE_NAME)
        String mergeSql =
            "MERGE INTO ETL_WATERMARK tgt " +
            "USING (SELECT ? AS JOB_TYPE, ? AS TABLE_NAME FROM DUAL) src " +
            "  ON (tgt.JOB_TYPE = src.JOB_TYPE AND tgt.TABLE_NAME = src.TABLE_NAME) " +
            "WHEN MATCHED THEN UPDATE SET " +
            "  LAST_EXTRACTED_TS  = ?, " +
            "  LAST_MAX_SOURCE_ID = ?, " +
            "  LAST_RUN_ID        = ?, " +
            "  RECORD_COUNT       = ?, " +
            "  UPDATED_AT         = SYS_EXTRACT_UTC(SYSTIMESTAMP) " +
            "WHEN NOT MATCHED THEN INSERT " +
            "  (JOB_TYPE, TABLE_NAME, LAST_EXTRACTED_TS, LAST_MAX_SOURCE_ID, " +
            "   LAST_RUN_ID, RECORD_COUNT, IS_ACTIVE, CREATED_AT, UPDATED_AT) " +
            "VALUES (?, ?, ?, ?, ?, ?, 1, " +
            "  SYS_EXTRACT_UTC(SYSTIMESTAMP), SYS_EXTRACT_UTC(SYSTIMESTAMP))";

        Timestamp ts = Timestamp.from(lastExtractedTs);
        jdbc.update(mergeSql,
                jobType, tableName,           // USING clause
                ts, lastMaxSourceId, runId, recordCount,  // WHEN MATCHED
                jobType, tableName, ts, lastMaxSourceId, runId, recordCount  // WHEN NOT MATCHED
        );
        log.info("Watermark updated: jobType={}, table={}, ts={}, maxId={}, count={}",
                jobType, tableName, lastExtractedTs, lastMaxSourceId, recordCount);
    }

    /**
     * Returns all active watermark rows ordered by JOB_TYPE, TABLE_NAME.
     * Used by the diagnostic API endpoint.
     */
    public List<WatermarkEntry> findAll() {
        String sql =
            "SELECT JOB_TYPE, TABLE_NAME, LAST_EXTRACTED_TS, LAST_MAX_SOURCE_ID, UPDATED_AT " +
            "FROM ETL_WATERMARK WHERE IS_ACTIVE = 1 ORDER BY JOB_TYPE, TABLE_NAME";
        return jdbc.query(sql, (rs, n) -> WatermarkEntry.builder()
                .watermarkName(rs.getString("JOB_TYPE") + "/" + rs.getString("TABLE_NAME"))
                .jobType(rs.getString("JOB_TYPE"))
                .tableName(rs.getString("TABLE_NAME"))
                .watermarkTimestamp(rs.getTimestamp("LAST_EXTRACTED_TS") != null
                        ? rs.getTimestamp("LAST_EXTRACTED_TS").toInstant() : null)
                .watermarkKey(rs.getString("LAST_MAX_SOURCE_ID"))
                .updatedAt(rs.getTimestamp("UPDATED_AT") != null
                        ? rs.getTimestamp("UPDATED_AT").toInstant() : null)
                .build());
    }

    /** Read-only projection used by the diagnostic API. */
    @Data
    @Builder
    public static class WatermarkEntry {
        private String  watermarkName;
        private String  jobType;
        private String  tableName;
        private Instant watermarkTimestamp;
        private String  watermarkKey;
        private Instant updatedAt;
    }
}
