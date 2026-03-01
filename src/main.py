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


def main():
    """run a console menu that has two options, runs in a while loop so multiple options can be selected"""

    initialize_logging()

    seed = GlobalSettings.SEED
    random.seed(seed)

    ts = datetime.now(timezone.utc).strftime("%Y%m%d_%H%M%S")
    run_id = f"run_{ts}_seed_{seed}"

    initial_city = city.City(population=Population.from_list([Pop()]))
    simulation = sim.Sim(city=initial_city, seed=seed, run_id=run_id)
    simulation.start()
