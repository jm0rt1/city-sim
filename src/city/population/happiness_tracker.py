from __future__ import annotations

from typing import TYPE_CHECKING

if TYPE_CHECKING:
    from src.city.population.population import Population

# Raw happiness range: min -55 (all bad + sick), max +40 (all good)
_RAW_MIN = -55.0
_RAW_MAX = 40.0


class HappinessTracker():

    def __init__(self, population: Population) -> None:
        self.average_happiness: float = 0.0
        self.update_happiness(population)

    def update_happiness(self, population: Population):
        if not population.pops:
            self.average_happiness = 0.0
            return
        total_raw = sum(person.overall_happiness for person in population.pops)
        avg_raw = total_raw / len(population.pops)
        # Normalize raw average to [0, 100]
        self.average_happiness = max(
            0.0,
            min(100.0, (avg_raw - _RAW_MIN) / (_RAW_MAX - _RAW_MIN) * 100.0),
        )

    def get_average_happiness(self) -> float:
        return self.average_happiness
