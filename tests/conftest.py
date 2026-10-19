from decimal import Decimal
from pathlib import Path

import pytest

from pipeline_core.contracts import load_contract


@pytest.fixture(scope="session")
def contracts_dir():
    return Path(__file__).resolve().parents[1] / "contracts"


@pytest.fixture(scope="session")
def ops(contracts_dir):
    return load_contract(contracts_dir / "ops_orders.yaml")


@pytest.fixture(scope="session")
def make_ops_record():
    def _make(event_id="e-1", **overrides):
        record = {
            "event_id": event_id,
            "event_type": "order_created",
            "event_ts": "2026-10-16T08:00:00Z",
            "order_id": "o-1",
            "order_status": "created",
            "customer_id": "c-1",
            "customer_unique_id": "u-1",
            "customer_zip_code_prefix": "01310",
            "customer_city": "sao paulo",
            "customer_state": "SP",
            "order_purchase_ts": "2026-10-16T07:55:00Z",
            "order_approved_ts": None,
            "order_delivered_carrier_ts": None,
            "order_delivered_customer_ts": None,
            "order_estimated_delivery_date": "2026-10-30",
            "items": [
                {"order_item_id": 1, "product_id": "p-1", "seller_id": "s-1", "price": Decimal("129.90"), "freight_value": Decimal("15.10")}
            ],
            "payments": [
                {"payment_sequential": 1, "payment_type": "credit_card", "payment_installments": 3, "payment_value": Decimal("145.00")}
            ],
        }
        record.update(overrides)
        return record

    return _make