import json
from datetime import datetime, timezone
from pathlib import Path

import pytest

from pipeline_core.gate import GateError, load_contracts, process_batch, run_and_report
from pipeline_core.generators.ops_orders import batch_prefix, generate_batch, to_jsonl
from pipeline_core.readers import read_records
from pipeline_core.storage import MemoryStore
from pipeline_core.validator import validate_records

CONTRACTS_DIR = Path(__file__).resolve().parents[1] / "contracts"
NOW = datetime(2026, 10, 16, 8, 0, tzinfo=timezone.utc)
PARTITION = "dt=2026-10-16/batch=20261016T080000Z/"
LANDING = "landing/ops/orders/" + PARTITION
VALIDATED = "validated/ops/orders/" + PARTITION
QUARANTINE = "quarantine/ops/orders/" + PARTITION
AUDIT = "audit/contract_violations/contract=ops_orders/" + PARTITION + "violations.jsonl"


@pytest.fixture(scope="module")
def contracts():
    return load_contracts(CONTRACTS_DIR)


def _by_name(contracts, name):
    return next(c for c in contracts if c.name == name)


def _store(data=None, break_mode=None):
    if data is None:
        data = to_jsonl(generate_batch(20, NOW, seed=1, break_mode=break_mode))
    prefix = batch_prefix(NOW) + "/"
    assert prefix == LANDING
    return MemoryStore({prefix + "part-00000.jsonl": data, prefix + "_SUCCESS": b""})


def _audit_rows(store):
    return [json.loads(line) for line in store.get(AUDIT).decode("utf-8").splitlines()]


class FakeStepFunctions:
    def __init__(self):
        self.calls = []

    def send_task_success(self, **kwargs):
        self.calls.append(("success", kwargs))

    def send_task_failure(self, **kwargs):
        self.calls.append(("failure", kwargs))


def test_good_batch_goes_to_validated_as_parquet(contracts):
    store = _store()
    outcome = process_batch(store, LANDING + "_SUCCESS", contracts, NOW)
    assert (outcome.status, outcome.files, outcome.records, outcome.breaking) == ("validated", 1, 20, 0)
    assert store.list_keys(VALIDATED) == [VALIDATED + "_SUCCESS", VALIDATED + "part-00000.parquet"]
    assert store.list_keys("landing/") == []
    assert outcome.audit_key is None
    records = read_records(store.get(VALIDATED + "part-00000.parquet"), "parquet")
    assert validate_records(records, _by_name(contracts, "ops_orders")).passed


def test_broken_batch_goes_to_quarantine_with_audit_rows(contracts):
    store = _store(break_mode="rename_column")
    outcome = process_batch(store, LANDING + "_SUCCESS", contracts, NOW)
    assert outcome.status == "quarantined"
    assert store.list_keys(QUARANTINE) == [QUARANTINE + "_SUCCESS", QUARANTINE + "part-00000.jsonl"]
    assert store.list_keys("validated/") == []
    assert store.list_keys("landing/") == []
    rows = _audit_rows(store)
    breaking = [(r["rule"], r["column_name"]) for r in rows if r["severity"] == "breaking"]
    assert breaking == [("missing_column", "order_status")]
    assert {r["contract_version"] for r in rows} == {"1.0.0"}
    assert {r["batch_status"] for r in rows} == {"quarantined"}


def test_extra_column_is_validated_and_warning_logged(contracts):
    store = _store(break_mode="extra_column")
    outcome = process_batch(store, LANDING + "_SUCCESS", contracts, NOW)
    assert (outcome.status, outcome.warnings) == ("validated", 1)
    rows = _audit_rows(store)
    assert [(r["rule"], r["column_name"], r["severity"]) for r in rows] == [("extra_column", "discount_code", "warning")]


def test_second_run_is_skipped(contracts):
    store = _store()
    process_batch(store, LANDING + "_SUCCESS", contracts, NOW)
    before = dict(store.objects)
    outcome = process_batch(store, LANDING + "_SUCCESS", contracts, NOW)
    assert outcome.status == "skipped"
    assert store.objects == before


def test_unreadable_file_is_quarantined(contracts):
    store = _store(data=b'{"event_id": "e-1"}\n{not json}\n')
    outcome = process_batch(store, LANDING + "_SUCCESS", contracts, NOW)
    assert outcome.status == "quarantined"
    assert [r["rule"] for r in _audit_rows(store)] == ["unreadable_file"]


def test_marker_without_data_is_quarantined(contracts):
    store = MemoryStore({LANDING + "_SUCCESS": b""})
    outcome = process_batch(store, LANDING + "_SUCCESS", contracts, NOW)
    assert outcome.status == "quarantined"
    assert [r["rule"] for r in _audit_rows(store)] == ["empty_batch"]


@pytest.mark.parametrize(
    "key, message",
    [
        ("landing/unknown/feed/dt=2026-10-16/_SUCCESS", "no contract covers"),
        (LANDING + "part-00000.jsonl", "is not a _SUCCESS marker"),
    ],
)
def test_bad_keys_are_rejected(contracts, key, message):
    with pytest.raises(GateError, match=message):
        process_batch(MemoryStore(), key, contracts, NOW)


def test_cap_writes_summary_row_and_counts_add_up(contracts):
    records = list(generate_batch(20, NOW, seed=1))
    for record in records:
        record["customer_zip_code_prefix"] = 1310
    records[0]["discount_code"] = "BF10"
    store = _store(data=to_jsonl(records))
    outcome = process_batch(store, LANDING + "_SUCCESS", contracts, NOW)
    assert (outcome.status, outcome.breaking, outcome.warnings, outcome.suppressed) == ("quarantined", 10, 1, 10)
    assert outcome.breaking + outcome.warnings + outcome.suppressed == 21
    rows = _audit_rows(store)
    assert len(rows) == 12
    info = [r for r in rows if r["severity"] == "info"]
    assert [(r["rule"], r["column_name"], r["row_number"], r["suppressed_count"]) for r in info] == [
        ("type_mismatch", "customer_zip_code_prefix", None, 10)
    ]
    assert all(r["suppressed_count"] is None for r in rows if r["severity"] != "info")


def test_task_token_reports_outcome(contracts):
    client = FakeStepFunctions()
    outcome = run_and_report(_store(), LANDING + "_SUCCESS", contracts, "token-1", client, NOW)
    assert outcome.status == "validated"
    [(kind, kwargs)] = client.calls
    assert (kind, kwargs["taskToken"]) == ("success", "token-1")
    assert json.loads(kwargs["output"]) == outcome.to_dict()


def test_task_token_reports_failure_and_reraises(contracts):
    client = FakeStepFunctions()
    with pytest.raises(GateError):
        run_and_report(MemoryStore(), "landing/unknown/feed/dt=2026-10-16/_SUCCESS", contracts, "token-2", client, NOW)
    [(kind, kwargs)] = client.calls
    assert (kind, kwargs["taskToken"], kwargs["error"]) == ("failure", "token-2", "GateError")
    assert "no contract covers" in kwargs["cause"]


def test_without_token_nothing_is_reported(contracts):
    client = FakeStepFunctions()
    outcome = run_and_report(_store(), LANDING + "_SUCCESS", contracts, None, client, NOW)
    assert outcome.status == "validated"
    assert client.calls == []