
from src.city.population.happiness_tracker import HappinessTracker
from src.city.population.population import Pop, Population


class City:
    def __init__(self, population: Population = Population.from_list([Pop()])):
        self.population: Population = population
        # Infrastructure
        self.water_facilities = 2
        self.electricity_facilities = 2
        self.housing_units = 30

    def on_advance_day(self):
        people_with_water = self.water_facilities * 20
        people_with_electricity = self.electricity_facilities * 20

        # Single pass: distribute resources and adjust happiness
        for i, person in enumerate(self.population):
            person.water_received = i < people_with_water
            person.electricity_received = i < people_with_electricity
            person.has_home = i < self.housing_units
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
