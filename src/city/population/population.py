import random

from src.city.population.happiness_tracker import HappinessTracker


class Population():
    def __init__(self, rng: random.Random | None = None) -> None:
        self.pops: list[Pop] = []
        self._rng = rng
        self.happiness_tracker = HappinessTracker(self)

    def add_pop(self, pop: "Pop"):
        self.pops.append(pop)

    def remove_pop(self, pop: "Pop"):
        self.pops.remove(pop)

    def property_tax(self):
        return sum(1 for pop in self.pops if pop.property)

    @classmethod
    def from_list(cls, pops_list: list["Pop"], rng: random.Random | None = None):
        population = cls(rng=rng)
        population.pops = pops_list
        population.happiness_tracker.update_happiness(population)
        return population

    def __iter__(self):
        return iter(self.pops)

    def __len__(self):
        return len(self.pops)

    def append(self, pop: "Pop"):
        self.add_pop(pop)

    def adjust_happiness(self):
        for pop in self.pops:
            pop.adjust_happiness()


class Pop():
    def __init__(self, rng: random.Random | None = None) -> None:
        self._rng: random.Random = rng if rng is not None else random.Random()

        self.overall_happiness: float = 0.0
        self.water_received = False
        self.electricity_received = False
        self.has_home = False
        self.property = None
        self.entertained = False
        self.sick = False
        self.garbage_collected = False
        self.electricity_consumption = self._rng.randint(0, 100)
        self.water_consumption = self._rng.randint(0, 100)

    def adjust_happiness(self):
        # Adjust happiness based on basic needs
        self.overall_happiness = 0.0
        if self.water_received:
            self.overall_happiness += 10
        else:
            self.overall_happiness -= 10

        if self.electricity_received:
            self.overall_happiness += 10
        else:
            self.overall_happiness -= 10

        if self.has_home:
            self.overall_happiness += 10
        else:
            self.overall_happiness -= 10

        if self.entertained:
            self.overall_happiness += 5
        else:
            self.overall_happiness -= 5

        if self.garbage_collected:
            self.overall_happiness += 5
        else:
            self.overall_happiness -= 5
        # Randomly make a person sick (1% chance)
        if self._rng.random() < 0.01:
            self.sick = True
            self.overall_happiness -= 15
