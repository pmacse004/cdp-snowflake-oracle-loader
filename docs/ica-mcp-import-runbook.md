# ICA/MCP Import Runbook

> **Document status:** Operator runbook — CDP Snowflake-Oracle Loader
> **Audience:** Platform engineer importing the ICA/MCP context package
> **Prerequisites:** IBM Watson Studio, IBM OpenScale, or IBM AI Governance environment with MCP/ICA tooling available

---

## 1. What this runbook covers

This runbook describes how to import the `ica-mcp-context/` package from this repository into IBM® Intelligent Catalog for AI (ICA) or an IBM MCP-compatible governance platform.

The context package is **design-time only**. The running application has zero runtime dependency on ICA/MCP.

---

## 2. Package overview

| Location | `ica-mcp-context/` |
|---|---|
| Artifacts | 20 YAML/JSON files |
| Format | Vendor-neutral YAML + JSON |
| Version | 1.0 |
| Authority | Derived directly from DDL (see `context-index.json`) |

### Artifact inventory

| File | Purpose |
|---|---|
| `manifest.yaml` | Package manifest and version |
| `business-glossary.yaml` | Term definitions |
| `source-schema.yaml` | Snowflake source table summary |
| `target-schema.yaml` | Oracle target table summary |
| `entity-mappings.yaml` | Entity-to-table mapping with load order |
| `column-mappings.yaml` | Column-level mapping matrix |
| `join-rules.yaml` | CTE/JOIN structure per export view |
| `transformation-rules.yaml` | TR-* transformation rules |
| `validation-rules.yaml` | VR-* validation rules |
| `reference-code-rules.yaml` | Reference domains and ATTRIBUTES schema |
| `incremental-watermark-rules.yaml` | Watermark strategy per dataset |
| `initial-load-rules.yaml` | INITIAL_LOAD_JOB rules |
| `daily-load-rules.yaml` | DAILY_INCREMENTAL_JOB rules |
| `monthly-load-rules.yaml` | MONTHLY_USAGE_JOB rules |
| `error-handling-rules.yaml` | Error classification and code catalogue |
| `reconciliation-rules.yaml` | Post-job reconciliation checks |
| `security-classification.yaml` | Data sensitivity and PII rules |
| `nonfunctional-requirements.yaml` | Performance, deployment, testing |
| `tenant-adapter-template.yaml` | Tenant customisation template |
| `context-index.json` | Machine-readable artifact index |

---

## 3. Pre-import validation

Before importing into ICA/MCP, validate the package locally:

```powershell
# Load environment (required for PowerShell script execution)
# The validation script does NOT require live database connections.

.\scripts\validate-ica-context.ps1
```

Expected output:
```
ICA/MCP Context Package Validation
─────────────────────────────────────────────────────────────────────
[PASS] EXISTS:  manifest.yaml  (2.1 KB)
...
[PASS] No credential patterns found in context package files
[PASS] All files referenced in context-index.json are present
────────────────────────────────────────────────────────────────────
  TOTAL: 65 checks   PASS: 65   FAIL: 0
Context package validation PASSED. Safe to import into ICA/MCP.
```

Resolve all `[FAIL]` items before proceeding.

---

## 4. Import procedure (IBM Watson Knowledge Catalog / ICA)

### 4.1 Manual import (UI)

1. Open IBM Watson Knowledge Catalog.
2. Navigate to **Catalogs** → **Import assets**.
3. Select file format: **YAML / Custom metadata**.
4. Upload each YAML file from `ica-mcp-context/` in order:
   - Start with `manifest.yaml` (registers the package).
   - Then `business-glossary.yaml`, `source-schema.yaml`, `target-schema.yaml`.
   - Then all mapping/rules files.
   - Finish with `context-index.json`.
5. Map ICA field labels to the YAML keys shown in `manifest.yaml`.

### 4.2 API import (automation)

```bash
# Example using IBM OpenScale REST API (adjust base URL for your environment)
BASE="https://<your-wkc-host>/v2/data_assets"

for f in ica-mcp-context/*.yaml ica-mcp-context/context-index.json; do
    echo "Uploading: $f"
    curl -s -X POST "$BASE" \
         -H "Authorization: Bearer $ICA_TOKEN" \
         -H "Content-Type: application/x-yaml" \
         --data-binary "@$f"
done
```

> Replace `$ICA_TOKEN` with a valid platform IAM token. Do not hardcode tokens in scripts.

### 4.3 IBM MCP (Model Context Protocol) server

If using an IBM MCP server with a local YAML resource handler:

```json
{
  "servers": {
    "cdp-context": {
      "command": "node",
      "args": ["mcp-yaml-server/index.js"],
      "env": {
        "CONTEXT_DIR": "${workspaceFolder}/ica-mcp-context"
      }
    }
  }
}
```

Register each YAML file as a `resource` via `registerResource()`. Use `context-index.json` as the directory manifest for the MCP server's resource list.

---

## 5. Key rules for ICA users

### 5.1 DDL is the schema authority

| Source | Authority |
|---|---|
| `infra/snowflake/03-*.sql`, `04-*.sql` | Physical source schema |
| `cdp-loader-batch/.../V004__*.sql` | Physical target schema |
| `ica-mcp-context/column-mappings.yaml` | Derived from the above DDL |
| `docs/ica-context/*.md` | Business rules (ICA authority) |

If a conflict exists between the ICA documentation and the executable DDL, **DDL wins for column names/types**. The ICA documents govern business rules (allowed values, calculation formulas, rejection logic).

### 5.2 No runtime dependency

The running Spring Boot application reads `application.yml` only. It does NOT connect to ICA/MCP at runtime. Context files are consumed by:
- Human developers during design
- AI assistant tools (Copilot, IBM Bob) for code generation guidance
- ICA governance workflows for lineage and compliance

### 5.3 Tenant customisation

When adapting for a specific tenant:
1. Copy `tenant-adapter-template.yaml`.
2. Fill in all `<PLACEHOLDER>` values.
3. **Do not commit** the completed tenant file (it contains real identifiers).
4. Use the completed file only inside your ICA tenant workspace.

---

## 6. Post-import verification queries (ICA)

After import, verify the following lineage links are resolvable in your ICA environment:

| Lineage relationship | Expected |
|---|---|
| `STAGING.VW_DAILY_CUSTOMER_EXPORT` → `TGT_CUSTOMER` | Column-level lineage via `column-mappings.yaml` |
| `STAGING.VW_DAILY_CUSTOMER_ACCOUNT_EXPORT` → `TGT_ENERGY_ACCOUNT` | Same |
| `STAGING.VW_MONTHLY_USAGE_BILLING_EXPORT` → `TGT_MONTHLY_USAGE` | Same |
| `REF.CODE_VALUE.ATTRIBUTES` → `TGT_MONTHLY_USAGE.FIXED_CHARGE` | Via TR-BILL-02 in `transformation-rules.yaml` |
| `BILLING.MONTHLY_USAGE.KWH_USAGE` → `VR-USG-008` | Validation rule in `validation-rules.yaml` |

---

## 7. Security checklist before export

Before exporting or sharing the context package outside the development environment, verify:

```powershell
.\scripts\validate-ica-context.ps1
```

Specifically confirm:
- [ ] No `LJPNAFI-RW79936` (real Snowflake account) in YAML files
- [ ] No `BEGIN PRIVATE KEY` content
- [ ] No real Oracle passwords
- [ ] All files are vendor-neutral (no tenant-specific values)

The package is safe to import if `validate-ica-context.ps1` reports 0 failures.

---

## 8. Updating the context package

When the source DDL changes (new Snowflake columns, new Oracle tables):

1. Update the relevant YAML files in `ica-mcp-context/`.
2. Update `context-index.json` if new files are added.
3. Bump `version` in `manifest.yaml`.
4. Re-run `.\scripts\validate-ica-context.ps1`.
5. Re-import into ICA following section 4.

**Do not modify already-applied Flyway migrations (V001-V004)**. Oracle schema changes require a new `V005` or later migration.

---

## 9. Related documentation

| Document | Location |
|---|---|
| Quick-start and demo walkthrough | `README.md` |
| ICA setup guide | `docs/ica-mcp-setup-guide.md` |
| ICA rule → Java traceability | `docs/ica-mcp-validation.md` |
| JSON import bundle | `docs/ica-context/ica-context-bundle.json` |
| Context index | `ica-mcp-context/context-index.json` |
