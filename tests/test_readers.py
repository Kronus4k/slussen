import io
from datetime import date, datetime, timedelta, timezone
from decimal import Decimal
from pathlib import Path

import pyarrow as pa
import pyarrow.parquet as pq
import pytest

from pipeline_core.contracts import load_contract
from pipeline_core.readers import ReadError, read_records
from pipeline_core.validator import validate_records

CONTRACTS = Path(__file__).resolve().parents[1] / "contracts"


def _finance_parquet(gross_amount_type):
    gross = [Decimal("100.00")] if pa.types.is_decimal(gross_amount_type) else [100.0]
    table = pa.table(
        {
            "settlement_id": pa.array(["s-1"]),
            "payout_batch_id": pa.array(["b-1"]),
            "order_id": pa.array(["o-1"]),
            "payment_sequential": pa.array([1], pa.int64()),
            "payment_type": pa.array(["credit_card"]),
            "gross_amount": pa.array(gross, gross_amount_type),
            "fee_amount": pa.array([Decimal("2.50")], pa.decimal128(12, 2)),
            "net_amount": pa.array([Decimal("97.50")], pa.decimal128(12, 2)),
            "currency": pa.array(["BRL"]),
            "payment_date": pa.array([date(2026, 10, 12)], pa.date32()),
            "settlement_date": pa.array([None], pa.date32()),
            "settlement_status": pa.array(["pending"]),
            "generated_at": pa.array(
                [datetime(2026, 10, 19, 5, 0, tzinfo=timezone.utc)], pa.timestamp("us", tz="UTC")
            ),
        }
    )
    buffer = io.BytesIO()
    pq.write_table(table, buffer)
    return buffer.getvalue()


def test_jsonl_numbers_with_decimals_stay_exact():
    data = b'{"price": 129.90, "n": 1}\n\n{"price": 0.1}\n'
    assert read_records(data, "jsonl") == [{"price": Decimal("129.90"), "n": 1}, {"price": Decimal("0.1")}]


def test_jsonl_byte_order_mark_is_tolerated():
    assert read_records(b'\xef\xbb\xbf{"a": "x"}\n', "jsonl") == [{"a": "x"}]


@pytest.mark.parametrize(
    "data, message",
    [
        (b'{"a": 1}\n{not json}\n', "line 2"),
        (b"[1, 2]\n", "line 1: expected a JSON object"),
        (b"\xff\xfe", "not valid UTF-8"),
    ],
)
def test_jsonl_unreadable_raises(data, message):
    with pytest.raises(ReadError, match=message):
        read_records(data, "jsonl")


def test_parquet_logical_types_map_to_python():
    record = read_records(_finance_parquet(pa.decimal128(12, 2)), "parquet")[0]
    assert record["gross_amount"] == Decimal("100.00")
    assert record["payment_date"] == date(2026, 10, 12)
    assert record["settlement_date"] is None
    assert record["generated_at"].utcoffset() == timedelta(0)


@pytest.mark.parametrize("gross_type, should_pass", [(pa.decimal128(12, 2), True), (pa.float64(), False)])
def test_parquet_through_finance_contract(gross_type, should_pass):
    contract = load_contract(CONTRACTS / "finance_settlements.yaml")
    result = validate_records(read_records(_finance_parquet(gross_type), "parquet"), contract)
    assert result.passed is should_pass
    if not should_pass:
        assert ("type_mismatch", "gross_amount") in {(v.rule, v.column) for v in result.breaking}


def test_corrupt_parquet_raises():
    with pytest.raises(ReadError, match="not a readable Parquet file"):
        read_records(b"definitely not parquet", "parquet")


def test_unknown_format_raises():
    with pytest.raises(ReadError, match="no reader for format 'csv'"):
        read_records(b"a,b\n1,2\n", "csv")