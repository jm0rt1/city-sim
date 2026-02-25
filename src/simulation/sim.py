import json
import random
import time
from datetime import datetime, timezone
from typing import Callable
from src.city.city import City, Pop
from src.shared.settings import GlobalSettings


class Sim():
    def __init__(self, city: City, seed: int = 0, run_id: str = "run") -> None:
        self.city = city
        self.seed = seed
        self.run_id = run_id
        self._tick_index = 0
        self._log_path = GlobalSettings.GLOBAL_LOGS_DIR / f"{run_id}.jsonl"

    def _write_tick_log(self, tick_duration_ms: float) -> None:
        population = len(self.city.population.pops)
        happiness = self.city.happiness_tracker.get_average_happiness()
        entry = {
            "timestamp": datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%S.") +
                         f"{datetime.now(timezone.utc).microsecond // 1000:03d}Z",
            "run_id": self.run_id,
            "tick_index": self._tick_index,
            "budget": 0.0,
            "revenue": 0.0,
            "expenses": 0.0,
            "population": population,
            "happiness": round(happiness, 4),
            "policies_applied": [],
            "tick_duration_ms": round(tick_duration_ms, 4),
        }
        with open(self._log_path, "a") as f:
            f.write(json.dumps(entry) + "\n")

    def roll_disasters(self):
        # For simplicity, we'll roll a 1% chance for a disaster
        if random.random() < 0.01:
            print("A disaster has struck the city!")
            for person in self.city.population.pops:
                person.overall_happiness -= 50

    def roll_population(self):
        pass

    def advance_day(self):
        tick_start = time.monotonic()
        self.roll_for_newcomers()
        self.roll_for_leavers()
        self.city.on_advance_day()
        self.roll_disasters()
        tick_duration_ms = (time.monotonic() - tick_start) * 1000.0
        self._write_tick_log(tick_duration_ms)
        self._tick_index += 1

    def run(self, ticks: int) -> None:
        """Execute a fixed number of ticks (for automated/scenario runs)."""
        for _ in range(ticks):
            self.advance_day()

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
            self.city.population.add_pop(Pop())

        if newcomers:
            print(f"{newcomers} new individuals have moved into the city!")

    def roll_for_leavers(self):
        avg_happiness = self.city.happiness_tracker.get_average_happiness()

        if avg_happiness < 0:
            pops_to_remove: list[Pop] = []
            for pop in list(self.city.population.pops):
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
                if wants_to_leave:
                    pops_to_remove.append(pop)
            for pop in pops_to_remove:
                self.city.population.remove_pop(pop)

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
        total_population = len(self.city.population.pops)
        avg_happiness = self.city.happiness_tracker.get_average_happiness()

        sick_count = 0
        without_water = 0
        without_electricity = 0
        without_home = 0
        for person in self.city.population.pops:
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
