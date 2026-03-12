import random


class RandomService:
    """Seeded random number generator for deterministic simulation."""

    def __init__(self, seed: int = 42) -> None:
        self._rng = random.Random(seed)

    def random(self) -> float:
        return self._rng.random()

    def randint(self, a: int, b: int) -> int:
        return self._rng.randint(a, b)
