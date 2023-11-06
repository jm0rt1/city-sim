
import random
from src.city.city import City
from src.city.population.population import Pop
from abc import ABC


class DecisionBase(ABC):
    def __init__(self, city: City):
        self.city = city
        self.chance_percentage = 0.5

    def roll(self) -> bool:
        """
        Returns True if a random float between 0 and 1 is less than the given chance_percentage.
        """
        return random.random() < self.chance_percentage


class DisasterDecision(DecisionBase):
    def __init__(self, city: City):
        super().__init__(city)
        self.chance_percentage = 0.01

    def roll(self) -> bool:
        # For now, we'll set a simple 1% chance for a disaster.
        return super().roll()


class StayDecision(DecisionBase):
    def __init__(self, city: City, pop: Pop):
        super().__init__(city)
        self.pop = pop
        self.base_chance = 0.9  # Base chance for a Pop to stay
        self.no_home_penalty = 0.2
        self.low_happiness_penalty = 0.3
        self.no_water_penalty = 0.2
        self.no_electricity_penalty = 0.2

    def roll(self):
        self.chance_percentage = self.base_chance

        if not self.pop.has_home:
            self.chance_percentage += self.no_home_penalty

        if self.pop.overall_happiness < 0:  # If happiness is negative
            self.chance_percentage += self.low_happiness_penalty

        return super().roll()
