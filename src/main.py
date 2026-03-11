import logging
import logging.handlers
import random
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
    """Start the isometric renderer with a background simulation tick loop."""
    import threading
    import time

    from src.shared.graphics_settings import GraphicsSettings
    from src.simulation.event_bus import EventBus
    from src.gui.renderer.city_renderer import CityRenderer

    settings = GraphicsSettings()
    event_bus = EventBus()
    renderer = CityRenderer(
        city=the_city, event_bus=event_bus, settings=settings)

    # Auto-advance simulation at 1 tick/second on a daemon thread so it does
    # not block the pygame render loop on the main thread.
    def _sim_loop() -> None:
        simulation = sim.Sim(city=the_city)
        while True:
            simulation.advance_day()
            time.sleep(1.0)

    t = threading.Thread(target=_sim_loop, daemon=True)
    t.start()

    renderer.run()  # blocking; returns when window is closed
