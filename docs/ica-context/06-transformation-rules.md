# ICA Context Document 06 — Transformation Rules

**ICA Document ID:** ICA-06  
**Project:** CDP Snowflake to Oracle Data Loader  
**Version:** 1.1 (Phase 1 Amendment)  
**Status:** Phase 1 — Amended  
**Last Updated:** 2025 (Phase 1 Amendment)

**Amendment:** Added join rules, ranking/selection rules, combined-status derivation, address formatting, charge calculation rules and GREATEST timestamp derivation. Distinguished which rules execute in Snowflake (Layer 1) vs Spring Batch (Layer 2).

---

## 1. Rule Categories

| Category | Prefix | Executed In |
|----------|--------|-------------|
| Join and set operations | TR-JOIN-* | Snowflake Layer 1 |
| Selection and ranking | TR-RANK-* | Snowflake Layer 1 |
| Conditional / CASE derivation | TR-COMB-* / TR-COND-* | Snowflake Layer 1 |
| Address and text assembly | TR-ADDR-* | Snowflake Layer 1 |
| Billing calculations | TR-BILL-* | Snowflake Layer 1 |
| Flag and boolean conversion | TR-01 | Spring Batch Layer 2 |
| Name normalisation | TR-02, TR-03 | Spring Batch Layer 2 |
| Status code translation | TR-04, TR-05 | Spring Batch Layer 2 |
| Contact normalisation | TR-06, TR-07 | Spring Batch Layer 2 |
| Soft-delete handling | TR-08 | Spring Batch Layer 2 |
| FK resolution | TR-FK-01 | Spring Batch Layer 2 |
| Date/timestamp conversion | TR-DATE-01, TR-TS-01 | Spring Batch Layer 2 |
| Decimal normalisation | TR-DEC-01, TR-DEC-02 | Spring Batch Layer 2 |
| Audit stamping | TR-AUD-01..04 | Oracle Layer 3 |

---

## 2. Snowflake Layer 1 Rules

### TR-JOIN-01: Primary Customer Join
| Property | Value |
|----------|-------|
| Rule ID | TR-JOIN-01 |
| Name | CustomerToEnergyAccountJoin |
| Layer | Snowflake (VW_DAILY_CUSTOMER_ACCOUNT_EXPORT) |
| Type | INNER JOIN |
| Tables | `RAW.ENERGY_ACCOUNT ea` INNER JOIN `RAW.CUSTOMER c` |
| Condition | `c.CUSTOMER_ID = ea.ENERGY_ACCOUNT_ID` *(join on CUSTOMER_ID)* |
| Null behaviour | No row emitted if CUSTOMER not found (INNER JOIN) |
| Used by | EM-02, EM-04 |

### TR-JOIN-02: Contact Left Join
| Property | Value |
|----------|-------|
| Rule ID | TR-JOIN-02 |
| Layer | Snowflake Layer 1 |
| Type | LEFT JOIN |
| Tables | `ranked_contact cc` ON `cc.CUSTOMER_ID = c.CUSTOMER_ID AND cc.rn = 1` |
| Null behaviour | Contact columns NULL if no qualifying mailing contact exists |
| Used by | EM-03 |

### TR-JOIN-03: Billing Account Left Join
| Property | Value |
|----------|-------|
| Rule ID | TR-JOIN-03 |
| Layer | Snowflake Layer 1 |
| Type | LEFT JOIN |
| Tables | `ranked_billing ba` ON `ba.ENERGY_ACCOUNT_ID = ea.ENERGY_ACCOUNT_ID AND ba.rn = 1` |
| Null behaviour | Billing columns NULL if no current billing account |
| Used by | EM-05 |

### TR-JOIN-04: Premise Left Join
| Property | Value |
|----------|-------|
| Rule ID | TR-JOIN-04 |
| Layer | Snowflake Layer 1 |
| Type | LEFT JOIN |
| Tables | `RAW.SERVICE_PREMISE sp` ON `sp.ENERGY_ACCOUNT_ID = ea.ENERGY_ACCOUNT_ID` |
| Null behaviour | Premise columns NULL if no premise |
| Used by | EM-06 |

### TR-JOIN-05: Meter Left Join
| Property | Value |
|----------|-------|
| Rule ID | TR-JOIN-05 |
| Layer | Snowflake Layer 1 |
| Type | LEFT JOIN |
| Tables | `ranked_meter m` ON `m.PREMISE_ID = sp.PREMISE_ID AND m.rn = 1` |
| Null behaviour | Meter columns NULL if no active meter |
| Used by | EM-07 |

### TR-JOIN-06: Rate Plan Reference Lookup
| Property | Value |
|----------|-------|
| Rule ID | TR-JOIN-06 |
| Layer | Snowflake Layer 1 |
| Type | LEFT JOIN |
| Tables | `REF.CODE_VALUE rc_rate` ON `rc_rate.CODE_DOMAIN = 'RATE_PLAN' AND rc_rate.CODE_VALUE = ea.RATE_CLASS` |
| Output | `RATE_CLASS_DESCRIPTION` |
| Null behaviour | NULL if rate code not found in reference table; warning issued |
| Used by | EM-04 |

### TR-JOIN-07: Status Reference Lookup
| Property | Value |
|----------|-------|
| Rule ID | TR-JOIN-07 |
| Layer | Snowflake Layer 1 |
| Type | LEFT JOIN |
| Tables | `REF.CODE_VALUE rc_status` ON domain `ACCT_STATUS`, value = `COMBINED_STATUS_CODE` |
| Output | `COMBINED_STATUS_LABEL` |
| Used by | EM-02, EM-04 |

---

### TR-RANK-01: Primary Mailing Contact Selection
| Property | Value |
|----------|-------|
| Rule ID | TR-RANK-01 |
| Name | PrimaryMailingContactSelector |
| Layer | Snowflake Layer 1 |
| Function | `ROW_NUMBER() OVER (PARTITION BY CUSTOMER_ID ORDER BY IS_PRIMARY DESC, EFFECTIVE_DATE DESC, CONTACT_ID DESC)` |
| Filter | `CONTACT_TYPE = 'MAILING'` AND `(EXPIRY_DATE IS NULL OR EXPIRY_DATE >= CURRENT_DATE())` |
| Selection | `WHERE rn = 1` |
| Rationale | Prefer the explicitly primary contact; use most-recent effective date as tie-break; highest ID as final deterministic tie-break |
| Example input | 3 mailing contacts (one IS_PRIMARY=Y, one expired, one older) |
| Example output | The IS_PRIMARY=Y contact row |
| Used by | EM-03 (CM-048..052) |

### TR-RANK-02: Current Billing Account Selection
| Property | Value |
|----------|-------|
| Rule ID | TR-RANK-02 |
| Name | CurrentBillingAccountSelector |
| Layer | Snowflake Layer 1 |
| Function | `ROW_NUMBER() OVER (PARTITION BY ENERGY_ACCOUNT_ID ORDER BY EFFECTIVE_DATE DESC, BILLING_ACCOUNT_ID DESC)` |
| Filter | `EFFECTIVE_DATE <= CURRENT_DATE()` AND `(EXPIRY_DATE IS NULL OR EXPIRY_DATE >= CURRENT_DATE())` |
| Selection | `WHERE rn = 1` |
| Example input | 2 billing records for same account; one expired last month, one current |
| Example output | The current (non-expired) record |
| Used by | EM-05 (CM-080..087) |

### TR-RANK-03: Current Active Meter Selection
| Property | Value |
|----------|-------|
| Rule ID | TR-RANK-03 |
| Name | CurrentActiveMeterSelector |
| Layer | Snowflake Layer 1 |
| Function | `ROW_NUMBER() OVER (PARTITION BY PREMISE_ID ORDER BY INSTALL_DATE DESC, METER_ID DESC)` |
| Filter | `ACTIVE_FLAG = 'Y'` AND `(REMOVAL_DATE IS NULL OR REMOVAL_DATE >= CURRENT_DATE())` |
| Selection | `WHERE rn = 1` |
| Example input | Meter A installed 2020 (removed 2023), Meter B installed 2023 (active) |
| Example output | Meter B |
| Used by | EM-07 (CM-110..120) |

---

### TR-COMB-01: Combined Account Status Derivation
| Property | Value |
|----------|-------|
| Rule ID | TR-COMB-01 |
| Name | CombinedAccountStatusDeriver |
| Layer | Snowflake Layer 1 |
| Inputs | `c.ACCOUNT_STATUS`, `ea.ACCOUNT_STATUS`, `c.DELETED_FLAG`, `ea.DELETED_FLAG`, `ea.END_DATE` |
| Output | `COMBINED_STATUS_CODE` — one of `CLOSED`, `INACTIVE`, `PENDING`, `ACTIVE` |
| Logic | Priority: CLOSED (any deleted/closed) > INACTIVE > PENDING > ACTIVE |
| Example input | c.ACCOUNT_STATUS=ACT, ea.ACCOUNT_STATUS=CLO |
| Example output | `CLOSED` |
| Example input | c.ACCOUNT_STATUS=ACT, ea.ACCOUNT_STATUS=INA, ea.DELETED_FLAG=N |
| Example output | `INACTIVE` |
| Used by | CM-027, CM-028, CM-063, CM-064 |

### TR-COND-01: IS_ACTIVE from Multi-Source Conditions
| Property | Value |
|----------|-------|
| Rule ID | TR-COND-01 |
| Name | MultiSourceIsActiveDeriver |
| Layer | Snowflake Layer 1 |
| Inputs | `c.DELETED_FLAG`, `ea.DELETED_FLAG`, `ea.END_DATE`, `c.ACCOUNT_STATUS`, `ea.ACCOUNT_STATUS` |
| Output | `IS_ACTIVE` NUMBER(1): 1 = active, 0 = inactive |
| Logic | 1 only when: no deleted flag, no past end date, both statuses not inactive/closed |
| Example input | ea.END_DATE = 2023-06-01 (past), ea.ACCOUNT_STATUS=ACT |
| Example output | `0` (end date has passed) |
| Used by | CM-028, CM-064 |

---

### TR-ADDR-01: Formatted Mailing Address Assembly
| Property | Value |
|----------|-------|
| Rule ID | TR-ADDR-01 |
| Name | FormattedMailingAddressAssembler |
| Layer | Snowflake Layer 1 |
| Inputs | `cc.ADDRESS_LINE1`, `cc.ADDRESS_LINE2`, `cc.CITY`, `cc.STATE_CODE`, `cc.ZIP_CODE` |
| Output | Single VARCHAR string with null-guarded concatenation |
| Format | `{LINE1}[, {LINE2}][, {CITY}][, {STATE}][ {ZIP}]` |
| Null handling | Skips absent components; no trailing separators |
| Example input | LINE1='123 Main St', LINE2=NULL, CITY='Springfield', STATE='IL', ZIP='62701' |
| Example output | `'123 Main St, Springfield, IL 62701'` |
| Used by | CM-ADDR-01 |

### TR-TS-GREATEST-01: Record Effective Timestamp (GREATEST of all contributing UPDATED_AT)
| Property | Value |
|----------|-------|
| Rule ID | TR-TS-GREATEST-01 |
| Name | RecordEffectiveTsDeriver |
| Layer | Snowflake Layer 1 |
| Inputs | `c.UPDATED_AT`, `cc.UPDATED_AT`, `ea.UPDATED_AT`, `ba.UPDATED_AT`, `sp.UPDATED_AT`, `m.UPDATED_AT` |
| Output | `RECORD_EFFECTIVE_TS` — the most recent modification timestamp across all sources |
| Null handling | `COALESCE(x, '1970-01-01')` before GREATEST to avoid propagating NULL |
| Purpose | Represents when the logical record was last changed by any contributing source |
| Used by | Watermark advancement; dashboard display; ordering |

---

### TR-BILL-01 through TR-BILL-07: Charge Calculations (Snowflake Layer 1)

All charge calculations execute in `VW_MONTHLY_USAGE_BILLING_EXPORT`. See Section 3.4 of ICA-17 for the full calculation sequence. Summary:

| Rule ID | Name | Calculation | Rounding |
|---------|------|-------------|---------|
| TR-BILL-01 | AdjustedKwhCalculator | `(CURR_READING - PREV_READING) * MULTIPLIER` | ROUND(x, 6) |
| TR-BILL-02 | FixedChargeExtractor | `rate_params.FIXED_CHARGE_RATE` | ROUND(x, 2) |
| TR-BILL-03 | EnergyChargeCalculator | `KWH_USAGE * ENERGY_RATE_PER_KWH` | ROUND(x, 2) |
| TR-BILL-04 | DemandChargeCalculator | `PEAK_DEMAND_KW * DEMAND_RATE_PER_KW` (0 if no demand rate) | ROUND(x, 2) |
| TR-BILL-05 | SubtotalCalculator | `FIXED + ENERGY + DEMAND` | ROUND(x, 2) |
| TR-BILL-06 | TaxCalculator | `SUBTOTAL * TAX_RATE` | ROUND(x, 2) |
| TR-BILL-07 | TotalBilledCalculator | `SUBTOTAL * (1 + TAX_RATE)` | ROUND(x, 2) |

**Rounding convention:** Each intermediate step rounds to the appropriate scale before being used in the next step. This matches typical utility billing system behaviour and prevents accumulated rounding drift.

**Synthetic rates:** All rate values (fixed charge, energy rate, demand rate, tax rate) are entirely synthetic demonstration values stored in `REF.CODE_VALUE` (domain `RATE_PLAN`).

**Source column for rates (Phase 3 audit fix — Issue #1):** Rate parameters are stored in the `ATTRIBUTES` VARIANT column, **not** in `CODE_LABEL`. `CODE_LABEL` is a human-readable label only (e.g., `'Residential Standard'`). The export view reads `ATTRIBUTES['fixed']::STRING` etc., using bracket notation for Snowflake VARIANT path access. `TRY_PARSE_JSON(CODE_LABEL)` must **not** be used.

No real utility tariff is represented.

---

## 3. Spring Batch Layer 2 Rules (unchanged from v1.0, re-confirmed in scope)

### TR-01: Y/N to 1/0 Conversion
*See v1.0 — unchanged. Applies to IS_PRIMARY, PAPERLESS_BILLING, ACTIVE_FLAG.*

### TR-02: Title Case Normalisation
*See v1.0. Applied to FIRST_NAME, LAST_NAME, CITY fields in processor after view extraction.*

### TR-03: Full Name Derivation
*See v1.0. FULL_NAME = LAST_NAME + ', ' + FIRST_NAME, using title-cased components.*

### TR-04: IS_ACTIVE Derivation from Canonical Status Code
*Applies to canonical status received from processor after TR-05 translation. Supplements TR-COND-01 (view level).*

### TR-05: Account Status Code Translation
*See v1.0. Translates source codes (ACT, INA, PND, CLO) to canonical values. Applied in processor to COMBINED_STATUS_CODE from view.*

### TR-06: Email Lower-Case Normalisation
*See v1.0 — unchanged.*

### TR-07: Phone Number E.164 Normalisation
*See v1.0 — unchanged.*

### TR-08: Soft Delete Transformer
*See v1.0. Triggered when view returns DELETED_FLAG=Y for either CUSTOMER or ENERGY_ACCOUNT.*

### TR-FK-01: Source-to-Target FK Resolver
*See v1.0. Resolves source IDs to Oracle target IDs. Unchanged.*

### TR-DATE-01, TR-TS-01, TR-DEC-01, TR-DEC-02
*See v1.0. Type and scale conversions. Unchanged.*

---

## 4. Oracle Layer 3 Rules (unchanged)

TR-AUD-01 through TR-AUD-04 (CREATED_AT, CREATED_BY, UPDATED_AT, UPDATED_BY stamping) remain in Oracle MERGE as before.
