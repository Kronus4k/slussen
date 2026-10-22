from __future__ import annotations

import random
import uuid
from datetime import date, datetime, timedelta
from decimal import ROUND_HALF_UP, Decimal

from pipeline_core.generators.ops_orders import _as_ts

PAID_STATUSES = ("approved", "shipped", "delivered")
PERCENT_FEES = {"credit_card": Decimal("0.0299"), "debit_card": Decimal("0.0149")}
FLAT_FEES = {"boleto": Decimal("3.49")}
PAYOUT_DELAY_DAYS = {"credit_card": 30, "boleto": 2, "debit_card": 1, "voucher": 7}
DEFAULT_DELAY_DAYS = 7
CENT = Decimal("0.01")
SETTLEMENT_NAMESPACE = uuid.uuid5(uuid.NAMESPACE_URL, "slussen/finance_settlements")


def _money(value) -> Decimal:
    return Decimal(str(value)).quantize(CENT, rounding=ROUND_HALF_UP)


def _latest(records: list[dict]) -> list[dict]:
    latest: dict[str, tuple] = {}
    for r in records:
        key = (_as_ts(r["event_ts"]), r["event_id"])
        current = latest.get(r["order_id"])
        if current is None or key > current[0]:
            latest[r["order_id"]] = (key, r)
    return [latest[order_id][1] for order_id in sorted(latest)]


def payout_week(batch_time: datetime) -> tuple[date, date, str]:
    week_start = batch_time.date() - timedelta(days=batch_time.weekday() + 7)
    year, week, _ = week_start.isocalendar()
    return week_start, week_start + timedelta(days=6), f"PB-{year}W{week:02d}"


def _fee(payment_type: str, gross: Decimal) -> Decimal:
    if payment_type in PERCENT_FEES:
        return _money(gross * PERCENT_FEES[payment_type])
    return min(FLAT_FEES.get(payment_type, Decimal("0.00")), gross)


def settle_week(
    records: list[dict],
    batch_time: datetime,
    seed: int | None = None,
    mismatch_rate: float = 0.005,
    dispute_rate: float = 0.01,
) -> list[dict]:
    rng = random.Random(None if seed is None else f"{seed}:{batch_time:%Y-%m-%dT%H:%M:%SZ}")
    week_start, week_end, payout_batch_id = payout_week(batch_time)
    rows: list[dict] = []
    for order in _latest(records):
        approved = _as_ts(order.get("order_approved_ts"))
        if order["order_status"] not in PAID_STATUSES or not approved or not order.get("payments"):
            continue
        payment_date = date.fromisoformat(approved[:10])
        if not week_start <= payment_date <= week_end:
            continue
        for payment in sorted(order["payments"], key=lambda p: p["payment_sequential"]):
            gross = _money(payment["payment_value"])
            if rng.random() < mismatch_rate:
                gross = max(gross + rng.choice((-1, 1)) * Decimal(rng.randint(1, 500)) / 100, CENT)
            payment_type = payment["payment_type"]
            fee = _fee(payment_type, gross)
            due = payment_date + timedelta(days=PAYOUT_DELAY_DAYS.get(payment_type, DEFAULT_DELAY_DAYS))
            if rng.random() < dispute_rate:
                status, settled_on = "disputed", None
            elif due <= batch_time.date():
                status, settled_on = "settled", due
            else:
                status, settled_on = "pending", None
            sequential = int(payment["payment_sequential"])
            rows.append(
                {
                    "settlement_id": str(
                        uuid.uuid5(SETTLEMENT_NAMESPACE, f"{order['order_id']}:{sequential}:{payout_batch_id}")
                    ),
                    "payout_batch_id": payout_batch_id,
                    "order_id": order["order_id"],
                    "payment_sequential": sequential,
                    "payment_type": payment_type,
                    "gross_amount": gross,
                    "fee_amount": fee,
                    "net_amount": gross - fee,
                    "currency": "BRL",
                    "payment_date": payment_date,
                    "settlement_date": settled_on,
                    "settlement_status": status,
                    "generated_at": batch_time,
                }
            )
    return rows