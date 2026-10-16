from pathlib import Path

import pytest
import yaml

from pipeline_core.contracts import ContractError, load_contract

CONTRACTS = Path(__file__).resolve().parents[1] / "contracts"


def _write_contract(tmp_path, **overrides):
    data = {
        "contract": "test",
        "version": "1.0.0",
        "format": "jsonl",
        "location": {},
        "completeness": {"success_marker": "_SUCCESS"},
        "primary_key": ["id"],
        "columns": [{"name": "id", "type": "string", "nullable": False}],
    }
    data.update(overrides)
    path = tmp_path / "contract.yaml"
    path.write_text(yaml.safe_dump(data), encoding="utf-8")
    return path


def test_ops_orders_contract_loads():
    c = load_contract(CONTRACTS / "ops_orders.yaml")
    assert (c.name, c.version, c.format) == ("ops_orders", "1.0.0", "jsonl")
    assert len(c.columns) == 17
    assert c.primary_key == ("event_id",)
    items = c.column("items")
    assert [f.name for f in items.fields] == ["order_item_id", "product_id", "seller_id", "price", "freight_value"]
    assert items.fields[3].decimal_spec == (10, 2)


def test_finance_settlements_contract_loads():
    c = load_contract(CONTRACTS / "finance_settlements.yaml")
    assert (c.name, c.format, len(c.columns)) == ("finance_settlements", "parquet", 13)
    assert c.column("gross_amount").decimal_spec == (12, 2)
    assert c.sla["deadline"]["time_utc"] == "06:00"


def test_pii_columns_flagged():
    c = load_contract(CONTRACTS / "ops_orders.yaml")
    assert {col.name for col in c.columns if col.pii} == {
        "customer_zip_code_prefix",
        "customer_city",
        "customer_state",
    }


@pytest.mark.parametrize(
    "overrides, message",
    [
        ({"format": "csv"}, "unsupported format"),
        ({"columns": [{"name": "id", "type": "uuid", "nullable": False}]}, "unknown type"),
        ({"primary_key": ["order_id"]}, "is not a column"),
        ({"columns": [{"name": "id", "type": "string", "nullable": True}]}, "must not be nullable"),
        (
            {"columns": [{"name": "id", "type": "string", "nullable": False}, {"name": "items", "type": "array", "nullable": False}]},
            "need 'fields'",
        ),
    ],
)
def test_malformed_contract_rejected(tmp_path, overrides, message):
    with pytest.raises(ContractError, match=message):
        load_contract(_write_contract(tmp_path, **overrides))