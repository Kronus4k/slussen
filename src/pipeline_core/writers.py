from __future__ import annotations

import io
from datetime import date, datetime

import pyarrow as pa
import pyarrow.parquet as pq

from pipeline_core.contracts import Column, Contract

SIMPLE_ARROW_TYPES = {
    "string": pa.string(),
    "integer": pa.int64(),
    "boolean": pa.bool_(),
    "date": pa.date32(),
    "timestamp": pa.timestamp("us", tz="UTC"),
}


def _arrow_type(column: Column) -> pa.DataType:
    spec = column.decimal_spec
    if spec:
        return pa.decimal128(*spec)
    if column.type == "array":
        return pa.list_(pa.struct([_arrow_field(f) for f in column.fields]))
    return SIMPLE_ARROW_TYPES[column.type]


def _arrow_field(column: Column) -> pa.Field:
    return pa.field(column.name, _arrow_type(column), nullable=column.nullable)


def arrow_schema(contract: Contract) -> pa.Schema:
    return pa.schema([_arrow_field(c) for c in contract.columns])


def _normalize(value, column: Column):
    if value is None:
        return None
    if column.type == "timestamp" and isinstance(value, str):
        return datetime.fromisoformat(value)
    if column.type == "date" and isinstance(value, str):
        return date.fromisoformat(value)
    if column.type == "array":
        return [{f.name: _normalize(element.get(f.name), f) for f in column.fields} for element in value]
    return value


def to_parquet(records: list[dict], contract: Contract) -> bytes:
    rows = [{c.name: _normalize(record.get(c.name), c) for c in contract.columns} for record in records]
    table = pa.Table.from_pylist(rows, schema=arrow_schema(contract))
    buffer = io.BytesIO()
    pq.write_table(table, buffer, compression="snappy")
    return buffer.getvalue()