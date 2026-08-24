package com.ibm.cdp.loader.core.validation;

import com.ibm.cdp.loader.core.model.CustomerAccountRecord;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.params.ParameterizedTest;
import org.junit.jupiter.params.provider.ValueSource;

import java.time.LocalDate;

import static org.assertj.core.api.Assertions.assertThat;

/**
 * Unit tests for {@link CustomerAccountValidator}.
 */
class CustomerAccountValidatorTest {

    private final CustomerAccountValidator validator = new CustomerAccountValidator();

    private CustomerAccountRecord valid() {
        CustomerAccountRecord r = new CustomerAccountRecord();
        r.setEnergyAccountId("EA-000001");
        r.setCustomerId("CUST-000001");
        r.setAccountNumber("ACCT-000001");
        r.setAccountStatus("ACTIVE");
        r.setRateClass("RESIDENTIAL");
        r.setOpenDate(LocalDate.of(2020, 1, 1));
        return r;
    }

    @Test
    void valid_record_passes() {
        assertThat(validator.validate(valid()).isValid()).isTrue();
    }

    @Test
    void missing_energy_account_id_fails() {
        CustomerAccountRecord r = valid();
        r.setEnergyAccountId(null);
        ValidationResult result = validator.validate(r);
        assertThat(result.isValid()).isFalse();
        assertThat(result.getErrorCode()).isEqualTo("ACCT_MISSING_ID");
    }

    @Test
    void missing_customer_id_fails() {
        CustomerAccountRecord r = valid();
        r.setCustomerId(null);
        ValidationResult result = validator.validate(r);
        assertThat(result.isValid()).isFalse();
        assertThat(result.getErrorCode()).isEqualTo("ACCT_MISSING_CUST_ID");
    }

    @ParameterizedTest
    @ValueSource(strings = {"ACTIVE", "INACTIVE", "SUSPENDED", "PENDING"})
    void valid_statuses_pass(String status) {
        CustomerAccountRecord r = valid();
        r.setAccountStatus(status);
        assertThat(validator.validate(r).isValid()).isTrue();
    }

    /**
     * INACTIVE must be valid — it is the canonical post-transform value for
     * source CLOSED accounts (translated by CustomerAccountProcessor before
     * validation). The validator must accept it.
     */
    @Test
    void inactive_status_passes_as_post_transform_target_value() {
        CustomerAccountRecord r = valid();
        r.setAccountStatus("INACTIVE");
        assertThat(validator.validate(r).isValid()).isTrue();
    }

    /**
     * The raw source value CLOSED must still be rejected by the validator.
     * CustomerAccountProcessor translates CLOSED→INACTIVE before calling
     * validate(), so the validator must never see CLOSED from a correctly
     * transformed record. This test pins that contract.
     */
    @Test
    void raw_CLOSED_status_fails_at_validator_boundary() {
        CustomerAccountRecord r = valid();
        r.setAccountStatus("CLOSED");
        ValidationResult result = validator.validate(r);
        assertThat(result.isValid()).isFalse();
        assertThat(result.getErrorCode()).isEqualTo("ACCT_INVALID_STATUS");
    }

    @Test
    void invalid_status_fails() {
        CustomerAccountRecord r = valid();
        r.setAccountStatus("CLOSED");
        ValidationResult result = validator.validate(r);
        assertThat(result.isValid()).isFalse();
        assertThat(result.getErrorCode()).isEqualTo("ACCT_INVALID_STATUS");
    }

    @Test
    void missing_open_date_fails() {
        CustomerAccountRecord r = valid();
        r.setOpenDate(null);
        ValidationResult result = validator.validate(r);
        assertThat(result.isValid()).isFalse();
        assertThat(result.getErrorCode()).isEqualTo("ACCT_MISSING_OPEN_DATE");
    }
}
