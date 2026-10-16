from __future__ import annotations

import json
from decimal import Decimal

import pyarrow as pa
import pyarrow.parquet as pq


class ReadError(ValueError):
    pass


def read_jsonl(data: bytes) -> list[dict]:
    try:
        text = data.decode("utf-8-sig")
    except UnicodeDecodeError as exc:
        raise ReadError(f"not valid UTF-8: {exc.reason}") from exc
    records: list[dict] = []
    for line_no, line in enumerate(text.splitlines(), start=1):
        if not line.strip():
            continue
        try:
            obj = json.loads(line, parse_float=Decimal)
        except json.JSONDecodeError as exc:
            raise ReadError(f"line {line_no}: invalid JSON ({exc.msg})") from exc
        if not isinstance(obj, dict):
            raise ReadError(f"line {line_no}: expected a JSON object")
        records.append(obj)
    return records


def read_parquet(data: bytes) -> list[dict]:
    try:
        table = pq.read_table(pa.BufferReader(data))
    except (pa.ArrowException, OSError) as exc:
        raise ReadError(f"not a readable Parquet file: {exc}") from exc
    return table.to_pylist()


READERS = {"jsonl": read_jsonl, "parquet": read_parquet}


def read_records(data: bytes, fmt: str) -> list[dict]:
    reader = READERS.get(fmt)
    if reader is None:
        raise ReadError(f"no reader for format '{fmt}'")
    return reader(data)