from __future__ import annotations

from dataclasses import dataclass, field

import pygame
import pygame.freetype

from src.city.building import BuildingType
from src.gui.renderer.building_sprite_selector import BuildingSpriteSelector
from src.gui.renderer.tile_atlas import TileAtlas
from src.city.building import Building


#: Sentinel value for road-placement mode (not a BuildingType).
ROAD_TOOL: str = "__road__"

#: Union of valid palette selections — building type or road tool sentinel.
PaletteTool = BuildingType | str

# Building types that can be directly placed by the player.
PLACEABLE_TYPES: list[BuildingType] = [
    BuildingType.EMPTY_LOT,          # acts as an eraser
    BuildingType.RESIDENTIAL_SMALL,
    BuildingType.RESIDENTIAL_MEDIUM,
    BuildingType.RESIDENTIAL_LARGE,
    BuildingType.COMMERCIAL,
    BuildingType.INDUSTRIAL,
    BuildingType.CIVIC_CITY_HALL,
    BuildingType.CIVIC_HOSPITAL,
    BuildingType.CIVIC_SCHOOL,
    BuildingType.CIVIC_FIRE_STATION,
    BuildingType.CIVIC_POLICE_STATION,
    BuildingType.CIVIC_POWER_PLANT,
    BuildingType.PARK,
]

# Short display names for the palette labels.
_DISPLAY_NAMES: dict[BuildingType, str] = {
    BuildingType.EMPTY_LOT:           "Erase",
    BuildingType.RESIDENTIAL_SMALL:   "Res. S",
    BuildingType.RESIDENTIAL_MEDIUM:  "Res. M",
    BuildingType.RESIDENTIAL_LARGE:   "Res. L",
    BuildingType.COMMERCIAL:          "Comm.",
    BuildingType.INDUSTRIAL:          "Indust.",
    BuildingType.CIVIC_CITY_HALL:     "City H.",
    BuildingType.CIVIC_HOSPITAL:      "Hosp.",
    BuildingType.CIVIC_SCHOOL:        "School",
    BuildingType.CIVIC_FIRE_STATION:  "Fire St.",
    BuildingType.CIVIC_POLICE_STATION: "Police",
    BuildingType.CIVIC_POWER_PLANT:   "Power",
    BuildingType.PARK:                "Park",
}


@dataclass
class _PaletteEntry:
    building_type: PaletteTool
    rect: pygame.Rect = field(default_factory=lambda: pygame.Rect(0, 0, 0, 0))


class BuildingPalette:
    """
    Horizontal bottom-bar palette that lets the player select which building
    type to place on the isometric grid.

    The currently-selected type is highlighted.  The palette tile sprites
    are rendered using the same :class:`TileAtlas` as the main grid.

    The ``selected`` property gives the currently-active
    :class:`~src.city.building.BuildingType`.

    Args:
        screen_w: Full window width in pixels.
        screen_h: Full window height in pixels.
        atlas: Shared tile atlas for drawing tile preview sprites.
    """

    _ENTRY_W: int = 80
    _ENTRY_H: int = 64
    _PADDING: int = 6
    _FONT_SIZE: int = 11
    _BAR_EXTRA_H: int = 4   # padding above/below entries

    _COLOR_BG:       tuple[int, int, int, int] = (20, 20, 30, 220)
    _COLOR_SELECTED: tuple[int, int, int]       = (255, 220, 60)
    _COLOR_HOVER:    tuple[int, int, int]       = (180, 180, 220)
    _COLOR_NORMAL:   tuple[int, int, int]       = (55, 58, 80)
    _COLOR_TEXT:     tuple[int, int, int]       = (220, 220, 230)
    _COLOR_LABEL:    tuple[int, int, int]       = (160, 160, 200)

    def __init__(self, screen_w: int, screen_h: int, atlas: TileAtlas) -> None:
        self._screen_w = screen_w
        self._screen_h = screen_h
        self._atlas = atlas
        self._selector = BuildingSpriteSelector()
        self._font_instance: pygame.freetype.Font | None = None
        self._rects_built: bool = False

        self._entries: list[_PaletteEntry] = [
            _PaletteEntry(bt) for bt in PLACEABLE_TYPES
        ]
        # Road tool entry appended after standard building types.
        self._entries.append(_PaletteEntry(ROAD_TOOL))
        self._selected: PaletteTool = BuildingType.RESIDENTIAL_SMALL

    @property
    def selected(self) -> PaletteTool:
        """The tool currently active for placement (BuildingType or ROAD_TOOL)."""
        return self._selected

    @property
    def bar_height(self) -> int:
        """Total pixel height of the palette bar."""
        return self._ENTRY_H + self._PADDING * 2 + self._BAR_EXTRA_H * 2 + self._FONT_SIZE + 2

    @property
    def bar_y(self) -> int:
        """Y position of the top edge of the palette bar."""
        return self._screen_h - self.bar_height

    # ------------------------------------------------------------------
    # Input
    # ------------------------------------------------------------------

    def handle_click(self, pos: tuple[int, int]) -> bool:
        """
        Select the entry at *pos* if it falls inside the palette bar.

        Returns ``True`` if the click was consumed by the palette.
        """
        self._ensure_rects()
        for entry in self._entries:
            if entry.rect.collidepoint(pos):
                self._selected = entry.building_type
                return True
        return False

    def contains(self, pos: tuple[int, int]) -> bool:
        """Return ``True`` if *pos* is inside the palette bar area."""
        return pos[1] >= self.bar_y

    # ------------------------------------------------------------------
    # Rendering
    # ------------------------------------------------------------------

    def draw(self, surface: pygame.Surface) -> None:
        """Render the palette bar onto *surface*."""
        self._ensure_rects()

        # Background strip
        bar = pygame.Surface((self._screen_w, self.bar_height), pygame.SRCALPHA)
        bar.fill(self._COLOR_BG)
        surface.blit(bar, (0, self.bar_y))

        mouse_pos = pygame.mouse.get_pos()
        for entry in self._entries:
            is_selected = entry.building_type == self._selected
            if is_selected:
                pygame.draw.rect(surface, self._COLOR_SELECTED, entry.rect, border_radius=4)
                pygame.draw.rect(surface, self._COLOR_SELECTED, entry.rect, 2, border_radius=4)
            elif entry.rect.collidepoint(mouse_pos):
                pygame.draw.rect(surface, self._COLOR_HOVER, entry.rect, 2, border_radius=4)
            else:
                pygame.draw.rect(surface, self._COLOR_NORMAL, entry.rect, border_radius=4)

            # Tile sprite preview centred in the entry
            if entry.building_type == ROAD_TOOL:
                sprite_id = "road_h"
                label = "Road"
            else:
                btype = entry.building_type
                assert isinstance(btype, BuildingType), (
                    f"expected BuildingType, got {btype!r}"
                )
                dummy_building = Building(btype)
                sprite_id = self._selector.get_sprite_id(dummy_building)
                label = _DISPLAY_NAMES.get(btype, btype.name)
            tile_surf = self._atlas.get_tile(sprite_id)
            tw, th = tile_surf.get_size()
            tile_x = entry.rect.x + (self._ENTRY_W - tw) // 2
            tile_y = entry.rect.y + self._PADDING
            surface.blit(tile_surf, (tile_x, tile_y))

            # Label below sprite
            lsurf, lrect = self._font.render(label, self._COLOR_TEXT)
            lx = entry.rect.x + (self._ENTRY_W - lrect.width) // 2
            ly = tile_y + th + 2
            surface.blit(lsurf, (lx, ly))

        # "BUILD MODE" label on the left
        self._font.render_to(
            surface,
            (self._PADDING, self.bar_y + self._BAR_EXTRA_H),
            "BUILD:",
            self._COLOR_LABEL,
        )

    # ------------------------------------------------------------------
    # Private
    # ------------------------------------------------------------------

    @property
    def _font(self) -> pygame.freetype.Font:
        self._ensure_font()
        assert self._font_instance is not None
        return self._font_instance

    def _ensure_font(self) -> None:
        if self._font_instance is None:
            pygame.freetype.init()
            self._font_instance = pygame.freetype.SysFont("monospace", self._FONT_SIZE)

    def _ensure_rects(self) -> None:
        if self._rects_built:
            return
        total_w = len(self._entries) * (self._ENTRY_W + self._PADDING) - self._PADDING
        start_x = (self._screen_w - total_w) // 2
        y = self.bar_y + self._BAR_EXTRA_H
        for entry in self._entries:
            entry.rect = pygame.Rect(start_x, y, self._ENTRY_W, self._ENTRY_H)
            start_x += self._ENTRY_W + self._PADDING
        self._rects_built = True
