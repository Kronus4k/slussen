from dataclasses import asdict, dataclass

SEVERITIES = ("error", "warn")
STATUSES = ("pass", "fail")


@dataclass(frozen=True)
class CheckResult:
    check_name: str
    dataset: str
    severity: str
    status: str
    checked_count: int
    failing_count: int
    detail: str = ""

    def __post_init__(self) -> None:
        if self.severity not in SEVERITIES:
            raise ValueError(f"unknown severity {self.severity!r}")
        if self.status not in STATUSES:
            raise ValueError(f"unknown status {self.status!r}")

    def as_row(self) -> dict:
        return asdict(self)


def evaluate(check_name: str, dataset: str, severity: str, checked_count: int, failing_count: int, detail: str = "") -> CheckResult:
    status = "fail" if failing_count > 0 else "pass"
    return CheckResult(check_name, dataset, severity, status, checked_count, failing_count, detail)


def blocking(results) -> list[CheckResult]:
    return [r for r in results if r.status == "fail" and r.severity == "error"]