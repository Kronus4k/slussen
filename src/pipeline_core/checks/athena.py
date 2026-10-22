import time

FINAL_STATES = ("SUCCEEDED", "FAILED", "CANCELLED")


class AthenaQueryError(RuntimeError):
    pass


def run_statement(client, sql: str, workgroup: str, database: str, poll_s: float = 1.0, timeout_s: float = 300.0, sleep=time.sleep) -> dict:
    query_id = client.start_query_execution(
        QueryString=sql, WorkGroup=workgroup, QueryExecutionContext={"Database": database}
    )["QueryExecutionId"]
    waited = 0.0
    while True:
        execution = client.get_query_execution(QueryExecutionId=query_id)["QueryExecution"]
        if execution["Status"]["State"] in FINAL_STATES:
            break
        if waited >= timeout_s:
            client.stop_query_execution(QueryExecutionId=query_id)
            raise AthenaQueryError(f"query {query_id} still running after {timeout_s:.0f} s; stopped")
        sleep(poll_s)
        waited += poll_s
    result = {
        "query_id": query_id,
        "state": execution["Status"]["State"],
        "reason": execution["Status"].get("StateChangeReason", ""),
        "scanned_bytes": execution.get("Statistics", {}).get("DataScannedInBytes", 0),
        "rows": [],
    }
    if result["state"] == "SUCCEEDED" and execution.get("StatementType") == "DML":
        page = client.get_query_results(QueryExecutionId=query_id, MaxResults=11)
        result["rows"] = [[c.get("VarCharValue", "") for c in r["Data"]] for r in page["ResultSet"]["Rows"]]
    return result


def fetch_one_row(client, sql: str, workgroup: str, database: str, **kwargs) -> list[str]:
    result = run_statement(client, sql, workgroup, database, **kwargs)
    if result["state"] != "SUCCEEDED":
        raise AthenaQueryError(f"query {result['query_id']} {result['state']}: {result['reason']}")
    if len(result["rows"]) < 2:
        raise AthenaQueryError(f"query {result['query_id']} returned no data row")
    return result["rows"][1]