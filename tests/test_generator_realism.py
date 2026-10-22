from datetime import datetime, timezone
from decimal import Decimal

from pipeline_core.generators.ops_orders import Catalog, generate_batch, open_orders

NOW = datetime(2026, 1, 9, 12, 0, tzinfo=timezone.utc)
ITEMS = [
    {"product_id": f"p{i:02d}", "seller_id": f"s{i % 3}", "price": Decimal(f"{10 + i}.90"), "freight_value": Decimal("7.50")}
    for i in range(10)
]
CUSTOMERS = [
    {
        "customer_unique_id": f"olist-c{i:03d}",
        "customer_zip_code_prefix": f"0{i:04d}",
        "customer_city": "sao paulo",
        "customer_state": "SP",
    }
    for i in range(50)
]
CATALOG = Catalog(items=ITEMS, customers=CUSTOMERS)


def _order(order_id, status, event_ts):
    return {
        "event_id": f"e-{order_id}-{status}",
        "event_type": "order_created" if status == "created" else "status_changed",
        "event_ts": event_ts,
        "order_id": order_id,
        "order_status": status,
        "customer_id": f"cid-{order_id}",
        "customer_unique_id": f"cu-{order_id}",
        "customer_zip_code_prefix": "01001",
        "customer_city": "sao paulo",
        "customer_state": "SP",
        "order_purchase_ts": "2026-01-08T09:00:00Z",
        "order_approved_ts": None,
        "order_delivered_carrier_ts": None,
        "order_delivered_customer_ts": None,
        "order_estimated_delivery_date": "2026-01-25",
        "items": [
            {"order_item_id": 1, "product_id": "p01", "seller_id": "s1", "price": Decimal("11.90"), "freight_value": Decimal("7.50")}
        ],
        "payments": [
            {"payment_sequential": 1, "payment_type": "boleto", "payment_installments": 1, "payment_value": Decimal("19.40")}
        ],
    }


def test_new_orders_use_catalog_items_and_start_as_created():
    records = generate_batch(200, NOW, seed=3, catalog=CATALOG)
    known = {(i["product_id"], i["seller_id"], i["price"], i["freight_value"]) for i in ITEMS}
    assert {r["order_status"] for r in records} == {"created"}
    assert all(
        (i["product_id"], i["seller_id"], i["price"], i["freight_value"]) in known for r in records for i in r["items"]
    )


def test_returning_customers_are_about_three_percent():
    records = generate_batch(4000, NOW, seed=3, catalog=CATALOG)
    olist_ids = {c["customer_unique_id"] for c in CUSTOMERS}
    share = sum(r["customer_unique_id"] in olist_ids for r in records) / len(records)
    assert 0.015 < share < 0.05


def test_open_orders_keeps_latest_event_and_drops_closed():
    events = [
        _order("a", "created", "2026-01-08T10:00:00Z"),
        _order("a", "approved", "2026-01-08T14:00:00Z"),
        _order("b", "shipped", "2026-01-08T10:00:00Z"),
        _order("b", "delivered", "2026-01-09T02:00:00Z"),
        _order("c", "created", "2026-01-09T01:00:00Z"),
    ]
    assert [(o["order_id"], o["order_status"]) for o in open_orders(events)] == [("a", "approved"), ("c", "created")]


def test_open_orders_move_one_step_and_keep_their_snapshot():
    pool = [
        _order("a", "created", "2026-01-09T09:00:00Z"),
        _order("b", "approved", "2026-01-09T09:00:00Z"),
        _order("c", "shipped", "2026-01-09T09:00:00Z"),
    ]
    records = generate_batch(6, NOW, seed=11, catalog=CATALOG, open_pool=pool)
    moved = {r["order_id"]: r for r in records if r["order_id"] in {"a", "b", "c"}}
    assert set(moved) == {"a", "b", "c"}
    allowed = {"a": {"approved", "canceled"}, "b": {"shipped", "canceled"}, "c": {"delivered"}}
    for order_id, record in moved.items():
        assert record["order_status"] in allowed[order_id]
        assert record["customer_unique_id"] == f"cu-{order_id}"
        assert record["items"][0]["product_id"] == "p01"
        assert record["event_ts"] > "2026-01-09T09:00:00Z"
    assert moved["c"]["order_delivered_customer_ts"] == moved["c"]["event_ts"]


def test_realistic_batches_are_reproducible():
    pool = [_order("a", "created", "2026-01-09T09:00:00Z")]
    first = generate_batch(20, NOW, seed=5, catalog=CATALOG, open_pool=pool)
    second = generate_batch(20, NOW, seed=5, catalog=CATALOG, open_pool=pool)
    assert first == second