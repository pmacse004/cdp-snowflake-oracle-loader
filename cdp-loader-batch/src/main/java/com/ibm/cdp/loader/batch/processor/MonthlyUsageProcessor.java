package com.ibm.cdp.loader.batch.processor;

import com.ibm.cdp.loader.batch.repository.EtlRecordErrorRepository;
import com.ibm.cdp.loader.core.exception.RecordValidationException;
import com.ibm.cdp.loader.core.model.MonthlyUsageRecord;
import com.ibm.cdp.loader.core.validation.MonthlyUsageValidator;
import com.ibm.cdp.loader.core.validation.ValidationResult;
import lombok.extern.slf4j.Slf4j;
import org.springframework.batch.core.configuration.annotation.StepScope;
import org.springframework.batch.item.ItemProcessor;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Component;

/**
 * Validates {@link MonthlyUsageRecord}.
 *
 * <p>The two intentionally invalid records (USG-INVK-* with negative KW,
 * USG-INVD-* with bill end before start) are rejected here and written to
 * ETL_RECORD_ERROR. Processing continues for all other records.
 *
 * <p>Declared {@code @StepScope} so that {@code etlRunId} is resolved from
 * {@code JobParameters} at step-execution time.
 */
@Slf4j
@Component
@StepScope
public class MonthlyUsageProcessor implements ItemProcessor<MonthlyUsageRecord, MonthlyUsageRecord> {

    private static final MonthlyUsageValidator VALIDATOR = new MonthlyUsageValidator();

    private final long etlRunId;
    private final String jobName;
    private final String stepName;
    private final EtlRecordErrorRepository errorRepo;

    public MonthlyUsageProcessor(
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
    public MonthlyUsageRecord process(MonthlyUsageRecord item) {
        ValidationResult result = VALIDATOR.validate(item);
        if (!result.isValid()) {
            String id = item.getUsageId() != null ? item.getUsageId() : "UNKNOWN";
            log.warn("Usage validation failed: {} — {}", id, result);
            try {
                errorRepo.recordError(
                    etlRunId, jobName, stepName,
                    "VW_MONTHLY_USAGE_BILLING_EXPORT", id,
                    result.getErrorCode(), result.getErrorMessage(),
                    "USAGE_ID=" + id + " EA=" + item.getEnergyAccountId());
            } catch (Exception ex) {
                log.error("Failed to record error for usage {}: {}", id, ex.getMessage(), ex);
            }
            throw new RecordValidationException(result.getErrorCode(), result.getErrorMessage(), id);
        }
        return item;
    }
}
