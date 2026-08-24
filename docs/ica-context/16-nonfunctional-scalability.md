# ICA Context Document 16 — Non-Functional and Scalability Requirements

**ICA Document ID:** ICA-16  
**Project:** CDP Snowflake to Oracle Data Loader  
**Version:** 1.0  
**Status:** Phase 1 — Approved  
**Last Updated:** 2025 (Phase 1)

---

## 1. Purpose

This document complements the formal NFRs in `docs/requirements/non-functional-requirements.md` with ICA-specific context for scalability design patterns, performance targets and migration pathways.

---

## 2. Volume Targets

| Entity | Demo volume | Scale-up target | Notes |
|--------|------------|----------------|-------|
| CUSTOMER | ~10,000 | ~1,000,000 | No redesign needed |
| CUSTOMER_CONTACT | ~12,000 | ~1,200,000 | |
| ENERGY_ACCOUNT | ~11,000 | ~1,100,000 | |
| BILLING_ACCOUNT | ~11,000 | ~1,100,000 | |
| SERVICE_PREMISE | ~11,000 | ~1,100,000 | |
| METER | ~11,500 | ~1,150,000 | |
| MONTHLY_USAGE | ~110,000 (12 months) | ~12,000,000 | Partition by BILLING_MONTH |

---

## 3. Scalability Design Patterns

### 3.1 Configurable Chunk Size

```yaml
etl:
  chunk-size: 500           # rows per JDBC fetch and per Oracle commit
  fetch-size: 500           # JDBC ResultSet fetch size
  fatal-error-threshold-percent: 5
  writer-threads: 1         # increase for parallel writers in scale-up
```

Increasing chunk size improves throughput at the cost of memory and transaction size. The default 500 balances both.

### 3.2 Oracle Partitioning (Scale-Up Path)

For the 1M-customer target, `MONTHLY_USAGE` should be range-partitioned on `BILLING_MONTH`:

```sql
-- Phase 7 (scale-up) — NOT Phase 1 DDL
PARTITION BY RANGE (BILLING_MONTH) INTERVAL ('0001-00') (
  PARTITION p_2024_01 VALUES LESS THAN ('2024-02')
)
```

The `BILLING_MONTH VARCHAR2(7)` column and existing index `IDX_MU_MONTH` ensure this is a zero-code-change migration.

### 3.3 Snowflake Pagination

For 1M-record extraction:
- Use Snowflake JDBC cursor-based streaming (`setFetchSize()` on PreparedStatement).
- Do NOT load full result sets into memory.
- Spring Batch `JdbcPagingItemReader` with `LIMIT` + `OFFSET` or keyset pagination via the composite watermark key.

### 3.4 FK Cache Strategy

For 1M customers, the FK cache holds ~1M `(sourceId, targetId)` Long pairs:
- Two longs = 16 bytes per entry
- 1M entries ≈ 16 MB — well within the 2 GB heap target
- No redesign needed at scale

For 10M+ customers (beyond current scope), replace in-memory cache with a staging table.

---

## 4. Performance Requirements

| Metric | Demo Target | Scale-Up Target |
|--------|------------|----------------|
| Initial load throughput | ≥ 5,000 records/minute | ≥ 50,000 records/minute (adjust chunk/parallelism) |
| Daily incremental (1K records) | ≤ 5 minutes | ≤ 30 minutes for 100K changes |
| Monthly usage (1K records) | ≤ 3 minutes | ≤ 10 minutes for 100K records |
| Heap usage | ≤ 2 GB | ≤ 4 GB with 1M FK cache |
| REST API p95 latency | ≤ 500 ms | ≤ 500 ms |

---

## 5. Open Liberty Migration Path

The application is designed to deploy to Open Liberty with the following changes only:

| Change | Effort |
|--------|--------|
| Add `SpringBootServletInitializer` subclass | ~5 min |
| Switch Maven packaging to `war` | ~5 min |
| Add `server.xml` with springBoot-3.0 and servlet-6.0 features | ~30 min |
| Replace `spring.port` with Open Liberty `httpEndpoint` | ~10 min |
| Remove embedded Tomcat exclusion from pom.xml (if needed) | ~10 min |

No Java application code changes are required. Spring Batch, Oracle JDBC, Snowflake JDBC, Spring Security and Flyway all work identically on Open Liberty.

---

## 6. Technology Compatibility Matrix

| Component | Spring Boot standalone | Open Liberty |
|-----------|----------------------|-------------|
| Spring Batch 5.x | ✅ Native | ✅ springBoot-3.0 feature |
| Flyway 10.x | ✅ Auto-runs at startup | ✅ Same (Spring context) |
| Oracle JDBC 23c | ✅ | ✅ |
| Snowflake JDBC 3.x | ✅ | ✅ |
| Spring Actuator | ✅ /actuator/* | ✅ (same endpoints) |
| Spring Security | ✅ | ✅ |
| React static assets | ✅ src/main/resources/static | ✅ Same |

---

## 7. Horizontal Scale Notes

For volumes beyond 1M customers (out of current scope):

| Component | Scale-up approach |
|-----------|------------------|
| Snowflake extraction | Parallel warehouse queries via Spring Batch Partitioner |
| Oracle writes | Parallel Spring Batch Partitioner with multiple DataSources |
| FK cache | Oracle staging table instead of in-memory |
| Scheduling | Quartz clustered job scheduler |
| Observability | Prometheus + Grafana metrics |

These changes are explicitly deferred and do not affect Phase 1–7 design.

---

## 8. Technology Decisions That Enable Scale-Up

| Decision | Scale benefit |
|----------|--------------|
| Composite watermark (UPDATED_AT + SOURCE_ID) | No re-processing on restart |
| Oracle MERGE for all writes | Idempotent bulk operations |
| Configurable chunk size | Tune for throughput vs. memory |
| BigDecimal for all financials | No precision loss at any volume |
| Oracle NUMBER(18,6) | Handles all foreseeable precision |
| VARCHAR2 BILLING_MONTH | Simple partition key |
| SOURCE_*_ID unique constraints | Prevents duplicates regardless of volume |

---

## 9. Restraint Decisions (What Was NOT Added)

The following were considered and explicitly rejected for this project:

| Technology | Reason not used |
|-----------|----------------|
| Apache Kafka | Not needed for batch ETL; adds significant operational complexity |
| Apache Spark | Volume does not require distributed processing |
| Kubernetes | Not required for standalone demo; adds deployment complexity |
| Redis cache | FK cache in JVM memory is sufficient for demo volume |
| External scheduler (Airflow) | Spring Scheduler is sufficient; reduces external dependencies |
| Debezium CDC | Change Data Capture is powerful but complex; watermark-based polling is sufficient |

These restraints are intentional. The design can adopt any of these if requirements change, without changing the core data model or mapping catalogue.
