from datetime import datetime, timedelta, timezone

from airflow.sdk import dag, task

from slussen_load_log import log_load

BATCH_TIME = "{{ (data_interval_end or dag_run.run_after).replace(second=0, microsecond=0).isoformat() }}"


@task.external_python(python="/opt/slussen-venv/bin/python", expect_airflow=False)
def publish(batch_time_iso: str) -> dict:
    from datetime import datetime

    from pipeline_core.producer_jobs import run_finance_producer
    from pipeline_core.storage import S3Store

    return run_finance_producer(S3Store("slussen-lake-qwer"), "/opt/slussen/contracts", datetime.fromisoformat(batch_time_iso))


@dag(
    dag_id="finance_settlements_producer",
    schedule="0 5 * * 1",
    start_date=datetime(2026, 10, 19, tzinfo=timezone.utc),
    catchup=False,
    max_active_runs=1,
    default_args={"retries": 2, "retry_delay": timedelta(minutes=10)},
    tags=["slussen", "producer", "finance"],
    doc_md="Finance team producer: every Monday 05:00 UTC, settlements for last week's paid ops orders "
    "(contract deadline 06:00), then a LOAD_LOG row. Skips an empty week.",
)
def finance_settlements_producer():
    log_load(publish(BATCH_TIME))


finance_settlements_producer()