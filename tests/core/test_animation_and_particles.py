"""
Tests for AnimationController (Phase 5A) and ParticleSystem (Phase 5C).

Both modules are pure Python (no pygame) so these tests run in headless CI
without a display.  The pygame-dependent draw() path is guarded by the
standard _HAS_PYGAME pattern used elsewhere in the test suite.
"""
from __future__ import annotations

import random
import unittest

try:
    import pygame
    _HAS_PYGAME = True
except ImportError:
    _HAS_PYGAME = False

from src.gui.renderer.animation_controller import AnimationController
from src.gui.renderer.particle_system import ParticleSystem, _PARTICLE_LIFETIME_MS


# ---------------------------------------------------------------------------
# AnimationController tests
# ---------------------------------------------------------------------------

class TestAnimationControllerRegister(unittest.TestCase):
    """Registration validation."""

    def test_register_valid_sprite(self) -> None:
        ac = AnimationController()
        ac.register("water", 4, fps=8.0)
        # After registering and no tick: always frame 0
        self.assertEqual(ac.get_frame("water"), 0)

    def test_register_rejects_zero_frames(self) -> None:
        ac = AnimationController()
        with self.assertRaises(ValueError):
            ac.register("bad", 0)

    def test_register_rejects_negative_fps(self) -> None:
        ac = AnimationController()
        with self.assertRaises(ValueError):
            ac.register("bad", 4, fps=-1.0)

    def test_unregistered_sprite_returns_zero(self) -> None:
        ac = AnimationController()
        self.assertEqual(ac.get_frame("nonexistent"), 0)


class TestAnimationControllerTick(unittest.TestCase):
    """Frame advancement logic."""

    def test_no_tick_stays_on_frame_zero(self) -> None:
        ac = AnimationController()
        ac.register("sprite", 4, fps=8.0)
        self.assertEqual(ac.get_frame("sprite"), 0)

    def test_one_full_interval_advances_one_frame(self) -> None:
        """Exactly one frame duration should advance to frame 1."""
        ac = AnimationController()
        ac.register("sprite", 4, fps=8.0)
        ms_per_frame = 1000.0 / 8.0  # 125 ms
        ac.tick(ms_per_frame)
        self.assertEqual(ac.get_frame("sprite"), 1)

    def test_two_full_intervals_advance_two_frames(self) -> None:
        ac = AnimationController()
        ac.register("sprite", 4, fps=8.0)
        ms_per_frame = 1000.0 / 8.0
        ac.tick(ms_per_frame * 2)
        self.assertEqual(ac.get_frame("sprite"), 2)

    def test_frames_wrap_around(self) -> None:
        """After the last frame the counter wraps back to 0."""
        ac = AnimationController()
        ac.register("sprite", 4, fps=8.0)
        ms_per_frame = 1000.0 / 8.0
        # 4 intervals → back to 0
        ac.tick(ms_per_frame * 4)
        self.assertEqual(ac.get_frame("sprite"), 0)

    def test_frames_wrap_multiple_times(self) -> None:
        ac = AnimationController()
        ac.register("sprite", 4, fps=8.0)
        ms_per_frame = 1000.0 / 8.0
        # 9 intervals → frame 1 (9 mod 4 = 1)
        ac.tick(ms_per_frame * 9)
        self.assertEqual(ac.get_frame("sprite"), 1)

    def test_partial_interval_does_not_advance(self) -> None:
        ac = AnimationController()
        ac.register("sprite", 4, fps=8.0)
        ms_per_frame = 1000.0 / 8.0
        ac.tick(ms_per_frame * 0.5)
        self.assertEqual(ac.get_frame("sprite"), 0)

    def test_multiple_sprites_advance_independently(self) -> None:
        ac = AnimationController()
        ac.register("fast", 4, fps=16.0)
        ac.register("slow", 4, fps=4.0)
        # Tick 250 ms: fast (62.5ms/frame) advances 4 frames→0; slow (250ms/frame) advances 1
        ac.tick(250.0)
        self.assertEqual(ac.get_frame("slow"), 1)

    def test_accumulated_partial_ticks_eventually_advance(self) -> None:
        ac = AnimationController()
        ac.register("sprite", 4, fps=8.0)
        ms_per_frame = 1000.0 / 8.0  # 125 ms
        for _ in range(5):
            ac.tick(ms_per_frame / 5)  # 25 ms each
        # 5 × 25 = 125 ms → should have advanced to frame 1
        self.assertEqual(ac.get_frame("sprite"), 1)


# ---------------------------------------------------------------------------
# ParticleSystem tests
# ---------------------------------------------------------------------------

class TestParticleSystemUpdate(unittest.TestCase):
    """Pure-Python update logic tests."""

    def test_update_advances_age(self) -> None:
        ps = ParticleSystem(rng=random.Random(0))
        ps.emit_at_screen(0, 0, 100, 100, elapsed_ms=200.0)
        initial_count = len(ps.particles)
        self.assertGreater(initial_count, 0)
        ps.update(16.0)
        for p in ps.particles:
            self.assertGreater(p.age_ms, 0.0)

    def test_particles_rise_upward(self) -> None:
        """Vertical velocity must be negative (screen-up direction)."""
        ps = ParticleSystem(rng=random.Random(0))
        ps.emit_at_screen(0, 0, 100, 100, elapsed_ms=200.0)
        for p in ps.particles:
            self.assertLess(p.vel[1], 0.0)

    def test_particles_fade_over_lifetime(self) -> None:
        ps = ParticleSystem(rng=random.Random(0))
        ps.emit_at_screen(0, 0, 100, 100, elapsed_ms=200.0)
        ps.update(_PARTICLE_LIFETIME_MS)
        # All particles should be gone after one full lifetime.
        self.assertEqual(len(ps.particles), 0)

    def test_expired_particles_are_removed(self) -> None:
        ps = ParticleSystem(rng=random.Random(0))
        ps.emit_at_screen(0, 0, 100, 100, elapsed_ms=200.0)
        initial = len(ps.particles)
        self.assertGreater(initial, 0)
        # Advance well past lifetime
        ps.update(_PARTICLE_LIFETIME_MS * 2)
        self.assertEqual(len(ps.particles), 0)

    def test_rate_limiting_prevents_spam(self) -> None:
        """Second immediate emit (elapsed_ms=0) should be rate-limited."""
        ps = ParticleSystem(rng=random.Random(0))
        # First call with enough elapsed to pass cooldown
        ps.emit_at_screen(0, 0, 100, 100, elapsed_ms=200.0)
        count_after_first = len(ps.particles)
        # Second call with 0 elapsed — cooldown not satisfied
        ps.emit_at_screen(0, 0, 100, 100, elapsed_ms=0.0)
        self.assertEqual(len(ps.particles), count_after_first)

    def test_different_tiles_are_independent(self) -> None:
        ps = ParticleSystem(rng=random.Random(0))
        ps.emit_at_screen(0, 0, 100, 100, elapsed_ms=200.0)
        count_after_first = len(ps.particles)
        # Different tile — its own cooldown, should emit
        ps.emit_at_screen(1, 1, 200, 200, elapsed_ms=200.0)
        self.assertGreater(len(ps.particles), count_after_first)

    def test_alpha_decreases_with_age(self) -> None:
        ps = ParticleSystem(rng=random.Random(0))
        ps.emit_at_screen(0, 0, 100, 100, elapsed_ms=200.0)
        initial_alphas = [p.alpha for p in ps.particles]
        ps.update(300.0)
        later_alphas = [p.alpha for p in ps.particles]
        for before, after in zip(initial_alphas, later_alphas):
            self.assertLessEqual(after, before)

    def test_particles_property_returns_copy(self) -> None:
        ps = ParticleSystem(rng=random.Random(0))
        ps.emit_at_screen(0, 0, 100, 100, elapsed_ms=200.0)
        snapshot = ps.particles
        # Modifying the returned list should not change the internal state
        snapshot.clear()
        self.assertGreater(len(ps.particles), 0)


if __name__ == "__main__":
    unittest.main()
