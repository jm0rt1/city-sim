"""
Tests for Phase 6 Rich UI components.

Covers the pygame-free parts:
  - EventLog.append() / entries / toggle visibility
  - Minimap.contains() and handle_click() pure logic
  - Sim.budget_history ring-buffer
"""
from __future__ import annotations

import unittest

from src.gui.renderer.event_log import (
    EventLog,
    LogEntry,
    SEVERITY_INFO,
    SEVERITY_WARNING,
    SEVERITY_NEUTRAL,
    _MAX_ENTRIES,
)
from src.gui.renderer.minimap import Minimap
from src.gui.renderer.camera_controller import CameraController


# ---------------------------------------------------------------------------
# EventLog
# ---------------------------------------------------------------------------

class TestEventLogAppend(unittest.TestCase):
    """EventLog.append() stores entries correctly."""

    def setUp(self) -> None:
        self.log = EventLog()

    def test_append_single_entry(self) -> None:
        self.log.append(1, "hello")
        self.assertEqual(len(self.log.entries), 1)

    def test_entry_fields(self) -> None:
        self.log.append(5, "test message", SEVERITY_WARNING)
        entry = self.log.entries[0]
        self.assertEqual(entry.tick, 5)
        self.assertEqual(entry.message, "test message")
        self.assertEqual(entry.severity, SEVERITY_WARNING)

    def test_default_severity_is_info(self) -> None:
        self.log.append(0, "info msg")
        self.assertEqual(self.log.entries[0].severity, SEVERITY_INFO)

    def test_neutral_severity_stored(self) -> None:
        self.log.append(0, "neutral", SEVERITY_NEUTRAL)
        self.assertEqual(self.log.entries[0].severity, SEVERITY_NEUTRAL)

    def test_multiple_entries_ordered(self) -> None:
        for i in range(5):
            self.log.append(i, f"msg{i}")
        entries = self.log.entries
        self.assertEqual(len(entries), 5)
        self.assertEqual(entries[0].tick, 0)
        self.assertEqual(entries[4].tick, 4)

    def test_entries_returns_list_copy(self) -> None:
        self.log.append(1, "a")
        snapshot = self.log.entries
        # Appending more should not affect the snapshot.
        self.log.append(2, "b")
        self.assertEqual(len(snapshot), 1)

    def test_ring_buffer_max_capacity(self) -> None:
        for i in range(_MAX_ENTRIES + 10):
            self.log.append(i, f"msg{i}")
        self.assertEqual(len(self.log.entries), _MAX_ENTRIES)

    def test_ring_buffer_oldest_dropped(self) -> None:
        for i in range(_MAX_ENTRIES + 5):
            self.log.append(i, f"msg{i}")
        entries = self.log.entries
        # Oldest should be entry with tick=5 (first 5 were dropped).
        self.assertEqual(entries[0].tick, 5)

    def test_empty_entries_on_new_log(self) -> None:
        self.assertEqual(self.log.entries, [])


# ---------------------------------------------------------------------------
# Minimap pure logic
# ---------------------------------------------------------------------------

class TestMinimapContains(unittest.TestCase):

    def setUp(self) -> None:
        # grid_area_w=800, win_h=600 → minimap at (800-80-8, 600-80-8) = (712, 512)
        self.mm = Minimap(grid_area_w=800, win_h=600)

    def test_contains_inside(self) -> None:
        x, y, w, h = self.mm.rect
        self.assertTrue(self.mm.contains((x + w // 2, y + h // 2)))

    def test_contains_top_left_corner(self) -> None:
        x, y, _, _ = self.mm.rect
        self.assertTrue(self.mm.contains((x, y)))

    def test_not_contains_outside_right(self) -> None:
        x, y, w, h = self.mm.rect
        self.assertFalse(self.mm.contains((x + w, y + h // 2)))

    def test_not_contains_outside_bottom(self) -> None:
        x, y, w, h = self.mm.rect
        self.assertFalse(self.mm.contains((x + w // 2, y + h)))

    def test_not_contains_above(self) -> None:
        x, y, _, _ = self.mm.rect
        self.assertFalse(self.mm.contains((x + 5, y - 1)))

    def test_not_contains_left(self) -> None:
        x, y, _, h = self.mm.rect
        self.assertFalse(self.mm.contains((x - 1, y + h // 2)))


class TestMinimapHandleClick(unittest.TestCase):

    def setUp(self) -> None:
        self.mm = Minimap(grid_area_w=800, win_h=600)
        self.camera = CameraController(origin_x=400, origin_y=150)

    def test_click_outside_returns_false(self) -> None:
        result = self.mm.handle_click((0, 0), self.camera, 32, 32, 64, 32)
        self.assertFalse(result)

    def test_click_inside_returns_true(self) -> None:
        x, y, w, h = self.mm.rect
        result = self.mm.handle_click((x + w // 2, y + h // 2), self.camera, 32, 32, 64, 32)
        self.assertTrue(result)

    def test_click_inside_modifies_camera_origin(self) -> None:
        x, y, w, h = self.mm.rect
        old_ox = self.camera.origin_x
        old_oy = self.camera.origin_y
        self.mm.handle_click((x + w // 2, y + h // 2), self.camera, 32, 32, 64, 32)
        # Camera origin should have changed (panned to target position).
        changed = (
            self.camera.origin_x != old_ox or self.camera.origin_y != old_oy
        )
        self.assertTrue(changed)

    def test_click_zero_grid_returns_false(self) -> None:
        x, y, _, _ = self.mm.rect
        # cols=0 / rows=0 should guard against division by zero and return False.
        result = self.mm.handle_click((x + 10, y + 10), self.camera, 0, 0, 64, 32)
        self.assertFalse(result)

    def test_camera_zoom_preserved(self) -> None:
        self.camera.zoom_level = 1.5
        x, y, w, h = self.mm.rect
        self.mm.handle_click((x + 10, y + 10), self.camera, 32, 32, 64, 32)
        self.assertAlmostEqual(self.camera.zoom_level, 1.5)


# ---------------------------------------------------------------------------
# Sim budget_history ring-buffer
# ---------------------------------------------------------------------------

class TestSimBudgetHistory(unittest.TestCase):

    def _make_sim(self) -> object:
        from src.city.city import City
        from src.simulation.sim import Sim
        return Sim(city=City(), seed=0, run_id="test")

    def test_initial_budget_history_empty(self) -> None:
        sim = self._make_sim()
        self.assertEqual(sim.budget_history, [])

    def test_advance_day_appends_entry(self) -> None:
        sim = self._make_sim()
        sim.advance_day()
        self.assertEqual(len(sim.budget_history), 1)

    def test_entry_is_three_tuple(self) -> None:
        sim = self._make_sim()
        sim.advance_day()
        entry = sim.budget_history[0]
        self.assertIsInstance(entry, tuple)
        self.assertEqual(len(entry), 3)

    def test_entry_contains_floats(self) -> None:
        sim = self._make_sim()
        sim.advance_day()
        rev, exp, bal = sim.budget_history[0]
        self.assertIsInstance(rev, float)
        self.assertIsInstance(exp, float)
        self.assertIsInstance(bal, float)

    def test_ring_buffer_max_20(self) -> None:
        sim = self._make_sim()
        for _ in range(25):
            sim.advance_day()
        self.assertLessEqual(len(sim.budget_history), 20)

    def test_ring_buffer_exactly_20_after_25_ticks(self) -> None:
        sim = self._make_sim()
        for _ in range(25):
            sim.advance_day()
        self.assertEqual(len(sim.budget_history), 20)

    def test_balance_matches_city_budget(self) -> None:
        sim = self._make_sim()
        sim.advance_day()
        _, _, bal = sim.budget_history[-1]
        self.assertAlmostEqual(bal, float(sim.city_budget.balance))


if __name__ == "__main__":
    unittest.main()
