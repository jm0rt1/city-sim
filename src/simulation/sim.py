from __future__ import annotations
import random
import time
from src.city.city import City, Pop
from src.city.finance import CityBudget
from src.simulation.event_bus import EventBus, Event
from src.simulation.logger import SimLogger, normalize_happiness
from src.shared.settings import GlobalSettings

class Sim:
    """Deterministic, tick-driven simulation shared by CLI and GUI."""
    def __init__(self, city: City, seed: int | None = None, run_id: str = "run") -> None:
        self.city, self.seed, self.run_id = city, seed if seed is not None else GlobalSettings.SEED, run_id
        self.rng = random.Random(self.seed); self.day = 0; self.event_bus = EventBus()
        self.city_budget = CityBudget(); self.budget_history: list[tuple[float, float, float]] = []
        if not hasattr(city, "budget"): city.budget = 5000.0
        if not hasattr(city, "previous_budget"): city.previous_budget = None
        self.logger = SimLogger(run_id, GlobalSettings.GLOBAL_LOGS_DIR / f"{run_id}.jsonl")

    def advance_day(self) -> None:
        started = time.perf_counter(); self.roll_for_newcomers(); self.city.on_advance_day(); self.roll_for_leavers()
        delta = self.city_budget.update_budget(self.city, tick_index=self.day); self.budget_history.append((delta.revenue, delta.expenses, self.city.budget)); self.budget_history = self.budget_history[-20:]
        self.day += 1
        self.logger.log_tick(self.day - 1, self.city.budget, delta.revenue, delta.expenses, len(self.city.population.pops), normalize_happiness(self.city.happiness_tracker.get_average_happiness()), [], (time.perf_counter() - started) * 1000)
        self.event_bus.publish(Event(tick=self.day))

    def run(self, ticks: int) -> None:
        for _ in range(ticks): self.advance_day()

    def roll_for_newcomers(self) -> int:
        happiness = self.city.happiness_tracker.get_average_happiness(); newcomers = 0
        if happiness >= 20 and self.rng.random() < .20: newcomers = 20
        elif happiness > 10 and self.rng.random() < .10: newcomers = 10
        elif happiness > 0 and self.rng.random() < .05: newcomers = 1
        for _ in range(newcomers): self.city.population.add_pop(Pop())
        return newcomers

    def roll_for_leavers(self) -> int:
        if self.city.happiness_tracker.get_average_happiness() >= 0: return 0
        staying = []; leaving = 0
        for person in self.city.population.pops:
            wants = ((not person.has_home and self.rng.random() < .5) or (not person.electricity_received and self.rng.random() < .5) or (not person.water_received and self.rng.random() < .5))
            if wants: leaving += 1
            else: staying.append(person)
        self.city.population = type(self.city.population).from_list(staying)
        return leaving

    def display_city_info(self) -> None:
        print(f"Day {self.day}\nPopulation: {len(self.city.population.pops)}\nAvg Happiness: {self.city.happiness_tracker.get_average_happiness():.2f}\nWater Facilities: {self.city.water_facilities}\nElec. Facilities: {self.city.electricity_facilities}\nHousing Units: {self.city.housing_units}")

    def display_run_summary(self) -> None:
        print(f"Run Summary\nTotal Days Simulated:  {self.day}\nFinal Population: {len(self.city.population.pops)}")

    def _write_run_summary(self) -> None:
        self.logger.log_summary(self.city.budget, len(self.city.population.pops), normalize_happiness(self.city.happiness_tracker.get_average_happiness()), self.day, 0.0)

    def start(self) -> None:
        while True:
            choice = input("[1] Advance day  [x] Exit: ").strip().lower()
            if choice == "1": self.advance_day(); self.display_city_info()
            elif choice == "x": break
