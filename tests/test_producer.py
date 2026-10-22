from datetime import datetime, timezone
from pathlib import Path

import pytest

from pipeline_core.gate import load_contracts, process_batch
from pipeline_core.generators.ops_orders import generate_batch, to_jsonl
from pipeline_core.producer import partition_for, publish_batch
from pipeline_core.storage import MemoryStore

CONTRACTS = load_contracts(Path(__file__).resolve().parents[1] / "contracts")
OPS = next(c for c in CONTRACTS if c.location["landing"] == "landing/ops/orders/")
BATCH_TIME = datetime(2026, 1, 8, 12, 0, tzinfo=timezone.utc)
PREFIX = "landing/ops/orders/dt=2026-01-08/batch=20260108T120000Z/"


class RecordingStore(MemoryStore):
    def __init__(self, objects=None):
        super().__init__(objects)
        self.put_order = []

    def put(self, key, data):
        self.put_order.append(key)
        super().put(key, data)


def _files(n=5):
    records = generate_batch(n, BATCH_TIME, seed=7)
    return {"part-00000.jsonl": to_jsonl(records)}, n


def test_partition_matches_generator_layout():
    assert partition_for(BATCH_TIME) == "dt=2026-01-08/batch=20260108T120000Z/"


def test_publish_writes_data_first_and_marker_last():
    store = RecordingStore()
    files, n = _files()
    result = publish_batch(store, OPS, BATCH_TIME, files, n)
    assert store.put_order == [PREFIX + "part-00000.jsonl", PREFIX + "_SUCCESS"]
    assert (result.action, result.file_count, result.record_count) == ("uploaded", 1, n)
    assert result.byte_count == len(files["part-00000.jsonl"])
    assert result.s3_prefix == PREFIX
    assert result.batch_id == "20260108T120000Z"


def test_published_batch_passes_gate_and_republish_is_skipped():
    store = MemoryStore()
    files, n = _files()
    publish_batch(store, OPS, BATCH_TIME, files, n)
    outcome = process_batch(store, PREFIX + "_SUCCESS", CONTRACTS)
    assert outcome.status == "validated"
    again = publish_batch(store, OPS, BATCH_TIME, files, n)
    assert again.action == "skipped_validated"
    assert store.list_keys(PREFIX) == []


def test_quarantined_batch_is_skipped():
    store = MemoryStore({"quarantine/ops/orders/dt=2026-01-08/batch=20260108T120000Z/_SUCCESS": b""})
    files, n = _files()
    assert publish_batch(store, OPS, BATCH_TIME, files, n).action == "skipped_quarantined"
    assert store.list_keys(PREFIX) == []


def test_batch_in_flight_is_not_overwritten():
    store = MemoryStore({PREFIX + "part-00000.jsonl": b"earlier upload"})
    files, n = _files()
    result = publish_batch(store, OPS, BATCH_TIME, files, n)
    assert result.action == "skipped_in_flight"
    assert store.get(PREFIX + "part-00000.jsonl") == b"earlier upload"
    assert not store.exists(PREFIX + "_SUCCESS")


@pytest.mark.parametrize("files", [{}, {"_SUCCESS": b""}])
def test_rejects_empty_batch_or_marker_in_files(files):
    with pytest.raises(ValueError):
        publish_batch(MemoryStore(), OPS, BATCH_TIME, files, 0)