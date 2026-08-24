package com.ibm.cdp.loader.core.model;

import lombok.Data;
import lombok.NoArgsConstructor;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.time.OffsetDateTime;

/**
 * Represents one row from VW_DAILY_CUSTOMER_ACCOUNT_EXPORT.
 * One row per ENERGY_ACCOUNT.
 */
@Data
@NoArgsConstructor
public class CustomerAccountRecord {

    // ---- Energy account ----
    private String energyAccountId;
    private String accountNumber;
    private String accountStatus;
    private String serviceType;
    private String rateClass;
    private LocalDate openDate;
    private LocalDate closeDate;

    // ---- Customer ----
    private String customerId;
    private String firstName;
    private String lastName;
    private String middleName;
    private String nameSuffix;
    private String fullNameNormalized;
    private String customerType;
    private String preferredLanguage;
    private String customerStatus;

    // ---- Contact ----
    private String emailAddress;
    private Boolean emailVerified;
    private String phoneNumber;

    // ---- Billing account ----
    private String billingAccountId;
    private String billingAccountNbr;
    private String billingCycle;
    private String paymentMethod;
    private Boolean autoPayEnrolled;
    private Boolean paperlessEnrolled;

    // ---- Premise ----
    private String premiseId;
    private String addressLine1;
    private String addressLine2;
    private String city;
    private String stateCode;
    private String zipCode;
    private String county;
    private BigDecimal geoLatitude;
    private BigDecimal geoLongitude;
    private String premiseType;
    private String fullAddress;

    // ---- Meter ----
    private String meterId;
    private String meterNumber;
    private String meterType;
    private LocalDate installDate;

    // ---- Reference labels ----
    private String acctStatusLabel;
    private String custTypeLabel;

    // ---- Watermark ----
    private OffsetDateTime recordEffectiveTs;
}
