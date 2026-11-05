# Slussen Terraform

Terraform adoption of the **existing** Slussen Snowflake and AWS objects,
brought under management *without changing them*: the configuration mirrors
the live objects exactly and `imports.tf` adopts them into state. Session 1
covered warehouses, `ECOM_DB` and the resource monitor; session 2 added the S3
storage integration, its IAM role and the two S3 buckets; session 3 added
account roles, the role hierarchy and privilege grants on the managed objects.

| | |
|---|---|
| Terraform | `1.11.4` (exact) |
| Providers | `snowflakedb/snowflake` `2.22.0`, `hashicorp/aws` `6.69.1` (exact; lock file committed with Windows, Linux and macOS hashes) |
| State | S3, key `slussen/terraform.tfstate`, `eu-north-1`, encrypted, native S3 lockfile |
| Identity | Snowflake: `TERRAFORM_SVC` user, `TERRAFORM_ROLE`, key-pair (JWT) auth. AWS: SSO via `AWS_PROFILE`, region `eu-north-1` |

## What is managed

Source of truth for current Snowflake values: `inventory/snowflake_inventory_2026-11-05.csv`
(trimmed to the in-scope objects; `DETAILS` is the `SHOW` output as JSON) and
`inventory/snowflake_grants_2026-11-05.csv` (`ACCOUNT_USAGE.GRANTS_TO_ROLES`,
trimmed from 273 to the 86 in-scope rows).

| File | Objects |
|---|---|
| `warehouses.tf` | `BI_WH`, `COMPUTE_WH`, `LOAD_WH`, `TRANSFORM_WH` |
| `databases.tf` | database `ECOM_DB`; schemas `AUDIT`, `BRONZE`, `SILVER`, `GOLD`, `GOVERNANCE` (all managed access) |
| `resource_monitors.tf` | `SLUSSEN_MONITOR` (25 credits, monthly, notify 50/80 %, suspend 100 %, suspend immediately 110 %) |
| `storage_integration.tf` | `SLUSSEN_S3_INT` (owned by SYSADMIN; allowed locations `validated/` and `audit/contract_violations/` only) |
| `iam.tf` | IAM role `slussen-snowflake-integration` and its single inline policy `slussen-snowflake-read` (no attached managed policies) |
| `s3.tf` | `slussen-lake-qwer` and the state bucket: `aws_s3_bucket`, `aws_s3_bucket_versioning`, `aws_s3_bucket_public_access_block` only |
| `roles.tf` | 25 account roles, 42 role-to-role grants, 18 privilege grants (grouped per role and object), and their three `for_each` `import` blocks |
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

### Roles and grants

`roles.tf` is driven by three locals, so adding a role or grant is a one-line
change:

- `account_roles`: role name => comment. Only `ORCHESTRATOR_ROLE` has a
  comment (`Airflow: reads Bronze, writes Audit results`); the other 24 are
  `null`, which matches the live roles.
- `role_hierarchy`: parent role => granted roles. Built from the `GRANTED_ON =
  ROLE` rows where both sides are in `account_roles` (42 grants).
- `privilege_grants`: one entry per (role, object) with its privileges grouped
  (18 resources covering 44 CSV rows): `USAGE` on `ECOM_DB`; `USAGE` / `CREATE …`
  on the `AUDIT`, `BRONZE`, `SILVER`, `GOLD` schemas; `MONITOR`, `OPERATE`,
  `USAGE` on `BI_WH`, `LOAD_WH`, `TRANSFORM_WH`; `USAGE` on `SLUSSEN_S3_INT`;
  `EXECUTE TASK` + `EXECUTE MANAGED TASK` on the account for `TASK_EXECUTE`.
  No in-scope grant on `COMPUTE_WH` or `GOVERNANCE` exists (the only ones are
  to `PLATFORM_ADMIN`, see below).

Things that are deliberate:

- **`with_grant_option = false` on every grant**, matching `GRANT_OPTION =
  FALSE` in the inventory. Flipping it plans a revoke and re-grant.
- **`snowflake_grant_privileges_to_account_role` only tracks the privileges it
  lists.** Live privileges not in the list (e.g. `OWNERSHIP`, object-level
  grants) are ignored, not revoked. Removing a privilege from a list *does*
  revoke it.
- **`PLATFORM_ADMIN` is managed as a role only (D8.10).** Its grants are owned
  by the governance deployment and are not in Terraform.
- **Never revoke or add a grant in Snowflake to make a plan clean.** If a grant
  diffs, fix the locals to match the account.
- In the committed CSV, the account locator in `NAME` for the two `ACCOUNT`
  rows is redacted to `<ACCOUNT_LOCATOR>`; Terraform does not use it
  (`on_account = true`).

## Out of scope (not managed here, and why)

| Object(s) | Reason |
|---|---|
| Tags, row access policies, masking policies | **D8.10:** owned by `PLATFORM_ADMIN` and deployed via `sql/governance/`. Governance stays with the role accountable for data protection, separate from the infrastructure identity; if `TERRAFORM_ROLE` owned or altered policies, an infrastructure change could silently weaken masking or row access |
| `ADMIN_DB` and its schemas | Account-administration objects owned by ACCOUNTADMIN |
| `SANDBOX`, `SNOWFLAKE_LEARNING_DB`, `USER$…` | Personal / scratch / Snowflake-provisioned, not platform |
| `PUBLIC` schemas | Snowflake-created defaults, unused by the platform |
| `SYSTEM$…` warehouses | Snowflake-managed |
| Users; `SNOWFLAKE_LEARNING_ROLE`; system roles | Users are a separate workstream; the learning role is Snowflake-provisioned; system roles are Snowflake-owned |
| Grants: see "Grants not managed" below | |
| Tables, views, dynamic tables, stages, pipes, semantic views | Owned by the SQL deployment in `sql/`, not Terraform |
| Bucket policies, notifications, lifecycle, encryption; KMS keys; AWS tags | Wired to EventBridge, Snowpipe and KMS; see "AWS" above |

### Grants not managed

Counts are rows of the original 273-row `GRANTS_TO_ROLES` export (each row
counted once, in this order; 86 rows are in scope, 187 are not).

| Grants | Rows | Reason |
|---|---|---|
| `PRIVILEGE = OWNERSHIP` (tables 33, pipes 12, stages 2, file formats 2, views 2, stream 1, task 1) | 53 | Ownership is set by the SQL deployment that creates the object; transferring it through Terraform could break the object's grants and the pipelines that rely on them |
| All other grants **to** `PLATFORM_ADMIN` (account 7, `ECOM_DB` 1, `GOVERNANCE` schema 5, role `DATA_ENGINEER` 1) | 14 | **D8.10:** `PLATFORM_ADMIN` is managed as a role only; its privileges belong to the governance deployment, separate from the infrastructure identity |
| `GRANTED_ON` = `TABLE` (108), `VIEW` (2); `PIPE`, `STAGE`, `STREAM`, `TASK`, `FILE FORMAT` (0 beyond ownership) | 110 | Object-level grants are made by the SQL deployment in `sql/` alongside the objects themselves |
| Anything on `ADMIN_DB`, `SANDBOX` or `SNOWFLAKE_LEARNING_DB` (all on `SNOWFLAKE_LEARNING_DB`, to `SNOWFLAKE_LEARNING_ROLE`) | 2 | Not platform objects (see table above) |
| `USAGE` on role `CORTEX_USER_ROLE` (to the five analysts, `DATA_ENGINEER`, `EXEC`, `PRODUCT_OWNER`) | 8 | `CORTEX_USER_ROLE` is granted by ACCOUNTADMIN and is not in the managed role set, so the hierarchy rule (both sides managed) excludes it |
| Future grants | 0 | Not in `GRANTS_TO_ROLES`. **Follow-up:** inventory with `SHOW FUTURE GRANTS IN SCHEMA …` and adopt with `snowflake_grant_privileges_to_account_role` `on_schema_object.future` |
| Grants of custom roles to system roles (e.g. to `SYSADMIN`) | 0 | The export contains no such rows; they are owned by USERADMIN/SECURITYADMIN, and revoking one would orphan the role from the admin hierarchy |

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
`Plan: 9 to import, 0 to add, 0 to change, 0 to destroy.` (session 2), then
`Plan: 85 to import, 0 to add, 0 to change, 0 to destroy.` (session 3: 25
roles, 42 role grants, 18 privilege grants).
After the imports are applied: `No changes.`

**Stop if a plan shows any destroy, "must be replaced", or an in-place change
on an imported object.** Fix the HCL to match the live object; never change the
real object to make the plan clean. `terraform apply` is run only after the
plan has been reviewed.

## Secrets

No account identifiers, bucket names, keys or passphrases are committed.
`.gitignore` excludes `.terraform/`, `*.tfstate*`, `*.tfvars` (except
`*.tfvars.example`), `*.tfplan`, `*.p8`, `*.pem` and `crash.log`.
