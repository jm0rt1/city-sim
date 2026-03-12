from __future__ import annotations

from typing import TYPE_CHECKING, Optional

import pygame
import pygame.freetype

from src.city.city import City

if TYPE_CHECKING:
    from src.city.transport.models import TrafficDelta


class UIOverlay:
    """
    HUD panel drawn on top of the isometric grid.

    Displays: population count, average happiness, infrastructure counts,
    and (optionally) live traffic metrics from the TransportSubsystem.
    """

    _FONT_SIZE = 16
    _PADDING = 10
    _BG_COLOR = (0, 0, 0, 160)
    _TEXT_COLOR = (255, 255, 255)
    _TRAFFIC_HEADER_COLOR = (120, 200, 255)
    _CONGESTION_LOW_COLOR  = (80, 220, 80)    # green  – congestion < 0.3
    _CONGESTION_MID_COLOR  = (255, 200, 60)   # amber  – 0.3 – 0.7
    _CONGESTION_HIGH_COLOR = (255, 80, 80)    # red    – > 0.7

    def __init__(self) -> None:
        pygame.freetype.init()
        self._font = pygame.freetype.SysFont("monospace", self._FONT_SIZE)

    def draw(
        self,
        surface: pygame.Surface,
        city: City,
        traffic_delta: "Optional[TrafficDelta]" = None,
    ) -> None:
        """Render the HUD onto *surface* using current *city* state.

        Args:
            surface: Target pygame surface.
            city: Current city state for population/infrastructure lines.
            traffic_delta: Latest ``TrafficDelta`` from the transport
                subsystem, or ``None`` if the subsystem is not active.
        """
        population = len(city.population.pops)
        try:
            happiness = city.population.happiness_tracker.get_average_happiness()
        except Exception:
            happiness = 0.0

        city_lines: list[tuple[str, tuple[int, int, int]]] = [
            (f"Population : {population}",                     self._TEXT_COLOR),
            (f"Happiness  : {happiness:.1f}",                  self._TEXT_COLOR),
            (f"Water fac. : {city.water_facilities}",          self._TEXT_COLOR),
            (f"Elec. fac. : {city.electricity_facilities}",    self._TEXT_COLOR),
            (f"Housing    : {city.housing_units}",             self._TEXT_COLOR),
        ]

        traffic_lines: list[tuple[str, tuple[int, int, int]]] = []
        if traffic_delta is not None:
            ci = traffic_delta.congestion_index
            if ci < 0.3:
                ci_color = self._CONGESTION_LOW_COLOR
            elif ci < 0.7:
                ci_color = self._CONGESTION_MID_COLOR
            else:
                ci_color = self._CONGESTION_HIGH_COLOR

            avg_speed_kph = traffic_delta.avg_speed * 3.6  # m/s → km/h
            traffic_lines = [
                ("── Traffic ──────────",                       self._TRAFFIC_HEADER_COLOR),
                (f"Vehicles   : {traffic_delta.vehicles_active}",  self._TEXT_COLOR),
                (f"Avg speed  : {avg_speed_kph:.1f} km/h",     self._TEXT_COLOR),
                (f"Congestion : {ci:.2f}",                      ci_color),
                (f"Throughput : {traffic_delta.total_throughput}", self._TEXT_COLOR),
            ]
            if traffic_delta.incidents_active:
                traffic_lines.append(
                    (f"Incidents  : {traffic_delta.incidents_active} active",
                     self._CONGESTION_HIGH_COLOR)
                )

        all_lines = city_lines + traffic_lines

        line_h = self._FONT_SIZE + 4
        panel_w = 230
        panel_h = len(all_lines) * line_h + self._PADDING * 2

        panel = pygame.Surface((panel_w, panel_h), pygame.SRCALPHA)
        panel.fill(self._BG_COLOR)
        surface.blit(panel, (self._PADDING, self._PADDING))

        for i, (line, color) in enumerate(all_lines):
            y = self._PADDING + i * line_h + self._PADDING
            self._font.render_to(
                surface,
                (self._PADDING * 2, y),
                line,
                color,
            )

