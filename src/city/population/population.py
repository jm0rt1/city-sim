import random

from src.city.population.happiness_tracker import HappinessTracker


class Population():
    def __init__(self) -> None:
        self.pops = []
        self.happiness_tracker = HappinessTracker(self)

    def add_pop(self, pop: "Pop"):
        self.pops.append(pop)

    def remove_pop(self, pop: "Pop"):
        self.pops.remove(pop)

    def property_tax(self):
        return sum([1 for pop in self.pops if pop.property])

    @classmethod
    def from_list(cls, pops_list: list["Pop"]):
        population = cls()
        cls.pops = pops_list
        return population

    def adjust_happiness(self):
        for pop in self.pops:
            pop.adjust_happiness()


class Pop():
    def __init__(self) -> None:

        self.overall_happiness = 0
        self.water_received = False
        self.electricity_received = False
        self.has_home = False
        self.property = None
        self.entertained = False
        self.sick = False
        self.garbage_collected = False
        self.electricity_consumption = random.randint(0, 100)
        self.water_consumption = random.randint(0, 100)

    def adjust_happiness(self):
        # Adjust happiness based on basic needs
        self.overall_happiness = 0
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
        # Randomly make a person sick (for simplicity, 1% chance)
        if random.random() < 0.01:
            self.sick = True
            self.overall_happiness -= 15
