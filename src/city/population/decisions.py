
import random
from src.city.city import City


class DecisionsBase(object):
    def __init__(self, city: City):
        self.city = city

    def roll(self, chance_percentage: float) -> bool:
        """
        Returns True if a random float between 0 and 1 is less than the given chance_percentage.
        """
        return random.random() < chance_percentage
