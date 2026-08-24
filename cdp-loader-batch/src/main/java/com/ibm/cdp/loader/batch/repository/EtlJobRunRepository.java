package com.ibm.cdp.loader.batch.repository;

import lombok.Builder;
import lombok.Data;
import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Qualifier;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.jdbc.support.GeneratedKeyHolder;
import org.springframework.jdbc.support.KeyHolder;
import org.springframework.stereotype.Repository;
import org.springframework.transaction.annotation.Transactional;

import java.math.BigDecimal;
import java.math.RoundingMode;
import java.sql.PreparedStatement;
import java.sql.Statement;
import java.sql.Timestamp;
import java.time.Instant;

/**
 * Repository for ETL_JOB_RUN table — one row per job execution.
 *
 * <p>Valid status transitions:
 * STARTED → COMPLETED | FAILED
 */
@Slf4j
@Repository
public class EtlJobRunRepository {

    private final JdbcTemplate jdbc;

    public EtlJobRunRepository(@Qualifier("oracleJdbcTemplate") JdbcTemplate jdbc) {
        this.jdbc = jdbc;
    }

    /**
     * Creates a new ETL_JOB_RUN row in STARTED status and returns the generated RUN_ID.
     */
    @Transactional("oracleTransactionManager")
    public long startRun(String jobName, String jobType, Long springExecId, String triggeredBy) {
        String sql =
            "INSERT INTO ETL_JOB_RUN " +
            "(JOB_NAME, JOB_TYPE, SPRING_EXEC_ID, STATUS, START_TIME, TRIGGERED_BY, " +
            " RECORDS_READ, RECORDS_INSERTED, RECORDS_UPDATED, RECORDS_SKIPPED, RECORDS_REJECTED) " +
            "VALUES (?, ?, ?, 'STARTED', SYS_EXTRACT_UTC(SYSTIMESTAMP), ?, 0, 0, 0, 0, 0)";

        KeyHolder keyHolder = new GeneratedKeyHolder();
        jdbc.update(con -> {
            PreparedStatement ps = con.prepareStatement(sql, new String[]{"RUN_ID"});
            ps.setString(1, jobName);
            ps.setString(2, jobType);
            if (springExecId != null) ps.setLong(3, springExecId);
            else ps.setNull(3, java.sql.Types.NUMERIC);
            ps.setString(4, triggeredBy);
            return ps;
        }, keyHolder);

        long runId = keyHolder.getKey().longValue();
        log.info("ETL_JOB_RUN created: runId={}, job={}, type={}", runId, jobName, jobType);
        return runId;
    }

    /**
     * Updates the run to RUNNING status with current START_TIME.
     */
    @Transactional("oracleTransactionManager")
    public void markRunning(long runId) {
        jdbc.update(
            "UPDATE ETL_JOB_RUN SET STATUS = 'STARTED', UPDATED_AT = SYS_EXTRACT_UTC(SYSTIMESTAMP) " +
            "WHERE RUN_ID = ?", runId);
    }

    /**
     * Finalises the run with final metrics.
     */
    @Transactional("oracleTransactionManager")
    public void completeRun(long runId, String status,
                            long read, long inserted, long updated, long skipped, long rejected,
                            String errorSummary, String wmBefore, String wmAfter) {
        String sql =
            "UPDATE ETL_JOB_RUN SET " +
            "  STATUS = ?, END_TIME = SYS_EXTRACT_UTC(SYSTIMESTAMP), " +
            "  DURATION_SECONDS = (EXTRACT(SECOND FROM (SYS_EXTRACT_UTC(SYSTIMESTAMP) - START_TIME)) + " +
            "                      EXTRACT(MINUTE FROM (SYS_EXTRACT_UTC(SYSTIMESTAMP) - START_TIME)) * 60 + " +
            "                      EXTRACT(HOUR FROM (SYS_EXTRACT_UTC(SYSTIMESTAMP) - START_TIME)) * 3600), " +
            "  RECORDS_READ = ?, RECORDS_INSERTED = ?, RECORDS_UPDATED = ?, " +
            "  RECORDS_SKIPPED = ?, RECORDS_REJECTED = ?, " +
            "  ERROR_SUMMARY = ?, WATERMARK_BEFORE = ?, WATERMARK_AFTER = ?, " +
            "  UPDATED_AT = SYS_EXTRACT_UTC(SYSTIMESTAMP) " +
            "WHERE RUN_ID = ?";
        jdbc.update(sql, status, read, inserted, updated, skipped, rejected,
                errorSummary, wmBefore, wmAfter, runId);
        log.info("ETL_JOB_RUN completed: runId={}, status={}, read={}, ins={}, upd={}, rej={}",
                runId, status, read, inserted, updated, rejected);
    }

    /**
     * Returns the most-recent run record for a given job type, or null if none.
     */
    public JobRunSummary findLatestByJobType(String jobType) {
        String sql =
            "SELECT RUN_ID, JOB_NAME, JOB_TYPE, STATUS, START_TIME, END_TIME, " +
            "DURATION_SECONDS, RECORDS_READ, RECORDS_INSERTED, RECORDS_UPDATED, " +
            "RECORDS_SKIPPED, RECORDS_REJECTED, ERROR_SUMMARY, WATERMARK_BEFORE, WATERMARK_AFTER " +
            "FROM ETL_JOB_RUN WHERE JOB_TYPE = ? " +
            "ORDER BY RUN_ID DESC FETCH FIRST 1 ROWS ONLY";
        try {
            return jdbc.queryForObject(sql, (rs, n) -> JobRunSummary.builder()
                    .runId(rs.getLong("RUN_ID"))
                    .jobName(rs.getString("JOB_NAME"))
                    .jobType(rs.getString("JOB_TYPE"))
                    .status(rs.getString("STATUS"))
                    .startTime(rs.getTimestamp("START_TIME") != null ?
                            rs.getTimestamp("START_TIME").toInstant() : null)
                    .endTime(rs.getTimestamp("END_TIME") != null ?
                            rs.getTimestamp("END_TIME").toInstant() : null)
                    .durationSeconds(rs.getBigDecimal("DURATION_SECONDS"))
                    .recordsRead(rs.getLong("RECORDS_READ"))
                    .recordsInserted(rs.getLong("RECORDS_INSERTED"))
                    .recordsUpdated(rs.getLong("RECORDS_UPDATED"))
                    .recordsSkipped(rs.getLong("RECORDS_SKIPPED"))
                    .recordsRejected(rs.getLong("RECORDS_REJECTED"))
                    .errorSummary(rs.getString("ERROR_SUMMARY"))
                    .watermarkBefore(rs.getString("WATERMARK_BEFORE"))
                    .watermarkAfter(rs.getString("WATERMARK_AFTER"))
                    .build(), jobType);
        } catch (org.springframework.dao.EmptyResultDataAccessException e) {
            return null;
        }
    }

    public java.util.List<JobRunSummary> findAll(int page, int size) {
        String sql =
            "SELECT RUN_ID, JOB_NAME, JOB_TYPE, STATUS, START_TIME, END_TIME, " +
            "DURATION_SECONDS, RECORDS_READ, RECORDS_INSERTED, RECORDS_UPDATED, " +
            "RECORDS_SKIPPED, RECORDS_REJECTED, ERROR_SUMMARY, WATERMARK_BEFORE, WATERMARK_AFTER " +
            "FROM ETL_JOB_RUN ORDER BY RUN_ID DESC " +
            "OFFSET ? ROWS FETCH NEXT ? ROWS ONLY";
        return jdbc.query(sql, (rs, n) -> JobRunSummary.builder()
                .runId(rs.getLong("RUN_ID"))
                .jobName(rs.getString("JOB_NAME"))
                .jobType(rs.getString("JOB_TYPE"))
                .status(rs.getString("STATUS"))
                .startTime(rs.getTimestamp("START_TIME") != null ?
                        rs.getTimestamp("START_TIME").toInstant() : null)
                .endTime(rs.getTimestamp("END_TIME") != null ?
                        rs.getTimestamp("END_TIME").toInstant() : null)
                .durationSeconds(rs.getBigDecimal("DURATION_SECONDS"))
                .recordsRead(rs.getLong("RECORDS_READ"))
                .recordsInserted(rs.getLong("RECORDS_INSERTED"))
                .recordsUpdated(rs.getLong("RECORDS_UPDATED"))
                .recordsSkipped(rs.getLong("RECORDS_SKIPPED"))
                .recordsRejected(rs.getLong("RECORDS_REJECTED"))
                .errorSummary(rs.getString("ERROR_SUMMARY"))
                .watermarkBefore(rs.getString("WATERMARK_BEFORE"))
                .watermarkAfter(rs.getString("WATERMARK_AFTER"))
                .build(), page * size, size);
    }

    public JobRunSummary findByRunId(long runId) {
        String sql =
            "SELECT RUN_ID, JOB_NAME, JOB_TYPE, STATUS, START_TIME, END_TIME, " +
            "DURATION_SECONDS, RECORDS_READ, RECORDS_INSERTED, RECORDS_UPDATED, " +
            "RECORDS_SKIPPED, RECORDS_REJECTED, ERROR_SUMMARY, WATERMARK_BEFORE, WATERMARK_AFTER " +
            "FROM ETL_JOB_RUN WHERE RUN_ID = ?";
        try {
            return jdbc.queryForObject(sql, (rs, n) -> JobRunSummary.builder()
                    .runId(rs.getLong("RUN_ID"))
                    .jobName(rs.getString("JOB_NAME"))
                    .jobType(rs.getString("JOB_TYPE"))
                    .status(rs.getString("STATUS"))
                    .startTime(rs.getTimestamp("START_TIME") != null ?
                            rs.getTimestamp("START_TIME").toInstant() : null)
                    .endTime(rs.getTimestamp("END_TIME") != null ?
                            rs.getTimestamp("END_TIME").toInstant() : null)
                    .durationSeconds(rs.getBigDecimal("DURATION_SECONDS"))
                    .recordsRead(rs.getLong("RECORDS_READ"))
                    .recordsInserted(rs.getLong("RECORDS_INSERTED"))
                    .recordsUpdated(rs.getLong("RECORDS_UPDATED"))
                    .recordsSkipped(rs.getLong("RECORDS_SKIPPED"))
                    .recordsRejected(rs.getLong("RECORDS_REJECTED"))
                    .errorSummary(rs.getString("ERROR_SUMMARY"))
                    .watermarkBefore(rs.getString("WATERMARK_BEFORE"))
                    .watermarkAfter(rs.getString("WATERMARK_AFTER"))
                    .build(), runId);
        } catch (org.springframework.dao.EmptyResultDataAccessException e) {
            return null;
        }
    }

    /**
     * Returns true if any run for the given job type is in STARTED status.
     */
    public boolean isRunning(String jobType) {
        Integer count = jdbc.queryForObject(
            "SELECT COUNT(1) FROM ETL_JOB_RUN WHERE JOB_TYPE = ? AND STATUS = 'STARTED'",
            Integer.class, jobType);
        return count != null && count > 0;
    }

    @Data
    @Builder
    public static class JobRunSummary {
        private long runId;
        private String jobName;
        private String jobType;
        private String status;
        private Instant startTime;
        private Instant endTime;
        private BigDecimal durationSeconds;
        private long recordsRead;
        private long recordsInserted;
        private long recordsUpdated;
        private long recordsSkipped;
        private long recordsRejected;
        private String errorSummary;
        private String watermarkBefore;
        private String watermarkAfter;
    }
}
