from datetime import timedelta
from decimal import Decimal
from pathlib import Path

import pyarrow as pa
import pyarrow.parquet as pq
import pytest

from pipeline_core.contracts import load_contract
from pipeline_core.readers import read_records
from pipeline_core.validator import validate_records
from pipeline_core.writers import arrow_schema, to_parquet

CONTRACTS = Path(__file__).resolve().parents[1] / "contracts"


@pytest.fixture(scope="module")
def ops():
    return load_contract(CONTRACTS / "ops_orders.yaml")


def _ops_record(event_id="e-1", **overrides):
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


def test_schema_types_come_from_contract(ops):
    schema = arrow_schema(ops)
    assert schema.field("customer_zip_code_prefix").type == pa.string()
    assert schema.field("event_ts").type == pa.timestamp("us", tz="UTC")
    assert schema.field("order_estimated_delivery_date").type == pa.date32()
    assert schema.field("order_id").nullable is False
    assert schema.field("payments").nullable is True
    item = schema.field("items").type.value_type
    assert item.field("price").type == pa.decimal128(10, 2)


def test_round_trip_passes_contract_again(ops):
    data = to_parquet([_ops_record("e-1"), _ops_record("e-2", payments=None)], ops)
    records = read_records(data, "parquet")
    assert validate_records(records, ops).passed
    assert records[0]["event_ts"].utcoffset() == timedelta(0)
    assert records[0]["items"][0]["price"] == Decimal("129.90")
    assert records[0]["customer_zip_code_prefix"] == "01310"
    assert records[1]["payments"] is None


def test_extra_columns_are_not_written(ops):
    data = to_parquet([_ops_record(discount_code="BF10")], ops)
    assert pq.read_schema(pa.BufferReader(data)).names == list(ops.column_names)