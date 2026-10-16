from datetime import datetime, timezone
from pathlib import Path

from pipeline_core.gate import load_contracts, process_batch
from pipeline_core.generators.ops_orders import batch_prefix, generate_batch, write_batch
from pipeline_core.storage import LocalStore

CONTRACTS_DIR = Path(__file__).resolve().parents[1] / "contracts"
NOW = datetime(2026, 10, 16, 8, 0, tzinfo=timezone.utc)


def test_local_store_behaves_like_a_bucket(tmp_path):
    store = LocalStore(tmp_path)
    store.put("a/b/c.txt", b"x")
    assert store.exists("a/b/c.txt")
    assert store.list_keys("a/") == ["a/b/c.txt"]
    store.copy("a/b/c.txt", "d/c.txt")
    store.delete("a/b/c.txt")
    assert store.list_keys("") == ["d/c.txt"]
    assert not store.exists("a/b/c.txt")


def test_gate_runs_on_a_local_folder(tmp_path):
    write_batch(generate_batch(10, NOW, seed=1), tmp_path, NOW)
    outcome = process_batch(LocalStore(tmp_path), batch_prefix(NOW) + "/_SUCCESS", load_contracts(CONTRACTS_DIR), NOW)
    assert outcome.status == "validated"
    assert (tmp_path / "validated/ops/orders/dt=2026-10-16/batch=20261016T080000Z/part-00000.parquet").is_file()