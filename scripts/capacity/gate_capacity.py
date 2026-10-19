import argparse
import base64
import json
import re
import time
from datetime import datetime, timedelta, timezone

import boto3
from botocore.config import Config

from pipeline_core.generators.ops_orders import batch_prefix, generate_batch, to_jsonl

FUNCTION = "slussen-validator"
LANDING = "landing/ops/orders/"
REPORT_RE = re.compile(
    r"REPORT RequestId: \S+\s+Duration: ([\d.]+) ms\s+Billed Duration: (\d+) ms"
    r".*?Max Memory Used: (\d+) MB(?:\s+Init Duration: ([\d.]+) ms)?"
)


def delete_prefix(s3, bucket: str, prefix: str) -> None:
    for page in s3.get_paginator("list_objects_v2").paginate(Bucket=bucket, Prefix=prefix):
        keys = [{"Key": o["Key"]} for o in page.get("Contents", [])]
        if keys:
            s3.delete_objects(Bucket=bucket, Delete={"Objects": keys, "Quiet": True})


def run_once(s3, lam, bucket: str, records: int, when: datetime, seed: int) -> dict:
    prefix = batch_prefix(when)
    partition = prefix[len(LANDING):]
    data = to_jsonl(generate_batch(records, when, seed=seed))
    s3.put_object(Bucket=bucket, Key=f"{prefix}/part-00000.jsonl", Body=data)

    # No _SUCCESS is uploaded, so EventBridge never fires; the gate only lists data files.
    started = time.monotonic()
    response = lam.invoke(
        FunctionName=FUNCTION,
        Payload=json.dumps({"bucket": bucket, "key": f"{prefix}/_SUCCESS"}).encode("utf-8"),
        LogType="Tail",
    )
    wall = time.monotonic() - started
    log = base64.b64decode(response.get("LogResult", "")).decode("utf-8", "replace")
    payload = json.loads(response["Payload"].read() or b"{}")

    if "FunctionError" in response:
        status = payload.get("errorType") or payload.get("errorMessage", "error")[:60]
    else:
        status = payload.get("status", "unknown")
    match = REPORT_RE.search(log)
    duration, billed, memory, init = match.groups() if match else (None, None, None, None)

    for p in (f"{prefix}/", f"validated/ops/orders/{partition}/", f"quarantine/ops/orders/{partition}/",
              f"audit/contract_violations/contract=ops_orders/{partition}/"):
        delete_prefix(s3, bucket, p)

    return {
        "records": records,
        "mb": len(data) / 1_000_000,
        "status": status,
        "duration_s": float(duration) / 1000 if duration else None,
        "billed_s": int(billed) / 1000 if billed else None,
        "max_memory_mb": int(memory) if memory else None,
        "init_ms": float(init) if init else None,
        "wall_s": wall,
    }


def fmt(value, pattern: str) -> str:
    return "-" if value is None else format(value, pattern)


def main() -> None:
    parser = argparse.ArgumentParser(description="Measure the contract gate Lambda on growing ops batches.")
    parser.add_argument("--bucket", default="slussen-lake-qwer")
    parser.add_argument("--profile", default="slussen-de")
    parser.add_argument("--region", default="eu-north-1")
    parser.add_argument("--sizes", default="1000,10000,25000,50000,100000,150000,200000")
    parser.add_argument("--warmup", type=int, default=100)
    args = parser.parse_args()

    session = boto3.Session(profile_name=args.profile, region_name=args.region)
    s3 = session.client("s3")
    # One attempt only: a retried invoke would run the gate twice on the same batch.
    lam = session.client("lambda", config=Config(read_timeout=310, connect_timeout=10,
                                                 retries={"total_max_attempts": 1}))
    base = datetime(2026, 1, 1, tzinfo=timezone.utc)

    run_once(s3, lam, args.bucket, args.warmup, base, seed=0)
    print("| Records | MB | Status | Duration s | Billed s | Max memory MB | Init ms | Wall s |")
    print("| ---: | ---: | --- | ---: | ---: | ---: | ---: | ---: |")
    for i, size in enumerate(int(s) for s in args.sizes.split(",")):
        row = run_once(s3, lam, args.bucket, size, base + timedelta(minutes=i + 1), seed=i + 1)
        print(f"| {row['records']:,} | {row['mb']:.1f} | {row['status']} | {fmt(row['duration_s'], '.2f')} | "
              f"{fmt(row['billed_s'], '.2f')} | {fmt(row['max_memory_mb'], 'd')} | {fmt(row['init_ms'], '.0f')} | "
              f"{row['wall_s']:.1f} |", flush=True)
        if row["status"] != "validated":
            print(f"Stopped at {size:,} records: {row['status']}")
            break


if __name__ == "__main__":
    main()