import argparse
import sys
from pathlib import Path

import boto3

from pipeline_core.checks.athena import run_statement


def split_statements(text: str) -> list[str]:
    return [s.strip() for s in text.split(";\n") if s.strip()]


def main() -> None:
    parser = argparse.ArgumentParser(description="Run a SQL file statement by statement in Athena.")
    parser.add_argument("file")
    parser.add_argument("--workgroup", default="slussen")
    parser.add_argument("--database", default="slussen_lake")
    parser.add_argument("--profile", default="slussen-de")
    parser.add_argument("--region", default="eu-north-1")
    args = parser.parse_args()

    client = boto3.Session(profile_name=args.profile, region_name=args.region).client("athena")
    failed = 0
    for sql in split_statements(Path(args.file).read_text(encoding="utf-8")):
        result = run_statement(client, sql, args.workgroup, args.database)
        first_line = sql.splitlines()[0][:80]
        print(f"{result['state']:<9} {result['scanned_bytes'] / 1_000_000:>9.2f} MB  {first_line}")
        if result["state"] != "SUCCEEDED":
            failed += 1
            print(f"          {result['reason']}")
        for row in result["rows"]:
            print("          " + " | ".join(row))
    sys.exit(1 if failed else 0)


if __name__ == "__main__":
    main()