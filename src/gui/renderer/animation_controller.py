"""
src/gui/renderer/animation_controller.py
-----------------------------------------
Phase 5A — AnimationController

Manages per-sprite frame advancement at a configurable frame rate (default
8 fps).  Completely decoupled from both the simulation tick rate and the
display frame rate — callers just pass the elapsed milliseconds each display
frame and query the current frame index for any registered sprite.

This module is **pure Python** — it never imports pygame and is therefore
importable and testable in headless / CI environments.
"""
from __future__ import annotations


class AnimationController:
    """
    Tracks per-sprite animation state.

    Each sprite is registered with a frame count and frames-per-second rate.
    On every display frame the owner calls :meth:`tick` with the elapsed
    milliseconds; :meth:`get_frame` then returns the 0-based frame index that
    should be used when selecting the correct sprite from the strip.
    """

    def __init__(self) -> None:
        # sprite_id → (frame_count, fps, accumulated_ms, current_frame)
        self._sprites: dict[str, list[int | float]] = {}

    # ------------------------------------------------------------------
    # Public API
    # ------------------------------------------------------------------

    def register(self, sprite_id: str, frame_count: int, fps: float = 8.0) -> None:
        """
        Declare an animated sprite strip.

        Parameters
        ----------
        sprite_id:
            Base sprite identifier (e.g. ``"terrain_water"``).
        frame_count:
            Number of frames in the animation strip (must be ≥ 1).
        fps:
            Target frame advancement rate in frames per second.
        """
        if frame_count < 1:
            raise ValueError("frame_count must be >= 1")
        if fps <= 0.0:
            raise ValueError("fps must be > 0")
        self._sprites[sprite_id] = [frame_count, fps, 0.0, 0]

    def tick(self, elapsed_ms: float) -> None:
        """
        Advance all animation accumulators by *elapsed_ms* milliseconds.

        Should be called once per display frame, with the value returned by
        ``pygame.Clock.get_time()``.
        """
        for entry in self._sprites.values():
            frame_count, fps, acc, current = entry
            ms_per_frame = 1000.0 / fps
            acc += elapsed_ms
            while acc >= ms_per_frame:
                acc -= ms_per_frame
                current = (int(current) + 1) % int(frame_count)
            entry[2] = acc
            entry[3] = current

    def get_frame(self, sprite_id: str) -> int:
        """
        Return the current 0-based frame index for *sprite_id*.

        Returns ``0`` for any sprite that has not been registered, so callers
        can safely call this without checking existence first.
        """
        entry = self._sprites.get(sprite_id)
        if entry is None:
            return 0
        return int(entry[3])
