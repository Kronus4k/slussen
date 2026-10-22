from datetime import date, datetime, timezone
from decimal import Decimal
from pathlib import Path

from pipeline_core.gate import load_contracts, process_batch
from pipeline_core.generators.finance_settlements import settle_week
from pipeline_core.producer import publish_batch
from pipeline_core.storage import MemoryStore
from pipeline_core.writers import to_parquet

CONTRACTS = load_contracts(Path(__file__).resolve().parents[1] / "contracts")
FINANCE = next(c for c in CONTRACTS if c.location["landing"] == "landing/finance/settlements/")
BATCH_TIME = datetime(2026, 1, 12, 5, 0, tzinfo=timezone.utc)
PREFIX = "landing/finance/settlements/dt=2026-01-12/batch=20260112T050000Z/"


def _event(order_id, status, approved, payment_type="credit_card", value="100.00", event_ts="2026-01-10T10:00:00Z"):
    return {
        "event_id": f"e-{order_id}-{status}",
        "event_ts": event_ts,
        "order_id": order_id,
        "order_status": status,
        "order_approved_ts": approved,
        "payments": [
            {"payment_sequential": 1, "payment_type": payment_type, "payment_installments": 1, "payment_value": Decimal(value)}
        ]
        if approved
        else None,
    }


EVENTS = [
    _event("a", "created", None, event_ts="2026-01-05T09:00:00Z"),
    _event("a", "delivered", "2026-01-06T10:00:00Z"),
    _event("b", "canceled", "2026-01-06T10:00:00Z"),
    _event("c", "created", None),
    _event("d", "approved", "2026-01-02T10:00:00Z"),
    _event("e", "shipped", "2026-01-11T10:00:00Z", payment_type="boleto", value="50.00"),
    _event("f", "delivered", "2026-01-08T10:00:00Z", payment_type="debit_card", value="20.00"),
]


def _exact(records):
    return settle_week(records, BATCH_TIME, seed=1, mismatch_rate=0, dispute_rate=0)


def test_settles_last_week_payments_of_paid_orders_only():
    assert sorted(r["order_id"] for r in _exact(EVENTS)) == ["a", "e", "f"]


def test_fees_net_dates_and_status():
    rows = {r["order_id"]: r for r in _exact(EVENTS)}
    a, e, f = rows["a"], rows["e"], rows["f"]
    assert (a["gross_amount"], a["fee_amount"], a["net_amount"]) == (Decimal("100.00"), Decimal("2.99"), Decimal("97.01"))
    assert (a["payment_date"], a["settlement_status"], a["settlement_date"]) == (date(2026, 1, 6), "pending", None)
    assert (e["fee_amount"], e["net_amount"], e["settlement_status"]) == (Decimal("3.49"), Decimal("46.51"), "pending")
    assert (f["fee_amount"], f["net_amount"]) == (Decimal("0.30"), Decimal("19.70"))
    assert (f["settlement_status"], f["settlement_date"]) == ("settled", date(2026, 1, 9))
    assert {r["currency"] for r in rows.values()} == {"BRL"}
    assert {r["generated_at"] for r in rows.values()} == {BATCH_TIME}


def test_ids_are_deterministic_and_unique():
    first, second = _exact(EVENTS), _exact(EVENTS)
    assert first == second
    assert len({r["settlement_id"] for r in first}) == len(first)
    assert {r["payout_batch_id"] for r in first} == {"PB-2026W02"}


def test_planted_mismatches_and_disputes_are_rare():
    many = [_event(f"o{i:04d}", "delivered", "2026-01-07T12:00:00Z") for i in range(3000)]
    rows = settle_week(many, BATCH_TIME, seed=2)
    mismatched = sum(r["gross_amount"] != Decimal("100.00") for r in rows) / len(rows)
    disputed = sum(r["settlement_status"] == "disputed" for r in rows) / len(rows)
    assert 0.001 < mismatched < 0.015
    assert 0.003 < disputed < 0.025
    assert all(r["net_amount"] == r["gross_amount"] - r["fee_amount"] for r in rows)


def test_empty_week_gives_no_rows():
    assert settle_week([_event("x", "delivered", "2025-12-20T10:00:00Z")], BATCH_TIME, seed=1) == []


def test_finance_batch_passes_the_gate():
    store = MemoryStore()
    rows = _exact(EVENTS)
    publish_batch(store, FINANCE, BATCH_TIME, {"part-00000.parquet": to_parquet(rows, FINANCE)}, len(rows))
    assert process_batch(store, PREFIX + "_SUCCESS", CONTRACTS).status == "validated"