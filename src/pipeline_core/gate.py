from __future__ import annotations

import json
from dataclasses import asdict, dataclass, field
from datetime import datetime, timezone
from pathlib import Path, PurePosixPath

from pipeline_core.contracts import Contract, load_contract
from pipeline_core.readers import ReadError, read_records
from pipeline_core.storage import Store
from pipeline_core.validator import BREAKING, Violation, validate_records
from pipeline_core.writers import to_parquet

AUDIT_PREFIX = "audit/contract_violations"


class GateError(ValueError):
    pass


@dataclass
class GateOutcome:
    status: str
    contract: str
    version: str
    batch: str
    files: int = 0
    records: int = 0
    breaking: int = 0
    warnings: int = 0
    written: list[str] = field(default_factory=list)
    audit_key: str | None = None

    def to_dict(self) -> dict:
        return asdict(self)


def load_contracts(directory: str | Path) -> list[Contract]:
    return [load_contract(p) for p in sorted(Path(directory).glob("*.yaml"))]


def match_contract(key: str, contracts: list[Contract]) -> Contract:
    for contract in contracts:
        if key.startswith(contract.location["landing"]):
            return contract
    raise GateError(f"no contract covers key '{key}'")


def _audit_lines(findings, contract: Contract, outcome: GateOutcome, detected_at: str) -> bytes:
    rows = [
        {
            "detected_at": detected_at,
            "contract": contract.name,
            "contract_version": contract.version,
            "batch": outcome.batch,
            "file_key": key,
            "batch_status": outcome.status,
            "rule": v.rule,
            "severity": v.severity,
            "column_name": v.column,
            "row_number": v.row,
            "detail": v.detail,
        }
        for key, v in findings
    ]
    return "".join(json.dumps(r) + "\n" for r in rows).encode("utf-8")


def process_batch(store: Store, success_key: str, contracts: list[Contract], now: datetime | None = None) -> GateOutcome:
    contract = match_contract(success_key, contracts)
    if PurePosixPath(success_key).name != contract.success_marker:
        raise GateError(f"'{success_key}' is not a {contract.success_marker} marker")

    batch_prefix = success_key[: -len(contract.success_marker)]
    partition = batch_prefix[len(contract.location["landing"]):]
    validated_prefix = contract.location["validated"] + partition
    quarantine_prefix = contract.location["quarantine"] + partition
    outcome = GateOutcome("validated", contract.name, contract.version, partition.rstrip("/"))

    if store.exists(validated_prefix + contract.success_marker) or store.exists(quarantine_prefix + contract.success_marker):
        outcome.status = "skipped"
        return outcome

    data_keys = [k for k in store.list_keys(batch_prefix) if k != success_key]
    outcome.files = len(data_keys)
    findings: list[tuple[str, Violation]] = []
    parsed: dict[str, list[dict]] = {}

    if not data_keys:
        findings.append((batch_prefix, Violation("empty_batch", BREAKING, None, "success marker without data files")))
    for key in data_keys:
        try:
            records = read_records(store.get(key), contract.format)
        except ReadError as exc:
            findings.append((key, Violation("unreadable_file", BREAKING, None, str(exc))))
            continue
        result = validate_records(records, contract)
        outcome.records += len(records)
        findings.extend((key, v) for v in result.violations)
        parsed[key] = records

    outcome.breaking = sum(1 for _, v in findings if v.severity == BREAKING)
    outcome.warnings = len(findings) - outcome.breaking

    if outcome.breaking:
        outcome.status = "quarantined"
        target_prefix = quarantine_prefix
        for key in data_keys:
            target = quarantine_prefix + PurePosixPath(key).name
            store.copy(key, target)
            outcome.written.append(target)
    else:
        target_prefix = validated_prefix
        for key in data_keys:
            target = validated_prefix + PurePosixPath(key).stem + ".parquet"
            store.put(target, to_parquet(parsed[key], contract))
            outcome.written.append(target)

    if findings:
        detected_at = (now or datetime.now(timezone.utc)).strftime("%Y-%m-%dT%H:%M:%SZ")
        outcome.audit_key = f"{AUDIT_PREFIX}/contract={contract.name}/{partition}violations.jsonl"
        store.put(outcome.audit_key, _audit_lines(findings, contract, outcome, detected_at))

    store.put(target_prefix + contract.success_marker, b"")
    for key in data_keys + [success_key]:
        store.delete(key)
    return outcome