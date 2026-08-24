package com.ibm.cdp.loader.core.validation;

import com.ibm.cdp.loader.core.model.MonthlyUsageRecord;

import java.math.BigDecimal;

/**
 * Validates a {@link MonthlyUsageRecord} against ICA rules.
 *
 * <p>The two intentionally invalid records USG-INVK-* (negative KW) and
 * USG-INVD-* (bill end before start) will be rejected here and logged to
 * ETL_RECORD_ERROR.
 */
public class MonthlyUsageValidator {

    public ValidationResult validate(MonthlyUsageRecord r) {
        if (r.getUsageId() == null || r.getUsageId().isBlank()) {
            return ValidationResult.fail("USG_MISSING_ID", "USAGE_ID is null or blank");
        }
        if (r.getEnergyAccountId() == null || r.getEnergyAccountId().isBlank()) {
            return ValidationResult.fail("USG_MISSING_EA_ID",
                    "ENERGY_ACCOUNT_ID missing for " + r.getUsageId());
        }
        if (r.getMeterId() == null || r.getMeterId().isBlank()) {
            return ValidationResult.fail("USG_MISSING_METER_ID",
                    "METER_ID missing for " + r.getUsageId());
        }
        if (r.getBillingMonth() == null || r.getBillingMonth().isBlank()) {
            return ValidationResult.fail("USG_MISSING_BILLING_MONTH",
                    "BILLING_MONTH missing for " + r.getUsageId());
        }
        if (r.getBillStartDate() == null) {
            return ValidationResult.fail("USG_MISSING_BILL_START",
                    "BILL_START_DATE missing for " + r.getUsageId());
        }
        if (r.getBillEndDate() == null) {
            return ValidationResult.fail("USG_MISSING_BILL_END",
                    "BILL_END_DATE missing for " + r.getUsageId());
        }
        // ICA: bill end must not be before bill start
        if (r.getBillEndDate().isBefore(r.getBillStartDate())) {
            return ValidationResult.fail("USG_BILL_DATE_INVALID",
                    "BILL_END_DATE " + r.getBillEndDate() + " before BILL_START_DATE "
                            + r.getBillStartDate() + " for " + r.getUsageId());
        }
        if (r.getBillingDays() == null || r.getBillingDays() <= 0) {
            return ValidationResult.fail("USG_INVALID_BILLING_DAYS",
                    "BILLING_DAYS must be > 0 for " + r.getUsageId());
        }
        if (r.getKwhUsage() == null) {
            return ValidationResult.fail("USG_MISSING_KWH",
                    "KWH_USAGE missing for " + r.getUsageId());
        }
        // ICA: negative KWH is invalid (rejects USG-INVK-* records)
        if (r.getKwhUsage().compareTo(BigDecimal.ZERO) < 0) {
            return ValidationResult.fail("USG_NEGATIVE_KWH",
                    "KWH_USAGE " + r.getKwhUsage() + " is negative for " + r.getUsageId());
        }
        // ICA: negative KW is invalid where present (rejects USG-INVK-* records)
        if (r.getPeakDemandKw() != null && r.getPeakDemandKw().compareTo(BigDecimal.ZERO) < 0) {
            return ValidationResult.fail("USG_NEGATIVE_KW",
                    "PEAK_DEMAND_KW " + r.getPeakDemandKw() + " is negative for " + r.getUsageId());
        }
        if (r.getRatePlan() == null || r.getRatePlan().isBlank()) {
            return ValidationResult.fail("USG_MISSING_RATE_PLAN",
                    "RATE_PLAN missing for " + r.getUsageId());
        }
        // ICA: missing FIXED_RATE means we cannot compute charges — reject
        if (r.getFixedRate() == null) {
            return ValidationResult.fail("USG_MISSING_FIXED_RATE",
                    "FIXED_RATE null (unknown rate plan?) for " + r.getUsageId());
        }
        if (r.getEnergyRatePerKwh() == null) {
            return ValidationResult.fail("USG_MISSING_ENERGY_RATE",
                    "ENERGY_RATE_PER_KWH null for " + r.getUsageId());
        }
        // Computed charges must not be null if rates are present
        if (r.getCalcTotalBilled() == null) {
            return ValidationResult.fail("USG_NULL_TOTAL_BILLED",
                    "CALC_TOTAL_BILLED is null for " + r.getUsageId());
        }
        if (r.getCalcTotalBilled().compareTo(BigDecimal.ZERO) < 0) {
            return ValidationResult.fail("USG_NEGATIVE_TOTAL_BILLED",
                    "CALC_TOTAL_BILLED " + r.getCalcTotalBilled() + " is negative for " + r.getUsageId());
        }
        return ValidationResult.ok();
    }
}
