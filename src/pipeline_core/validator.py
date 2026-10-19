from __future__ import annotations

import re
from dataclasses import dataclass, field
from datetime import date, datetime, timedelta
from decimal import Decimal, InvalidOperation

from pipeline_core.contracts import Column, Contract

BREAKING = "breaking"
WARNING = "warning"
INFO = "info"
MAX_ROWS_PER_RULE = 10
ISO_DATE_RE = re.compile(r"^\d{4}-\d{2}-\d{2}$")
NTZ_TIMESTAMP_RE = re.compile(r"^\d{4}-\d{2}-\d{2}[ T]\d{2}:\d{2}:\d{2}(\.\d{1,6})?$")


@dataclass(frozen=True)
class Violation:
    rule: str
    severity: str
    column: str | None
    detail: str
    row: int | None = None
    suppressed_count: int | None = None


@dataclass
class ValidationResult:
    contract: str
    version: str
    records: int
    violations: list[Violation] = field(default_factory=list)
    suppressed: int = 0

    @property
    def breaking(self) -> list[Violation]:
        return [v for v in self.violations if v.severity == BREAKING]

    @property
    def warnings(self) -> list[Violation]:
        return [v for v in self.violations if v.severity == WARNING]

    @property
    def passed(self) -> bool:
        return not self.breaking


def _is_utc_timestamp(value) -> bool:
    if isinstance(value, datetime):
        ts = value
    elif isinstance(value, str):
        try:
            ts = datetime.fromisoformat(value)
        except ValueError:
            return False
    else:
        return False
    return ts.utcoffset() == timedelta(0)


def _is_ntz_timestamp(value) -> bool:
    if isinstance(value, datetime):
        return value.tzinfo is None
    if isinstance(value, str) and NTZ_TIMESTAMP_RE.match(value):
        try:
            return datetime.fromisoformat(value).tzinfo is None
        except ValueError:
            return False
    return False


def _is_date(value) -> bool:
    if isinstance(value, datetime):
        return False
    if isinstance(value, date):
        return True
    if isinstance(value, str) and ISO_DATE_RE.match(value):
        try:
            date.fromisoformat(value)
            return True
        except ValueError:
            return False
    return False


def _fits_decimal(value, precision: int, scale: int) -> bool:
    if isinstance(value, bool):
        return False
    if isinstance(value, int):
        value = Decimal(value)
    if not isinstance(value, Decimal) or not value.is_finite():
        return False
    try:
        if value != value.quantize(Decimal(1).scaleb(-scale)):
            return False
    except InvalidOperation:
        return False
    return abs(value) < Decimal(10) ** (precision - scale)


def _matches_type(value, column: Column) -> bool:
    spec = column.decimal_spec
    if spec:
        return _fits_decimal(value, *spec)
    if column.type == "string":
        return isinstance(value, str)
    if column.type == "integer":
        return isinstance(value, int) and not isinstance(value, bool)
    if column.type == "boolean":
        return isinstance(value, bool)
    if column.type == "date":
        return _is_date(value)
    if column.type == "timestamp":
        return _is_utc_timestamp(value)
    if column.type == "timestamp_ntz":
        return _is_ntz_timestamp(value)
    return False


def _type_mismatch(path: str, column: Column, value, row: int) -> Violation:
    return Violation("type_mismatch", BREAKING, path, f"expected {column.type}, got {type(value).__name__}", row)


def _check_value(value, column: Column, path: str, row: int, out: list[Violation]) -> None:
    if value is None:
        if not column.nullable:
            out.append(Violation("null_in_required", BREAKING, path, "required value is null", row))
        return
    if column.type != "array":
        if not _matches_type(value, column):
            out.append(_type_mismatch(path, column, value, row))
        return
    if not isinstance(value, list):
        out.append(_type_mismatch(path, column, value, row))
        return
    known = {f.name for f in column.fields}
    for element in value:
        if not isinstance(element, dict):
            out.append(_type_mismatch(path, column, element, row))
            continue
        for name in sorted(set(element) - known):
            out.append(Violation("extra_column", WARNING, f"{path}.{name}", "field not in contract, not loaded", row))
        for f in column.fields:
            child = f"{path}.{f.name}"
            if f.name not in element:
                out.append(Violation("missing_column", BREAKING, child, "field missing from array element", row))
                continue
            _check_value(element[f.name], f, child, row, out)


def _check_primary_key(records: list[dict], contract: Contract, out: list[Violation]) -> None:
    if not contract.primary_key:
        return
    first_seen: dict[tuple, int] = {}
    key_name = ",".join(contract.primary_key)
    for row, record in enumerate(records):
        key = tuple(record.get(k) for k in contract.primary_key)
        if any(part is None for part in key):
            continue
        if key in first_seen:
            out.append(Violation("duplicate_primary_key", BREAKING, key_name, f"same key as row {first_seen[key]}", row))
        else:
            first_seen[key] = row


def _limit(violations: list[Violation]) -> tuple[list[Violation], int]:
    kept: list[Violation] = []
    counts: dict[tuple, int] = {}
    for v in violations:
        key = (v.rule, v.column)
        counts[key] = counts.get(key, 0) + 1
        if counts[key] <= MAX_ROWS_PER_RULE:
            kept.append(v)
    summaries = [
        Violation(
            rule,
            INFO,
            column,
            f"{n - MAX_ROWS_PER_RULE} more suppressed (cap {MAX_ROWS_PER_RULE} per rule and column)",
            None,
            n - MAX_ROWS_PER_RULE,
        )
        for (rule, column), n in counts.items()
        if n > MAX_ROWS_PER_RULE
    ]
    return kept + summaries, sum(s.suppressed_count for s in summaries)


def validate_records(records: list[dict], contract: Contract) -> ValidationResult:
    found: list[Violation] = []
    present = set().union(*(r.keys() for r in records)) if records else set()
    expected = set(contract.column_names)

    for name in sorted(present - expected):
        found.append(Violation("extra_column", WARNING, name, "column not in contract, not loaded"))
    missing = [c.name for c in contract.columns if c.name not in present]
    for name in missing:
        found.append(Violation("missing_column", BREAKING, name, "column absent from every record"))

    for row, record in enumerate(records):
        for column in contract.columns:
            if column.name in missing:
                continue
            _check_value(record.get(column.name), column, column.name, row, found)

    _check_primary_key(records, contract, found)

    kept, suppressed = _limit(found)
    return ValidationResult(
        contract=contract.name,
        version=contract.version,
        records=len(records),
        violations=kept,
        suppressed=suppressed,
    )