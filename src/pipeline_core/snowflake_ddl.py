from __future__ import annotations

import argparse
from pathlib import Path

import yaml

from pipeline_core.contracts import Column, load_contract

DATABASE = "ECOM_DB"
SCHEMA = "BRONZE"
STAGE = f"{DATABASE}.{SCHEMA}.STG_VALIDATED"
FILE_FORMAT = f"{DATABASE}.{SCHEMA}.FF_PARQUET"
PARQUET_PATTERN = ".*[.]parquet"
TS_TEXT_FORMAT = "YYYY-MM-DD HH24:MI:SS.FF6"
HEADER = (
    "USE ROLE DATA_ENGINEER;\n"
    "USE SECONDARY ROLES NONE;\n"
    "USE WAREHOUSE LOAD_WH;\n"
    f"USE SCHEMA {DATABASE}.{SCHEMA};\n"
)
SIMPLE_TYPES = {
    "string": "VARCHAR",
    "integer": "NUMBER(38,0)",
    "date": "DATE",
    "boolean": "BOOLEAN",
    "timestamp": "TIMESTAMP_TZ",
    "timestamp_ntz": "TIMESTAMP_NTZ",
    "array": "VARIANT",
}
METADATA_COLUMNS = (
    ("_file_name", "VARCHAR", "METADATA$FILENAME"),
    ("_file_row_number", "NUMBER(38,0)", "METADATA$FILE_ROW_NUMBER"),
    ("_loaded_at", "TIMESTAMP_LTZ DEFAULT CURRENT_TIMESTAMP()", "CURRENT_TIMESTAMP()"),
)


def _quote(text: str) -> str:
    return text.replace("'", "''")


def column_type(column: Column) -> str:
    spec = column.decimal_spec
    if spec:
        return f"NUMBER({spec[0]},{spec[1]})"
    return SIMPLE_TYPES[column.type]


def column_expression(column: Column) -> str:
    source = f"$1:{column.name}"
    if column.type == "array":
        return source
    if column.type == "timestamp":
        return (
            f"TO_TIMESTAMP_TZ(TO_VARCHAR({source}::TIMESTAMP_NTZ, '{TS_TEXT_FORMAT}') || ' +00:00', "
            f"'{TS_TEXT_FORMAT} TZH:TZM')"
        )
    if column.type == "timestamp_ntz":
        return f"TO_TIMESTAMP_NTZ({source}::NUMBER, 6)"
    return f"{source}::{column_type(column)}"


def render_contract(path: str | Path) -> str:
    path = Path(path)
    raw = yaml.safe_load(path.read_text(encoding="utf-8"))
    contract = load_contract(path)
    descriptions = {c["name"]: c.get("description", "") for c in raw["columns"]}
    team = (raw.get("owner") or {}).get("team", "unknown")
    table = contract.name.upper()
    qualified = f"{DATABASE}.{SCHEMA}.{table}"
    stage_path = contract.location["validated"][len("validated/"):]

    definitions = []
    for column in contract.columns:
        line = f"    {column.name} {column_type(column)}"
        if not column.nullable:
            line += " NOT NULL"
        if descriptions.get(column.name):
            line += f" COMMENT '{_quote(descriptions[column.name])}'"
        definitions.append(line)
    definitions += [f"    {name} {sf_type}" for name, sf_type, _ in METADATA_COLUMNS]
    definitions.append("    _source_team VARCHAR")

    table_comment = (
        f"{raw.get('description', '')} Contract {contract.name} v{contract.version}; "
        f"loaded by Snowpipe from validated/{stage_path}."
    ).strip()
    insert_columns = [c.name for c in contract.columns] + [m[0] for m in METADATA_COLUMNS] + ["_source_team"]
    select_lines = [column_expression(c) for c in contract.columns] + [m[2] for m in METADATA_COLUMNS]
    select_lines.append(f"'{_quote(team)}'")

    return (
        f"CREATE TABLE IF NOT EXISTS {qualified} (\n"
        + ",\n".join(definitions)
        + f"\n)\nCOMMENT = '{_quote(table_comment)}';\n\n"
        + f"CREATE PIPE IF NOT EXISTS {DATABASE}.{SCHEMA}.PIPE_{table}\n"
        + "    AUTO_INGEST = TRUE\n"
        + f"    COMMENT = 'Loads contract {contract.name} from validated/{stage_path} into {table}.'\n"
        + "AS\n"
        + f"COPY INTO {qualified} (\n    "
        + ",\n    ".join(insert_columns)
        + "\n)\nFROM (\n    SELECT\n        "
        + ",\n        ".join(select_lines)
        + f"\n    FROM @{STAGE}/{stage_path}\n)\n"
        + f"PATTERN = '{PARQUET_PATTERN}'\n"
        + f"FILE_FORMAT = (FORMAT_NAME = '{FILE_FORMAT}');\n"
    )


def render_all(directory: str | Path) -> str:
    parts = [HEADER] + [render_contract(p) for p in sorted(Path(directory).glob("*.yaml"))]
    return "\n".join(parts)


def main() -> None:
    parser = argparse.ArgumentParser(description="Generate Bronze tables and Snowpipes from the data contracts.")
    parser.add_argument("--contracts", default="contracts")
    parser.add_argument("--out", default="sql/bronze/05_contract_tables.sql")
    args = parser.parse_args()
    Path(args.out).write_text(render_all(args.contracts), encoding="utf-8", newline="\n")
    print(f"Wrote {args.out}")


if __name__ == "__main__":
    main()