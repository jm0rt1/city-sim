"""
src/gui/renderer/particle_system.py
-------------------------------------
Phase 5C — Smoke Particle System

Emits rising smoke particles from POWER_PLANT and INDUSTRIAL tiles.  The
update logic (physics, lifetime management) is **pure Python** and requires
no pygame, so it can be unit-tested in headless CI environments.  Only
:meth:`ParticleSystem.draw` imports and uses pygame surfaces.

Determinism: the per-frame spawn RNG is seeded from a caller-supplied
``random.Random`` instance so that identical seeds produce identical visual
output.
"""
from __future__ import annotations

import random
from dataclasses import dataclass, field

# ------------------------------------------------------------------
# Data model
# ------------------------------------------------------------------

_EMIT_INTERVAL_MS: float = 80.0   # minimum ms between emission bursts per tile
_PARTICLE_LIFETIME_MS: float = 1200.0  # how long a particle lives
_RISE_SPEED: float = 0.04          # pixels per millisecond (upward)
_DRIFT_RANGE: float = 0.01         # horizontal drift magnitude (px/ms)


@dataclass
class Particle:
    """A single smoke puff."""
    pos: list[float]       # [x, y] in screen pixels
    vel: list[float]       # [vx, vy] in pixels/ms
    alpha: int             # 0-255 opacity
    radius: float          # display radius in pixels
    age_ms: float = 0.0    # accumulated lifetime


# ------------------------------------------------------------------
# System
# ------------------------------------------------------------------

class ParticleSystem:
    """
    Manages a pool of :class:`Particle` objects for factory smoke effects.

    Typical usage inside :class:`~src.gui.renderer.city_renderer.CityRenderer`::

        # Construction (once)
        self._particles = ParticleSystem(rng=random.Random(seed))

        # Each frame — before building blit, after road blit
        for (col, row) in factory_tile_positions:
            self._particles.emit(col, row)
        self._particles.update(elapsed_ms)
        self._particles.draw(surface, self._mapper, self._camera)

    The ``emit`` method is rate-limited: at most one burst per tile per
    ``_EMIT_INTERVAL_MS`` milliseconds.
    """

    def __init__(self, rng: random.Random | None = None) -> None:
        self._rng: random.Random = rng if rng is not None else random.Random(0)
        self._particles: list[Particle] = []
        # tile (col,row) → accumulated ms since last emission
        self._cooldowns: dict[tuple[int, int], float] = {}
        # pending screen-space origins for emit() called this frame
        # actual world→screen conversion happens lazily in emit()
        self._pending_origins: list[tuple[int, int, int, int]] = []  # (col, row, sx, sy)

    # ------------------------------------------------------------------
    # Pure-Python API (no pygame)
    # ------------------------------------------------------------------

    def emit_at_screen(
        self,
        col: int,
        row: int,
        screen_x: int,
        screen_y: int,
        elapsed_ms: float = 0.0,
    ) -> None:
        """
        Attempt to spawn 1–3 particles above the screen position *(screen_x,
        screen_y)* for tile *(col, row)*.

        Rate-limited: if the tile was emitted within ``_EMIT_INTERVAL_MS`` ms
        no new particles are spawned.
        """
        cooldown = self._cooldowns.get((col, row), _EMIT_INTERVAL_MS)
        cooldown += elapsed_ms
        if cooldown < _EMIT_INTERVAL_MS:
            self._cooldowns[(col, row)] = cooldown
            return
        self._cooldowns[(col, row)] = 0.0
        count = self._rng.randint(1, 3)
        for _ in range(count):
            vx = (self._rng.random() - 0.5) * _DRIFT_RANGE
            vy = -_RISE_SPEED * (0.8 + self._rng.random() * 0.4)
            r = 3.0 + self._rng.random() * 4.0
            ox = self._rng.randint(-6, 6)
            self._particles.append(
                Particle(
                    pos=[float(screen_x + ox), float(screen_y - 4)],
                    vel=[vx, vy],
                    alpha=200,
                    radius=r,
                )
            )

    def update(self, elapsed_ms: float) -> None:
        """
        Advance all particles by *elapsed_ms* milliseconds.

        Particles whose alpha reaches 0 (or whose age exceeds the lifetime)
        are removed from the pool.
        """
        alive: list[Particle] = []
        fade_per_ms = 255.0 / _PARTICLE_LIFETIME_MS
        for p in self._particles:
            p.age_ms += elapsed_ms
            p.pos[0] += p.vel[0] * elapsed_ms
            p.pos[1] += p.vel[1] * elapsed_ms
            p.alpha = max(0, int(200 - p.age_ms * fade_per_ms))
            if p.alpha > 0 and p.age_ms < _PARTICLE_LIFETIME_MS:
                alive.append(p)
        self._particles = alive

    # ------------------------------------------------------------------
    # Pygame-dependent draw
    # ------------------------------------------------------------------

    def draw(self, surface: object) -> None:
        """
        Blit all live particles onto *surface*.

        The surface must be a ``pygame.Surface``.  This method is the only
        part of :class:`ParticleSystem` that requires pygame.
        """
        try:
            import pygame  # noqa: PLC0415
        except ImportError:
            return
        surf: pygame.Surface = surface  # type: ignore[assignment]
        for p in self._particles:
            if p.alpha <= 0:
                continue
            r = max(1, int(p.radius))
            smoke_surf = pygame.Surface((r * 2, r * 2), pygame.SRCALPHA)
            pygame.draw.circle(
                smoke_surf,
                (180, 180, 180, p.alpha),
                (r, r),
                r,
            )
            surf.blit(smoke_surf, (int(p.pos[0]) - r, int(p.pos[1]) - r))

    # ------------------------------------------------------------------
    # Convenience accessor
    # ------------------------------------------------------------------

    @property
    def particles(self) -> list[Particle]:
        """Read-only view of the live particle list (for testing)."""
        return list(self._particles)
