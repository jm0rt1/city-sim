from src.city.population.population import Population


class HappinessTracker():

    def __init__(self, population: Population) -> None:
        self.average_happiness = 0
        self.update_happiness(population)

    def update_happiness(self, population: Population):
        total_happiness = sum(
            person.overall_happiness for person in population.pops)
        self.average_happiness = total_happiness / \
            len(population.pops) if population.pops else 0

    def get_average_happiness(self):
        return self.average_happiness
