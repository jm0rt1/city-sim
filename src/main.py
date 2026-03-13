import logging
import logging.handlers
import random
import threading
from datetime import datetime, timezone
from src.shared.settings import GlobalSettings
import src.simulation.sim as sim
import src.city.city as city
from src.city.population.population import Population, Pop


def initialize_logging():

    file_handler = logging.handlers.RotatingFileHandler(
        GlobalSettings.GLOBAL_LOGS_DIR/GlobalSettings.LoggingParams.GLOBAL_FILE_NAME,
        backupCount=GlobalSettings.LoggingParams.BACKUP_COUNT)

    logging.getLogger().addHandler(file_handler)
    file_handler.doRollover()
    logging.info("Global Logging Started")


class _PauseController:
    """Thread-safe pause/resume controller shared between the render loop and
    the background simulation thread."""

    def __init__(self) -> None:
        self._paused: bool = False
        self._lock: threading.Lock = threading.Lock()

    def is_paused(self) -> bool:
        """Return ``True`` when the simulation is currently paused."""
        with self._lock:
            return self._paused

    def toggle(self) -> None:
        """Flip the paused state."""
        with self._lock:
            self._paused = not self._paused


def main(gui: bool = False):
    """Initialize logging and start the simulation.

    Args:
        gui: When ``True``, open the isometric renderer window instead of
             the headless console loop.
    """
    initialize_logging()
    the_city = city.City()

    if gui:
        _run_with_gui(the_city)
    else:
        simulation = sim.Sim(city=the_city)
        simulation.start()


def _run_with_gui(the_city: "city.City") -> None:
    """Start the isometric renderer with a background simulation tick loop.

    The simulation auto-advances at 1 tick/second on a daemon thread.
    Interactive controls (buttons and keyboard shortcuts in the rendered
    window) let the user add infrastructure and pause/resume the sim.
    """
    import time

    from src.shared.graphics_settings import GraphicsSettings
    from src.simulation.event_bus import EventBus
    from src.gui.renderer.city_renderer import CityRenderer

    settings = GraphicsSettings()
    event_bus = EventBus()
    simulation = sim.Sim(city=the_city)
    pause_ctrl = _PauseController()

    renderer = CityRenderer(
        city=the_city,
        event_bus=event_bus,
        settings=settings,
        toggle_pause=pause_ctrl.toggle,
        is_paused=pause_ctrl.is_paused,
        get_city_budget=lambda: simulation.city_budget,
        get_budget_history=lambda: list(simulation.budget_history),
    )

    def _sim_loop() -> None:
        while True:
            if not pause_ctrl.is_paused():
                simulation.advance_day()
            time.sleep(1.0)

    t = threading.Thread(target=_sim_loop, daemon=True)
    t.start()

    renderer.run()  # blocking; returns when window is closed
