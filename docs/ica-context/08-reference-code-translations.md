# ICA Context Document 08 — Reference / Code Translations

**ICA Document ID:** ICA-08  
**Project:** CDP Snowflake to Oracle Data Loader  
**Version:** 1.0  
**Status:** Phase 1 — Approved  
**Last Updated:** 2025 (Phase 1)

---

## 1. Purpose

This document defines all code-value translation tables used during transformation. Source codes originate in Snowflake; target (canonical) codes are stored in Oracle. The translations are applied by TR-05 (Account Status Translator) and similar rules.

Each translation set has a stable domain ID.

---

## 2. Account Status — Domain: ACCT_STATUS

Applied by: TR-05  
Validation rule: VR-STATUS-001 (unrecognised source code → REJECT)

| Source Code | Source Label | Target Canonical Code | Target Label | IS_ACTIVE |
|-------------|-------------|----------------------|-------------|-----------|
| `ACT` | Active | `ACTIVE` | Active | 1 |
| `ACTIVE` | Active (alternate) | `ACTIVE` | Active | 1 |
| `INA` | Inactive | `INACTIVE` | Inactive | 0 |
| `INACTIVE` | Inactive (alternate) | `INACTIVE` | Inactive | 0 |
| `PND` | Pending | `PENDING` | Pending | 0 |
| `PENDING` | Pending (alternate) | `PENDING` | Pending | 0 |
| `CLO` | Closed | `CLOSED` | Closed | 0 |
| `CLOSED` | Closed (alternate) | `CLOSED` | Closed | 0 |
| `SUS` | Suspended | `INACTIVE` | Inactive (suspended) | 0 |
| `DIS` | Disconnected | `INACTIVE` | Inactive (disconnected) | 0 |

---

## 3. Customer Type — Domain: CUST_TYPE

No translation required; source values are passed through after uppercase-trim. Valid values:

| Source Value | Target Value | Description |
|-------------|-------------|-------------|
| `RESIDENTIAL` | `RESIDENTIAL` | Residential customer |
| `COMMERCIAL` | `COMMERCIAL` | Commercial business customer |
| `INDUSTRIAL` | `INDUSTRIAL` | Industrial customer |

---

## 4. Meter Type — Domain: METER_TYPE

No translation required; source values are passed through after uppercase-trim. Valid values:

| Source Value | Target Value | Description |
|-------------|-------------|-------------|
| `ANALOG` | `ANALOG` | Electromechanical dial meter |
| `DIGITAL` | `DIGITAL` | Electronic digital meter |
| `SMART_AMI` | `SMART_AMI` | Advanced Metering Infrastructure (smart meter) |

---

## 5. Premise Type — Domain: PREMISE_TYPE

No translation required; pass-through after uppercase-trim. Valid values: RESIDENTIAL, COMMERCIAL, INDUSTRIAL.

---

## 6. Contact Type — Domain: CONTACT_TYPE

No translation required; pass-through after uppercase-trim. Valid values: MAILING, SERVICE, BILLING, EMAIL, PHONE.

---

## 7. Billing Cycle — Domain: BILLING_CYCLE

No translation required; pass-through after uppercase-trim. Valid values:

| Source Value | Target Value | Description |
|-------------|-------------|-------------|
| `MONTHLY` | `MONTHLY` | Bill generated monthly |
| `BIMONTHLY` | `BIMONTHLY` | Bill generated every two months |

---

## 8. Payment Method — Domain: PAYMENT_METHOD

Pass-through after uppercase-trim. Valid values: AUTO_PAY, MAIL, ONLINE.

---

## 9. Service Type — Domain: SERVICE_TYPE

Pass-through after uppercase-trim. Valid values for this demo: ELECTRIC, GAS, SOLAR.

---

## 10. Read Type — Domain: READ_TYPE

| Source Value | Target Value | Description |
|-------------|-------------|-------------|
| `A` | `A` | Actual meter read |
| `E` | `E` | Estimated meter read |

---

## 11. Rate Plans — Domain: RATE_PLAN

Reference rate plan codes for synthetic data. These are loaded as REF.CODE_VALUE rows (domain = `RATE_PLAN`):

| Code | Label | Customer Type |
|------|-------|--------------|
| `RES-1` | Residential Standard | RESIDENTIAL |
| `RES-2` | Residential Time-of-Use | RESIDENTIAL |
| `RES-3` | Residential Budget Billing | RESIDENTIAL |
| `COM-1` | Commercial Standard Demand | COMMERCIAL |
| `COM-2` | Commercial Time-of-Use | COMMERCIAL |
| `COM-3` | Commercial Small Business | COMMERCIAL |
| `IND-1` | Industrial Large Load | INDUSTRIAL |
| `IND-2` | Industrial Interruptible | INDUSTRIAL |
| `SOL-1` | Solar Net Metering | RESIDENTIAL |

---

## 12. Distribution Zones

Reference distribution zone codes for synthetic data. These are loaded as REF.CODE_VALUE rows (domain = `DIST_ZONE`):

| Code | Label |
|------|-------|
| `ZONE-N` | Northern Zone |
| `ZONE-S` | Southern Zone |
| `ZONE-E` | Eastern Zone |
| `ZONE-W` | Western Zone |
| `ZONE-C` | Central Zone |

---

## 13. US State Codes

Valid US state codes (2-letter abbreviations) used in VR-CONT-003 and VR-PREM-004:

`AL, AK, AZ, AR, CA, CO, CT, DE, FL, GA, HI, ID, IL, IN, IA, KS, KY, LA, ME, MD, MA, MI, MN, MS, MO, MT, NE, NV, NH, NJ, NM, NY, NC, ND, OH, OK, OR, PA, RI, SC, SD, TN, TX, UT, VT, VA, WA, WV, WI, WY, DC`

---

## 14. Code Translation Implementation

Translations are loaded at job startup from `CDP_APP.REF_CODE_VALUE` into an in-memory cache (`CodeTranslationCache`). The cache is keyed by `(CODE_DOMAIN, SOURCE_VALUE)` → `TARGET_CODE`.

```java
// Pseudocode — Phase 4 implementation
public class CodeTranslationCache {
    // Loaded from DB at startup
    Map<String, Map<String, String>> cache; // domain → sourceCode → targetCode

    public String translate(String domain, String sourceCode) {
        return Optional.ofNullable(cache.get(domain))
            .map(m -> m.get(sourceCode.toUpperCase()))
            .orElseThrow(() -> new ValidationException(
                "VAL-STATUS-001", "Unknown code: " + domain + "/" + sourceCode));
    }
}
```
