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
        # Income from taxes
        # For simplicity, those with homes are considered employed
        employed = sum([1 for person in city.population if person.property])
        self.income += employed * self.income_tax_rate

        properties = sum([1 for person in city.population if person.property])
        self.income += properties * self.property_tax_rate

        utility_users = sum(
            [1 for person in city.population if person.water_received or person.electricity_received])
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
