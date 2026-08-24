package com.ibm.cdp.loader.core.validation;

import com.ibm.cdp.loader.core.model.MonthlyUsageRecord;
import org.junit.jupiter.api.Test;

import java.math.BigDecimal;
import java.time.LocalDate;

import static org.assertj.core.api.Assertions.assertThat;

/**
 * Unit tests for {@link MonthlyUsageValidator}.
 *
 * Includes tests that verify the two intentionally invalid record patterns
 * (USG-INVK-* negative KW, USG-INVD-* bill end before start) are correctly rejected.
 */
class MonthlyUsageValidatorTest {

    private final MonthlyUsageValidator validator = new MonthlyUsageValidator();

    private MonthlyUsageRecord valid() {
        MonthlyUsageRecord r = new MonthlyUsageRecord();
        r.setUsageId("USG-2024-06-EA000001");
        r.setEnergyAccountId("EA-000001");
        r.setPremiseId("PREM-000001");
        r.setMeterId("MTR-000001");
        r.setBillingMonth("2024-06");
        r.setBillStartDate(LocalDate.of(2024, 6, 1));
        r.setBillEndDate(LocalDate.of(2024, 6, 30));
        r.setBillingDays(30);
        r.setKwhUsage(new BigDecimal("500.000"));
        r.setKwhEffective(new BigDecimal("500.000"));
        r.setPeakDemandKw(new BigDecimal("5.0"));
        r.setReadType("ACTUAL");
        r.setRatePlan("RES-STD");
        r.setFixedRate(new BigDecimal("8.50"));
        r.setEnergyRatePerKwh(new BigDecimal("0.115000"));
        r.setCalcFixedCharge(new BigDecimal("8.50"));
        r.setCalcEnergyCharge(new BigDecimal("57.50"));
        r.setCalcDemandCharge(new BigDecimal("0.00"));
        r.setCalcSubtotal(new BigDecimal("66.00"));
        r.setCalcTaxAmount(new BigDecimal("5.28"));
        r.setCalcTotalBilled(new BigDecimal("71.28"));
        r.setUsageQualityStatus("ACTUAL");
        r.setIsCorrection(false);
        return r;
    }

    @Test
    void valid_record_passes() {
        assertThat(validator.validate(valid()).isValid()).isTrue();
    }

    @Test
    void missing_usage_id_fails() {
        MonthlyUsageRecord r = valid();
        r.setUsageId(null);
        ValidationResult result = validator.validate(r);
        assertThat(result.isValid()).isFalse();
        assertThat(result.getErrorCode()).isEqualTo("USG_MISSING_ID");
    }

    @Test
    void missing_energy_account_id_fails() {
        MonthlyUsageRecord r = valid();
        r.setEnergyAccountId(null);
        ValidationResult result = validator.validate(r);
        assertThat(result.isValid()).isFalse();
        assertThat(result.getErrorCode()).isEqualTo("USG_MISSING_EA_ID");
    }

    /**
     * USG-INVK-* pattern: negative PEAK_DEMAND_KW must be rejected.
     */
    @Test
    void negative_peak_demand_kw_rejected_like_USG_INVK() {
        MonthlyUsageRecord r = valid();
        r.setUsageId("USG-INVK-EA000001");
        r.setPeakDemandKw(new BigDecimal("-5.0"));
        ValidationResult result = validator.validate(r);
        assertThat(result.isValid()).isFalse();
        assertThat(result.getErrorCode()).isEqualTo("USG_NEGATIVE_KW");
    }

    /**
     * USG-INVD-* pattern: bill end before bill start must be rejected.
     */
    @Test
    void bill_end_before_start_rejected_like_USG_INVD() {
        MonthlyUsageRecord r = valid();
        r.setUsageId("USG-INVD-EA000001");
        r.setBillStartDate(LocalDate.of(2024, 6, 30));
        r.setBillEndDate(LocalDate.of(2024, 6, 1));   // BEFORE start
        ValidationResult result = validator.validate(r);
        assertThat(result.isValid()).isFalse();
        assertThat(result.getErrorCode()).isEqualTo("USG_BILL_DATE_INVALID");
    }

    @Test
    void negative_kwh_rejected() {
        MonthlyUsageRecord r = valid();
        r.setKwhUsage(new BigDecimal("-1.0"));
        ValidationResult result = validator.validate(r);
        assertThat(result.isValid()).isFalse();
        assertThat(result.getErrorCode()).isEqualTo("USG_NEGATIVE_KWH");
    }

    @Test
    void zero_billing_days_fails() {
        MonthlyUsageRecord r = valid();
        r.setBillingDays(0);
        ValidationResult result = validator.validate(r);
        assertThat(result.isValid()).isFalse();
        assertThat(result.getErrorCode()).isEqualTo("USG_INVALID_BILLING_DAYS");
    }

    @Test
    void null_fixed_rate_fails() {
        MonthlyUsageRecord r = valid();
        r.setFixedRate(null);
        ValidationResult result = validator.validate(r);
        assertThat(result.isValid()).isFalse();
        assertThat(result.getErrorCode()).isEqualTo("USG_MISSING_FIXED_RATE");
    }

    @Test
    void null_total_billed_fails() {
        MonthlyUsageRecord r = valid();
        r.setCalcTotalBilled(null);
        ValidationResult result = validator.validate(r);
        assertThat(result.isValid()).isFalse();
        assertThat(result.getErrorCode()).isEqualTo("USG_NULL_TOTAL_BILLED");
    }
}
