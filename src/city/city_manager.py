from src.city.decisions import DisasterDecision, StayDecision
from src.city.population.population import Pop
from src.city.city import City


class CityManager:
    def __init__(self, city: City):
        self.city = city

    def advance_day(self):
        # Advance the day for the city (this would include tasks like distributing water, electricity, etc.)
        self.city.on_advance_day()

        # Check for disasters
        if self.check_for_disaster():
            print("A disaster has struck!")
            # Handle the disaster effects here, e.g., reducing happiness, damaging infrastructure, etc.

        # Check if citizens should stay or leave
        self.manage_population()

        # Display the day's report
        self.display_daily_report()

    def check_for_disaster(self) -> bool:
        disaster_decision = DisasterDecision(self.city)
        return disaster_decision.roll()

    def manage_population(self):
        pops_to_remove: list[Pop] = []
        for pop in self.city.population.pops:
            stay_decision = StayDecision(self.city, pop)
            if not stay_decision.roll():
                pops_to_remove.append(pop)
                print("A citizen has left the city.")

        for pop in pops_to_remove:
            self.city.population.remove_pop(pop)

    def display_daily_report(self):
        # Display city stats
        # ...

        # Display financial report
        # ...
        pass
