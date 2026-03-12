from dataclasses import dataclass


@dataclass
class GraphicsSettings:
    """Configuration for the isometric renderer."""
    tile_width: int = 64
    tile_height: int = 32
    window_width: int = 1280
    window_height: int = 720
    fps_cap: int = 60
    fullscreen: bool = False
    vsync: bool = True
