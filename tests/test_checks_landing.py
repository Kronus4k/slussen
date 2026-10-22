from datetime import datetime, timedelta, timezone

import pytest

from pipeline_core.checks.landing import landing_at_rest, list_objects

NOW = datetime(2026, 10, 22, 12, 0, tzinfo=timezone.utc)
BATCH = "landing/ops/orders/dt=2026-01-01/batch=20260101T000000Z"


def test_empty_landing_passes():
    result = landing_at_rest([], NOW)
    assert (result.status, result.checked_count, result.failing_count) == ("pass", 0, 0)


def test_fresh_object_passes_and_exactly_one_hour_is_still_fresh():
    objects = [(f"{BATCH}/part-0.jsonl", NOW - timedelta(minutes=30)), (f"{BATCH}/_SUCCESS", NOW - timedelta(hours=1))]
    result = landing_at_rest(objects, NOW)
    assert (result.status, result.checked_count) == ("pass", 2)


def test_stale_batch_fails_and_is_named_once():
    objects = [
        (f"{BATCH}/part-0.jsonl", NOW - timedelta(hours=3)),
        (f"{BATCH}/_SUCCESS", NOW - timedelta(hours=3)),
        ("landing/finance/settlements/dt=2026-01-02/batch=20260102T000000Z/part-0.parquet", NOW - timedelta(minutes=5)),
    ]
    result = landing_at_rest(objects, NOW)
    assert (result.status, result.severity, result.failing_count, result.checked_count) == ("fail", "error", 2, 3)
    assert result.detail == f"2 object(s) older than 60 min in 1 batch(es): {BATCH}"


def test_folder_markers_are_ignored():
    result = landing_at_rest([("landing/", NOW - timedelta(days=30))], NOW)
    assert (result.status, result.checked_count) == ("pass", 0)


def test_naive_last_modified_rejected():
    with pytest.raises(ValueError):
        landing_at_rest([(f"{BATCH}/_SUCCESS", datetime(2026, 10, 22, 9, 0))], NOW)


class _FakeS3:
    def __init__(self, pages):
        self.pages = pages
        self.calls = []

    def get_paginator(self, name):
        assert name == "list_objects_v2"
        return self

    def paginate(self, **kwargs):
        self.calls.append(kwargs)
        return iter(self.pages)


def test_list_objects_reads_every_page():
    stamp = NOW - timedelta(hours=2)
    client = _FakeS3([{"Contents": [{"Key": "landing/a", "LastModified": stamp}]}, {}, {"Contents": [{"Key": "landing/b", "LastModified": stamp}]}])
    assert list_objects(client, "bucket") == [("landing/a", stamp), ("landing/b", stamp)]
    assert client.calls == [{"Bucket": "bucket", "Prefix": "landing/"}]