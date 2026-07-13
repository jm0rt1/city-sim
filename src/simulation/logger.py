"""
Structured JSONL logger for City-Sim simulation runs.

Schema defined in docs/specs/logging.md.  Each tick produces one JSON line;
a summary entry is appended when the run ends.
"""
import json
from datetime import datetime, timezone
from pathlib import Path
from typing import Optional


# Raw happiness range from Pop.adjust_happiness()
_HAPPINESS_RAW_MIN: float = -55.0
_HAPPINESS_RAW_MAX: float = 40.0


def normalize_happiness(raw: float) -> float:
    """Map raw happiness [-55, 40] to the 0-100 scale required by the schema."""
    span = _HAPPINESS_RAW_MAX - _HAPPINESS_RAW_MIN
    normalized = (raw - _HAPPINESS_RAW_MIN) / span * 100.0
    return max(0.0, min(100.0, normalized))


class SimLogger:
    """
    Writes structured JSONL log entries per docs/specs/logging.md.

    Usage::

        logger = SimLogger(run_id="run_001", log_path=Path("output/logs/global/run_001.jsonl"))
        logger.log_tick(tick_index=0, budget=0.0, revenue=100.0, ...)
        logger.log_summary(...)
        logger.close()
    """

    def __init__(self, run_id: str, log_path: Path) -> None:
        self.run_id = run_id
        self._path = log_path
        self._path.parent.mkdir(parents=True, exist_ok=True)
        self._file = open(self._path, "w", encoding="utf-8")

    # ------------------------------------------------------------------
    # Per-tick entry
    # ------------------------------------------------------------------

    def log_tick(
        self,
        tick_index: int,
        budget: float,
        revenue: float,
        expenses: float,
        population: int,
        happiness: float,
        policies_applied: list,
        tick_duration_ms: float,
        traffic: Optional[dict] = None,
    ) -> None:
        """Append one tick log entry (JSONL line) to the log file.

        Args:
            traffic: Optional dict of traffic metrics (avg_speed, congestion_index,
                     throughput, etc.) from the TransportSubsystem.  When provided
                     the fields are embedded in the entry under the key ``traffic``.
        """
        ts = datetime.now(timezone.utc)
        timestamp = ts.strftime("%Y-%m-%dT%H:%M:%S.") + f"{ts.microsecond // 1000:03d}Z"

        entry: dict = {
            "timestamp": timestamp,
            "run_id": self.run_id,
            "tick_index": tick_index,
            "budget": float(budget),
            "revenue": float(revenue),
            "expenses": float(expenses),
            "population": int(population),
            "happiness": float(happiness),
            "policies_applied": list(policies_applied),
            "tick_duration_ms": float(tick_duration_ms),
        }
        if traffic is not None:
            entry["traffic"] = traffic
        self._file.write(json.dumps(entry) + "\n")
        self._file.flush()

    # ------------------------------------------------------------------
    # End-of-run summary
    # ------------------------------------------------------------------

    def log_summary(
        self,
        final_budget: float,
        final_population: int,
        avg_happiness: float,
        total_ticks: int,
        run_duration_ms: float,
        run_kpis: Optional[dict] = None,
    ) -> None:
        """Append a run-summary entry to the log file."""
        entry: dict = {
            "run_id": self.run_id,
            "summary": True,
            "final_budget": float(final_budget),
            "final_population": int(final_population),
            "avg_happiness": float(avg_happiness),
            "total_ticks": int(total_ticks),
            "run_duration_ms": float(run_duration_ms),
            "run_kpis": run_kpis if run_kpis is not None else {},
        }
        self._file.write(json.dumps(entry) + "\n")
        self._file.flush()

    def close(self) -> None:
        """Close the underlying log file."""
        self._file.close()
