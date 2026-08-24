package com.ibm.cdp.loader.batch.repository;

import org.junit.jupiter.api.Test;
import org.springframework.transaction.annotation.Propagation;
import org.springframework.transaction.annotation.Transactional;

import java.lang.reflect.Method;

import static org.assertj.core.api.Assertions.assertThat;

/**
 * Unit tests for {@link EtlRecordErrorRepository} transaction semantics.
 *
 * <p>These tests do NOT require a live database — they verify that the
 * {@code recordError} method is annotated with {@code REQUIRES_NEW} propagation,
 * which is the essential fix for the "totalCount=0" symptom observed in live run 4.
 *
 * <h2>Root cause recap</h2>
 * Spring Batch's chunk-oriented processing opens a transaction with
 * {@code oracleTransactionManager} for each chunk.  When an item throws
 * {@link com.ibm.cdp.loader.core.exception.RecordValidationException} the skip
 * policy catches it, but Spring Batch still rolls back the chunk's transaction
 * before retrying without the bad item.  With the former {@code REQUIRED}
 * propagation on {@code recordError}, the INSERT joined the chunk transaction
 * and was rolled back with it — leaving ETL_RECORD_ERROR empty.
 * {@code REQUIRES_NEW} suspends the chunk transaction, opens a dedicated
 * connection, commits the INSERT independently, then resumes the chunk
 * transaction.
 *
 * <h2>Why annotation-presence proves correctness</h2>
 * The Spring proxy responsible for transaction demarcation reads the
 * {@code @Transactional} metadata at runtime.  If the annotation specifies
 * {@code REQUIRES_NEW}, the AOP interceptor will always open a new transaction
 * irrespective of any surrounding transaction.  This is verifiable from the
 * class bytecode without a live DataSource.
 */
class EtlRecordErrorRepositoryTransactionTest {

    /**
     * {@code recordError} must declare {@code REQUIRES_NEW} so that the
     * INSERT is committed independently of the surrounding chunk transaction.
     */
    @Test
    void recordError_declares_REQUIRES_NEW_propagation() throws NoSuchMethodException {
        Method method = EtlRecordErrorRepository.class.getMethod(
                "recordError",
                long.class, String.class, String.class,
                String.class, String.class,
                String.class, String.class, String.class);

        Transactional txAnn = method.getAnnotation(Transactional.class);
        assertThat(txAnn)
                .as("recordError must be @Transactional")
                .isNotNull();
        assertThat(txAnn.propagation())
                .as("recordError must use REQUIRES_NEW so it commits independently " +
                    "of the chunk transaction — prevents rollback of error rows")
                .isEqualTo(Propagation.REQUIRES_NEW);
    }

    /**
     * The transaction manager qualifier must be {@code oracleTransactionManager}
     * so Spring wires the correct manager (not the default Spring Batch manager
     * which routes to the same datasource but may have different settings).
     */
    @Test
    void recordError_targets_oracle_transaction_manager() throws NoSuchMethodException {
        Method method = EtlRecordErrorRepository.class.getMethod(
                "recordError",
                long.class, String.class, String.class,
                String.class, String.class,
                String.class, String.class, String.class);

        Transactional txAnn = method.getAnnotation(Transactional.class);
        assertThat(txAnn).isNotNull();
        assertThat(txAnn.value())
                .as("Must target the named oracleTransactionManager, not the Spring Batch default")
                .isEqualTo("oracleTransactionManager");
    }
}
