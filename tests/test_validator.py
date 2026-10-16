from decimal import Decimal
from pathlib import Path

import pytest

from pipeline_core.contracts import load_contract
from pipeline_core.validator import validate_records

CONTRACTS = Path(__file__).resolve().parents[1] / "contracts"


@pytest.fixture(scope="module")
def ops():
    return load_contract(CONTRACTS / "ops_orders.yaml")


def _record(event_id="e-1", **overrides):
    record = {
        "event_id": event_id,
        "event_type": "order_created",
        "event_ts": "2026-10-16T08:00:00Z",
        "order_id": "o-1",
        "order_status": "created",
        "customer_id": "c-1",
        "customer_unique_id": "u-1",
        "customer_zip_code_prefix": "01310",
        "customer_city": "sao paulo",
        "customer_state": "SP",
        "order_purchase_ts": "2026-10-16T07:55:00Z",
        "order_approved_ts": None,
        "order_delivered_carrier_ts": None,
        "order_delivered_customer_ts": None,
        "order_estimated_delivery_date": "2026-10-30",
        "items": [
            {"order_item_id": 1, "product_id": "p-1", "seller_id": "s-1", "price": Decimal("129.90"), "freight_value": Decimal("15.10")}
        ],
        "payments": [
            {"payment_sequential": 1, "payment_type": "credit_card", "payment_installments": 3, "payment_value": Decimal("145.00")}
        ],
    }
    record.update(overrides)
    return record


def _breaking(result):
    return {(v.rule, v.column) for v in result.breaking}


def test_valid_batch_passes(ops):
    result = validate_records([_record("e-1"), _record("e-2")], ops)
    assert result.passed
    assert result.violations == []
    assert (result.contract, result.version, result.records) == ("ops_orders", "1.0.0", 2)


def test_nullable_columns_accept_null(ops):
    result = validate_records([_record(payments=None, order_approved_ts=None)], ops)
    assert result.passed


def test_extra_column_is_warning_not_breaking(ops):
    result = validate_records([_record(discount_code="BF10")], ops)
    assert result.passed
    assert [(v.rule, v.column) for v in result.warnings] == [("extra_column", "discount_code")]


def test_missing_column_is_breaking(ops):
    record = _record()
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
def test_wrong_type_is_breaking(ops, column, value):
    result = validate_records([_record(**{column: value})], ops)
    assert ("type_mismatch", column) in _breaking(result)


def test_null_in_required_is_breaking(ops):
    result = validate_records([_record("e-1"), _record("e-2", order_id=None)], ops)
    found = [(v.column, v.row) for v in result.breaking if v.rule == "null_in_required"]
    assert found == [("order_id", 1)]


def test_duplicate_primary_key_is_breaking(ops):
    result = validate_records([_record("e-1"), _record("e-1")], ops)
    assert ("duplicate_primary_key", "event_id") in _breaking(result)


@pytest.mark.parametrize(
    "field, value",
    [
        ("price", "abc"),
        ("price", Decimal("129.999")),
        ("order_item_id", "1"),
    ],
)
def test_wrong_type_in_array_is_breaking(ops, field, value):
    record = _record()
    record["items"][0][field] = value
    assert ("type_mismatch", f"items.{field}") in _breaking(validate_records([record], ops))


def test_missing_field_in_array_is_breaking(ops):
    record = _record()
    del record["items"][0]["seller_id"]
    assert ("missing_column", "items.seller_id") in _breaking(validate_records([record], ops))