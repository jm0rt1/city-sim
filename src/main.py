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


def _build_sample_transport():
    """
    Build a small sample road network for the GUI demo.

    Creates a 3x3 grid of intersections connected by bidirectional segments,
    with the centre intersection signalised.  Returns a
    ``TransportSubsystem`` seeded deterministically.
    """
    import random as _random
    from src.city.transport.models import (
        Intersection, IntersectionType, Position, RoadGraph, RoadSegment, RoadType,
    )
    from src.city.transport.signals import SignalController
    from src.city.transport.transport_subsystem import TransportSubsystem

    graph = RoadGraph()
    spacing = 300.0  # metres between intersections

    node_ids = []
    for row in range(3):
        for col in range(3):
            nid = f"n{row}{col}"
            itype = (IntersectionType.SIGNALIZED
                     if (row == 1 and col == 1)
                     else IntersectionType.STOP)
            node = Intersection(nid, Position(col * spacing, row * spacing), itype)
            graph.add_intersection(node)
            node_ids.append(nid)

    # Add bidirectional segments for each horizontal and vertical neighbour pair
    seg_idx = 0
    for row in range(3):
        for col in range(3):
            src = f"n{row}{col}"
            for dr, dc in [(0, 1), (1, 0)]:
                nr, nc = row + dr, col + dc
                if 0 <= nr < 3 and 0 <= nc < 3:
                    dst = f"n{nr}{nc}"
                    sid_fwd = f"seg{seg_idx}"
                    sid_rev = f"seg{seg_idx + 1}"
                    seg_idx += 2
                    for sid, frm, to in [(sid_fwd, src, dst), (sid_rev, dst, src)]:
                        graph.add_segment(RoadSegment(
                            sid, frm, to,
                            length=spacing,
                            speed_limit=13.4,
                            capacity=1800,
                            road_type=RoadType.ARTERIAL,
                        ))

    # Attach a signal controller to the centre intersection
    centre = graph.nodes["n11"]
    centre.signal_controller = SignalController("n11")

    rng = _random.Random(GlobalSettings.SEED)
    return TransportSubsystem(network=graph, rng=rng)


def main(gui: bool = False):
    """Initialize logging and start the simulation.

    Args:
        gui: When ``True``, open the isometric renderer window instead of
             the headless console loop.
    """
    initialize_logging()

    seed = GlobalSettings.SEED
    random.seed(seed)

    ts = datetime.now(timezone.utc).strftime("%Y%m%d_%H%M%S")
    run_id = f"run_{ts}_seed_{seed}"

    the_city = city.City(population=Population.from_list([Pop()]))
    transport = _build_sample_transport()

    if gui:
        _run_with_gui(the_city, transport, run_id, seed)
    else:
        simulation = sim.Sim(city=the_city, seed=seed, run_id=run_id, transport=transport)
        simulation.start()


def _run_with_gui(
    the_city: "city.City",
    transport,
    run_id: str,
    seed: int,
) -> None:
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
    simulation = sim.Sim(city=the_city, seed=seed, run_id=run_id, transport=transport)
    pause_ctrl = _PauseController()

    renderer = CityRenderer(
        city=the_city,
        event_bus=event_bus,
        settings=settings,
        toggle_pause=pause_ctrl.toggle,
        is_paused=pause_ctrl.is_paused,
        get_traffic_delta=lambda: simulation.last_traffic_delta,
    )

    def _sim_loop() -> None:
        while True:
            if not pause_ctrl.is_paused():
                simulation.advance_day()
            time.sleep(1.0)

    t = threading.Thread(target=_sim_loop, daemon=True)
    t.start()

    renderer.run()  # blocking; returns when window is closed
