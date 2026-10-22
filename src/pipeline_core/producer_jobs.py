from __future__ import annotations

from datetime import date, datetime, timedelta
from pathlib import Path

from pipeline_core.contracts import Contract
from pipeline_core.gate import load_contracts
from pipeline_core.generators.finance_settlements import payout_week, settle_week
from pipeline_core.generators.ops_orders import Catalog, _as_ts, _ts, generate_batch, open_orders, to_jsonl
from pipeline_core.producer import ProducerResult, batch_id_for, batch_state, partition_for, publish_batch
from pipeline_core.readers import read_parquet
from pipeline_core.storage import Store
from pipeline_core.writers import to_parquet

OPS_LANDING = "landing/ops/orders/"
FINANCE_LANDING = "landing/finance/settlements/"
OPS_VALIDATED = "validated/ops/orders/"
OLIST_ITEMS = "validated/olist/order_items/"
OLIST_CUSTOMERS = "validated/olist/customers/"
OPS_SEED = 4101
FINANCE_SEED = 4102
OPS_RECORDS = 50
LOOKBACK_DAYS = 7


def _contract(contracts_dir: str | Path, landing: str) -> Contract:
    return next(c for c in load_contracts(contracts_dir) if c.location["landing"] == landing)


def _row(result: ProducerResult, feed: str, contract: str) -> dict:
    return {**result.to_dict(), "feed": feed, "contract": contract}


def _skipped(contract: Contract, batch_time: datetime, action: str) -> ProducerResult:
    prefix = contract.location["landing"] + partition_for(batch_time)
    return ProducerResult(batch_id_for(batch_time), prefix, action, 0, 0, 0)


def read_validated(store: Store, prefix: str) -> list[dict]:
    rows: list[dict] = []
    for key in sorted(store.list_keys(prefix)):
        if key.endswith(".parquet"):
            rows.extend(read_parquet(store.get(key)))
    return rows


def load_catalog(store: Store) -> Catalog:
    items = {
        (r["product_id"], r["seller_id"], r["price"], r["freight_value"])
        for r in read_validated(store, OLIST_ITEMS)
    }
    customers: dict[str, dict] = {}
    for r in read_validated(store, OLIST_CUSTOMERS):
        customers.setdefault(
            r["customer_unique_id"],
            {
                "customer_unique_id": r["customer_unique_id"],
                "customer_zip_code_prefix": r["customer_zip_code_prefix"],
                "customer_city": r["customer_city"],
                "customer_state": r["customer_state"],
            },
        )
    return Catalog(
        items=[
            {"product_id": p, "seller_id": s, "price": price, "freight_value": freight}
            for p, s, price, freight in sorted(items)
        ],
        customers=[customers[k] for k in sorted(customers)],
    )


def ops_events(store: Store, first_day: date, batch_time: datetime) -> list[dict]:
    cutoff = _ts(batch_time)
    rows: list[dict] = []
    day = first_day
    while day <= batch_time.date():
        rows.extend(read_validated(store, f"{OPS_VALIDATED}dt={day:%Y-%m-%d}/"))
        day += timedelta(days=1)
    return [r for r in rows if _as_ts(r["event_ts"]) < cutoff]


def run_ops_producer(
    store: Store,
    contracts_dir: str | Path,
    batch_time: datetime,
    seed: int = OPS_SEED,
    records: int = OPS_RECORDS,
    lookback_days: int = LOOKBACK_DAYS,
) -> dict:
    contract = _contract(contracts_dir, OPS_LANDING)
    state = batch_state(store, contract, partition_for(batch_time))
    if state != "new":
        return _row(_skipped(contract, batch_time, f"skipped_{state}"), "ops", "ops_orders")
    pool = open_orders(ops_events(store, (batch_time - timedelta(days=lookback_days)).date(), batch_time))
    batch = generate_batch(records, batch_time, seed=seed, catalog=load_catalog(store), open_pool=pool)
    result = publish_batch(store, contract, batch_time, {"part-00000.jsonl": to_jsonl(batch)}, len(batch))
    return _row(result, "ops", "ops_orders")


def run_finance_producer(
    store: Store,
    contracts_dir: str | Path,
    batch_time: datetime,
    seed: int = FINANCE_SEED,
) -> dict:
    contract = _contract(contracts_dir, FINANCE_LANDING)
    state = batch_state(store, contract, partition_for(batch_time))
    if state != "new":
        return _row(_skipped(contract, batch_time, f"skipped_{state}"), "finance", "finance_settlements")
    week_start, _, _ = payout_week(batch_time)
    rows = settle_week(ops_events(store, week_start, batch_time), batch_time, seed=seed)
    if not rows:
        return _row(_skipped(contract, batch_time, "skipped_empty"), "finance", "finance_settlements")
    result = publish_batch(store, contract, batch_time, {"part-00000.parquet": to_parquet(rows, contract)}, len(rows))
    return _row(result, "finance", "finance_settlements")