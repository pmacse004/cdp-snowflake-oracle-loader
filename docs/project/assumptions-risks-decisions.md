# Assumptions, Risks and Unresolved Decisions

**Document ID:** PROJ-003  
**Project:** CDP Snowflake to Oracle Data Loader  
**Version:** 1.0  
**Status:** Phase 1 — Approved  
**Last Updated:** 2025 (Phase 1)

---

## 1. Assumptions

| ID | Assumption | Impact if Wrong | Owner |
|----|-----------|-----------------|-------|
| A-01 | Snowflake account `LJPNAFI-RW79936` (locator `BM00315`, Azure Central India) is accessible from the Windows development machine over the internet. | Snowflake connection in Phase 2 will fail. Will need to check network policies or VPN requirements. | Engineer |
| A-02 | The Snowflake account has sufficient credits to run a dedicated X-Small warehouse for ETL workloads during development. | ETL extraction may be slow or fail on warehouse timeout. May need to share COMPUTE_WH temporarily. | Account Admin |
| A-03 | Docker Desktop is installed and running on the Windows dev machine, with sufficient resources to run Oracle Database Free 23c (requires ~4 GB RAM, ~20 GB disk). | Oracle cannot run locally; would need a remote Oracle instance. | Engineer |
| A-04 | Oracle Database Free 23c container is available from `container-registry.oracle.com` and can be pulled on the dev network. | Alternative: use Oracle XE or download manually. | Engineer |
| A-05 | A dedicated Snowflake service user (`SVC_CDP_LOADER`) with key-pair authentication will be created by the Snowflake administrator in Phase 2. | ETL cannot connect without a service user. | Account Admin |
| A-06 | The Snowflake human administrator has SYSADMIN or ACCOUNTADMIN privileges to create warehouses, databases, schemas, roles and users. | Provisioning scripts in Phase 2 will fail. | Account Admin |
| A-07 | The developer's machine has Java 17 JDK, Maven 3.9, Node.js 20 and PowerShell 7 installed or readily installable. | Build steps in Phase 2 will fail. | Engineer |
| A-08 | All source and target data used in this project is synthetic; no real utility customer data will be used. | Privacy and legal compliance issues if violated. | All |
| A-09 | IBM Consulting Advantage (ICA) Context Studio is accessible by Bob through MCP during development governance reviews. ICA is not a runtime dependency for the application. | ICA governance integration is documentation-only; no impact on application behaviour. | Architect |
| A-10 | The React dashboard will be used on 1280px+ desktop screens. No mobile optimisation required for this demonstration. | Dashboard may be unusable on small screens. | Architect |
| A-11 | Spring Batch's `@EnableBatchProcessing` auto-configuration in Spring Boot 3.x does not require explicit `JobRepository` bean if Oracle is the primary `DataSource`. | Manual `JobRepository` configuration may be needed. | Engineer |
| A-12 | Flyway 10.x supports Oracle 23c with the Oracle edition (not the community edition). Maven dependency must use `org.flywaydb:flyway-database-oracle`. | Flyway migrations will fail on Oracle. | Engineer |
| A-13 | The BILLING_ACCOUNT_NUMBER column contains sensitive business data but is not legally classified as PII in the US for this synthetic dataset context. | Needs legal/compliance review for real deployment. | Legal/Security |
| A-14 | UTC timestamp storage is acceptable for all operational timestamps. Billing dates use `DATE` type with no time component. | No timezone conversion issues as long as all components produce UTC. | Architect |
| A-15 | The `@Scheduled` cron triggers in Spring Boot are acceptable for this demonstration. Quartz clustering is not needed until multi-instance deployment. | Concurrent job runs possible if multiple app instances run. | Architect |

---

## 2. Risks

| ID | Risk | Likelihood | Impact | Mitigation |
|----|------|-----------|--------|-----------|
| R-01 | Snowflake trial account may expire before Phase 6 testing is complete. | Medium | High | Start Snowflake provisioning early in Phase 2. Consider upgrading to paid trial if needed. |
| R-02 | Oracle Database Free 23c container may have known issues with Spring Batch `BATCH_*` tables (data types or sequence semantics). | Low | Medium | Test Flyway + Spring Batch against Oracle Free early in Phase 2. Fallback: use Oracle XE 21c. |
| R-03 | Snowflake JDBC driver and Oracle JDBC driver may have classpath conflicts in a fat JAR. | Low | Medium | Test with Maven shade plugin or Spring Boot layered JAR. Known good combination exists. |
| R-04 | FK cache for 10,000 customers may exceed JVM heap if child entity counts are much higher than estimated. | Low | Low | Default 2 GB heap is far above estimated 16 MB FK cache. Monitor in Phase 4 load testing. |
| R-05 | The composite watermark `(UPDATED_AT, SOURCE_ID)` assumes SOURCE_ID is monotonically increasing for a given timestamp. If Snowflake re-uses IDs (unlikely for NUMBER sequences), watermark may skip records. | Very Low | High | Verify Snowflake sequence never reuses IDs. Add assertion in Phase 4. |
| R-06 | React Vite build may conflict with Spring Boot static resource serving if build output path is misconfigured. | Low | Low | Standard pattern; document in Phase 5. |
| R-07 | Phase 1 ICA documents are designed documents; actual Snowflake schema may differ from the design once real account is provisioned. | Medium | Medium | Snowflake schema is under our control — we create it in Phase 2 to match these documents. |
| R-08 | The `BILLING_ACCOUNT_NUMBER` handling: treating it as sensitive business data (not PII) may be incorrect in a real deployment context. | Low | Medium | Mitigation: apply PII-level protection to this field by default; review in Phase 7 security hardening. |
| R-09 | Open Liberty migration may reveal a Spring Boot dependency that doesn't work in an application server context. | Low | Medium | Test Open Liberty compatibility in Phase 7. Known issues: embedded Tomcat must be excluded. |
| R-10 | Synthetic data generation may produce edge cases (e.g., duplicate BILLING_MONTH for same account) that expose gaps in correction logic. | Medium | Low | Good: this is the purpose of the demo — test edge cases thoroughly in Phase 6. |

---

## 3. Unresolved Decisions

| ID | Decision | Options | Recommendation | Target Phase |
|----|---------|---------|----------------|-------------|
| UD-01 | How should the DAILY watermark be initialised after the INITIAL load? | Option A: Manually copy INITIAL watermark to DAILY. Option B: An automated post-initial-load step copies the watermark. | Option B (automated Flyway data migration or step listener) | Phase 4 |
| UD-02 | Should the FK cache be pre-loaded from the full target table at step start, or built incrementally during the parent entity step? | Option A: Full table scan at step start. Option B: Build cache during parent load (single pass). | Option A for simplicity; Option B for scale-up | Phase 4 |
| UD-03 | What is the Oracle application user name and password strategy for local development? | Option A: Single `CDP_LOADER_USER` with all schema grants. Option B: One user per schema. | Option A (simpler for demo, change in production) | Phase 2 |
| UD-04 | Should the Flyway migration user be the same as the application user? | Option A: Same user (simpler for demo). Option B: Separate DBA-level migration user. | Option A for demo; Option B for production | Phase 2 |
| UD-05 | Should Spring Batch's `@EnableBatchProcessing` be used or manual `JobRepository` configuration? | Auto-config via Spring Boot 3 is preferred. May need custom `DataSourceTransactionManager` for Oracle. | Decide in Phase 4 based on Spring Boot 3.x Oracle compatibility | Phase 4 |
| UD-06 | Which chart library for the React dashboard — Recharts or Victory? | Recharts (chosen) vs Victory. | Recharts — better React integration, widely used | Phase 5 |
| UD-07 | Should the mapping catalogue be loaded from `mapping-catalogue.yaml` at startup or hardcoded in Java? | Option A: YAML loaded via Spring `@ConfigurationProperties`. Option B: Java constants. | Option A (configurable, ICA-aligned) | Phase 4 |
| UD-08 | How to handle Snowflake warehouse auto-suspend during low-activity periods? | Option A: Keep warehouse always-on. Option B: Auto-suspend 1 minute; wake on connection. | Option B — trial account credits preservation. Accept 20–30 second first-connect delay. | Phase 2 |
| UD-09 | Should the React dashboard be served as Spring Boot static resources (production) or as a separate Nginx/CDN deployment? | Option A: Spring Boot static. Option B: Separate deployment. | Option A for demo; Option B for production | Phase 5 |
| UD-10 | Should error records be writable back to the API for manual reprocessing, or read-only? | Option A: Read-only (Phase 1 design). Option B: Reprocessing endpoint. | Option A for Phase 1–6; add reprocessing in Phase 7 | Phase 7 |

---

## 4. Constraints Confirmed

The following constraints are confirmed and will not be revisited:

- ✅ No Kafka, Spark or Kubernetes in this project
- ✅ No real customer data — all synthetic
- ✅ No passwords or keys in source control
- ✅ UTC for technical timestamps; business dates as DATE
- ✅ BigDecimal / NUMBER for all monetary and usage values
- ✅ MERGE for all Oracle writes (idempotent)
- ✅ ICA is the design-time governance authority; application does not connect to ICA at runtime; no runtime Oracle mapping-config tables unless justified
- ✅ Fat JAR is the sole validated deployment target; Open Liberty requires a compatibility spike in Phase 7
- ✅ Phase 2 does not start without Phase 1 sign-off
