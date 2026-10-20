import json
from datetime import datetime, timezone
from pathlib import Path

import pytest

from pipeline_core.gate import load_contracts, process_batch
from pipeline_core.generators.ops_orders import generate_batch, to_jsonl
from pipeline_core.storage import MemoryStore

CONTRACTS_DIR = Path(__file__).resolve().parents[1] / "contracts"
NOW = datetime(2026, 10, 16, 8, 0, tzinfo=timezone.utc)
LATER = datetime(2026, 10, 16, 9, 30, tzinfo=timezone.utc)
PARTITION = "dt=2026-10-16/batch=20261016T080000Z/"
LANDING = "landing/ops/orders/" + PARTITION
MARKER = LANDING + "_SUCCESS"
DUPLICATES = "quarantine/ops/orders/_duplicates/" + PARTITION + "received=20261016T093000Z/"
DUPLICATE_AUDIT = "audit/contract_violations/contract=ops_orders/" + PARTITION + "duplicate-20261016T093000Z.jsonl"


@pytest.fixture(scope="module")
def contracts():
    return load_contracts(CONTRACTS_DIR)


def _upload(store, break_mode=None):
    data = to_jsonl(generate_batch(20, NOW, seed=1, break_mode=break_mode))
    store.put(LANDING + "part-00000.jsonl", data)
    store.put(MARKER, b"")
    return data


def _audit_rows(store, key):
    return [json.loads(line) for line in store.get(key).decode("utf-8").splitlines()]


@pytest.mark.parametrize("break_mode, first_status", [(None, "validated"), ("rename_column", "quarantined")])
def test_reupload_into_decided_batch_is_parked_as_duplicate(contracts, break_mode, first_status):
    store = MemoryStore()
    _upload(store, break_mode)
    assert process_batch(store, MARKER, contracts, NOW).status == first_status
    decided = dict(store.objects)
    sent = _upload(store, break_mode)

    outcome = process_batch(store, MARKER, contracts, LATER)

    assert (outcome.status, outcome.files, outcome.breaking, outcome.warnings) == ("duplicate", 1, 0, 1)
    assert outcome.moved_to == DUPLICATES
    assert store.list_keys("landing/") == []
    assert store.list_keys(DUPLICATES) == [DUPLICATES + "_SUCCESS", DUPLICATES + "part-00000.jsonl"]
    assert store.get(DUPLICATES + "part-00000.jsonl") == sent
    assert outcome.audit_key == DUPLICATE_AUDIT
    assert all(store.get(k) == v for k, v in decided.items())
    rows = _audit_rows(store, DUPLICATE_AUDIT)
    assert [(r["rule"], r["severity"], r["batch_status"]) for r in rows] == [("duplicate_batch", "warning", "duplicate")]
    assert first_status in rows[0]["detail"]


def test_duplicate_event_after_decision_changes_nothing(contracts):
    store = MemoryStore()
    _upload(store)
    process_batch(store, MARKER, contracts, NOW)
    before = dict(store.objects)
    outcome = process_batch(store, MARKER, contracts, LATER)
    assert outcome.status == "skipped"
    assert store.objects == before