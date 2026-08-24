package com.ibm.cdp.loader.batch.repository;

import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Qualifier;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Repository;
import org.springframework.transaction.annotation.Propagation;
import org.springframework.transaction.annotation.Transactional;

import java.util.List;
import java.util.Map;

/**
 * Repository for ETL_RECORD_ERROR — stores rejected source records.
 *
 * <p>Payload excerpts are stored only when they do not contain sensitive data.
 * SSN, password, key material must never be stored here.
 */
@Slf4j
@Repository
public class EtlRecordErrorRepository {

    private final JdbcTemplate jdbc;

    public EtlRecordErrorRepository(@Qualifier("oracleJdbcTemplate") JdbcTemplate jdbc) {
        this.jdbc = jdbc;
    }

    /**
     * Inserts a rejection record into ETL_RECORD_ERROR.
     *
     * <p>{@code REQUIRES_NEW} opens a separate physical connection and commits
     * immediately, so the INSERT survives even when the surrounding chunk
     * transaction is rolled back by Spring Batch's skip/retry mechanics.
     *
     * @param runId          ETL_JOB_RUN.RUN_ID
     * @param jobName        job name
     * @param stepName       step name
     * @param sourceEntity   e.g. "VW_DAILY_CUSTOMER_EXPORT"
     * @param sourceRecordId e.g. the CUSTOMER_ID or USAGE_ID
     * @param errorCode      machine-readable code
     * @param errorMessage   human-readable description
     * @param payloadExcerpt safe excerpt — must not contain credentials or PII beyond record ID
     */
    @Transactional(value = "oracleTransactionManager", propagation = Propagation.REQUIRES_NEW)
    public void recordError(long runId, String jobName, String stepName,
                            String sourceEntity, String sourceRecordId,
                            String errorCode, String errorMessage,
                            String payloadExcerpt) {
        String sql =
            "INSERT INTO ETL_RECORD_ERROR " +
            "(RUN_ID, JOB_NAME, STEP_NAME, SOURCE_ENTITY, SOURCE_RECORD_ID, " +
            " ERROR_CODE, ERROR_MESSAGE, PAYLOAD_EXCERPT, IS_RETRYABLE) " +
            "VALUES (?, ?, ?, ?, ?, ?, ?, ?, 0)";
        // Truncate to column limits
        jdbc.update(sql,
                runId,
                truncate(jobName, 100),
                truncate(stepName, 100),
                truncate(sourceEntity, 100),
                truncate(sourceRecordId, 100),
                truncate(errorCode, 50),
                truncate(errorMessage, 1000),
                truncate(payloadExcerpt, 2000));
        log.debug("Rejection logged: runId={}, entity={}, recordId={}, code={}",
                runId, sourceEntity, sourceRecordId, errorCode);
    }

    public List<Map<String, Object>> findByRunId(long runId, int page, int size) {
        String sql =
            "SELECT ERROR_ID, RUN_ID, JOB_NAME, STEP_NAME, SOURCE_ENTITY, SOURCE_RECORD_ID, " +
            "ERROR_CODE, ERROR_MESSAGE, PAYLOAD_EXCERPT, ERROR_TIMESTAMP " +
            "FROM ETL_RECORD_ERROR WHERE RUN_ID = ? " +
            "ORDER BY ERROR_ID " +
            "OFFSET ? ROWS FETCH NEXT ? ROWS ONLY";
        return jdbc.queryForList(sql, runId, page * size, size);
    }

    public long countByRunId(long runId) {
        Long count = jdbc.queryForObject(
            "SELECT COUNT(1) FROM ETL_RECORD_ERROR WHERE RUN_ID = ?", Long.class, runId);
        return count != null ? count : 0L;
    }

    private static String truncate(String s, int maxLen) {
        if (s == null) return null;
        return s.length() > maxLen ? s.substring(0, maxLen - 3) + "..." : s;
    }
}
