from pathlib import Path

import pendulum
from airflow.sdk import dag, task, task_group

from slussen_audit import record_results, snowflake_first_rows

VENV = "/opt/slussen-venv/bin/python"
LAKE_BUCKET = "slussen-lake-qwer"
DQ_CHECKS = {
    "ops_event_id_unique": ["BRONZE.OPS_ORDERS", "error"],
    "ops_items_unknown_product": ["BRONZE.OPS_ORDERS", "warn"],
    "olist_orders_without_payment": ["BRONZE.OLIST_ORDERS", "warn"],
}
DQ_QUERIES = {name: (Path(__file__).parent / "sql" / "dq" / f"{name}.sql").read_text() for name in DQ_CHECKS}


@task.external_python(python=VENV, expect_airflow=False, multiple_outputs=True)
def athena_metrics() -> dict:
    import boto3
    from pipeline_core.checks.athena import fetch_one_row
    from pipeline_core.checks.reconciliation import RECONCILED, athena_sql, snowflake_sql

    client = boto3.client("athena", region_name="eu-north-1")
    return {
        "athena": {t: fetch_one_row(client, athena_sql(t), "slussen", "slussen_lake") for t in RECONCILED},
        "queries": {t: snowflake_sql(t) for t in RECONCILED},
    }


@task.external_python(python=VENV, expect_airflow=False, multiple_outputs=False)
def compare_metrics(athena: dict, snowflake: dict) -> dict:
    from pipeline_core.checks.reconciliation import compare
    from pipeline_core.checks.results import blocking

    results = [compare(t, athena[t], snowflake[t]) for t in athena]
    return {"rows": [r.as_row() for r in results], "blocking": [r.check_name for r in blocking(results)]}


@task.external_python(python=VENV, expect_airflow=False, multiple_outputs=False)
def freshness_queries() -> dict:
    from pathlib import Path

    from pipeline_core.contracts import load_contract

    out = {}
    for path in sorted(Path("/opt/slussen/contracts").glob("*.yaml")):
        name = load_contract(path).name
        out[name] = f"SELECT CONVERT_TIMEZONE('UTC', MAX(_loaded_at)) FROM ECOM_DB.BRONZE.{name.upper()}"
    return out


@task.external_python(python=VENV, expect_airflow=False, multiple_outputs=False)
def evaluate_freshness_rows(loaded: dict) -> dict:
    from datetime import datetime, timezone
    from pathlib import Path

    from pipeline_core.checks.freshness import blocking, evaluate_freshness
    from pipeline_core.contracts import load_contract

    now = datetime.now(timezone.utc)
    results = []
    for path in sorted(Path("/opt/slussen/contracts").glob("*.yaml")):
        contract = load_contract(path)
        raw = loaded[contract.name][0]
        last = datetime.fromisoformat(raw) if raw else None
        results.append(evaluate_freshness(contract, f"BRONZE.{contract.name.upper()}", last, now))
    rows = []
    for r in results:
        row = r.as_row()
        row["last_loaded_at"] = r.last_loaded_at.isoformat() if r.last_loaded_at else None
        rows.append(row)
    return {"rows": rows, "blocking": [r.dataset for r in blocking(results)]}


@task.external_python(python=VENV, expect_airflow=False, multiple_outputs=False)
def landing_row(bucket: str) -> dict:
    from datetime import datetime, timezone

    import boto3
    from pipeline_core.checks.landing import landing_at_rest, list_objects

    client = boto3.client("s3", region_name="eu-north-1")
    return landing_at_rest(list_objects(client, bucket), datetime.now(timezone.utc)).as_row()


@task.external_python(python=VENV, expect_airflow=False, multiple_outputs=False)
def evaluate_dq(values: dict, checks: dict, landing: dict) -> dict:
    from pipeline_core.checks.results import CheckResult, blocking, evaluate

    results = []
    for name, (dataset, severity) in checks.items():
        checked, failing = (int(v) for v in values[name])
        results.append(evaluate(name, dataset, severity, checked, failing, f"{failing} of {checked} failing"))
    results.append(CheckResult(**landing))
    return {"rows": [r.as_row() for r in results], "blocking": [r.check_name for r in blocking(results)]}


@dag(
    dag_id="platform_checks",
    schedule="15 */4 * * *",
    start_date=pendulum.datetime(2026, 10, 1, tz="UTC"),
    catchup=False,
    max_active_runs=1,
    default_args={"retries": 2, "retry_delay": pendulum.duration(minutes=2)},
    tags=["slussen", "checks"],
)
def platform_checks():
    @task_group(group_id="reconciliation")
    def reconciliation():
        metrics = athena_metrics()
        snowflake = snowflake_first_rows(metrics["queries"])
        record_results(compare_metrics(metrics["athena"], snowflake), "dq")

    @task_group(group_id="freshness")
    def freshness():
        loaded = snowflake_first_rows(freshness_queries())
        record_results(evaluate_freshness_rows(loaded), "freshness")

    @task_group(group_id="data_quality")
    def data_quality():
        values = snowflake_first_rows(DQ_QUERIES)
        record_results(evaluate_dq(values, DQ_CHECKS, landing_row(LAKE_BUCKET)), "dq")

    reconciliation()
    freshness()
    data_quality()


platform_checks()