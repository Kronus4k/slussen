import argparse
import sys
import time
from pathlib import Path

import boto3

FINAL_STATES = ("SUCCEEDED", "FAILED", "CANCELLED")


def split_statements(text: str) -> list[str]:
    return [s.strip() for s in text.split(";\n") if s.strip()]


def run_statement(client, sql: str, workgroup: str, database: str) -> dict:
    query_id = client.start_query_execution(
        QueryString=sql, WorkGroup=workgroup, QueryExecutionContext={"Database": database}
    )["QueryExecutionId"]
    while True:
        execution = client.get_query_execution(QueryExecutionId=query_id)["QueryExecution"]
        if execution["Status"]["State"] in FINAL_STATES:
            break
        time.sleep(1)
    result = {
        "state": execution["Status"]["State"],
        "reason": execution["Status"].get("StateChangeReason", ""),
        "scanned_bytes": execution.get("Statistics", {}).get("DataScannedInBytes", 0),
        "rows": [],
    }
    if result["state"] == "SUCCEEDED" and execution.get("StatementType") == "DML":
        page = client.get_query_results(QueryExecutionId=query_id, MaxResults=11)
        result["rows"] = [[c.get("VarCharValue", "") for c in r["Data"]] for r in page["ResultSet"]["Rows"]]
    return result


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