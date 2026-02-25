from src.city.city import City


class CityBudget():
    def __init__(self):
        self.income = 0
        self.expenditure = 0
        self.balance = 0

        # Set initial values
        self.income_tax_rate = 0.1  # 10% tax on income
        self.property_tax_rate = 0.05  # 5% tax on property
        self.utility_tax_rate = 0.02  # 2% tax on utilities

        self.facility_maintenance_cost = 50  # Cost per facility
        self.home_maintenance_cost = 5  # Cost per home

    def calculate_income(self, city: City):
        # Income from taxes — single pass over population
        with_property = 0
        utility_users = 0
        for person in city.population.pops:
            if person.property:
                with_property += 1
            if person.water_received or person.electricity_received:
                utility_users += 1
        self.income += with_property * (self.income_tax_rate + self.property_tax_rate)
        self.income += utility_users * self.utility_tax_rate

    def calculate_expenditure(self, city: City):
        # Expenditure for maintaining facilities and homes
        self.expenditure += city.water_facilities * self.facility_maintenance_cost
        self.expenditure += city.electricity_facilities * self.facility_maintenance_cost
        self.expenditure += city.housing_units * self.home_maintenance_cost

    def update_budget(self, city: "City"):
        self.calculate_income(city)
        self.calculate_expenditure(city)
        self.balance = self.income - self.expenditure
