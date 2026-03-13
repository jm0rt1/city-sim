from __future__ import annotations

try:
    import pygame
    _HAS_PYGAME = True
except ImportError:
    _HAS_PYGAME = False

# Sky colour key-frames (time_fraction, R, G, B)
# 0.0 = midnight, 0.25 = dawn, 0.5 = noon, 0.75 = dusk
_SKY_KEYFRAMES: list[tuple[float, int, int, int]] = [
    (0.00, 20, 20, 40),    # midnight
    (0.25, 255, 120, 60),  # dawn
    (0.50, 100, 160, 255), # noon
    (0.75, 255, 80, 30),   # dusk
    (1.00, 20, 20, 40),    # midnight (wrap)
]

# Ambient overlay alpha key-frames (time_fraction, alpha)
_ALPHA_KEYFRAMES: list[tuple[float, int]] = [
    (0.00, 160),  # midnight — darkest
    (0.25, 80),   # dawn
    (0.50, 0),    # noon — no overlay
    (0.75, 80),   # dusk
    (1.00, 160),  # midnight (wrap)
]


def _lerp(a: float, b: float, t: float) -> float:
    """Linear interpolation between *a* and *b* at fraction *t* ∈ [0, 1]."""
    return a + (b - a) * t


def _interp_color(
    keyframes: list[tuple[float, int, int, int]], t: float
) -> tuple[int, int, int]:
    """Interpolate an RGB colour from *keyframes* at fractional time *t*."""
    for i in range(len(keyframes) - 1):
        t0, r0, g0, b0 = keyframes[i]
        t1, r1, g1, b1 = keyframes[i + 1]
        if t0 <= t <= t1:
            frac = (t - t0) / (t1 - t0) if t1 > t0 else 0.0
            return (
                int(_lerp(r0, r1, frac)),
                int(_lerp(g0, g1, frac)),
                int(_lerp(b0, b1, frac)),
            )
    return (keyframes[-1][1], keyframes[-1][2], keyframes[-1][3])


def _interp_alpha(keyframes: list[tuple[float, int]], t: float) -> int:
    """Interpolate an alpha value from *keyframes* at fractional time *t*."""
    for i in range(len(keyframes) - 1):
        t0, a0 = keyframes[i]
        t1, a1 = keyframes[i + 1]
        if t0 <= t <= t1:
            frac = (t - t0) / (t1 - t0) if t1 > t0 else 0.0
            return int(_lerp(a0, a1, frac))
    return keyframes[-1][1]


class DayNightCycle:
    """
    Tick-driven day/night cycle for the city renderer.

    Time is represented as a fraction in ``[0.0, 1.0)`` where:

    * ``0.0``  — midnight
    * ``0.25`` — dawn
    * ``0.5``  — noon
    * ``0.75`` — dusk

    All methods except :meth:`get_ambient_overlay` are pure Python and can
    be used without a display or pygame.
    """

    def __init__(self, ticks_per_day: int = 24) -> None:
        self.ticks_per_day: int = ticks_per_day

    def get_time(self, tick_index: int) -> float:
        """Return the fractional time of day in ``[0.0, 1.0)`` for *tick_index*.

        Wraps automatically: ``get_time(24) == get_time(0) == 0.0``
        (with the default ``ticks_per_day=24``).
        """
        return (tick_index % self.ticks_per_day) / self.ticks_per_day

    def get_sky_color(self, time: float) -> tuple[int, int, int]:
        """Return the sky background RGB colour for fractional *time*.

        Interpolates between:

        * midnight  (20, 20, 40)
        * dawn      (255, 120, 60)
        * noon      (100, 160, 255)
        * dusk      (255, 80, 30)
        """
        t = max(0.0, min(time, 0.9999))
        return _interp_color(_SKY_KEYFRAMES, t)

    def is_night(self, time: float) -> bool:
        """Return ``True`` when *time* is in the night window.

        Night is defined as ``time ∈ [0.75, 1.0) ∪ [0.0, 0.25)``.
        """
        return time < 0.25 or time >= 0.75

    def get_ambient_overlay(self, time: float, width: int, height: int) -> "pygame.Surface":
        """Return a full-screen ``SRCALPHA`` surface with darkness overlay.

        Alpha ranges from ``0`` at noon to ``160`` at midnight.
        *width* and *height* must match the display surface dimensions.

        Requires pygame; raises ``RuntimeError`` if pygame is not installed.
        """
        if not _HAS_PYGAME:
            raise RuntimeError("pygame is required for get_ambient_overlay()")
        t = max(0.0, min(time, 0.9999))
        alpha = _interp_alpha(_ALPHA_KEYFRAMES, t)
        overlay = pygame.Surface((width, height), pygame.SRCALPHA)
        overlay.fill((0, 0, 30, alpha))
        return overlay
