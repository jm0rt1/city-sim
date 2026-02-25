import random
from typing import Callable
from src.city.city import City, Pop


class Sim():
    def __init__(self, city: City) -> None:
        self.city = city
        pass

    def roll_disasters(self):
        # For simplicity, we'll roll a 1% chance for a disaster
        if random.random() < 0.01:
            print("A disaster has struck the city!")
            for person in self.city.population:
                person.overall_happiness -= 50

    def roll_population(self):
        pass

    def advance_day(self):
        self.roll_for_newcomers()
        self.roll_for_leavers()
        self.city.on_advance_day()
        self.roll_disasters()

    def roll_for_newcomers(self):
        # For simplicity, we'll assume:
        # - If average happiness is > 50, there's a 10% chance 10 new individuals move in.
        # - If average happiness is > 70, there's a 20% chance 20 new individuals move in.
        avg_happiness = self.city.happiness_tracker.get_average_happiness()
        newcomers = 0

        if avg_happiness >= 20 and random.random() < 0.20:
            newcomers = 20
        elif avg_happiness > 10 and random.random() < 0.10:
            newcomers = 10
        elif avg_happiness > 0 and random.random() < 0.05:
            newcomers = 1
        for _ in range(newcomers):
            self.city.population.append(Pop())

        if newcomers:
            print(f"{newcomers} new individuals have moved into the city!")

    def roll_for_leavers(self):
        avg_happiness = self.city.happiness_tracker.get_average_happiness()
        pops_that_stay: list[Pop] = []

        if avg_happiness < 0:
            for pop in self.city.population:
                wants_to_leave = False
                if not pop.has_home:
                    if random.random() < .5:
                        wants_to_leave = True
                if not pop.electricity_received:
                    if random.random() < .5:
                        wants_to_leave = True
                if not pop.water_received:
                    if random.random() < .5:
                        wants_to_leave = True
                if not wants_to_leave:
                    pops_that_stay.append(pop)
            self.city.population = pops_that_stay

    def start(self):
        while True:
            print("Options:")
            print("1: Advance Day")
            print("2: Add Electrical Facilities")
            print("3: Add Water Facilities")
            print("4: Add Housing Units")

            print("X: Exit")

            input_str = input("Choose an option: ").lower().strip()

            if input_str == "1":
                self.advance_day()
                self.display_city_info()  # Display updated city info after advancing a day
            if input_str == "2":
                self.add_facilities_to_city(
                    self.city.add_electricity_facilities)
            if input_str == "3":
                self.add_facilities_to_city(self.city.add_water_facilities)
            if input_str == "4":
                self.add_facilities_to_city(self.city.add_housing_units)
            elif input_str == "x":
                break
            else:
                print("Invalid input")
                continue

    def add_facilities_to_city(self, add_func: Callable[[int], None]):
        data_collected = False
        fac_to_add = 0
        while not data_collected:
            try:
                fac_to_add = int(
                    input("Enter number to add: "))
                add_func(fac_to_add)
                data_collected = True
            except:
                print("Invalid input")
                continue

    def display_city_info(self):
        total_population = len(self.city.population)
        avg_happiness = self.city.happiness_tracker.get_average_happiness()

        sick_count = 0
        without_water = 0
        without_electricity = 0
        without_home = 0
        for person in self.city.population:
            if person.sick:
                sick_count += 1
            if not person.water_received:
                without_water += 1
            if not person.electricity_received:
                without_electricity += 1
            if not person.has_home:
                without_home += 1

        print("\n--- City Stats ---")
        print(f"Total Population: {total_population}")
        print(f"Average Happiness: {avg_happiness:.2f}")
        print(f"Sick Individuals: {sick_count}")
        print(f"Without Water: {without_water}")
        print(f"Without Electricity: {without_electricity}")
        print(f"Without Home: {without_home}")
        print("---------------------\n")
