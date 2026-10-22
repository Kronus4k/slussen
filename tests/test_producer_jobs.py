import io
import json
from datetime import datetime, timezone
from decimal import Decimal
from pathlib import Path

import pyarrow as pa
import pyarrow.parquet as pq

from pipeline_core.gate import load_contracts, process_batch
from pipeline_core.producer_jobs import run_finance_producer, run_ops_producer
from pipeline_core.storage import MemoryStore

CONTRACTS_DIR = Path(__file__).resolve().parents[1] / "contracts"
CONTRACTS = load_contracts(CONTRACTS_DIR)
FIRST = datetime(2026, 1, 6, 8, 0, tzinfo=timezone.utc)
SECOND = datetime(2026, 1, 6, 12, 0, tzinfo=timezone.utc)
MONDAY = datetime(2026, 1, 12, 5, 0, tzinfo=timezone.utc)


def _parquet(rows):
    buffer = io.BytesIO()
    pq.write_table(pa.Table.from_pylist(rows), buffer)
    return buffer.getvalue()


def _lake():
    items = [
        {"order_id": "o1", "product_id": "p1", "seller_id": "s1", "price": Decimal("10.00"), "freight_value": Decimal("2.00")},
        {"order_id": "o2", "product_id": "p2", "seller_id": "s2", "price": Decimal("20.00"), "freight_value": Decimal("3.00")},
    ]
    customers = [
        {"customer_id": "c1", "customer_unique_id": "u1", "customer_zip_code_prefix": "01001", "customer_city": "sao paulo", "customer_state": "SP"}
    ]
    return MemoryStore(
        {
            "validated/olist/order_items/dt=2026-01-01/batch=20260101T000000Z/part-00000.parquet": _parquet(items),
            "validated/olist/customers/dt=2026-01-01/batch=20260101T000000Z/part-00000.parquet": _parquet(customers),
        }
    )


def _landing_records(store, result):
    data = store.get(result["s3_prefix"] + "part-00000.jsonl")
    return [json.loads(line) for line in data.splitlines()]


def _gate(store, result):
    return process_batch(store, result["s3_prefix"] + "_SUCCESS", CONTRACTS).status


def test_ops_job_publishes_catalog_orders_and_is_idempotent():
    store = _lake()
    first = run_ops_producer(store, CONTRACTS_DIR, FIRST, records=10)
    assert (first["action"], first["record_count"], first["feed"], first["contract"]) == ("uploaded", 10, "ops", "ops_orders")
    products = {i["product_id"] for r in _landing_records(store, first) for i in r["items"]}
    assert products <= {"p1", "p2"}
    assert _gate(store, first) == "validated"
    assert run_ops_producer(store, CONTRACTS_DIR, FIRST, records=10)["action"] == "skipped_validated"


def test_next_ops_batch_moves_validated_orders_forward():
    store = _lake()
    first = run_ops_producer(store, CONTRACTS_DIR, FIRST, records=10)
    first_ids = {r["order_id"] for r in _landing_records(store, first)}
    assert _gate(store, first) == "validated"
    second = run_ops_producer(store, CONTRACTS_DIR, SECOND, records=10)
    moved = [r for r in _landing_records(store, second) if r["order_id"] in first_ids]
    assert len(moved) == 5
    assert {r["order_status"] for r in moved} <= {"approved", "canceled"}
    assert _gate(store, second) == "validated"


def test_finance_job_settles_validated_ops_payments():
    store = _lake()
    for batch_time in (FIRST, SECOND):
        assert _gate(store, run_ops_producer(store, CONTRACTS_DIR, batch_time, records=10)) == "validated"
    result = run_finance_producer(store, CONTRACTS_DIR, MONDAY)
    assert (result["action"], result["feed"], result["contract"]) == ("uploaded", "finance", "finance_settlements")
    assert 1 <= result["record_count"] <= 5
    assert _gate(store, result) == "validated"
    assert run_finance_producer(store, CONTRACTS_DIR, MONDAY)["action"] == "skipped_validated"


def test_finance_job_skips_an_empty_week():
    store = _lake()
    result = run_finance_producer(store, CONTRACTS_DIR, MONDAY)
    assert (result["action"], result["record_count"]) == ("skipped_empty", 0)
    assert store.list_keys("landing/finance/") == []