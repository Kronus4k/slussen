from datetime import datetime, timedelta, timezone
from pathlib import Path

import pytest

from pipeline_core.checks.freshness import blocking, evaluate_freshness, latest_deadline
from pipeline_core.contracts import load_contract

NOW = datetime(2026, 10, 22, 12, 0, tzinfo=timezone.utc)
MONDAY_0600 = {"day": "monday", "time_utc": "06:00"}


@pytest.fixture
def finance(contracts_dir):
    return load_contract(Path(contracts_dir) / "finance_settlements.yaml")


@pytest.fixture
def olist_orders(contracts_dir):
    return load_contract(Path(contracts_dir) / "olist_orders.yaml")


def test_ops_ok_at_the_limit(ops):
    result = evaluate_freshness(ops, "BRONZE.OPS_ORDERS", NOW - timedelta(hours=5), NOW)
    assert (result.status, result.sla_hours, result.age_hours) == ("ok", 5.0, 5.0)


def test_ops_late_blocks(ops):
    result = evaluate_freshness(ops, "BRONZE.OPS_ORDERS", NOW - timedelta(hours=6), NOW)
    assert result.status == "late"
    assert blocking([result]) == [result]


def test_no_rows_is_no_data_and_blocks(ops):
    result = evaluate_freshness(ops, "BRONZE.OPS_ORDERS", None, NOW)
    assert (result.status, result.age_hours) == ("no_data", None)
    assert blocking([result]) == [result]


def test_finance_ok_inside_the_cycle(finance):
    result = evaluate_freshness(finance, "BRONZE.FINANCE_SETTLEMENTS", NOW - timedelta(hours=24), NOW)
    assert (result.status, result.sla_hours, result.age_hours) == ("ok", 102.0, 24.0)


def test_finance_late_when_last_load_is_before_the_window(finance):
    last = datetime(2026, 10, 12, 5, 5, tzinfo=timezone.utc)
    assert evaluate_freshness(finance, "BRONZE.FINANCE_SETTLEMENTS", last, NOW).status == "late"


def test_latest_deadline_boundaries():
    before = datetime(2026, 10, 26, 5, 59, tzinfo=timezone.utc)
    at = datetime(2026, 10, 26, 6, 0, tzinfo=timezone.utc)
    assert latest_deadline(MONDAY_0600, before) == datetime(2026, 10, 19, 6, 0, tzinfo=timezone.utc)
    assert latest_deadline(MONDAY_0600, at) == at


def test_one_off_backfill_is_not_applicable(olist_orders):
    result = evaluate_freshness(olist_orders, "BRONZE.OLIST_ORDERS", NOW - timedelta(days=9), NOW)
    assert (result.status, result.sla_hours) == ("not_applicable", None)
    assert blocking([result]) == []


def test_naive_now_rejected(ops):
    with pytest.raises(ValueError):
        evaluate_freshness(ops, "BRONZE.OPS_ORDERS", None, datetime(2026, 10, 22, 12, 0))