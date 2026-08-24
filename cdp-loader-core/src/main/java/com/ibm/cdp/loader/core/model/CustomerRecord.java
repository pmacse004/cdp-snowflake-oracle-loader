package com.ibm.cdp.loader.core.model;

import lombok.Data;
import lombok.NoArgsConstructor;

import java.time.OffsetDateTime;

/**
 * Represents one row from VW_DAILY_CUSTOMER_EXPORT.
 * All fields are nullable to support defensive validation in the processor.
 */
@Data
@NoArgsConstructor
public class CustomerRecord {

    // ---- Customer master ----
    private String customerId;
    private String firstName;
    private String lastName;
    private String middleName;
    private String nameSuffix;
    private String fullNameNormalized;
    private String customerType;
    private String customerTypeLabel;
    private String preferredLanguage;
    private String customerStatus;       // maps to ACCOUNT_STATUS in target
    private String accountStatusLabel;
    private Boolean isInactive;          // VIEW: CASE WHEN ACCOUNT_STATUS='INACTIVE'
    private String statusReason;

    // ---- Contact ----
    private String emailAddress;
    private Boolean emailVerified;
    private String phoneNumber;

    // ---- Watermark ----
    private OffsetDateTime recordEffectiveTs;
    private OffsetDateTime createdAt;
    private OffsetDateTime updatedAt;
}
