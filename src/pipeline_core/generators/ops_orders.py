from __future__ import annotations

import argparse
import json
import random
import uuid
from dataclasses import dataclass, field
from datetime import date, datetime, timedelta, timezone
from decimal import Decimal
from pathlib import Path

LANDING_PREFIX = "landing/ops/orders"
BREAK_MODES = ("rename_column", "wrong_type", "null_required", "duplicate_key", "extra_column")
CITIES = {
    "SP": ["sao paulo", "campinas", "santos"],
    "RJ": ["rio de janeiro", "niteroi"],
    "MG": ["belo horizonte", "uberlandia"],
    "RS": ["porto alegre"],
    "PR": ["curitiba"],
    "BA": ["salvador"],
    "PE": ["recife"],
    "GO": ["goiania"],
    "DF": ["brasilia"],
    "AM": ["manaus"],
}
STATE_WEIGHTS = [42, 13, 12, 6, 5, 4, 2, 2, 2, 1]
PAYMENT_TYPES = ["credit_card", "boleto", "voucher", "debit_card"]
PAYMENT_WEIGHTS = [74, 19, 5, 2]
EVENTS = [
    ("order_created", "created"),
    ("status_changed", "approved"),
    ("status_changed", "shipped"),
    ("status_changed", "delivered"),
    ("order_canceled", "canceled"),
]
EVENT_WEIGHTS = [40, 20, 15, 20, 5]
CENT = Decimal("0.01")
NEXT_STATUS = {"created": "approved", "approved": "shipped", "shipped": "delivered"}
OPEN_STATUSES = tuple(NEXT_STATUS)
STAGE_FIELD = {
    "approved": "order_approved_ts",
    "shipped": "order_delivered_carrier_ts",
    "delivered": "order_delivered_customer_ts",
}
CANCEL_RATE = 0.05
RETURNING_RATE = 0.03
WINDOW = timedelta(hours=4)


@dataclass(frozen=True)
class Catalog:
    items: list[dict]
    customers: list[dict] = field(default_factory=list)


def _ts(value: datetime) -> str:
    return value.strftime("%Y-%m-%dT%H:%M:%SZ")


def _as_ts(value) -> str | None:
    if value is None or isinstance(value, str):
        return value
    if value.tzinfo is None:
        value = value.replace(tzinfo=timezone.utc)
    return _ts(value.astimezone(timezone.utc))


def _as_date(value) -> str | None:
    if value is None or isinstance(value, str):
        return value
    if isinstance(value, datetime):
        value = value.date()
    return value.isoformat() if isinstance(value, date) else str(value)


def _hex_id(rng: random.Random) -> str:
    return uuid.UUID(int=rng.getrandbits(128), version=4).hex


def _money(rng: random.Random, low: float, high: float) -> Decimal:
    return Decimal(str(rng.uniform(low, high))).quantize(CENT)


def _payments(rng: random.Random, items: list[dict]) -> list[dict]:
    payment_type = rng.choices(PAYMENT_TYPES, PAYMENT_WEIGHTS)[0]
    return [
        {
            "payment_sequential": 1,
            "payment_type": payment_type,
            "payment_installments": rng.randint(1, 10) if payment_type == "credit_card" else 1,
            "payment_value": sum((i["price"] + i["freight_value"] for i in items), Decimal("0")),
        }
    ]


def _record(rng: random.Random, now: datetime) -> dict:
    event_type, status = rng.choices(EVENTS, EVENT_WEIGHTS)[0]
    event_ts = now - timedelta(seconds=rng.randint(0, 4 * 3600 - 1))

    stages: dict[str, datetime] = {}
    t = event_ts
    if status == "delivered":
        stages["delivered"] = t
        t -= timedelta(days=rng.randint(2, 15))
    if status in ("shipped", "delivered"):
        stages["carrier"] = t
        t -= timedelta(days=rng.randint(1, 4))
    if status in ("approved", "shipped", "delivered"):
        stages["approved"] = t
        t -= timedelta(minutes=rng.randint(5, 600))
    if status == "canceled":
        t -= timedelta(hours=rng.randint(1, 72))
    purchase_ts = t

    state = rng.choices(list(CITIES), STATE_WEIGHTS)[0]
    items = [
        {
            "order_item_id": i,
            "product_id": _hex_id(rng),
            "seller_id": _hex_id(rng),
            "price": _money(rng, 10, 500),
            "freight_value": _money(rng, 5, 60),
        }
        for i in range(1, rng.choices([1, 2, 3], [85, 11, 4])[0] + 1)
    ]
    payments = _payments(rng, items)
    if status == "created" and rng.random() < 0.1:
        payments = None

    return {
        "event_id": str(uuid.UUID(int=rng.getrandbits(128), version=4)),
        "event_type": event_type,
        "event_ts": _ts(event_ts),
        "order_id": _hex_id(rng),
        "order_status": status,
        "customer_id": _hex_id(rng),
        "customer_unique_id": _hex_id(rng),
        "customer_zip_code_prefix": f"{rng.randint(1000, 99999):05d}",
        "customer_city": rng.choice(CITIES[state]),
        "customer_state": state,
        "order_purchase_ts": _ts(purchase_ts),
        "order_approved_ts": _ts(stages["approved"]) if "approved" in stages else None,
        "order_delivered_carrier_ts": _ts(stages["carrier"]) if "carrier" in stages else None,
        "order_delivered_customer_ts": _ts(stages["delivered"]) if "delivered" in stages else None,
        "order_estimated_delivery_date": (purchase_ts + timedelta(days=rng.randint(10, 30))).date().isoformat(),
        "items": items,
        "payments": payments,
    }


def _new_order(rng: random.Random, now: datetime, catalog: Catalog) -> dict:
    event_ts = now - timedelta(seconds=rng.randint(0, 4 * 3600 - 1))
    picks = [rng.choice(catalog.items) for _ in range(rng.choices([1, 2, 3], [85, 11, 4])[0])]
    items = [
        {
            "order_item_id": i,
            "product_id": p["product_id"],
            "seller_id": p["seller_id"],
            "price": Decimal(str(p["price"])).quantize(CENT),
            "freight_value": Decimal(str(p["freight_value"])).quantize(CENT),
        }
        for i, p in enumerate(picks, start=1)
    ]
    payments = _payments(rng, items)
    if rng.random() < 0.1:
        payments = None

    if catalog.customers and rng.random() < RETURNING_RATE:
        c = rng.choice(catalog.customers)
        customer = {
            "customer_unique_id": c["customer_unique_id"],
            "customer_zip_code_prefix": c["customer_zip_code_prefix"],
            "customer_city": c["customer_city"],
            "customer_state": c["customer_state"],
        }
    else:
        state = rng.choices(list(CITIES), STATE_WEIGHTS)[0]
        customer = {
            "customer_unique_id": _hex_id(rng),
            "customer_zip_code_prefix": f"{rng.randint(1000, 99999):05d}",
            "customer_city": rng.choice(CITIES[state]),
            "customer_state": state,
        }

    return {
        "event_id": str(uuid.UUID(int=rng.getrandbits(128), version=4)),
        "event_type": "order_created",
        "event_ts": _ts(event_ts),
        "order_id": _hex_id(rng),
        "order_status": "created",
        "customer_id": _hex_id(rng),
        **customer,
        "order_purchase_ts": _ts(event_ts),
        "order_approved_ts": None,
        "order_delivered_carrier_ts": None,
        "order_delivered_customer_ts": None,
        "order_estimated_delivery_date": (event_ts + timedelta(days=rng.randint(10, 30))).date().isoformat(),
        "items": items,
        "payments": payments,
    }


def _advance(rng: random.Random, now: datetime, order: dict) -> dict:
    status = order["order_status"]
    previous = datetime.fromisoformat(_as_ts(order["event_ts"]).replace("Z", "+00:00"))
    earliest = max(previous + timedelta(minutes=1), now - WINDOW)
    span = max(int((now - earliest).total_seconds()), 1)
    event_ts = earliest + timedelta(seconds=rng.randint(0, span - 1))

    if status in ("created", "approved") and rng.random() < CANCEL_RATE:
        event_type, new_status = "order_canceled", "canceled"
    else:
        event_type, new_status = "status_changed", NEXT_STATUS[status]

    items = [dict(i) for i in order["items"]]
    payments = [dict(p) for p in order["payments"]] if order.get("payments") else None
    if payments is None and new_status == "approved":
        payments = _payments(rng, items)

    record = {
        "event_id": str(uuid.UUID(int=rng.getrandbits(128), version=4)),
        "event_type": event_type,
        "event_ts": _ts(event_ts),
        "order_id": order["order_id"],
        "order_status": new_status,
        "customer_id": order["customer_id"],
        "customer_unique_id": order["customer_unique_id"],
        "customer_zip_code_prefix": order["customer_zip_code_prefix"],
        "customer_city": order["customer_city"],
        "customer_state": order["customer_state"],
        "order_purchase_ts": _as_ts(order["order_purchase_ts"]),
        "order_approved_ts": _as_ts(order.get("order_approved_ts")),
        "order_delivered_carrier_ts": _as_ts(order.get("order_delivered_carrier_ts")),
        "order_delivered_customer_ts": _as_ts(order.get("order_delivered_customer_ts")),
        "order_estimated_delivery_date": _as_date(order["order_estimated_delivery_date"]),
        "items": items,
        "payments": payments,
    }
    if new_status in STAGE_FIELD:
        record[STAGE_FIELD[new_status]] = _ts(event_ts)
    return record


def open_orders(records: list[dict]) -> list[dict]:
    latest: dict[str, dict] = {}
    for r in records:
        current = latest.get(r["order_id"])
        if current is None or (_as_ts(r["event_ts"]), r["event_id"]) > (_as_ts(current["event_ts"]), current["event_id"]):
            latest[r["order_id"]] = r
    return sorted((r for r in latest.values() if r["order_status"] in OPEN_STATUSES), key=lambda r: r["order_id"])


def _apply_break(records: list[dict], mode: str) -> None:
    if mode == "rename_column":
        for r in records:
            r["status"] = r.pop("order_status")
    elif mode == "wrong_type":
        for r in records:
            r["customer_zip_code_prefix"] = int(r["customer_zip_code_prefix"])
    elif mode == "null_required":
        records[0]["order_id"] = None
    elif mode == "duplicate_key":
        records[-1]["event_id"] = records[0]["event_id"]
    elif mode == "extra_column":
        for r in records:
            r["discount_code"] = "BF10"


def generate_batch(
    n: int,
    now: datetime,
    seed: int | None = None,
    break_mode: str | None = None,
    catalog: Catalog | None = None,
    open_pool: list[dict] | None = None,
) -> list[dict]:
    if break_mode is not None and break_mode not in BREAK_MODES:
        raise ValueError(f"unknown break mode '{break_mode}', choose from {BREAK_MODES}")
    if n < 2:
        raise ValueError("a batch needs at least 2 records")
    if catalog is not None and not catalog.items:
        raise ValueError("a catalog needs at least one item")
    rng = random.Random(None if seed is None else f"{seed}:{_ts(now)}")
    if catalog is None:
        records = [_record(rng, now) for _ in range(n)]
    else:
        pool = list(open_pool or [])
        k = min(len(pool), n // 2)
        advanced = [_advance(rng, now, order) for order in rng.sample(pool, k)]
        records = advanced + [_new_order(rng, now, catalog) for _ in range(n - k)]
    if break_mode:
        _apply_break(records, break_mode)
    return records


def _json_default(value):
    if isinstance(value, Decimal):
        return float(value)
    raise TypeError(f"not JSON serializable: {type(value).__name__}")


def to_jsonl(records: list[dict]) -> bytes:
    lines = (json.dumps(r, default=_json_default, ensure_ascii=False) + "\n" for r in records)
    return "".join(lines).encode("utf-8")


def batch_prefix(now: datetime) -> str:
    return f"{LANDING_PREFIX}/dt={now:%Y-%m-%d}/batch={now:%Y%m%dT%H%M%SZ}"


def write_batch(records: list[dict], out_dir: str | Path, now: datetime) -> Path:
    folder = Path(out_dir) / batch_prefix(now)
    folder.mkdir(parents=True, exist_ok=True)
    (folder / "part-00000.jsonl").write_bytes(to_jsonl(records))
    (folder / "_SUCCESS").write_bytes(b"")
    return folder


def main() -> None:
    parser = argparse.ArgumentParser(description="Write one synthetic ops_orders batch.")
    parser.add_argument("--out", required=True, help="local folder that mirrors the bucket root")
    parser.add_argument("--records", type=int, default=50)
    parser.add_argument("--seed", type=int, default=None)
    parser.add_argument("--break", dest="break_mode", choices=BREAK_MODES, default=None)
    parser.add_argument("--now", default=None, help="batch time, ISO 8601 UTC, e.g. 2026-10-16T08:00:00Z")
    args = parser.parse_args()

    now = datetime.fromisoformat(args.now) if args.now else datetime.now(timezone.utc).replace(microsecond=0)
    folder = write_batch(generate_batch(args.records, now, args.seed, args.break_mode), args.out, now)
    print(folder.as_posix())


if __name__ == "__main__":
    main()