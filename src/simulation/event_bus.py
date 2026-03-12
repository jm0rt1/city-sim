from __future__ import annotations

from dataclasses import dataclass, field
from queue import Queue


@dataclass
class Event:
    """Base class for all simulation events."""
    tick: int = 0


@dataclass
class BuildingConstructedEvent(Event):
    col: int = 0
    row: int = 0


@dataclass
class BuildingDamagedEvent(Event):
    col: int = 0
    row: int = 0


@dataclass
class TrafficUpdatedEvent(Event):
    pass


@dataclass
class WeatherChangedEvent(Event):
    weather_type: str = "clear"


class EventBus:
    """
    Synchronous fan-out event bus with queue-backed listeners.

    The simulation pushes events via ``publish()`` at tick time.
    The renderer drains its queue each frame without blocking the tick loop.
    """

    def __init__(self) -> None:
        self._queues: list[Queue[Event]] = []

    def subscribe(self) -> Queue[Event]:
        """Register a new listener queue and return it."""
        q: Queue[Event] = Queue()
        self._queues.append(q)
        return q

    def publish(self, event: Event) -> None:
        """Deliver *event* to all registered listener queues (non-blocking)."""
        for q in self._queues:
            q.put_nowait(event)
