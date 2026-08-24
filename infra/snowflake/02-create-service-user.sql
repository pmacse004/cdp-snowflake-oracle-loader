-- =============================================================================
-- Snowflake Provisioning -- Step 2: Service User
-- =============================================================================
-- Run as: ACCOUNTADMIN
-- Account: QI79280 (AWS AP_SOUTHEAST_7)
--
-- PREREQUISITES
--   1. Script 01 must have been executed (CDP_LOADER_ROLE must exist).
--   2. Generate an RSA key pair on the developer workstation FIRST:
--        .\infra\snowflake\keygen.ps1
--   3. Copy the PUBLIC key base-64 body (without header/footer lines) and
--      paste it to replace <<PASTE_RSA_PUBLIC_KEY_HERE>> below.
--
-- IDEMPOTENCY
--   CREATE USER IF NOT EXISTS is used.
--   If the user already exists but the public key needs rotating:
--     ALTER USER SVC_CDP_LOADER SET RSA_PUBLIC_KEY = '<new-key>';
--
-- PLACEHOLDER GUARD
--   The script will FAIL at the DESCRIBE step with a clear error if the
--   placeholder was not replaced, because <<...>> is not a valid key.
--   Do not execute this script before replacing the placeholder.
--
-- SECURITY NOTES
--   - No PASSWORD is set. Authentication is RSA key-pair only.
--   - The public key is NOT a secret. The private key MUST stay off source control.
-- =============================================================================

USE ROLE ACCOUNTADMIN;

-- ---------------------------------------------------------------------------
-- 1.  Create the service user
-- ---------------------------------------------------------------------------
-- TYPE = SERVICE: disables interactive login, disables password auth,
-- disables MFA prompt -- appropriate for a machine service account.
-- Supported on Snowflake Business Critical and above; on lower editions
-- it is silently accepted as USER (test with DESC USER after creation).
--
-- Replace <<PASTE_RSA_PUBLIC_KEY_HERE>> with the base-64 public key body.
-- The placeholder string intentionally contains angle brackets which are
-- invalid in a real RSA key, so the user object will fail key validation
-- if you forget to replace it.
-- ---------------------------------------------------------------------------
CREATE USER IF NOT EXISTS SVC_CDP_LOADER
    TYPE                = SERVICE
    LOGIN_NAME          = 'SVC_CDP_LOADER'
    DISPLAY_NAME        = 'CDP Oracle Loader Service Account'
    COMMENT             = 'Least-privilege service account for CDP Snowflake-to-Oracle ETL'
    DEFAULT_ROLE        = CDP_LOADER_ROLE
    DEFAULT_WAREHOUSE   = CDP_LOADER_WH
    DEFAULT_NAMESPACE   = CDP_UTIL_DB
    RSA_PUBLIC_KEY      = 'MIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEA4H8XV7GneYEwOMGbZ6YM
F4l94TJY37xV+poXvNhGmkExAWW5EfzPkC1CgfhXHyhXv6pLtr5/NsqOQ8lwSbmk
7nPNNYstLtzmT9JIsdztO3JTVXWNMHJrCe6RlyKWd8b5P4FDFM5Zs06GH5afblLw
oh1o00Rm/nx3CEuDd3iSOV4T4P3a1CddAmGaROb0xyQvdO22tTEX6Yu0pefFIpPY
1WNT9d91t2g2/ormLtJ+JVd7+xOdVUppLNrAa1NmqU5m+7td5bC0TRxFYc3r17ue
7LU54getYUpImGqsHwF5ft7/WI8JzWnvsLnYpIf5Sha7pl6uOgalpnGflXlehjjO
MwIDAQAB';

-- ---------------------------------------------------------------------------
-- 2.  Assign the dedicated role
-- ---------------------------------------------------------------------------
GRANT ROLE CDP_LOADER_ROLE TO USER SVC_CDP_LOADER;

-- ---------------------------------------------------------------------------
-- 3.  Verification
--     If RSA_PUBLIC_KEY is still the placeholder value, the DESC command
--     will show it clearly. The application will fail to authenticate until
--     a valid key is set.
-- ---------------------------------------------------------------------------
SHOW USERS LIKE 'SVC_CDP_LOADER';
DESC USER SVC_CDP_LOADER;

-- ---------------------------------------------------------------------------
-- Rollback / cleanup (if needed):
--   DROP USER IF EXISTS SVC_CDP_LOADER;
-- ---------------------------------------------------------------------------
