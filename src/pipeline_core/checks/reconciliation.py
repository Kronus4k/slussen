from decimal import Decimal

from pipeline_core.checks.results import CheckResult, evaluate

RECONCILED = {
    "ops_orders": {
        "row_count": "COUNT(*)",
        "distinct_event_id": "COUNT(DISTINCT event_id)",
        "distinct_order_id": "COUNT(DISTINCT order_id)",
    },
    "olist_order_items": {
        "row_count": "COUNT(*)",
        "distinct_key": "COUNT(DISTINCT CONCAT(order_id, '|', CAST(order_item_id AS VARCHAR)))",
        "sum_price": "SUM(price)",
        "sum_freight_value": "SUM(freight_value)",
    },
    "olist_customers": {
        "row_count": "COUNT(*)",
        "distinct_customer_id": "COUNT(DISTINCT customer_id)",
        "distinct_customer_unique_id": "COUNT(DISTINCT customer_unique_id)",
    },
}


def metrics_sql(table: str, source: str) -> str:
    select = ", ".join(f"{expr} AS {name}" for name, expr in RECONCILED[table].items())
    return f"SELECT {select} FROM {source}"


def athena_sql(table: str, database: str = "slussen_lake") -> str:
    return metrics_sql(table, f"{database}.{table}")


def snowflake_sql(table: str, database: str = "ECOM_DB") -> str:
    return metrics_sql(table, f"{database}.BRONZE.{table.upper()}")


def _value(raw) -> Decimal | None:
    return None if raw is None or raw == "" else Decimal(str(raw))


def compare(table: str, athena_values, snowflake_values) -> CheckResult:
    names = list(RECONCILED[table])
    athena_values, snowflake_values = list(athena_values), list(snowflake_values)
    if len(athena_values) != len(names) or len(snowflake_values) != len(names):
        raise ValueError(f"{table}: expected {len(names)} values from each engine")
    mismatches = []
    for name, a_raw, s_raw in zip(names, athena_values, snowflake_values):
        a, s = _value(a_raw), _value(s_raw)
        if a != s:
            mismatches.append(f"{name} athena={a} snowflake={s}")
    detail = "; ".join(mismatches) if mismatches else f"{len(names)} metrics match"
    return evaluate(f"reconcile_{table}", f"BRONZE.{table.upper()}", "error", len(names), len(mismatches), detail)