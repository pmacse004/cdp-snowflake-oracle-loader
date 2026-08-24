# ICA MCP Setup Guide
# CDP Snowflake-to-Oracle Loader

**Document:** `docs/ica-mcp-setup-guide.md`  
**Audience:** Operator / Bob user  
**Purpose:** Step-by-step instructions to load ICA project context into IBM Bob via MCP, enabling Bob to retrieve transformation rules, column mappings, and validation logic during code generation.

> **Runtime independence:** ICA/MCP is used **only during design and code generation by Bob**. The running application (`cdp-loader-api`) has no ICA or MCP dependency at runtime. It connects only to Snowflake and Oracle.

---

## Table of Contents

1. [Prerequisites](#1-prerequisites)
2. [Create or Import the Project Context in ICA Context Studio](#2-create-or-import-the-project-context)
3. [Expose the ICA Context via MCP Interface](#3-expose-ica-context-via-mcp-interface)
4. [Register the MCP Endpoint in IBM Bob](#4-register-the-mcp-endpoint-in-ibm-bob)
5. [Verify Bob Can Retrieve Mappings](#5-verify-bob-can-retrieve-mappings)
6. [Sample Bob Verification Prompts](#6-sample-bob-verification-prompts)
7. [Troubleshooting](#7-troubleshooting)
8. [Operator Checklist](#8-operator-checklist)

---

## 1. Prerequisites

| Requirement | Value / Status |
|-------------|----------------|
| IBM Business Automation ICA Context Studio | `<YOUR_ICA_TENANT_URL>` — *placeholder: obtain from your IBM account team* |
| ICA project role | Context Author or higher |
| MCP interface enabled on your ICA tenant | Contact IBM support if not visible |
| IBM Bob version | ≥ 1.0 (MCP server support required) |
| Local repository | This repository cloned and `docs/ica-context/` present |

> **⚠ Placeholder values:** This guide cannot supply tenant-specific ICA URLs, project IDs, API keys, or menu paths because these differ per IBM account and tenant deployment. All such values are marked `<PLACEHOLDER>`. An operator checklist in §8 lists every value you must supply.

---

## 2. Create or Import the Project Context

### 2.1 Using the ICA Context Bundle (Recommended)

The file `docs/ica-context/ica-context-bundle.json` in this repository is a self-contained, ICA-importable context artifact generated from all 17 ICA documents and the mapping catalogue.

**Steps:**

1. Open ICA Context Studio at `<YOUR_ICA_TENANT_URL>/context-studio`.
2. Select **Projects** → **New Project** (or open an existing project).
3. Project name: `CDP Snowflake Oracle Loader` (or any descriptive name).
4. Click **Import Context** → **From JSON file**.
5. Upload `docs/ica-context/ica-context-bundle.json`.
6. ICA will parse and create context nodes for:
   - Business glossary (ICA-01)
   - Source and target data dictionaries (ICA-02, ICA-03)
   - Entity-level and column-level mappings (ICA-04, ICA-05)
   - Transformation rules (ICA-06)
   - Validation rules (ICA-07)
   - Reference code translations (ICA-08)
   - Watermark / incremental rules (ICA-09)
   - Initial, daily, monthly load rules (ICA-10, ICA-11, ICA-12)
   - Error handling, reconciliation (ICA-13, ICA-14)
   - Security rules (ICA-15)
   - Snowflake view designs (ICA-17)
7. Review the import summary. Accept any field-mapping suggestions.
8. Click **Publish** to make the context available to MCP consumers.

### 2.2 Manual Creation (Alternative)

If JSON import is not available on your tenant:

1. Create a new ICA project.
2. For each file in `docs/ica-context/*.md`, create a context document:
   - Use the document title as the **Context Node Name**.
   - Paste the Markdown content into the **Description** field.
   - Tag each node with its ICA document ID (e.g., `ICA-07`).
3. Import `docs/ica-context/mapping-catalogue.yaml` as a **Mapping Catalogue** asset if your ICA version supports YAML import; otherwise paste key sections manually.
4. Publish the project.

---

## 3. Expose the ICA Context via MCP Interface

IBM ICA Context Studio exposes a Model Context Protocol (MCP) endpoint that allows AI assistants (including Bob) to query the context using natural-language or structured queries.

### 3.1 Enable the MCP Interface

1. In ICA Context Studio, open your project.
2. Navigate to **Settings** → **Integrations** → **MCP Interface**.  
   *(Menu path may vary — look for "AI Assistant Integration" or "MCP Server" in your tenant version.)*
3. Toggle **Enable MCP Interface** to ON.
4. Note the generated endpoint URL:  
   `https://<YOUR_ICA_TENANT_URL>/mcp/v1/projects/<PROJECT_ID>`  
   — *this is your MCP server URL for Bob registration.*

### 3.2 Generate an API Key / Authentication Token

1. In **Settings** → **API Keys**, create a new key scoped to your project.
2. Name it: `bob-cdp-loader-key`.
3. Copy the key — it will not be shown again.
4. Store it securely (password manager, not in source control).

> **Authentication method:** ICA MCP typically uses Bearer token authentication:  
> `Authorization: Bearer <YOUR_ICA_API_KEY>`  
> Confirm the exact header name with your ICA tenant documentation.

### 3.3 Verify the MCP Endpoint Directly

```bash
curl -H "Authorization: Bearer <YOUR_ICA_API_KEY>" \
     "<YOUR_ICA_MCP_URL>/capabilities"
```

Expected response (structure varies by ICA version):
```json
{
  "protocol": "mcp",
  "version": "1.0",
  "tools": ["search_context", "get_mapping", "get_rule", "list_entities"]
}
```

If this call fails, see §7 Troubleshooting before proceeding.

---

## 4. Register the MCP Endpoint in IBM Bob

### 4.1 Open Bob MCP Settings

1. In IBM Bob, click **Settings** (⚙) → **MCP Servers**.
2. Click **Add MCP Server**.

### 4.2 Configure the Server Entry

| Field | Value |
|-------|-------|
| **Server Name** | `ica-cdp-loader` |
| **Transport** | `HTTP / SSE` (select appropriate for your ICA version) |
| **Server URL** | `<YOUR_ICA_MCP_URL>` |
| **Authentication** | Bearer Token |
| **Token** | `<YOUR_ICA_API_KEY>` |
| **Description** | `ICA context for CDP Snowflake-Oracle Loader project` |

3. Click **Test Connection**.  
   Expected: green status, tool list visible.
4. Click **Save**.

### 4.3 Confirm Tools Are Available

After saving, Bob's tool list should show ICA tools such as:
- `ica-cdp-loader/search_context`
- `ica-cdp-loader/get_mapping`
- `ica-cdp-loader/get_rule`
- `ica-cdp-loader/list_entities`

The exact tool names depend on your ICA tenant version. See §6 for prompts that exercise these tools.

---

## 5. Verify Bob Can Retrieve Mappings

After registration, test with a simple prompt in Bob:

```
Using the ica-cdp-loader MCP context, show me the column-level mapping
for VW_DAILY_CUSTOMER_EXPORT to TGT_CUSTOMER.
```

Expected: Bob retrieves mapping rows CM-020 through CM-038 from ICA-05 and displays them, including source column, target column, transform rule ID, and validation rule ID.

If Bob returns generic information rather than ICA-specific content, confirm:
1. The MCP server is correctly registered (§4.2).
2. The ICA project is published (not in draft).
3. The API key has read access to the project.

---

## 6. Sample Bob Verification Prompts

Use these exact prompts (or close variants) to verify ICA context retrieval across all rule categories. Each prompt is designed to test a specific knowledge area.

### 6.1 Source-to-Target Column Mappings

```
Using ica-cdp-loader context:
What columns does VW_DAILY_CUSTOMER_EXPORT map to in TGT_CUSTOMER?
List: source column, target column, transform rule ID, mandatory flag.
```

Expected: Retrieves ICA-05 section for CUSTOMER entity (CM-020..CM-038). Key mappings:
- `CUSTOMER_ID` → `CUSTOMER_ID` (CM-020, business key)
- `ACCOUNT_STATUS` → `ACCOUNT_STATUS` + `IS_ACTIVE` derivation (CM-027, CM-028)
- `FULL_NAME_NORMALIZED` → `FULL_NAME_NORMALIZED` (view-computed, TR-COMB-01)

---

```
Using ica-cdp-loader context:
What columns does VW_MONTHLY_USAGE_BILLING_EXPORT map to in TGT_MONTHLY_USAGE?
Show the billing calculation columns and their transform rules.
```

Expected: Retrieves monthly usage mappings including CALC_FIXED_CHARGE, CALC_ENERGY_CHARGE, CALC_DEMAND_CHARGE, CALC_SUBTOTAL, CALC_TAX_AMOUNT, CALC_TOTAL_BILLED with rules TR-BILL-02 through TR-BILL-07.

---

### 6.2 Snowflake Join Rules

```
Using ica-cdp-loader context:
What joins does VW_DAILY_CUSTOMER_ACCOUNT_EXPORT perform?
List each join type, tables involved, and join condition.
```

Expected: Retrieves TR-JOIN-01 through TR-JOIN-07 from ICA-06:
- INNER JOIN CUSTOMER on CUSTOMER_ID
- LEFT JOIN primary_email CTE (QUALIFY ROW_NUMBER)
- LEFT JOIN primary_phone CTE
- LEFT JOIN current_billing CTE
- LEFT JOIN current_premise CTE
- LEFT JOIN active_meter CTE
- LEFT JOIN acct_status_ref / cust_type_ref

---

### 6.3 Calculated Billing Fields

```
Using ica-cdp-loader context:
Explain the 7-step billing charge calculation in VW_MONTHLY_USAGE_BILLING_EXPORT.
What are the ICA rules for each step, and what happens when a rate is NULL?
```

Expected: Retrieves ICA-12 §4 and ICA-06 TR-BILL-* rules:
- Step 1 FIXED_CHARGE: NULL rate → NULL result (TR-BILL-02)
- Step 2 ENERGY_CHARGE: ROUND(KWH * energy_rate, 2), NULL if rate invalid (TR-BILL-03)
- Step 3 DEMAND_CHARGE: NULL demand_rate → 0 (ICA MU-AC-09 explicit rule)
- Step 4 SUBTOTAL: fixed + energy + demand (NULL propagates)
- Step 5 TAX_AMOUNT: ROUND(subtotal * tax_rate, 2) (TR-BILL-06)
- Step 6 TOTAL_BILLED: subtotal + tax (TR-BILL-07)
- Step 7 USAGE_QUALITY_STATUS: ESTIMATED / CORRECTED / ACTUAL

---

### 6.4 Validation and Rejection Rules

```
Using ica-cdp-loader context:
List all validation rules for monthly usage records.
Which rules cause a REJECT vs a LOG warning?
Which intentional test records are expected to fail and why?
```

Expected: Retrieves ICA-07 §2.9 VR-USAGE-001 through VR-USAGE-012:
- VR-USAGE-003 (bill end before start) → REJECT → catches USG-INVD-* records
- VR-USAGE-006 (negative PEAK_DEMAND_KW) → REJECT → catches USG-INVK-* records
- VR-USAGE-011 (bill total consistency) → LOG warning, do not reject

---

```
Using ica-cdp-loader context:
What customer validation rules must pass before a customer record
is written to TGT_CUSTOMER? List rule IDs, field names, error codes.
```

Expected: Retrieves VR-CUST-001 through VR-CUST-006.

---

### 6.5 Composite Watermark Rules

```
Using ica-cdp-loader context:
Explain the composite watermark strategy for the daily incremental load.
What tables have independent watermarks? What is the tie-break condition?
```

Expected: Retrieves ICA-09:
- Per-table watermarks for: CUSTOMER, CUSTOMER_CONTACT, ENERGY_ACCOUNT, BILLING_ACCOUNT, SERVICE_PREMISE, METER, MONTHLY_USAGE
- Composite condition: `RECORD_EFFECTIVE_TS > :lastTs OR (RECORD_EFFECTIVE_TS = :lastTs AND STABLE_SOURCE_ID > :lastId)`
- UNION (not UNION ALL) deduplication strategy
- Watermark advances only after successful Oracle commit

---

### 6.6 Soft-Delete / Inactivation Rules

```
Using ica-cdp-loader context:
How does the ETL handle customer inactivation?
What is the IS_ACTIVE derivation rule and which source field drives it?
```

Expected: Retrieves TR-08 (soft-delete handling), CM-028 (IS_ACTIVE derivation):
- Source: `CUSTOMER.ACCOUNT_STATUS = 'INACTIVE'`
- Target: `TGT_CUSTOMER.IS_ACTIVE = 0`
- Rule: `CASE WHEN ACCOUNT_STATUS = 'INACTIVE' THEN TRUE ELSE FALSE END` (view computes IS_INACTIVE)
- Oracle: `IS_ACTIVE = 1` when not INACTIVE, `IS_ACTIVE = 0` when INACTIVE

---

### 6.7 Initial, Daily, and Monthly Job Rules

```
Using ica-cdp-loader context:
What is the mandatory load sequence for the initial load job?
Which steps must complete before others can start?
```

Expected: Retrieves ICA-10 §4 (load sequence):
Step 1 Reference Data → Step 2 Customers → Step 3 Contacts → Step 4 Energy Accounts → Step 5 Billing Accounts → Step 6 Premises → Step 7 Meters → Step 8 Monthly Usage → Step 9 Reconciliation

---

```
Using ica-cdp-loader context:
What are the trigger rules for the daily and monthly load jobs?
When can each job run, and what conflict checks are required?
```

Expected: Retrieves ICA-11 and ICA-12 trigger rules, plus ICA-10 IL-PRE-05 (only one initial load at a time).

---

## 7. Troubleshooting

### 7.1 MCP Connection Refused / 404

| Symptom | Likely Cause | Resolution |
|---------|-------------|------------|
| `Connection refused` | Wrong MCP URL | Verify the URL in ICA Settings → Integrations |
| `404 Not Found` | MCP interface not enabled | Enable in ICA Settings → Integrations → MCP Interface |
| `401 Unauthorized` | Invalid/expired API key | Regenerate key in ICA Settings → API Keys |
| `403 Forbidden` | Key lacks project scope | Ensure key was created with project-level access |

### 7.2 Bob Returns Generic Content (Not ICA-Specific)

1. Confirm the MCP server `ica-cdp-loader` is listed under **Settings → MCP Servers** with green status.
2. Confirm the ICA project is **Published** (not Draft).
3. Try a more specific prompt: *"Use the ica-cdp-loader MCP tool to search for rule ID VR-CUST-001"*.
4. If Bob still doesn't use MCP: ensure the context window includes the tool description. Start a fresh conversation.

### 7.3 Import Errors (Context Bundle)

| Error | Resolution |
|-------|------------|
| `Unsupported format` | Try manual creation (§2.2) |
| `Duplicate node names` | The project already has context — use "Update" instead of "Import" |
| `Missing required fields` | Check ICA version compatibility; the bundle targets ICA Context Studio 1.x |

### 7.4 Authentication Token Format

If ICA requires a non-Bearer format:

```
# Basic auth variant:
Authorization: Basic <base64(username:password)>

# IBM Cloud IAM variant:
Authorization: Bearer <IAM_TOKEN>
X-IBM-Client-Id: <CLIENT_ID>
```

Consult your ICA tenant documentation for the exact authentication header format.

---

## 8. Operator Checklist

Complete this checklist before attempting MCP verification:

```
[ ] ICA tenant URL obtained:           ________________________________
[ ] ICA project created/imported
[ ] ICA project published (not Draft)
[ ] MCP interface enabled on tenant
[ ] MCP endpoint URL noted:            ________________________________
[ ] API key created (project-scoped):  (store in password manager, not here)
[ ] MCP server registered in Bob:      server name = ica-cdp-loader
[ ] Bob connection test: green
[ ] Verification prompt §5 returns ICA-specific mappings
[ ] Verification prompt §6.1 returns CM-020..CM-038
[ ] Verification prompt §6.4 identifies USG-INVD-* and USG-INVK-* rejection rules
[ ] Verification prompt §6.5 returns per-table watermark table list
```

---

*This guide contains no tenant-specific URLs, credentials, or real API keys. All `<PLACEHOLDER>` values must be supplied by the operator.*
