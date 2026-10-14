import csv
from pathlib import Path


def count_csv_records(path: str | Path, encoding: str = "utf-8", has_header: bool = True) -> int:
    with open(path, newline="", encoding=encoding) as f:
        rows = sum(1 for _ in csv.reader(f))
    if has_header and rows > 0:
        rows -= 1
    return rows