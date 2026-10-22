from datetime import datetime, timedelta

from pipeline_core.checks.results import CheckResult, evaluate

CHECK_NAME = "landing_empty_at_rest"
DATASET = "s3:landing/"
LANDING_PREFIX = "landing/"
MAX_AGE = timedelta(hours=1)
SHOWN_BATCHES = 5


def list_objects(client, bucket: str, prefix: str = LANDING_PREFIX) -> list[tuple[str, datetime]]:
    pairs = []
    for page in client.get_paginator("list_objects_v2").paginate(Bucket=bucket, Prefix=prefix):
        for item in page.get("Contents", []):
            pairs.append((item["Key"], item["LastModified"]))
    return pairs


def stale_keys(objects, now: datetime, max_age: timedelta = MAX_AGE) -> list[str]:
    if now.tzinfo is None:
        raise ValueError("now must be timezone-aware")
    stale = []
    for key, modified in objects:
        if modified.tzinfo is None:
            raise ValueError(f"last_modified of {key} must be timezone-aware")
        if now - modified > max_age:
            stale.append(key)
    return sorted(stale)


def landing_at_rest(objects, now: datetime, max_age: timedelta = MAX_AGE) -> CheckResult:
    files = [(key, modified) for key, modified in objects if not key.endswith("/")]
    stale = stale_keys(files, now, max_age)
    batches = sorted({key.rsplit("/", 1)[0] for key in stale})
    minutes = int(max_age.total_seconds() // 60)
    detail = f"{len(stale)} object(s) older than {minutes} min in {len(batches)} batch(es)"
    if batches:
        detail += ": " + ", ".join(batches[:SHOWN_BATCHES])
    return evaluate(CHECK_NAME, DATASET, "error", len(files), len(stale), detail)