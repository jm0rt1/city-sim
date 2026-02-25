import json
import random
import time
from datetime import datetime, timezone
from typing import Callable

from src.city.city import City, Pop
from src.shared.settings import GlobalSettings


class Sim():
    def __init__(self, city: City, seed: int = 42) -> None:
        self.city = city
        self._rng = random.Random(seed)
        self._tick_index = 0
        self._run_id = (
            f"run_{seed}_{datetime.now(timezone.utc).strftime('%Y%m%d_%H%M%S')}"
        )
        self._log_path = GlobalSettings.GLOBAL_LOGS_DIR / f"{self._run_id}.jsonl"

    # ------------------------------------------------------------------
    # Population dynamics
    # ------------------------------------------------------------------

    def roll_disasters(self):
        # 1% chance for a disaster
        if self._rng.random() < 0.01:
            print("A disaster has struck the city!")
            for person in self.city.population.pops:
                person.overall_happiness -= 50

    def roll_population(self):
        pass

    def advance_day(self):
        t0 = time.monotonic()
        self.roll_for_newcomers()
        self.roll_for_leavers()
        self.city.on_advance_day()
        self.roll_disasters()
        tick_duration_ms = (time.monotonic() - t0) * 1000
        self._log_tick(tick_duration_ms)
        self._tick_index += 1

    def roll_for_newcomers(self):
        # Happiness is normalized 0-100; midpoint = 50 (raw = 0).
        # - >= 75 → high happiness: 20% chance 20 newcomers
        # - >  62 → moderate happiness: 10% chance 10 newcomers
        # - >  50 → slight happiness: 5% chance 1 newcomer
        avg_happiness = self.city.happiness_tracker.get_average_happiness()
        newcomers = 0

        if avg_happiness >= 75 and self._rng.random() < 0.20:
            newcomers = 20
        elif avg_happiness > 62 and self._rng.random() < 0.10:
            newcomers = 10
        elif avg_happiness > 50 and self._rng.random() < 0.05:
            newcomers = 1

        for _ in range(newcomers):
            self.city.population.add_pop(Pop(rng=self._rng))

        if newcomers:
            print(f"{newcomers} new individuals have moved into the city!")

    def roll_for_leavers(self):
        avg_happiness = self.city.happiness_tracker.get_average_happiness()
        pops_that_stay: list[Pop] = []

        if avg_happiness < 50:
            for pop in self.city.population.pops:
                wants_to_leave = False
                if not pop.has_home:
                    if self._rng.random() < .5:
                        wants_to_leave = True
                if not pop.electricity_received:
                    if self._rng.random() < .5:
                        wants_to_leave = True
                if not pop.water_received:
                    if self._rng.random() < .5:
                        wants_to_leave = True
                if not wants_to_leave:
                    pops_that_stay.append(pop)
            self.city.population.pops = pops_that_stay

    # ------------------------------------------------------------------
    # Logging
    # ------------------------------------------------------------------

    def _log_tick(self, tick_duration_ms: float):
        entry = {
            "timestamp": datetime.now(timezone.utc).isoformat(),
            "run_id": self._run_id,
            "tick_index": self._tick_index,
            "budget": 0.0,
            "revenue": 0.0,
            "expenses": 0.0,
            "population": len(self.city.population.pops),
            "happiness": self.city.happiness_tracker.get_average_happiness(),
            "policies_applied": [],
            "tick_duration_ms": tick_duration_ms,
        }
        with open(self._log_path, "a") as f:
            f.write(json.dumps(entry) + "\n")

    # ------------------------------------------------------------------
    # Interactive CLI
    # ------------------------------------------------------------------

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
