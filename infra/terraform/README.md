# Slussen Terraform

Terraform adoption of the **existing** Slussen Snowflake and AWS objects,
brought under management *without changing them*: the configuration mirrors
the live objects exactly and `imports.tf` adopts them into state. Session 1
covered warehouses, `ECOM_DB` and the resource monitor; session 2 added the S3
storage integration, its IAM role and the two S3 buckets.

| | |
|---|---|
| Terraform | `1.11.4` (exact) |
| Providers | `snowflakedb/snowflake` `2.22.0`, `hashicorp/aws` `6.69.1` (exact; lock file committed with Windows, Linux and macOS hashes) |
| State | S3, key `slussen/terraform.tfstate`, `eu-north-1`, encrypted, native S3 lockfile |
| Identity | Snowflake: `TERRAFORM_SVC` user, `TERRAFORM_ROLE`, key-pair (JWT) auth. AWS: SSO via `AWS_PROFILE`, region `eu-north-1` |

## What is managed

Source of truth for current Snowflake values: `inventory/snowflake_inventory_2026-11-05.csv`
(trimmed to the in-scope objects; `DETAILS` is the `SHOW` output as JSON).

| File | Objects |
|---|---|
| `warehouses.tf` | `BI_WH`, `COMPUTE_WH`, `LOAD_WH`, `TRANSFORM_WH` |
| `databases.tf` | database `ECOM_DB`; schemas `AUDIT`, `BRONZE`, `SILVER`, `GOLD`, `GOVERNANCE` (all managed access) |
| `resource_monitors.tf` | `SLUSSEN_MONITOR` (25 credits, monthly, notify 50/80 %, suspend 100 %, suspend immediately 110 %) |
| `storage_integration.tf` | `SLUSSEN_S3_INT` (owned by SYSADMIN; allowed locations `validated/` and `audit/contract_violations/` only) |
| `iam.tf` | IAM role `slussen-snowflake-integration` and its single inline policy `slussen-snowflake-read` (no attached managed policies) |
| `s3.tf` | `slussen-lake-qwer` and the state bucket: `aws_s3_bucket`, `aws_s3_bucket_versioning`, `aws_s3_bucket_public_access_block` only |
| `imports.tf` | 20 `import` blocks for the objects above (11 from session 1, 9 from session 2) |

The integration's role ARN is built from `data.aws_caller_identity`, and the
KMS key ARN in the inline policy comes from `data.aws_kms_key` (alias
`alias/slussen-data`); no account ID or key ARN is committed. The state bucket name comes from
`var.state_bucket_name` (`TF_VAR_state_bucket_name`) because it contains the
account ID.

### Snowflake: things that are deliberate and easy to break

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

### Storage integration and the IAM trust policy

- **The trust policy is built from `describe_output`, not from the top-level
  attributes.** `iam.tf` reads the IAM user ARN and the external ID from
  `snowflake_storage_integration.slussen_s3_int.describe_output[0]` (the
  provider's `DESC INTEGRATION` read-back). The top-level
  `storage_aws_external_id` is an optional *input* that the provider does not
  read back on import, so it is null in state. Building the trust policy from
  it planned an in-place change that dropped the `sts:ExternalId` condition.
  That would remove the confused-deputy protection: any Snowflake account that
  shares the same Snowflake-side IAM user could then assume the role. Reading
  both values from `describe_output` keeps the live values and commits
  neither the external ID nor Snowflake's AWS account ID.
- **Caveat:** `describe_output` becomes "known after apply" whenever the
  integration itself has a pending change. In that plan the IAM role also
  shows an update, because its trust policy is unknown. The values only really
  change if the integration is recreated. Plan integration changes on their
  own and confirm the role is clean on the next plan.
- **`snowflake_storage_integration` is deprecated in provider 2.22.0** in
  favour of `snowflake_storage_integration_aws`. It is a preview resource and
  only works with `preview_features_enabled =
  ["snowflake_storage_integration_resource"]` on the Snowflake provider
  (`providers.tf`).
- `storage_blocked_locations` is left unset (the live list is empty, and `[]`
  plans a diff). `use_privatelink_endpoint = "false"` is pinned; leaving it
  out plans a change to `"default"`.
- **Follow-up:** migrate to `snowflake_storage_integration_aws` later with a
  `moved` block (or `removed` + `import` if the provider does not support the
  cross-type move), never by destroying and recreating the integration. A
  recreate issues a new external ID and breaks every stage and Snowpipe until
  the trust policy catches up.

### AWS

- **Tags** on the IAM role and the lake bucket (`project = slussen`) are out of
  scope and listed in `ignore_changes`.
- **Not managed on the buckets:** bucket policies, event notifications,
  lifecycle rules and default encryption. They are wired to EventBridge (the
  contract gate), Snowpipe and KMS, and adopting them carelessly could cut that
  wiring. Both buckets have `prevent_destroy`.
- The KMS key that encrypts the lake is looked up by alias
  (`data.aws_kms_key.lake`) for the inline policy but is not managed.
- Only `slussen-lake-qwer` and the state bucket exist with the `slussen`
  prefix (checked 2026-11-05); there are no other buckets to adopt.

## Out of scope (not managed here, and why)

| Object(s) | Reason |
|---|---|
| Tags, row access policies, masking policies | **D8.10:** owned by `PLATFORM_ADMIN` and deployed via `sql/governance/`. Governance stays with the role accountable for data protection, separate from the infrastructure identity; if `TERRAFORM_ROLE` owned or altered policies, an infrastructure change could silently weaken masking or row access |
| `ADMIN_DB` and its schemas | Account-administration objects owned by ACCOUNTADMIN |
| `SANDBOX`, `SNOWFLAKE_LEARNING_DB`, `USER$…` | Personal / scratch / Snowflake-provisioned, not platform |
| `PUBLIC` schemas | Snowflake-created defaults, unused by the platform |
| `SYSTEM$…` warehouses | Snowflake-managed |
| Roles, grants, users | Separate RBAC workstream; adopting them carelessly can revoke access |
| Tables, views, dynamic tables, stages, pipes, semantic views | Owned by the SQL deployment in `sql/`, not Terraform |
| Bucket policies, notifications, lifecycle, encryption; KMS keys; AWS tags | Wired to EventBridge, Snowpipe and KMS; see "AWS" above |

## Prerequisites

- Terraform `1.11.4`.
- An **encrypted** PKCS#8 key for `TERRAFORM_SVC`, stored **outside** the repo.
- AWS SSO access (`AWS_PROFILE`) to the state bucket, IAM and S3.

## How to run (Windows cmd)

The environment comes from a personal script **outside the repo**,
`%USERPROFILE%\.snowflake\tf_env.cmd`. It holds no secrets and sets only:

- `SNOWFLAKE_ORGANIZATION_NAME`
- `SNOWFLAKE_ACCOUNT_NAME`
- `SNOWFLAKE_USER`
- `SNOWFLAKE_ROLE`
- `SNOWFLAKE_AUTHENTICATOR`
- `TF_VAR_snowflake_private_key_path`
- `AWS_PROFILE`
- `TF_STATE_BUCKET`
- `TF_VAR_state_bucket_name` (same value as `TF_STATE_BUCKET`; set below if the script does not)

```bat
call %USERPROFILE%\.snowflake\tf_env.cmd
set TF_VAR_state_bucket_name=%TF_STATE_BUCKET%
set /p SNOWFLAKE_PRIVATE_KEY_PASSPHRASE=Passphrase:
cls
aws sso login --profile %AWS_PROFILE%
cd infra\terraform
terraform init -backend-config="bucket=%TF_STATE_BUCKET%"
terraform plan
```

The passphrase lives only in the current cmd session; `cls` clears it from
the screen. The bucket name is supplied at init time and never committed.

Expected on first adoption: `Plan: 11 to import, …` (session 1), then
`Plan: 9 to import, 0 to add, 0 to change, 0 to destroy.` (session 2).
After the imports are applied: `No changes.`

**Stop if a plan shows any destroy, "must be replaced", or an in-place change
on an imported object.** Fix the HCL to match the live object; never change the
real object to make the plan clean. `terraform apply` is run only after the
plan has been reviewed.

## Secrets

No account identifiers, bucket names, keys or passphrases are committed.
`.gitignore` excludes `.terraform/`, `*.tfstate*`, `*.tfvars` (except
`*.tfvars.example`), `*.tfplan`, `*.p8`, `*.pem` and `crash.log`.
