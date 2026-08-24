# =============================================================================
# set-local-env.template.ps1 — CDP Loader Local Environment Setup Template
# =============================================================================
# INSTRUCTIONS
# 1. Copy this file to scripts/set-local-env.ps1
# 2. Fill in your actual values below (never commit set-local-env.ps1)
# 3. Run: . .\scripts\set-local-env.ps1
#    (dot-source to set vars in current shell)
# =============================================================================

# --- Oracle ---
$env:CDP_ORACLE_JDBC_URL   = "jdbc:oracle:thin:@//localhost:1521/FREEPDB1"
$env:CDP_ORACLE_USERNAME   = "CDP_LOADER"
$env:CDP_ORACLE_PASSWORD   = "<YOUR_ORACLE_PASSWORD_HERE>"

# --- Snowflake ---
$env:CDP_SNOWFLAKE_ACCOUNT          = "QI79280.ap-southeast-7.aws"
$env:CDP_SNOWFLAKE_USER             = "SVC_CDP_LOADER"
$env:CDP_SNOWFLAKE_ROLE             = "CDP_LOADER_ROLE"
$env:CDP_SNOWFLAKE_WAREHOUSE        = "CDP_LOADER_WH"
$env:CDP_SNOWFLAKE_DATABASE         = "CDP_UTIL_DB"
$env:CDP_SNOWFLAKE_PRIVATE_KEY_PATH = "<ABSOLUTE_PATH_TO_YOUR_snowflake_rsa_key.p8>"
# Example: "C:\Users\YourUser\.cdp-loader\keys\snowflake_rsa_key.p8"

Write-Host "Environment variables set (passwords not printed)." -ForegroundColor Green
Write-Host "Oracle URL  : $env:CDP_ORACLE_JDBC_URL"
Write-Host "Oracle User : $env:CDP_ORACLE_USERNAME"
Write-Host "SF Account  : $env:CDP_SNOWFLAKE_ACCOUNT"
Write-Host "SF User     : $env:CDP_SNOWFLAKE_USER"
Write-Host "SF Role     : $env:CDP_SNOWFLAKE_ROLE"
Write-Host "SF Warehouse: $env:CDP_SNOWFLAKE_WAREHOUSE"
Write-Host "SF Database : $env:CDP_SNOWFLAKE_DATABASE"
Write-Host "Key path set: $( if ($env:CDP_SNOWFLAKE_PRIVATE_KEY_PATH -and $env:CDP_SNOWFLAKE_PRIVATE_KEY_PATH -ne '<ABSOLUTE_PATH_TO_YOUR_snowflake_rsa_key.p8>') { 'YES' } else { 'NOT SET — update this template' } )"
