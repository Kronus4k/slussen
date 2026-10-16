from datetime import datetime, timezone
from pathlib import Path

import pytest

from pipeline_core.contracts import load_contract
from pipeline_core.generators.ops_orders import generate_batch, to_jsonl, write_batch
from pipeline_core.readers import read_records
from pipeline_core.validator import validate_records

CONTRACTS = Path(__file__).resolve().parents[1] / "contracts"
NOW = datetime(2026, 10, 16, 8, 0, tzinfo=timezone.utc)


@pytest.fixture(scope="module")
def ops():
    return load_contract(CONTRACTS / "ops_orders.yaml")


def _validate(records, contract):
    return validate_records(read_records(to_jsonl(records), "jsonl"), contract)


def test_clean_batch_passes_contract(ops):
    result = _validate(generate_batch(200, NOW, seed=1), ops)
    assert result.passed
    assert result.violations == []


def test_same_seed_gives_same_batch():
    assert generate_batch(20, NOW, seed=7) == generate_batch(20, NOW, seed=7)


@pytest.mark.parametrize(
    "mode, rule, column, passed",
    [
        ("rename_column", "missing_column", "order_status", False),
        ("wrong_type", "type_mismatch", "customer_zip_code_prefix", False),
        ("null_required", "null_in_required", "order_id", False),
        ("duplicate_key", "duplicate_primary_key", "event_id", False),
        ("extra_column", "extra_column", "discount_code", True),
    ],
)
def test_break_mode_triggers_expected_violation(ops, mode, rule, column, passed):
    result = _validate(generate_batch(20, NOW, seed=1, break_mode=mode), ops)
    assert result.passed is passed
    assert (rule, column) in {(v.rule, v.column) for v in result.violations}


def test_write_batch_layout(tmp_path):
    folder = write_batch(generate_batch(5, NOW, seed=1), tmp_path, NOW)
    assert folder.relative_to(tmp_path).as_posix() == "landing/ops/orders/dt=2026-10-16/batch=20261016T080000Z"
    assert sorted(p.name for p in folder.iterdir()) == ["_SUCCESS", "part-00000.jsonl"]
    assert (folder / "_SUCCESS").stat().st_size == 0