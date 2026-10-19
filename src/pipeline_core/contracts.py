from __future__ import annotations

import re
from dataclasses import dataclass
from pathlib import Path

import yaml

FORMATS = {"jsonl", "parquet", "csv"}
SIMPLE_TYPES = {"string", "integer", "date", "timestamp", "timestamp_ntz", "boolean", "array"}
DECIMAL_RE = re.compile(r"^decimal\((\d+),(\d+)\)$")
REQUIRED_KEYS = ("contract", "version", "format", "location", "completeness", "primary_key", "columns")


class ContractError(ValueError):
    pass


@dataclass(frozen=True)
class Column:
    name: str
    type: str
    nullable: bool
    pii: bool = False
    fields: tuple[Column, ...] = ()

    @property
    def decimal_spec(self) -> tuple[int, int] | None:
        match = DECIMAL_RE.match(self.type)
        return (int(match.group(1)), int(match.group(2))) if match else None


@dataclass(frozen=True)
class Contract:
    name: str
    version: str
    format: str
    primary_key: tuple[str, ...]
    columns: tuple[Column, ...]
    location: dict
    success_marker: str
    sla: dict

    @property
    def column_names(self) -> tuple[str, ...]:
        return tuple(c.name for c in self.columns)

    def column(self, name: str) -> Column:
        for c in self.columns:
            if c.name == name:
                return c
        raise KeyError(name)


def _parse_column(raw: dict, where: str) -> Column:
    for key in ("name", "type", "nullable"):
        if key not in raw:
            raise ContractError(f"{where}: column is missing '{key}'")
    name, ctype = raw["name"], raw["type"]
    if ctype not in SIMPLE_TYPES and not DECIMAL_RE.match(ctype):
        raise ContractError(f"{where}.{name}: unknown type '{ctype}'")
    if not isinstance(raw["nullable"], bool):
        raise ContractError(f"{where}.{name}: nullable must be true or false")
    fields: tuple[Column, ...] = ()
    if ctype == "array":
        if not raw.get("fields"):
            raise ContractError(f"{where}.{name}: array columns need 'fields'")
        fields = tuple(_parse_column(f, f"{where}.{name}") for f in raw["fields"])
    return Column(name=name, type=ctype, nullable=raw["nullable"], pii=bool(raw.get("pii", False)), fields=fields)


def load_contract(path: str | Path) -> Contract:
    path = Path(path)
    raw = yaml.safe_load(path.read_text(encoding="utf-8"))
    if not isinstance(raw, dict):
        raise ContractError(f"{path.name}: top level must be a mapping")
    missing = [k for k in REQUIRED_KEYS if k not in raw]
    if missing:
        raise ContractError(f"{path.name}: missing keys {missing}")
    if raw["format"] not in FORMATS:
        raise ContractError(f"{path.name}: unsupported format '{raw['format']}'")
    if not isinstance(raw["primary_key"], list):
        raise ContractError(f"{path.name}: primary_key must be a list (use [] when the source has no key)")

    columns = tuple(_parse_column(c, raw["contract"]) for c in raw["columns"])
    names = [c.name for c in columns]
    duplicates = sorted({n for n in names if names.count(n) > 1})
    if duplicates:
        raise ContractError(f"{path.name}: duplicate columns {duplicates}")

    primary_key = tuple(raw["primary_key"])
    for key in primary_key:
        if key not in names:
            raise ContractError(f"{path.name}: primary key '{key}' is not a column")
        if columns[names.index(key)].nullable:
            raise ContractError(f"{path.name}: primary key '{key}' must not be nullable")

    return Contract(
        name=raw["contract"],
        version=str(raw["version"]),
        format=raw["format"],
        primary_key=primary_key,
        columns=columns,
        location=raw["location"],
        success_marker=raw["completeness"].get("success_marker", "_SUCCESS"),
        sla=raw.get("sla", {}),
    )