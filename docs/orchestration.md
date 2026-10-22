# Orchestration

Slussen splits orchestration by the shape of the work. Scheduled batch work runs in Apache Airflow; event-driven work per batch runs in AWS Step Functions; loading into Snowflake is continuous through Snowpipe.

| Work | Trigger | Runs in |
| --- | --- | --- |
| Producing ops and finance batches | Schedule (every 4 hours; weekly) | Airflow |
| Platform checks (reconciliation, freshness, data quality) | Schedule (15 minutes after each ops batch) | Airflow |
| Validating a batch against its contract | `_SUCCESS` marker lands in S3 (EventBridge) | Step Functions → Lambda or ECS Fargate |
| Loading validated Parquet and audit files | New object in `validated/` or `audit/contract_violations/` | Snowpipe |

Airflow never validates or loads data itself. It produces batches the same way an external team would, and it checks the platform's results afterwards. The contract gate stays the only path into the lake's validated zone.

## Local runtime

Airflow runs locally in Docker Compose (project `slussen`), by design: a managed environment bills by the hour even when idle, and this platform needs a few task runs per day.

| Part | Setting |
| --- | --- |
| Version | Airflow 3.3.2 on Python 3.13, base image pinned by digest |
| Executor | LocalExecutor (tasks run as scheduler subprocesses; no Redis, no workers) |
| Services | Postgres metadata database, API server, scheduler, DAG processor; no triggerer (no deferrable operators) |
| Network | UI only on `127.0.0.1:8081`; no database port published |
| Project code | `pipeline_core` installed in its own virtual environment inside the image (`/opt/slussen-venv`) from the hashed lock file, so tasks run exactly the versions CI tests; contracts baked into the image |
| Task pattern | S3, Athena and generator work: `@task.external_python` in the project venv. Snowflake work: normal Airflow tasks through the Snowflake provider |
| Secrets | Snowflake connection in AWS Secrets Manager, read through Airflow's secrets backend; Airflow's own keys in a gitignored `.env` |
| Defaults | DAGs paused at creation, `catchup=False`, one active run per DAG, two retries |

## DAGs

| DAG | Schedule (UTC) | What it does |
| --- | --- | --- |
| `ops_orders_producer` | `0 */4 * * *` | Builds one ops batch from the Olist catalog and the open orders of the last 7 days, publishes data files first and `_SUCCESS` last, writes one `AUDIT.LOAD_LOG` row |
| `finance_settlements_producer` | `0 5 * * 1` | Derives the weekly settlement batch from last week's validated ops payments |
| `platform_checks` | `15 */4 * * *` | Reconciliation, freshness and data quality; results in `AUDIT.DQ_RESULTS` and `AUDIT.FRESHNESS_STATUS` |
| `snowflake_connection_check` | manual | One-row identity check through the secrets backend |

Producers are idempotent. The batch time comes from the DAG run, the seed is fixed per feed, sources are read only from before the batch time, and a batch that is already validated, quarantined or still in flight is skipped. A retry or a re-run therefore rebuilds the identical batch and skips it, which also makes missed slots safe to backfill.

## Platform checks

`platform_checks` has three task groups. Each group alternates between the project venv (logic from `pipeline_core.checks`) and Airflow tasks (Snowflake reads and writes), and every Snowflake task uses one connection.

| Group | Checks | Fails the run when |
| --- | --- | --- |
| `reconciliation` | Athena over `validated/` vs Snowflake Bronze for `ops_orders`, `olist_order_items` and `olist_customers`: row counts, distinct keys and money sums, compared as decimals | Any metric differs |
| `freshness` | Age of the latest Bronze load per contract against its SLA: ops 5 hours; finance by Monday 06:00 UTC; one-off backfills not applicable | A feed is late or has no data |
| `data_quality` | `event_id` unique across batches; `landing/` empty at rest (nothing older than 1 hour); ops items with an unknown product (last 24 hours); Olist orders without a payment | A check with severity `error` finds failures; `warn` checks only record |

Results are written before the run fails, and a blocking finding raises a non-retryable failure, so a red check never writes its audit rows twice. The audit tables are append-only histories with `dag_id`, `run_id` and `task_id`, and they hold counts only, never record values. The checks run 15 minutes after each ops batch so that the producer's load-log write and the checks share one warehouse wake-up.

## Identity

| | Local (this repository) | Production target |
| --- | --- | --- |
| AWS | The scheduler alone holds AWS credentials: a narrow role `slussen-airflow`, assumed from the engineer's IAM Identity Center session, shared through the SSO token cache | An execution role attached to the Airflow environment |
| Snowflake | Service user `SVC_AIRFLOW` (key pair only) with `ORCHESTRATOR_ROLE`: read Bronze, write audit tables | Unchanged |
| Secrets | AWS Secrets Manager | Unchanged |

The local setup has two known limits. Runs depend on a human SSO session, which ends after 8 hours, so unattended runs fail on credentials until the next login. And the shared SSO token could, in principle, obtain any permission set the engineer has. An execution role removes both. The narrow role's policy becomes the execution role's policy, and the DAG code doesn't change.

## Production target: Amazon MWAA

| Local | Amazon MWAA |
| --- | --- |
| DAGs folder bind-mounted into Compose | DAGs synced to the environment's S3 bucket by CI |
| Image with the project venv | `pipeline_core` and its locked dependencies provided to the environment (requirements file or startup script), keeping the venv separation |
| SSO-chained role | Environment execution role |
| Secrets Manager backend | Same backend and prefix |
| Postgres in Compose | Managed metadata database |
| UI on localhost | Private web server access through IAM |

Two things to check before moving: which Airflow 3 versions the service supports at that time, and how the venv-per-project pattern maps onto its package installation options.

## Mapping to Prefect

The design carries over to Prefect without structural changes:

| Airflow | Prefect |
| --- | --- |
| DAG | Flow |
| Task, task group | Task, subflow |
| Cron schedule on the DAG | Schedule on a deployment |
| Connection through the Secrets Manager backend | Block (for example an AWS credentials or secret block) |
| `external_python` venv | Work pool and worker running the project's own environment |
| Retries per task | Retries per task |
| Run failure on a blocking check | Failed flow run, alerted through an automation |

Idempotent producers, the audit tables and the split between scheduled and event-driven work don't depend on the orchestrator.
