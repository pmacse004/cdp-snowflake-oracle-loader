package com.ibm.cdp.loader.core.model;

import lombok.Data;
import lombok.NoArgsConstructor;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.time.OffsetDateTime;

/**
 * Represents one row from VW_MONTHLY_USAGE_BILLING_EXPORT.
 * One row per usage business key (USAGE_ID).
 */
@Data
@NoArgsConstructor
public class MonthlyUsageRecord {

    // ---- Usage identifiers ----
    private String usageId;
    private String energyAccountId;
    private String premiseId;
    private String meterId;
    private String billingMonth;        // YYYY-MM
    private LocalDate billStartDate;
    private LocalDate billEndDate;
    private Integer billingDays;

    // ---- Metered quantities ----
    private BigDecimal kwhUsage;
    private BigDecimal kwhEffective;    // COALESCE(KWH_ADJUSTED, KWH_USAGE)
    private BigDecimal peakDemandKw;
    private BigDecimal prevMeterReading;
    private BigDecimal currMeterReading;
    private String readType;            // ACTUAL / ESTIMATED

    // ---- Rate plan ----
    private String ratePlan;
    private BigDecimal fixedRate;
    private BigDecimal energyRatePerKwh;
    private BigDecimal demandRatePerKw;
    private BigDecimal taxRate;

    // ---- Charge calculations (Layer 1 — Snowflake computed) ----
    private BigDecimal calcFixedCharge;
    private BigDecimal calcEnergyCharge;
    private BigDecimal calcDemandCharge;
    private BigDecimal calcSubtotal;
    private BigDecimal calcTaxAmount;
    private BigDecimal calcTotalBilled;

    // ---- Quality and correction ----
    private String usageQualityStatus;   // ACTUAL / ESTIMATED / CORRECTED
    private Boolean isCorrection;
    private String correctionReason;

    // ---- Watermark ----
    private OffsetDateTime createdAt;
    private OffsetDateTime updatedAt;
}
