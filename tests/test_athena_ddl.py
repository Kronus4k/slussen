from pathlib import Path

import pytest

from pipeline_core.athena_ddl import athena_type, render_all, render_contract
from pipeline_core.contracts import Column

REPO = Path(__file__).resolve().parents[1]


@pytest.mark.parametrize(
    "ctype, expected",
    [
        ("string", "string"),
        ("integer", "bigint"),
        ("decimal(10,2)", "decimal(10,2)"),
        ("date", "date"),
        ("boolean", "boolean"),
        ("timestamp", "timestamp"),
        ("timestamp_ntz", "timestamp"),
    ],
)
def test_simple_types_map_to_athena(ctype, expected):
    assert athena_type(Column("c", ctype, False)) == expected


def test_arrays_become_array_of_struct():
    column = Column(
        "items",
        "array",
        False,
        fields=(Column("order_item_id", "integer", False), Column("price", "decimal(10,2)", False)),
    )
    assert athena_type(column) == "array<struct<order_item_id:bigint,price:decimal(10,2)>>"


def test_rendered_table_for_olist_orders(contracts_dir):
    sql = render_contract(contracts_dir / "olist_orders.yaml")
    assert "CREATE EXTERNAL TABLE IF NOT EXISTS slussen_lake.olist_orders (" in sql
    assert "  order_id string COMMENT 'Order identifier.'," in sql
    assert "  order_purchase_timestamp timestamp COMMENT" in sql
    assert "PARTITIONED BY (dt string)" in sql
    assert "STORED AS PARQUET" in sql
    assert "LOCATION 's3://slussen-lake-qwer/validated/olist/orders/'" in sql
    assert "'projection.enabled' = 'true'" in sql
    assert "'projection.dt.range' = '2026-01-01,NOW'" in sql
    assert "'storage.location.template' = 's3://slussen-lake-qwer/validated/olist/orders/dt=${dt}/'" in sql


def test_quotes_in_descriptions_are_escaped(tmp_path):
    path = tmp_path / "quoted.yaml"
    path.write_text(
        "contract: quoted\nversion: 1.0.0\ndescription: It's quoted.\nowner: {team: qa}\nformat: csv\n"
        "location: {landing: landing/q/, validated: validated/q/, quarantine: quarantine/q/}\n"
        "completeness: {success_marker: _SUCCESS}\nprimary_key: []\n"
        "columns:\n  - {name: note, type: string, nullable: true, description: \"Customer's note.\"}\n",
        encoding="utf-8",
    )
    sql = render_contract(path)
    assert "COMMENT 'Customer\\'s note.'" in sql
    assert "It\\'s quoted." in sql


def test_committed_sql_matches_contracts(contracts_dir):
    committed = (REPO / "sql" / "athena" / "01_validated_tables.sql").read_text(encoding="utf-8")
    assert committed == render_all(contracts_dir)