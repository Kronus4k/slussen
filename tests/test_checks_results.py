import pytest

from pipeline_core.checks.results import CheckResult, blocking, evaluate


def test_evaluate_sets_status_from_failing_count():
    assert evaluate("ops_event_id_unique", "BRONZE.OPS_ORDERS", "error", 300, 0).status == "pass"
    assert evaluate("ops_event_id_unique", "BRONZE.OPS_ORDERS", "error", 300, 50).status == "fail"


def test_blocking_keeps_failed_errors_only():
    results = [
        evaluate("a", "X", "error", 10, 1),
        evaluate("b", "X", "warn", 10, 1),
        evaluate("c", "X", "error", 10, 0),
    ]
    assert [r.check_name for r in blocking(results)] == ["a"]


def test_unknown_severity_or_status_rejected():
    with pytest.raises(ValueError):
        evaluate("a", "X", "critical", 1, 0)
    with pytest.raises(ValueError):
        CheckResult("a", "X", "warn", "maybe", 1, 0)