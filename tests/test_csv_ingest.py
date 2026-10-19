from dataclasses import replace
from datetime import datetime
from decimal import Decimal

import pyarrow as pa
import pytest

from pipeline_core.contracts import Column, Contract, load_contract
from pipeline_core.readers import ReadError, read_records
from pipeline_core.validator import validate_records
from pipeline_core.writers import arrow_schema, to_parquet

HEADER = "id,qty,price,created_ts,note\r\n"


@pytest.fixture(scope="module")
def csv_contract():
    return Contract(
        name="sample_csv",
        version="1.0.0",
        format="csv",
        primary_key=("id",),
        columns=(
            Column("id", "string", False),
            Column("qty", "integer", False),
            Column("price", "decimal(10,2)", False),
            Column("created_ts", "timestamp_ntz", True),
            Column("note", "string", True),
        ),
        location={"landing": "landing/sample/", "validated": "validated/sample/", "quarantine": "quarantine/sample/"},
        success_marker="_SUCCESS",
        sla={},
    )


def _csv(*rows):
    return (HEADER + "".join(r + "\r\n" for r in rows)).encode("utf-8")


def _row(**overrides):
    row = {"id": "a-1", "qty": 3, "price": Decimal("58.90"), "created_ts": "2017-10-02 10:56:33", "note": None}
    row.update(overrides)
    return row


def test_loader_accepts_csv_ntz_and_empty_key(tmp_path):
    path = tmp_path / "geo.yaml"
    path.write_text(
        "contract: geo\nversion: 1.0.0\nformat: csv\n"
        "location: {landing: landing/geo/, validated: validated/geo/, quarantine: quarantine/geo/}\n"
        "completeness: {success_marker: _SUCCESS}\nprimary_key: []\n"
        "columns:\n  - {name: seen_at, type: timestamp_ntz, nullable: true}\n",
        encoding="utf-8",
    )
    contract = load_contract(path)
    assert (contract.format, contract.primary_key, contract.columns[0].type) == ("csv", (), "timestamp_ntz")


def test_csv_values_are_typed_by_contract(csv_contract):
    records = read_records(_csv("a-1,3,58.90,2017-10-02 10:56:33,"), "csv", csv_contract)
    assert records == [_row()]
    assert validate_records(records, csv_contract).passed


def test_csv_keeps_quoted_line_breaks_and_leading_zeros(csv_contract):
    records = read_records(_csv('"0101",1,1.00,2017-10-02 10:56:33,"line one\nline two"'), "csv", csv_contract)
    assert len(records) == 1
    assert records[0]["id"] == "0101"
    assert records[0]["note"] == "line one\nline two"


def test_csv_bad_number_stays_text_and_is_flagged(csv_contract):
    records = read_records(_csv("a-1,three,58.90,2017-10-02 10:56:33,"), "csv", csv_contract)
    assert records[0]["qty"] == "three"
    found = {(v.rule, v.column) for v in validate_records(records, csv_contract).breaking}
    assert ("type_mismatch", "qty") in found


def test_csv_ragged_row_is_unreadable(csv_contract):
    with pytest.raises(ReadError, match="line 2"):
        read_records(_csv("a-1,3,58.90"), "csv", csv_contract)


def test_csv_needs_a_contract():
    with pytest.raises(ReadError, match="needs the contract"):
        read_records(_csv("a-1,3,58.90,2017-10-02 10:56:33,"), "csv")


@pytest.mark.parametrize("value", ["2017-10-02 10:56:33", datetime(2017, 10, 2, 10, 56, 33)])
def test_ntz_accepts_zone_less_values(csv_contract, value):
    assert validate_records([_row(created_ts=value)], csv_contract).passed


@pytest.mark.parametrize(
    "value",
    ["2017-10-02T10:56:33Z", "2017-10-02 10:56:33+00:00", "02/10/2017 10:56:33", "2017-10-02"],
)
def test_ntz_rejects_zones_and_other_formats(csv_contract, value):
    found = {(v.rule, v.column) for v in validate_records([_row(created_ts=value)], csv_contract).breaking}
    assert ("type_mismatch", "created_ts") in found


def test_empty_primary_key_allows_duplicate_rows(csv_contract):
    keyless = replace(csv_contract, primary_key=())
    assert validate_records([_row(), _row()], keyless).passed


def test_writer_stores_ntz_without_zone(csv_contract):
    assert arrow_schema(csv_contract).field("created_ts").type == pa.timestamp("us")
    records = read_records(to_parquet([_row()], csv_contract), "parquet")
    assert records[0]["created_ts"] == datetime(2017, 10, 2, 10, 56, 33)
    assert records[0]["created_ts"].tzinfo is None
    assert validate_records(records, csv_contract).passed



def test_olist_contracts_cover_all_tables(contracts_dir):
    tables = [
        "orders", "customers", "order_items", "order_payments", "order_reviews",
        "products", "sellers", "product_category_name_translation", "geolocation",
    ]
    contracts = {t: load_contract(contracts_dir / f"olist_{t}.yaml") for t in tables}
    for table, contract in contracts.items():
        assert contract.format == "csv"
        assert contract.location["landing"] == f"landing/olist/{table}/"
    assert contracts["order_reviews"].primary_key == ("review_id", "order_id")
    assert contracts["geolocation"].primary_key == ()