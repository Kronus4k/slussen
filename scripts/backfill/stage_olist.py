import argparse
import json
import shutil
import time
from collections import Counter
from datetime import datetime, timezone
from pathlib import Path

from pipeline_core.gate import load_contracts, process_batch
from pipeline_core.storage import LocalStore


def table_name(csv_path: Path) -> str:
    name = csv_path.stem
    if name.startswith("olist_"):
        name = name[len("olist_"):]
    if name.endswith("_dataset"):
        name = name[: -len("_dataset")]
    return name


def stage(source: Path, out: Path, now: datetime) -> list[str]:
    stamp = now.strftime("dt=%Y-%m-%d/batch=%Y%m%dT%H%M%SZ")
    prefixes = []
    for csv_path in sorted(source.glob("*.csv")):
        prefix = f"landing/olist/{table_name(csv_path)}/{stamp}"
        folder = out.joinpath(*prefix.split("/"))
        folder.mkdir(parents=True, exist_ok=True)
        shutil.copyfile(csv_path, folder / "part-00000.csv")
        (folder / "_SUCCESS").write_bytes(b"")
        prefixes.append(prefix)
    return prefixes


def check(out: Path, prefixes: list[str], contracts_dir: Path) -> None:
    store = LocalStore(str(out))
    contracts = load_contracts(contracts_dir)
    print("| Table | Status | Records | Breaking | Warnings | Suppressed | Seconds |")
    print("| --- | --- | ---: | ---: | ---: | ---: | ---: |")
    for prefix in prefixes:
        started = time.monotonic()
        outcome = process_batch(store, prefix + "/_SUCCESS", contracts)
        seconds = time.monotonic() - started
        table = prefix.split("/")[2]
        print(f"| {table} | {outcome.status} | {outcome.records:,} | {outcome.breaking} | "
              f"{outcome.warnings} | {outcome.suppressed} | {seconds:.1f} |", flush=True)
        if outcome.audit_key:
            rows = [json.loads(line) for line in store.get(outcome.audit_key).decode("utf-8").splitlines()]
            counts = Counter((r["severity"], r["rule"], r["column_name"]) for r in rows)
            for (severity, rule, column), n in counts.items():
                print(f"    {severity} {rule} {column}: {n} row(s)")
            for r in rows:
                if r["severity"] == "info":
                    print(f"    info {r['rule']} {r['column_name']}: {r['detail']}")
                elif r["row_number"] is not None and r["severity"] == "breaking":
                    print(f"    example: {r['rule']} {r['column_name']} row {r['row_number']}: {r['detail']}")
                    break


def main() -> None:
    parser = argparse.ArgumentParser(description="Stage the Olist CSVs as contract batches, optionally run the gate locally.")
    parser.add_argument("--source", default="../data/olist", help="folder with the Olist CSV files")
    parser.add_argument("--out", default="local_data", help="local folder that mirrors the bucket root")
    parser.add_argument("--now", help="batch time, ISO 8601 UTC, e.g. 2026-10-19T12:00:00Z (default: now)")
    parser.add_argument("--contracts", default="contracts")
    parser.add_argument("--check", action="store_true", help="run the gate on every staged batch")
    args = parser.parse_args()

    now = datetime.fromisoformat(args.now) if args.now else datetime.now(timezone.utc).replace(microsecond=0)
    prefixes = stage(Path(args.source), Path(args.out), now)
    for prefix in prefixes:
        print(prefix)
    if args.check:
        check(Path(args.out), prefixes, Path(args.contracts))


if __name__ == "__main__":
    main()