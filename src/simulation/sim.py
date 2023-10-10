import random
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
        self.city.on_advance_day()
        self.roll_disasters()

    def roll_for_newcomers(self):
        # For simplicity, we'll assume:
        # - If average happiness is > 50, there's a 10% chance 10 new individuals move in.
        # - If average happiness is > 70, there's a 20% chance 20 new individuals move in.
        avg_happiness = self.city.happiness_tracker.get_average_happiness()
        newcomers = 0

        if avg_happiness > 70 and random.random() < 0.20:
            newcomers = 20
        elif avg_happiness > 50 and random.random() < 0.10:
            newcomers = 10

        for _ in range(newcomers):
            self.city.population.append(Pop())

        if newcomers:
            print(f"{newcomers} new individuals have moved into the city!")

    def start(self):
        while True:
            print("Options:")
            print("1: Advance Day")
            print("2: Add Electrical Facilities")
            print("3: Add Water Facilities")

            print("X: Exit")

            input_str = input("Choose an option: ").lower().strip()

            if input_str == "1":
                self.advance_day()
                self.display_city_info()  # Display updated city info after advancing a day

            elif input_str == "x":
                break
            else:
                print("Invalid input")
                continue

    def display_city_info(self):
        total_population = len(self.city.population)
        avg_happiness = self.city.happiness_tracker.get_average_happiness()

        sick_count = sum([1 for person in self.city.population if person.sick])
        without_water = sum(
            [1 for person in self.city.population if not person.water_received])
        without_electricity = sum(
            [1 for person in self.city.population if not person.electricity_received])
        without_home = sum(
            [1 for person in self.city.population if not person.has_home])

        print("\n--- City Stats ---")
        print(f"Total Population: {total_population}")
        print(f"Average Happiness: {avg_happiness:.2f}")
        print(f"Sick Individuals: {sick_count}")
        print(f"Without Water: {without_water}")
        print(f"Without Electricity: {without_electricity}")
        print(f"Without Home: {without_home}")
        print("---------------------\n")
