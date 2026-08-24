package com.ibm.cdp.loader.batch.repository;

import lombok.Builder;
import lombok.Data;
import org.springframework.beans.factory.annotation.Qualifier;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Repository;
import org.springframework.transaction.annotation.Transactional;

import java.math.BigDecimal;
import java.time.Instant;
import java.util.List;

/**
 * Repository for ETL_RECONCILIATION — source-to-target count and aggregate comparison.
 */
@Repository
public class EtlReconciliationRepository {

    private final JdbcTemplate jdbc;

    public EtlReconciliationRepository(@Qualifier("oracleJdbcTemplate") JdbcTemplate jdbc) {
        this.jdbc = jdbc;
    }

    @Transactional("oracleTransactionManager")
    public void insertRecon(long runId, String jobType, String entityName,
                            String metric, BigDecimal sourceVal, BigDecimal targetVal,
                            BigDecimal tolerancePct, String notes) {
        BigDecimal variance = sourceVal != null && targetVal != null
                ? sourceVal.subtract(targetVal) : null;
        BigDecimal variancePct = variance != null && sourceVal != null
                && sourceVal.compareTo(BigDecimal.ZERO) != 0
                ? variance.abs().divide(sourceVal, 6, java.math.RoundingMode.HALF_UP)
                          .multiply(BigDecimal.valueOf(100))
                : BigDecimal.ZERO;

        String status = "PASS";
        if (variance != null && tolerancePct != null) {
            if (variancePct.compareTo(tolerancePct) > 0) {
                status = "FAIL";
            }
        }

        String sql =
            "INSERT INTO ETL_RECONCILIATION " +
            "(RUN_ID, JOB_TYPE, ENTITY_NAME, RECON_METRIC, SOURCE_VALUE, TARGET_VALUE, " +
            " VARIANCE, VARIANCE_PCT, TOLERANCE_PCT, STATUS, NOTES) " +
            "VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)";

        jdbc.update(sql, runId, jobType, entityName, metric,
                sourceVal, targetVal, variance, variancePct, tolerancePct, status, notes);
    }

    public List<ReconSummary> findLatestByJobType(String jobType) {
        String sql =
            "SELECT r.RECON_ID, r.RUN_ID, r.JOB_TYPE, r.ENTITY_NAME, r.RECON_METRIC, " +
            "r.SOURCE_VALUE, r.TARGET_VALUE, r.VARIANCE, r.VARIANCE_PCT, r.STATUS, r.NOTES, " +
            "r.RECON_TIMESTAMP " +
            "FROM ETL_RECONCILIATION r " +
            "JOIN (SELECT MAX(RUN_ID) AS LATEST_RUN_ID FROM ETL_JOB_RUN WHERE JOB_TYPE = ? AND STATUS = 'COMPLETED') lj " +
            "  ON r.RUN_ID = lj.LATEST_RUN_ID " +
            "ORDER BY r.ENTITY_NAME, r.RECON_METRIC";
        return jdbc.query(sql, (rs, n) -> ReconSummary.builder()
                .reconId(rs.getLong("RECON_ID"))
                .runId(rs.getLong("RUN_ID"))
                .jobType(rs.getString("JOB_TYPE"))
                .entityName(rs.getString("ENTITY_NAME"))
                .reconMetric(rs.getString("RECON_METRIC"))
                .sourceValue(rs.getBigDecimal("SOURCE_VALUE"))
                .targetValue(rs.getBigDecimal("TARGET_VALUE"))
                .variance(rs.getBigDecimal("VARIANCE"))
                .variancePct(rs.getBigDecimal("VARIANCE_PCT"))
                .status(rs.getString("STATUS"))
                .notes(rs.getString("NOTES"))
                .reconTimestamp(rs.getTimestamp("RECON_TIMESTAMP") != null ?
                        rs.getTimestamp("RECON_TIMESTAMP").toInstant() : null)
                .build(), jobType);
    }

    @Data @Builder
    public static class ReconSummary {
        private long reconId;
        private long runId;
        private String jobType;
        private String entityName;
        private String reconMetric;
        private BigDecimal sourceValue;
        private BigDecimal targetValue;
        private BigDecimal variance;
        private BigDecimal variancePct;
        private String status;
        private String notes;
        private Instant reconTimestamp;
    }
}
