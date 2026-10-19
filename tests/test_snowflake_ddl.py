from pathlib import Path

import pytest

from pipeline_core.contracts import Column
from pipeline_core.snowflake_ddl import column_expression, column_type, render_all, render_contract

REPO = Path(__file__).resolve().parents[1]
UTC_EXPRESSION = (
    "TO_TIMESTAMP_TZ(TO_VARCHAR($1:c::TIMESTAMP_NTZ, 'YYYY-MM-DD HH24:MI:SS.FF6') || ' +00:00', "
    "'YYYY-MM-DD HH24:MI:SS.FF6 TZH:TZM')"
)


@pytest.mark.parametrize(
    "ctype, sf_type, expression",
    [
        ("string", "VARCHAR", "$1:c::VARCHAR"),
        ("integer", "NUMBER(38,0)", "$1:c::NUMBER(38,0)"),
        ("decimal(10,2)", "NUMBER(10,2)", "$1:c::NUMBER(10,2)"),
        ("date", "DATE", "$1:c::DATE"),
        ("boolean", "BOOLEAN", "$1:c::BOOLEAN"),
        ("timestamp_ntz", "TIMESTAMP_NTZ", "TO_TIMESTAMP_NTZ($1:c::NUMBER, 6)"),
        ("timestamp", "TIMESTAMP_TZ", UTC_EXPRESSION),
    ],
)
def test_simple_types_map_to_snowflake(ctype, sf_type, expression):
    column = Column("c", ctype, False)
    assert column_type(column) == sf_type
    assert column_expression(column) == expression


def test_arrays_stay_variant():
    column = Column("c", "array", True, fields=(Column("x", "string", False),))
    assert (column_type(column), column_expression(column)) == ("VARIANT", "$1:c")


def test_rendered_table_and_pipe_for_olist_orders(contracts_dir):
    sql = render_contract(contracts_dir / "olist_orders.yaml")
    assert "CREATE TABLE IF NOT EXISTS ECOM_DB.BRONZE.OLIST_ORDERS (" in sql
    assert "    order_id VARCHAR NOT NULL COMMENT 'Order identifier.'," in sql
    assert "    order_approved_at TIMESTAMP_NTZ COMMENT" in sql
    assert "    _loaded_at TIMESTAMP_LTZ DEFAULT CURRENT_TIMESTAMP()," in sql
    assert "CREATE PIPE IF NOT EXISTS ECOM_DB.BRONZE.PIPE_OLIST_ORDERS" in sql
    assert "AUTO_INGEST = TRUE" in sql
    assert "FROM @ECOM_DB.BRONZE.STG_VALIDATED/olist/orders/" in sql
    assert "PATTERN = '.*[.]parquet'" in sql
    assert "'data-platform'" in sql
    assert "TO_TIMESTAMP_NTZ($1:order_purchase_timestamp::NUMBER, 6)" in sql


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
    assert "COMMENT 'Customer''s note.'" in sql
    assert "It''s quoted." in sql


def test_committed_sql_matches_contracts(contracts_dir):
    committed = (REPO / "sql" / "bronze" / "05_contract_tables.sql").read_text(encoding="utf-8")
    assert committed == render_all(contracts_dir)