from decimal import Decimal

import pytest

from pipeline_core.checks.athena import AthenaQueryError, fetch_one_row
from pipeline_core.checks.reconciliation import athena_sql, compare, snowflake_sql


def test_athena_sql_for_ops():
    assert athena_sql("ops_orders") == (
        "SELECT COUNT(*) AS row_count, COUNT(DISTINCT event_id) AS distinct_event_id, "
        "COUNT(DISTINCT order_id) AS distinct_order_id FROM slussen_lake.ops_orders"
    )


def test_both_engines_get_the_same_select_list():
    a, s = athena_sql("olist_order_items"), snowflake_sql("olist_order_items")
    assert s.endswith("FROM ECOM_DB.BRONZE.OLIST_ORDER_ITEMS")
    assert a.split(" FROM ")[0] == s.split(" FROM ")[0]


def test_strings_and_numbers_compare_by_value():
    athena = ["112650", "112650", "13591643.70", "2251909.54"]
    snowflake = (112650, 112650, Decimal("13591643.7"), Decimal("2251909.54"))
    result = compare("olist_order_items", athena, snowflake)
    assert (result.status, result.checked_count, result.detail) == ("pass", 4, "4 metrics match")


def test_mismatch_fails_with_metric_named():
    result = compare("ops_orders", ["300", "250", "200"], (300, 300, 200))
    assert (result.status, result.severity, result.failing_count) == ("fail", "error", 1)
    assert result.detail == "distinct_event_id athena=250 snowflake=300"


def test_wrong_value_count_rejected():
    with pytest.raises(ValueError):
        compare("ops_orders", ["300"], (300, 250, 200))


class _FakeAthena:
    def __init__(self, states, rows=()):
        self.states = list(states)
        self.rows = list(rows)
        self.stopped = []
        self.started = None

    def start_query_execution(self, **kwargs):
        self.started = kwargs
        return {"QueryExecutionId": "q-1"}

    def get_query_execution(self, QueryExecutionId):
        state = self.states.pop(0) if len(self.states) > 1 else self.states[0]
        return {"QueryExecution": {"Status": {"State": state}, "Statistics": {"DataScannedInBytes": 42}, "StatementType": "DML"}}

    def get_query_results(self, QueryExecutionId, MaxResults):
        return {"ResultSet": {"Rows": [{"Data": [{"VarCharValue": v} for v in row]} for row in self.rows]}}

    def stop_query_execution(self, QueryExecutionId):
        self.stopped.append(QueryExecutionId)


def test_fetch_one_row_polls_until_done():
    client = _FakeAthena(["QUEUED", "RUNNING", "SUCCEEDED"], [["row_count"], ["300"]])
    sleeps = []
    assert fetch_one_row(client, "SELECT 1", "slussen", "slussen_lake", sleep=sleeps.append) == ["300"]
    assert len(sleeps) == 2
    assert client.started["WorkGroup"] == "slussen"


def test_timeout_stops_the_query():
    client = _FakeAthena(["RUNNING"])
    with pytest.raises(AthenaQueryError):
        fetch_one_row(client, "SELECT 1", "slussen", "slussen_lake", poll_s=1, timeout_s=2, sleep=lambda s: None)
    assert client.stopped == ["q-1"]


def test_failed_query_raises():
    with pytest.raises(AthenaQueryError):
        fetch_one_row(_FakeAthena(["FAILED"]), "SELECT 1", "slussen", "slussen_lake", sleep=lambda s: None)