# Slussen Terraform

Terraform adoption of the **existing** Slussen Snowflake objects. Session 1
brings them under management *without changing them*: the configuration
mirrors the live objects exactly and `imports.tf` adopts them into state.
The AWS provider and AWS resources follow in session 2.

| | |
|---|---|
| Terraform | `1.11.4` (exact) |
| Provider | `snowflakedb/snowflake` `2.22.0` (exact; lock file committed with Windows, Linux and macOS hashes) |
| State | S3, key `slussen/terraform.tfstate`, `eu-north-1`, encrypted, native S3 lockfile |
| Identity | `TERRAFORM_SVC` user, `TERRAFORM_ROLE`, key-pair (JWT) auth |

## What is managed

Source of truth for current values: `inventory/snowflake_inventory_2026-11-05.csv`
(trimmed to the in-scope objects; `DETAILS` is the `SHOW` output as JSON).

| File | Objects |
|---|---|
| `warehouses.tf` | `BI_WH`, `COMPUTE_WH`, `LOAD_WH`, `TRANSFORM_WH` |
| `databases.tf` | database `ECOM_DB`; schemas `AUDIT`, `BRONZE`, `SILVER`, `GOLD`, `GOVERNANCE` (all managed access) |
| `resource_monitors.tf` | `SLUSSEN_MONITOR` (25 credits, monthly, notify 50/80 %, suspend 100 %, suspend immediately 110 %) |
| `imports.tf` | 11 `import` blocks for the objects above |

Things that are deliberate and easy to break:

- **Warehouse `resource_monitor`** is unset on every warehouse; `SLUSSEN_MONITOR`
  is attached at **account** level. Only ACCOUNTADMIN can change warehouse
  monitor assignments, so it is left unset and listed in `ignore_changes`.
- **`initially_suspended`** only matters at create time and is ignored.
- **Default-valued attributes are pinned** (`warehouse_type`, `generation`,
  cluster counts, `scaling_policy` on warehouses; `is_transient = "false"` on
  schemas). If you remove them, the provider plans an `UNSET` or, for
  `is_transient`, a **destroy and recreate** of the schema.
- **`statement_timeout_in_seconds`** is set at object level on `BI_WH` (600)
  and `LOAD_WH` / `TRANSFORM_WH` (1800). It is not in the `SHOW WAREHOUSES`
  inventory but is read back by the provider.
- **`SLUSSEN_MONITOR` `start_timestamp`** is the provider's read-back of
  2026-10-14 13:42:42.053 UTC rendered in the session time zone
  (`+02:00`). The provider requires it whenever `frequency` is set. If the
  service user's `TIMEZONE` changes, this line can show a diff.
- `SLUSSEN_MONITOR` is owned by ACCOUNTADMIN; `TERRAFORM_ROLE` has
  `MONITOR` + `MODIFY` on it, which is enough to read and alter quota/triggers.

## Out of scope (not managed here, and why)

| Object(s) | Reason |
|---|---|
| `ADMIN_DB` and its schemas | Account-administration objects owned by ACCOUNTADMIN |
| `SANDBOX`, `SNOWFLAKE_LEARNING_DB`, `USER$…` | Personal / scratch / Snowflake-provisioned, not platform |
| `PUBLIC` schemas | Snowflake-created defaults, unused by the platform |
| `SYSTEM$…` warehouses | Snowflake-managed |
| Integrations (e.g. the S3 storage integration) | Require ACCOUNTADMIN; coupled to AWS IAM (session 2+) |
| Roles, grants, users | Separate RBAC workstream; adopting them carelessly can revoke access |
| Tables, views, dynamic tables, policies, tags, semantic views | Owned by the SQL deployment in `sql/`, not Terraform |

## Prerequisites

- Terraform `1.11.4`.
- An **encrypted** PKCS#8 key for `TERRAFORM_SVC`, stored **outside** the repo.
- AWS SSO access to the state bucket (`aws sso login --profile <profile>`).

## How to run (PowerShell)

1. Keep a personal env script outside the repo, e.g. `~\.slussen\terraform.env.ps1`
   (never commit it):

   ```powershell
   $env:SNOWFLAKE_ORGANIZATION_NAME     = "<org>"
   $env:SNOWFLAKE_ACCOUNT_NAME          = "<account>"
   $env:SNOWFLAKE_USER                  = "TERRAFORM_SVC"
   $env:SNOWFLAKE_ROLE                  = "TERRAFORM_ROLE"
   $env:SNOWFLAKE_AUTHENTICATOR         = "SNOWFLAKE_JWT"
   $env:TF_VAR_snowflake_private_key_path = "$HOME\.snowflake\keys\terraform_svc_rsa_key.p8"
   $env:AWS_PROFILE                     = "<sso-profile>"
   $env:TF_STATE_BUCKET                 = "<state-bucket-name>"
   ```

2. Load it into the current shell (dot-source), then set the key passphrase
   interactively so it never lands in a file or in shell history:

   ```powershell
   . $HOME\.slussen\terraform.env.ps1

   $sec = Read-Host "Key passphrase" -AsSecureString
   $env:SNOWFLAKE_PRIVATE_KEY_PASSPHRASE = [Runtime.InteropServices.Marshal]::PtrToStringAuto(
     [Runtime.InteropServices.Marshal]::SecureStringToBSTR($sec))
   ```

3. Initialise with the bucket supplied at init time (it is not in code):

   ```powershell
   cd infra\terraform
   terraform init -backend-config="bucket=$env:TF_STATE_BUCKET"
   ```

4. Check and plan:

   ```powershell
   terraform fmt -check
   terraform validate
   terraform plan
   ```

   Expected on first adoption:
   `Plan: 11 to import, 0 to add, 0 to change, 0 to destroy.`

**Stop if a plan shows any destroy, "must be replaced", or an in-place change
on an imported object.** Fix the HCL to match the live object; never change the
real object to make the plan clean. `terraform apply` is run only after the
plan has been reviewed.

## Secrets

No account identifiers, bucket names, keys or passphrases are committed.
`.gitignore` excludes `.terraform/`, `*.tfstate*`, `*.tfvars` (except
`*.tfvars.example`), `*.p8`, `*.pem` and `crash.log`.
