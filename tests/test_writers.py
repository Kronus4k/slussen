from datetime import timedelta
from decimal import Decimal

import pyarrow as pa
import pyarrow.parquet as pq

from pipeline_core.readers import read_records
from pipeline_core.validator import validate_records
from pipeline_core.writers import arrow_schema, to_parquet


def test_schema_types_come_from_contract(ops):
    schema = arrow_schema(ops)
    assert schema.field("customer_zip_code_prefix").type == pa.string()
    assert schema.field("event_ts").type == pa.timestamp("us", tz="UTC")
    assert schema.field("order_estimated_delivery_date").type == pa.date32()
    assert schema.field("order_id").nullable is False
    assert schema.field("payments").nullable is True
    item = schema.field("items").type.value_type
    assert item.field("price").type == pa.decimal128(10, 2)


def test_round_trip_passes_contract_again(ops, make_ops_record):
    data = to_parquet([make_ops_record("e-1"), make_ops_record("e-2", payments=None)], ops)
    records = read_records(data, "parquet")
    assert validate_records(records, ops).passed
    assert records[0]["event_ts"].utcoffset() == timedelta(0)
    assert records[0]["items"][0]["price"] == Decimal("129.90")
    assert records[0]["customer_zip_code_prefix"] == "01310"
    assert records[1]["payments"] is None


def test_extra_columns_are_not_written(ops, make_ops_record):
    data = to_parquet([make_ops_record(discount_code="BF10")], ops)
    assert pq.read_schema(pa.BufferReader(data)).names == list(ops.column_names)