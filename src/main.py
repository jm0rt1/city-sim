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
    def __init__(self) -> None:
        self._paused = False; self._lock = threading.Lock()
    def toggle(self) -> None:
        with self._lock: self._paused = not self._paused
    def is_paused(self) -> bool:
        with self._lock: return self._paused

def main(gui: bool = False):
    """run a console menu that has two options, runs in a while loop so multiple options can be selected"""

    initialize_logging()

    seed = GlobalSettings.SEED
    random.seed(seed)

    ts = datetime.now(timezone.utc).strftime("%Y%m%d_%H%M%S")
    run_id = f"run_{ts}_seed_{seed}"

    initial_city = city.City(population=Population.from_list([Pop()]))
    simulation = sim.Sim(city=initial_city, seed=seed, run_id=run_id)
    if not gui:
        simulation.start(); return
    from src.gui.renderer.city_renderer import CityRenderer
    from src.shared.graphics_settings import GraphicsSettings
    pause = _PauseController()
    CityRenderer(initial_city, simulation.event_bus, GraphicsSettings(), toggle_pause=pause.toggle, is_paused=pause.is_paused, advance_simulation=simulation.advance_day).run()
