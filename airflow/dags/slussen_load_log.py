from airflow.sdk import get_current_context, task

LOAD_LOG_SQL = (
    "INSERT INTO ECOM_DB.AUDIT.LOAD_LOG (logged_at, dag_id, run_id, feed, contract, batch_id, s3_prefix, "
    "action, file_count, record_count, byte_count) "
    "SELECT CURRENT_TIMESTAMP(), %(dag_id)s, %(run_id)s, %(feed)s, %(contract)s, %(batch_id)s, %(s3_prefix)s, "
    "%(action)s, %(file_count)s, %(record_count)s, %(byte_count)s"
)


@task
def log_load(result: dict) -> dict:
    from airflow.providers.snowflake.hooks.snowflake import SnowflakeHook

    context = get_current_context()
    row = {**result, "dag_id": context["dag"].dag_id, "run_id": context["run_id"]}
    SnowflakeHook().run(LOAD_LOG_SQL, parameters=row)
    return row