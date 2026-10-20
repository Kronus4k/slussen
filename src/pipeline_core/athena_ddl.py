from __future__ import annotations

import argparse
from pathlib import Path

import yaml

from pipeline_core.contracts import Column, load_contract

DATABASE = "slussen_lake"
BUCKET = "slussen-lake-qwer"
PROJECTION_START = "2026-01-01"
SIMPLE_TYPES = {
    "string": "string",
    "integer": "bigint",
    "date": "date",
    "boolean": "boolean",
    "timestamp": "timestamp",
    "timestamp_ntz": "timestamp",
}


def _quote(text: str) -> str:
    return text.replace("\\", "\\\\").replace("'", "\\'")


def athena_type(column: Column) -> str:
    spec = column.decimal_spec
    if spec:
        return f"decimal({spec[0]},{spec[1]})"
    if column.type == "array":
        return "array<struct<" + ",".join(f"{f.name}:{athena_type(f)}" for f in column.fields) + ">>"
    return SIMPLE_TYPES[column.type]


def render_contract(path: str | Path) -> str:
    path = Path(path)
    raw = yaml.safe_load(path.read_text(encoding="utf-8"))
    contract = load_contract(path)
    descriptions = {c["name"]: c.get("description", "") for c in raw["columns"]}
    location = f"s3://{BUCKET}/{contract.location['validated']}"

    definitions = []
    for column in contract.columns:
        line = f"  {column.name} {athena_type(column)}"
        if descriptions.get(column.name):
            line += f" COMMENT '{_quote(descriptions[column.name])}'"
        definitions.append(line)

    table_comment = (
        f"{raw.get('description', '')} Contract {contract.name} v{contract.version}; "
        f"contract-validated Parquet from the gate."
    ).strip()

    return (
        f"CREATE EXTERNAL TABLE IF NOT EXISTS {DATABASE}.{contract.name} (\n"
        + ",\n".join(definitions)
        + "\n)\n"
        + f"COMMENT '{_quote(table_comment)}'\n"
        + "PARTITIONED BY (dt string)\n"
        + "STORED AS PARQUET\n"
        + f"LOCATION '{location}'\n"
        + "TBLPROPERTIES (\n"
        + "  'projection.enabled' = 'true',\n"
        + "  'projection.dt.type' = 'date',\n"
        + "  'projection.dt.format' = 'yyyy-MM-dd',\n"
        + f"  'projection.dt.range' = '{PROJECTION_START},NOW',\n"
        + "  'projection.dt.interval' = '1',\n"
        + "  'projection.dt.interval.unit' = 'DAYS',\n"
        + f"  'storage.location.template' = '{location}dt=${{dt}}/'\n"
        + ");\n"
    )


def render_all(directory: str | Path) -> str:
    return "\n".join(render_contract(p) for p in sorted(Path(directory).glob("*.yaml")))


def main() -> None:
    parser = argparse.ArgumentParser(description="Generate Athena tables for validated/ from the data contracts.")
    parser.add_argument("--contracts", default="contracts")
    parser.add_argument("--out", default="sql/athena/01_validated_tables.sql")
    args = parser.parse_args()
    out = Path(args.out)
    out.parent.mkdir(parents=True, exist_ok=True)
    out.write_text(render_all(args.contracts), encoding="utf-8", newline="\n")
    print(f"Wrote {args.out}")


if __name__ == "__main__":
    main()