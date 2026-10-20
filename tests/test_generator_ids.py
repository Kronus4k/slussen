from datetime import datetime, timezone

from pipeline_core.generators.ops_orders import generate_batch

T1 = datetime(2026, 1, 3, 8, 0, tzinfo=timezone.utc)
T2 = datetime(2026, 1, 3, 12, 0, tzinfo=timezone.utc)


def _ids(records, field="event_id"):
    return {r[field] for r in records}


def test_same_seed_and_time_reproduces_batch():
    assert generate_batch(50, T1, seed=7) == generate_batch(50, T1, seed=7)


def test_same_seed_different_time_shares_no_event_ids():
    first = _ids(generate_batch(50, T1, seed=7))
    second = _ids(generate_batch(50, T2, seed=7))
    assert first.isdisjoint(second), f"{len(first & second)} shared event_ids"


def test_event_ids_unique_within_batch():
    assert len(_ids(generate_batch(500, T1, seed=7))) == 500