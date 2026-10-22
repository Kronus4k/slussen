from __future__ import annotations

from dataclasses import asdict, dataclass
from datetime import datetime

from pipeline_core.contracts import Contract
from pipeline_core.storage import Store


@dataclass
class ProducerResult:
    batch_id: str
    s3_prefix: str
    action: str
    file_count: int
    record_count: int
    byte_count: int

    def to_dict(self) -> dict:
        return asdict(self)


def batch_id_for(batch_time: datetime) -> str:
    return f"{batch_time:%Y%m%dT%H%M%SZ}"


def partition_for(batch_time: datetime) -> str:
    return f"dt={batch_time:%Y-%m-%d}/batch={batch_id_for(batch_time)}/"


def batch_state(store: Store, contract: Contract, partition: str) -> str:
    """Return validated, quarantined, in_flight or new, using the gate's own markers."""
    marker = contract.success_marker
    if store.exists(contract.location["validated"] + partition + marker):
        return "validated"
    if store.exists(contract.location["quarantine"] + partition + marker):
        return "quarantined"
    if store.list_keys(contract.location["landing"] + partition):
        return "in_flight"
    return "new"


def publish_batch(
    store: Store,
    contract: Contract,
    batch_time: datetime,
    files: dict[str, bytes],
    record_count: int,
) -> ProducerResult:
    if not files:
        raise ValueError("a batch needs at least one data file")
    if contract.success_marker in files:
        raise ValueError("the producer writes the success marker itself")

    partition = partition_for(batch_time)
    prefix = contract.location["landing"] + partition
    state = batch_state(store, contract, partition)
    if state != "new":
        return ProducerResult(batch_id_for(batch_time), prefix, f"skipped_{state}", 0, 0, 0)

    for name in sorted(files):
        store.put(prefix + name, files[name])
    store.put(prefix + contract.success_marker, b"")
    return ProducerResult(
        batch_id_for(batch_time),
        prefix,
        "uploaded",
        len(files),
        record_count,
        sum(len(data) for data in files.values()),
    )