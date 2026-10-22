from dataclasses import asdict, dataclass
from datetime import datetime, time, timedelta, timezone

from pipeline_core.contracts import Contract

WEEKDAYS = ("monday", "tuesday", "wednesday", "thursday", "friday", "saturday", "sunday")
DEADLINE_WINDOW = timedelta(hours=24)
BLOCKING_STATUSES = ("late", "no_data")


@dataclass(frozen=True)
class FreshnessResult:
    dataset: str
    contract: str
    sla_hours: float | None
    last_loaded_at: datetime | None
    age_hours: float | None
    status: str

    def as_row(self) -> dict:
        return asdict(self)


def _hours(delta: timedelta) -> float:
    return round(delta.total_seconds() / 3600, 2)


def _require_aware(value: datetime, name: str) -> None:
    if value.tzinfo is None:
        raise ValueError(f"{name} must be timezone-aware")


def latest_deadline(deadline: dict, now: datetime) -> datetime:
    _require_aware(now, "now")
    weekday = WEEKDAYS.index(str(deadline["day"]).lower())
    hour, minute = (int(part) for part in str(deadline["time_utc"]).split(":"))
    now_utc = now.astimezone(timezone.utc)
    days_back = (now_utc.weekday() - weekday) % 7
    candidate = datetime.combine(now_utc.date() - timedelta(days=days_back), time(hour, minute), tzinfo=timezone.utc)
    if candidate > now_utc:
        candidate -= timedelta(days=7)
    return candidate


def allowed_age(sla: dict, now: datetime) -> timedelta | None:
    if "freshness_hours" in sla:
        return timedelta(hours=float(sla["freshness_hours"]))
    if "deadline" in sla:
        # a load counts for the current cycle if it lands at most 24 h before the latest passed deadline
        return now - (latest_deadline(sla["deadline"], now) - DEADLINE_WINDOW)
    return None


def evaluate_freshness(contract: Contract, dataset: str, last_loaded_at: datetime | None, now: datetime) -> FreshnessResult:
    _require_aware(now, "now")
    if last_loaded_at is not None:
        _require_aware(last_loaded_at, "last_loaded_at")
    limit = allowed_age(contract.sla or {}, now)
    age = None if last_loaded_at is None else now - last_loaded_at
    if age is None:
        status = "no_data"
    elif limit is None:
        status = "not_applicable"
    else:
        status = "ok" if age <= limit else "late"
    return FreshnessResult(
        dataset=dataset,
        contract=contract.name,
        sla_hours=None if limit is None else _hours(limit),
        last_loaded_at=last_loaded_at,
        age_hours=None if age is None else _hours(age),
        status=status,
    )


def blocking(results) -> list[FreshnessResult]:
    return [r for r in results if r.status in BLOCKING_STATUSES]