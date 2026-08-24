package com.ibm.cdp.loader.core.validation;

import com.ibm.cdp.loader.core.model.CustomerAccountRecord;

import java.util.Set;

/**
 * Validates a {@link CustomerAccountRecord} against ICA rules.
 */
public class CustomerAccountValidator {

    private static final Set<String> VALID_STATUSES = Set.of(
            "ACTIVE", "INACTIVE", "SUSPENDED", "PENDING");

    public ValidationResult validate(CustomerAccountRecord r) {
        if (r.getEnergyAccountId() == null || r.getEnergyAccountId().isBlank()) {
            return ValidationResult.fail("ACCT_MISSING_ID", "ENERGY_ACCOUNT_ID is null or blank");
        }
        if (r.getCustomerId() == null || r.getCustomerId().isBlank()) {
            return ValidationResult.fail("ACCT_MISSING_CUST_ID",
                    "CUSTOMER_ID missing for account " + r.getEnergyAccountId());
        }
        if (r.getAccountNumber() == null || r.getAccountNumber().isBlank()) {
            return ValidationResult.fail("ACCT_MISSING_ACCT_NBR",
                    "ACCOUNT_NUMBER missing for account " + r.getEnergyAccountId());
        }
        if (r.getAccountStatus() == null || r.getAccountStatus().isBlank()) {
            return ValidationResult.fail("ACCT_MISSING_STATUS",
                    "ACCOUNT_STATUS missing for account " + r.getEnergyAccountId());
        }
        if (!VALID_STATUSES.contains(r.getAccountStatus())) {
            return ValidationResult.fail("ACCT_INVALID_STATUS",
                    "Invalid ACCOUNT_STATUS '" + r.getAccountStatus() + "' for " + r.getEnergyAccountId());
        }
        if (r.getRateClass() == null || r.getRateClass().isBlank()) {
            return ValidationResult.fail("ACCT_MISSING_RATE_CLASS",
                    "RATE_CLASS missing for account " + r.getEnergyAccountId());
        }
        if (r.getOpenDate() == null) {
            return ValidationResult.fail("ACCT_MISSING_OPEN_DATE",
                    "OPEN_DATE missing for account " + r.getEnergyAccountId());
        }
        return ValidationResult.ok();
    }
}
