
from city.population.population import HappinessTracker
from city.population.population import Pop


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
