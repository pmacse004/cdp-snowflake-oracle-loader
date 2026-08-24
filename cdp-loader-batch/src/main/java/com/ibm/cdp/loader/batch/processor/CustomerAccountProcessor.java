package com.ibm.cdp.loader.batch.processor;

import com.ibm.cdp.loader.batch.repository.EtlRecordErrorRepository;
import com.ibm.cdp.loader.core.exception.RecordValidationException;
import com.ibm.cdp.loader.core.model.CustomerAccountRecord;
import com.ibm.cdp.loader.core.validation.CustomerAccountValidator;
import com.ibm.cdp.loader.core.validation.ValidationResult;
import lombok.extern.slf4j.Slf4j;
import org.springframework.batch.core.configuration.annotation.StepScope;
import org.springframework.batch.item.ItemProcessor;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Component;

/**
 * Transforms and validates a {@link CustomerAccountRecord} before Oracle write.
 *
 * <h2>ICA soft-delete rule — CLOSED accounts</h2>
 * Source {@code ACCOUNT_STATUS='CLOSED'} is translated to the target inactive
 * representation before validation:
 * <ul>
 *   <li>{@code accountStatus} is set to {@code "INACTIVE"} so the target column
 *       receives a valid canonical value.</li>
 *   <li>{@code IS_ACTIVE} is consequently written as {@code 0} by
 *       {@link com.ibm.cdp.loader.batch.writer.CustomerAccountWriter} because the
 *       writer already maps any non-ACTIVE status to 0.</li>
 * </ul>
 * The source status meaning is preserved through the standard CLOSE_DATE field
 * that the reader populates independently.
 *
 * <p>All other unrecognised statuses are still rejected and written to
 * ETL_RECORD_ERROR.
 *
 * <p>Declared {@code @StepScope} so that {@code etlRunId} is resolved from
 * {@code JobParameters} at step-execution time.
 */
@Slf4j
@Component
@StepScope
public class CustomerAccountProcessor implements ItemProcessor<CustomerAccountRecord, CustomerAccountRecord> {

    private static final CustomerAccountValidator VALIDATOR = new CustomerAccountValidator();

    private final long etlRunId;
    private final String jobName;
    private final String stepName;
    private final EtlRecordErrorRepository errorRepo;

    public CustomerAccountProcessor(
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
    public CustomerAccountRecord process(CustomerAccountRecord item) {
        // ICA soft-delete: CLOSED → INACTIVE before validation so the record
        // is loaded with IS_ACTIVE=0 rather than rejected.
        if ("CLOSED".equals(item.getAccountStatus())) {
            log.debug("Account {}: translating CLOSED → INACTIVE (ICA soft-delete rule)",
                    item.getEnergyAccountId());
            item.setAccountStatus("INACTIVE");
        }

        ValidationResult result = VALIDATOR.validate(item);
        if (!result.isValid()) {
            String id = item.getEnergyAccountId() != null ? item.getEnergyAccountId() : "UNKNOWN";
            log.warn("Account validation failed: {} — {}", id, result);
            try {
                errorRepo.recordError(
                    etlRunId, jobName, stepName,
                    "VW_DAILY_CUSTOMER_ACCOUNT_EXPORT", id,
                    result.getErrorCode(), result.getErrorMessage(),
                    "ENERGY_ACCOUNT_ID=" + id);
            } catch (Exception ex) {
                log.error("Failed to record error for account {}: {}", id, ex.getMessage(), ex);
            }
            throw new RecordValidationException(result.getErrorCode(), result.getErrorMessage(), id);
        }
        return item;
    }
}
