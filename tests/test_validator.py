from decimal import Decimal

import pytest

from pipeline_core.validator import validate_records


def _breaking(result):
    return {(v.rule, v.column) for v in result.breaking}


def test_valid_batch_passes(ops, make_ops_record):
    result = validate_records([make_ops_record("e-1"), make_ops_record("e-2")], ops)
    assert result.passed
    assert result.violations == []
    assert (result.contract, result.version, result.records) == ("ops_orders", "1.0.0", 2)


def test_nullable_columns_accept_null(ops, make_ops_record):
    result = validate_records([make_ops_record(payments=None, order_approved_ts=None)], ops)
    assert result.passed


def test_extra_column_is_warning_not_breaking(ops, make_ops_record):
    result = validate_records([make_ops_record(discount_code="BF10")], ops)
    assert result.passed
    assert [(v.rule, v.column) for v in result.warnings] == [("extra_column", "discount_code")]


def test_missing_column_is_breaking(ops, make_ops_record):
    record = make_ops_record()
    del record["order_status"]
    result = validate_records([record], ops)
    assert not result.passed
    assert ("missing_column", "order_status") in _breaking(result)


@pytest.mark.parametrize(
    "column, value",
    [
        ("customer_zip_code_prefix", 1310),
        ("event_ts", "not-a-timestamp"),
        ("event_ts", "2026-10-16T08:00:00"),
        ("order_estimated_delivery_date", "30/10/2026"),
    ],
)
def test_wrong_type_is_breaking(ops, make_ops_record, column, value):
    result = validate_records([make_ops_record(**{column: value})], ops)
    assert ("type_mismatch", column) in _breaking(result)


def test_null_in_required_is_breaking(ops, make_ops_record):
    result = validate_records([make_ops_record("e-1"), make_ops_record("e-2", order_id=None)], ops)
    found = [(v.column, v.row) for v in result.breaking if v.rule == "null_in_required"]
    assert found == [("order_id", 1)]


def test_duplicate_primary_key_is_breaking(ops, make_ops_record):
    result = validate_records([make_ops_record("e-1"), make_ops_record("e-1")], ops)
    assert ("duplicate_primary_key", "event_id") in _breaking(result)


@pytest.mark.parametrize(
    "field, value",
    [
        ("price", "abc"),
        ("price", Decimal("129.999")),
        ("order_item_id", "1"),
    ],
)
def test_wrong_type_in_array_is_breaking(ops, make_ops_record, field, value):
    record = make_ops_record()
    record["items"][0][field] = value
    assert ("type_mismatch", f"items.{field}") in _breaking(validate_records([record], ops))


def test_missing_field_in_array_is_breaking(ops, make_ops_record):
    record = make_ops_record()
    del record["items"][0]["seller_id"]
    assert ("missing_column", "items.seller_id") in _breaking(validate_records([record], ops))


def test_cap_keeps_ten_and_summarises_the_rest(ops, make_ops_record):
    records = [make_ops_record(f"e-{i}", customer_zip_code_prefix=1310) for i in range(15)]
    result = validate_records(records, ops)
    kept = [v for v in result.violations if v.severity == "breaking"]
    summaries = [v for v in result.violations if v.severity == "info"]
    assert len(kept) == 10
    assert result.suppressed == 5
    assert [(v.rule, v.column, v.row, v.suppressed_count) for v in summaries] == [
        ("type_mismatch", "customer_zip_code_prefix", None, 5)
    ]
    assert "5 more suppressed" in summaries[0].detail
    assert not result.passed


def test_no_summary_under_the_cap(ops, make_ops_record):
    records = [make_ops_record(f"e-{i}", customer_zip_code_prefix=1310) for i in range(10)]
    result = validate_records(records, ops)
    assert result.suppressed == 0
    assert [v for v in result.violations if v.severity == "info"] == []