

from pathlib import Path


class GlobalSettings():
    ##
    # Paths ---------
    APP_DIR = Path("./").resolve()

    # Output Directory
    OUTPUT_DIR = APP_DIR/"output"
    # Logging Related Paths
    LOGS_DIR = OUTPUT_DIR/"logs"
    GLOBAL_LOGS_DIR = LOGS_DIR/"global"
    UI_LOGS_DIR = LOGS_DIR/"ui"
    REPORTS_DIR = OUTPUT_DIR/"reports"
    # Paths ---------
    ##

    # Simulation Parameters
    SEED: int = 12345
    TICK_HORIZON: int = 10

    class LoggingParams():
        BACKUP_COUNT = 10
        GLOBAL_FILE_NAME = "global.log"

    # Operations
    OUTPUT_DIR.mkdir(exist_ok=True, parents=True)
    LOGS_DIR.mkdir(exist_ok=True, parents=True)
    GLOBAL_LOGS_DIR.mkdir(exist_ok=True, parents=True)
    UI_LOGS_DIR.mkdir(exist_ok=True, parents=True)
    REPORTS_DIR.mkdir(exist_ok=True, parents=True)
