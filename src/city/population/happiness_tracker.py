from __future__ import annotations

from typing import TYPE_CHECKING

if TYPE_CHECKING:
    from src.city.population.population import Population


class HappinessTracker():

    def __init__(self, population: Population) -> None:
        self.average_happiness = 0
        self.update_happiness(population)

    def update_happiness(self, population: Population):
        pops = population.pops
        self.average_happiness = sum(p.overall_happiness for p in pops) / len(pops) if pops else 0

    def get_average_happiness(self):
        return self.average_happiness
