import sys
from pathlib import Path

from pipeline_core.csv_utils import count_csv_records

src = Path(sys.argv[1]) if len(sys.argv) > 1 else Path("../data/olist")

for path in sorted(src.glob("*.csv")):
    with open(path, encoding="utf-8", newline="") as f:
        lines = sum(1 for _ in f) - 1
    records = count_csv_records(path)
    flag = "" if lines == records else "  <- line count differs"
    print(f"{path.name:45} records={records:>9,}  lines={lines:>9,}{flag}")