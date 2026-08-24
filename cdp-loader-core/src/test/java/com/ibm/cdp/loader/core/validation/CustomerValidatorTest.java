package com.ibm.cdp.loader.core.validation;

import com.ibm.cdp.loader.core.model.CustomerRecord;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.params.ParameterizedTest;
import org.junit.jupiter.params.provider.ValueSource;

import static org.assertj.core.api.Assertions.assertThat;

/**
 * Unit tests for {@link CustomerValidator}.
 * No Spring context, no database connections.
 */
class CustomerValidatorTest {

    private final CustomerValidator validator = new CustomerValidator();

    private CustomerRecord validRecord() {
        CustomerRecord r = new CustomerRecord();
        r.setCustomerId("CUST-000001");
        r.setFirstName("John");
        r.setLastName("Smith");
        r.setFullNameNormalized("JOHN SMITH");
        r.setCustomerType("RESIDENTIAL");
        r.setCustomerStatus("ACTIVE");
        return r;
    }

    @Test
    void valid_record_passes() {
        assertThat(validator.validate(validRecord()).isValid()).isTrue();
    }

    @Test
    void missing_customer_id_fails() {
        CustomerRecord r = validRecord();
        r.setCustomerId(null);
        ValidationResult result = validator.validate(r);
        assertThat(result.isValid()).isFalse();
        assertThat(result.getErrorCode()).isEqualTo("CUST_MISSING_ID");
    }

    @Test
    void blank_customer_id_fails() {
        CustomerRecord r = validRecord();
        r.setCustomerId("   ");
        ValidationResult result = validator.validate(r);
        assertThat(result.isValid()).isFalse();
        assertThat(result.getErrorCode()).isEqualTo("CUST_MISSING_ID");
    }

    @Test
    void missing_first_name_fails() {
        CustomerRecord r = validRecord();
        r.setFirstName(null);
        ValidationResult result = validator.validate(r);
        assertThat(result.isValid()).isFalse();
        assertThat(result.getErrorCode()).isEqualTo("CUST_MISSING_FIRSTNAME");
    }

    @Test
    void missing_last_name_fails() {
        CustomerRecord r = validRecord();
        r.setLastName("");
        ValidationResult result = validator.validate(r);
        assertThat(result.isValid()).isFalse();
        assertThat(result.getErrorCode()).isEqualTo("CUST_MISSING_LASTNAME");
    }

    // UNKNOWN, DELETED, SUSPENDED are not ICA canonical values — rejected
    @ParameterizedTest
    @ValueSource(strings = {"UNKNOWN", "DELETED", "SUSPENDED", "", "active"})
    void invalid_status_fails(String status) {
        CustomerRecord r = validRecord();
        r.setCustomerStatus(status);
        ValidationResult result = validator.validate(r);
        if (status.isBlank()) {
            assertThat(result.getErrorCode()).isEqualTo("CUST_MISSING_STATUS");
        } else {
            assertThat(result.getErrorCode()).isEqualTo("CUST_INVALID_STATUS");
        }
    }

    // ICA VR-CUST-006 / TR-05: CLOSED (CLO/CLOSED from source) is a valid canonical value
    @ParameterizedTest
    @ValueSource(strings = {"ACTIVE", "INACTIVE", "PENDING", "CLOSED"})
    void valid_statuses_pass(String status) {
        CustomerRecord r = validRecord();
        r.setCustomerStatus(status);
        assertThat(validator.validate(r).isValid()).isTrue();
    }

    @ParameterizedTest
    @ValueSource(strings = {"RESIDENTIAL", "COMMERCIAL", "INDUSTRIAL"})
    void valid_customer_types_pass(String type) {
        CustomerRecord r = validRecord();
        r.setCustomerType(type);
        assertThat(validator.validate(r).isValid()).isTrue();
    }

    @Test
    void invalid_customer_type_fails() {
        CustomerRecord r = validRecord();
        r.setCustomerType("GOVERNMENT");
        ValidationResult result = validator.validate(r);
        assertThat(result.isValid()).isFalse();
        assertThat(result.getErrorCode()).isEqualTo("CUST_INVALID_TYPE");
    }
}
