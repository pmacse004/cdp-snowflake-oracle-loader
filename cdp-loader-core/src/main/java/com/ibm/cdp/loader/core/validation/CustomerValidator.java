package com.ibm.cdp.loader.core.validation;

import com.ibm.cdp.loader.core.model.CustomerRecord;

import java.util.Set;

/**
 * Validates a {@link CustomerRecord} against ICA rules.
 * Stateless — safe to use as a Spring singleton.
 */
public class CustomerValidator {

    // ICA VR-CUST-006 / GL-003 / TR-05: post-translation canonical values.
    // CLOSED  — CLO/CLOSED translated by TR-05; valid per VR-CUST-006.
    // SUSPENDED is not a canonical ICA target value — removed.
    private static final Set<String> VALID_STATUSES = Set.of(
            "ACTIVE", "INACTIVE", "PENDING", "CLOSED");

    private static final Set<String> VALID_TYPES = Set.of(
            "RESIDENTIAL", "COMMERCIAL", "INDUSTRIAL");

    public ValidationResult validate(CustomerRecord r) {
        if (r.getCustomerId() == null || r.getCustomerId().isBlank()) {
            return ValidationResult.fail("CUST_MISSING_ID", "CUSTOMER_ID is null or blank");
        }
        if (r.getFirstName() == null || r.getFirstName().isBlank()) {
            return ValidationResult.fail("CUST_MISSING_FIRSTNAME", "FIRST_NAME missing for " + r.getCustomerId());
        }
        if (r.getLastName() == null || r.getLastName().isBlank()) {
            return ValidationResult.fail("CUST_MISSING_LASTNAME", "LAST_NAME missing for " + r.getCustomerId());
        }
        if (r.getFullNameNormalized() == null || r.getFullNameNormalized().isBlank()) {
            return ValidationResult.fail("CUST_MISSING_FULLNAME", "FULL_NAME_NORMALIZED missing for " + r.getCustomerId());
        }
        if (r.getCustomerStatus() == null || r.getCustomerStatus().isBlank()) {
            return ValidationResult.fail("CUST_MISSING_STATUS", "CUSTOMER_STATUS missing for " + r.getCustomerId());
        }
        if (!VALID_STATUSES.contains(r.getCustomerStatus())) {
            return ValidationResult.fail("CUST_INVALID_STATUS",
                    "Invalid CUSTOMER_STATUS '" + r.getCustomerStatus() + "' for " + r.getCustomerId());
        }
        if (r.getCustomerType() == null || r.getCustomerType().isBlank()) {
            return ValidationResult.fail("CUST_MISSING_TYPE", "CUSTOMER_TYPE missing for " + r.getCustomerId());
        }
        if (!VALID_TYPES.contains(r.getCustomerType())) {
            return ValidationResult.fail("CUST_INVALID_TYPE",
                    "Invalid CUSTOMER_TYPE '" + r.getCustomerType() + "' for " + r.getCustomerId());
        }
        return ValidationResult.ok();
    }
}
