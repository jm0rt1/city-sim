import random


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


class HappinessTracker():

    def __init__(self, population: list[Pop]) -> None:
        self.average_happiness = 0
        self.update_happiness(population)

    def update_happiness(self, population: list[Pop]):
        total_happiness = sum(
            [person.overall_happiness for person in population])
        self.average_happiness = total_happiness / \
            len(population) if population else 0

    def get_average_happiness(self):
        return self.average_happiness
