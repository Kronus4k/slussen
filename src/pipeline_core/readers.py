from __future__ import annotations

import csv
import io
import json
import re
from decimal import Decimal

import pyarrow as pa
import pyarrow.parquet as pq

from pipeline_core.contracts import Column, Contract

INTEGER_TEXT_RE = re.compile(r"^-?\d+$")
DECIMAL_TEXT_RE = re.compile(r"^-?\d+(\.\d+)?$")


class ReadError(ValueError):
    pass


def _decode(data: bytes) -> str:
    try:
        return data.decode("utf-8-sig")
    except UnicodeDecodeError as exc:
        raise ReadError(f"not valid UTF-8: {exc.reason}") from exc


def read_jsonl(data: bytes) -> list[dict]:
    text = _decode(data)
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


def _convert(text: str, column: Column | None):
    if text == "":
        return None
    if column is None:
        return text
    if column.type == "integer" and INTEGER_TEXT_RE.match(text):
        return int(text)
    if column.decimal_spec and DECIMAL_TEXT_RE.match(text):
        return Decimal(text)
    return text


def read_csv(data: bytes, contract: Contract) -> list[dict]:
    reader = csv.reader(io.StringIO(_decode(data), newline=""))
    columns = {c.name: c for c in contract.columns}
    records: list[dict] = []
    try:
        header = next(reader, None)
        if header is None:
            return records
        for row in reader:
            if not row:
                continue
            if len(row) != len(header):
                raise ReadError(f"line {reader.line_num}: expected {len(header)} fields, got {len(row)}")
            records.append({name: _convert(value, columns.get(name)) for name, value in zip(header, row)})
    except csv.Error as exc:
        raise ReadError(f"line {reader.line_num}: {exc}") from exc
    return records


READERS = {"jsonl": read_jsonl, "parquet": read_parquet}


def read_records(data: bytes, fmt: str, contract: Contract | None = None) -> list[dict]:
    if fmt == "csv":
        if contract is None:
            raise ReadError("csv needs the contract to type its values")
        return read_csv(data, contract)
    reader = READERS.get(fmt)
    if reader is None:
        raise ReadError(f"no reader for format '{fmt}'")
    return reader(data)