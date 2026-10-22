from datetime import datetime, timedelta, timezone

from airflow.sdk import dag, task

from slussen_load_log import log_load

BATCH_TIME = "{{ (data_interval_end or dag_run.run_after).replace(second=0, microsecond=0).isoformat() }}"


@task.external_python(python="/opt/slussen-venv/bin/python", expect_airflow=False)
def publish(batch_time_iso: str) -> dict:
    from datetime import datetime

    from pipeline_core.producer_jobs import run_ops_producer
    from pipeline_core.storage import S3Store

    return run_ops_producer(S3Store("slussen-lake-qwer"), "/opt/slussen/contracts", datetime.fromisoformat(batch_time_iso))


@dag(
    dag_id="ops_orders_producer",
    schedule="0 */4 * * *",
    start_date=datetime(2026, 10, 22, tzinfo=timezone.utc),
    catchup=False,
    max_active_runs=1,
    default_args={"retries": 2, "retry_delay": timedelta(minutes=5)},
    tags=["slussen", "producer", "ops"],
    doc_md="Operations team producer: one ops_orders batch every 4 hours into landing/, then a LOAD_LOG row. "
    "Idempotent: a re-run of the same DAG run finds its batch decided and logs a skip.",
)
def ops_orders_producer():
    log_load(publish(BATCH_TIME))


ops_orders_producer()