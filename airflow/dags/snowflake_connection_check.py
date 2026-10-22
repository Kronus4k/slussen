from datetime import datetime

from airflow.providers.common.sql.operators.sql import SQLExecuteQueryOperator
from airflow.sdk import dag


@dag(
    dag_id="snowflake_connection_check",
    schedule=None,
    start_date=datetime(2026, 10, 1),
    catchup=False,
    tags=["slussen", "check"],
    doc_md="Proves the Snowflake connection from Secrets Manager: one row with role, user, warehouse and Bronze access.",
)
def snowflake_connection_check():
    SQLExecuteQueryOperator(
        task_id="whoami",
        conn_id="snowflake_default",
        sql=(
            "SELECT CURRENT_ROLE() AS role_name, CURRENT_USER() AS user_name, "
            "CURRENT_WAREHOUSE() AS warehouse_name, "
            "(SELECT COUNT(*) FROM ECOM_DB.BRONZE.OPS_ORDERS) AS ops_rows"
        ),
        show_return_value_in_logs=True,
    )


snowflake_connection_check()