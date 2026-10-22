from datetime import date, datetime
from decimal import Decimal

from airflow.sdk import get_current_context, task

try:
    from airflow.sdk.exceptions import AirflowFailException
except ImportError:
    from airflow.exceptions import AirflowFailException

DQ_SQL = (
    "INSERT INTO ECOM_DB.AUDIT.DQ_RESULTS (checked_at, dag_id, run_id, task_id, check_name, dataset, severity, "
    "status, checked_count, failing_count, detail) "
    "SELECT CURRENT_TIMESTAMP(), %(dag_id)s, %(run_id)s, %(task_id)s, %(check_name)s, %(dataset)s, %(severity)s, "
    "%(status)s, %(checked_count)s, %(failing_count)s, %(detail)s"
)

FRESHNESS_SQL = (
    "INSERT INTO ECOM_DB.AUDIT.FRESHNESS_STATUS (checked_at, dag_id, run_id, dataset, contract, sla_hours, "
    "last_loaded_at, age_hours, status) "
    "SELECT CURRENT_TIMESTAMP(), %(dag_id)s, %(run_id)s, %(dataset)s, %(contract)s, %(sla_hours)s, "
    "TO_TIMESTAMP_TZ(%(last_loaded_at)s), %(age_hours)s, %(status)s"
)

TARGETS = {"dq": DQ_SQL, "freshness": FRESHNESS_SQL}


def _plain(value):
    if isinstance(value, Decimal):
        return str(value)
    if isinstance(value, (datetime, date)):
        return value.isoformat()
    return value


def _connection():
    from airflow.providers.snowflake.hooks.snowflake import SnowflakeHook

    return SnowflakeHook().get_conn()


@task
def snowflake_first_rows(queries: dict) -> dict:
    conn = _connection()
    try:
        cur = conn.cursor()
        out = {}
        for name, sql in queries.items():
            cur.execute(sql)
            out[name] = [_plain(v) for v in cur.fetchone()]
        return out
    finally:
        conn.close()


@task
def record_results(evaluated: dict, target: str) -> int:
    context = get_current_context()
    lineage = {"dag_id": context["dag"].dag_id, "run_id": context["run_id"], "task_id": context["ti"].task_id}
    conn = _connection()
    try:
        cur = conn.cursor()
        for row in evaluated["rows"]:
            cur.execute(TARGETS[target], {**row, **lineage})
        conn.commit()
    finally:
        conn.close()
    if evaluated["blocking"]:
        raise AirflowFailException("blocking findings: " + ", ".join(evaluated["blocking"]))
    return len(evaluated["rows"])