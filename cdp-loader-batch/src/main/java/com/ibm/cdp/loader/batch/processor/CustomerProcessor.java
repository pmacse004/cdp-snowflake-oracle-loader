package com.ibm.cdp.loader.batch.processor;

import com.ibm.cdp.loader.batch.repository.EtlRecordErrorRepository;
import com.ibm.cdp.loader.core.exception.RecordValidationException;
import com.ibm.cdp.loader.core.model.CustomerRecord;
import com.ibm.cdp.loader.core.validation.CustomerValidator;
import com.ibm.cdp.loader.core.validation.ValidationResult;
import lombok.extern.slf4j.Slf4j;
import org.springframework.batch.core.configuration.annotation.StepScope;
import org.springframework.batch.item.ItemProcessor;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Component;

/**
 * Validates a {@link CustomerRecord} and throws {@link RecordValidationException}
 * for invalid records. Spring Batch skip policy catches this and routes to ETL_RECORD_ERROR.
 *
 * <p>Declared {@code @StepScope} so that {@code etlRunId} is resolved from
 * {@code JobParameters} at step-execution time — not at context startup when the
 * real ETL_JOB_RUN.RUN_ID does not yet exist.
 *
 * <p>{@code recordError} failures are swallowed so a transient DB error
 * during error recording cannot replace the real {@link RecordValidationException}
 * or cause the chunk transaction to roll back.
 */
@Slf4j
@Component
@StepScope
public class CustomerProcessor implements ItemProcessor<CustomerRecord, CustomerRecord> {

    private static final CustomerValidator VALIDATOR = new CustomerValidator();

    private final long etlRunId;
    private final String jobName;
    private final String stepName;
    private final EtlRecordErrorRepository errorRepo;

    public CustomerProcessor(
            @Value("#{jobParameters['etlRunId']}") Long etlRunId,
            @Value("#{stepExecution.jobExecution.jobInstance.jobName}") String jobName,
            @Value("#{stepExecution.stepName}") String stepName,
            EtlRecordErrorRepository errorRepo) {
        this.etlRunId  = etlRunId != null ? etlRunId : 0L;
        this.jobName   = jobName;
        this.stepName  = stepName;
        this.errorRepo = errorRepo;
    }

    @Override
    public CustomerRecord process(CustomerRecord item) {
        ValidationResult result = VALIDATOR.validate(item);
        if (!result.isValid()) {
            String id = item.getCustomerId() != null ? item.getCustomerId() : "UNKNOWN";
            log.warn("Customer validation failed: {} — {}", id, result);
            try {
                errorRepo.recordError(
                    etlRunId, jobName, stepName,
                    "VW_DAILY_CUSTOMER_EXPORT", id,
                    result.getErrorCode(), result.getErrorMessage(),
                    "CUSTOMER_ID=" + id);
            } catch (Exception ex) {
                log.error("Failed to record error for customer {}: {}", id, ex.getMessage(), ex);
            }
            throw new RecordValidationException(result.getErrorCode(), result.getErrorMessage(), id);
        }
        return item;
    }
}
