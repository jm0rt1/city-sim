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


class City:
    def __init__(self, population: list["Pop"] = [Pop()]):

        self.population: list[Pop] = population
        self.happiness_tracker = HappinessTracker(population=population)
        # Infrastructure
        self.water_facilities = 2
        self.electricity_facilities = 2
        self.housing_units = 30

    def on_advance_day(self):
        # Distribute water
        people_with_water = self.water_facilities * 20
        for person in self.population[:people_with_water]:
            person.water_received = True

        # Distribute electricity
        people_with_electricity = self.electricity_facilities * 20
        for person in self.population[:people_with_electricity]:
            person.electricity_received = True

        # Assign homes
        for person in self.population[:self.housing_units]:
            person.has_home = True

        for person in self.population:

            person.adjust_happiness()

        # Update happiness tracker
        self.happiness_tracker.update_happiness(self.population)

    def add_water_facilities(self, fac_to_add: int):
        # check if positive
        if fac_to_add < 0:
            raise ValueError("No Negative Numbers")
        self.water_facilities += fac_to_add

    def add_electricity_facilities(self, fac_to_add: int):
        if fac_to_add < 0:
            raise ValueError("No Negative Numbers")
        self.electricity_facilities += fac_to_add

    def add_housing_units(self, units_to_add: int):
        if units_to_add < 0:
            raise ValueError("No Negative Numbers")
        self.housing_units += units_to_add


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
