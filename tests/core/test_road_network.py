"""
Tests for RoadNetwork (4A) and RoadTileSelector (4B).

Follows the same pattern as the rest of the test suite:
  - from __future__ import annotations
  - _HAS_PYGAME guard for any pygame-dependent classes
  - Pygame-free classes tested unconditionally
"""
from __future__ import annotations

import unittest

try:
    import pygame  # noqa: F401
    _HAS_PYGAME = True
except ImportError:
    _HAS_PYGAME = False

from src.city.road_network import RoadNetwork, RoadSegment
from src.gui.renderer.road_tile_selector import RoadTileSelector


# ---------------------------------------------------------------------------
# RoadSegment enum
# ---------------------------------------------------------------------------

class TestRoadSegment(unittest.TestCase):

    def test_none_and_road_members_exist(self) -> None:
        self.assertIn("NONE", RoadSegment.__members__)
        self.assertIn("ROAD", RoadSegment.__members__)

    def test_values_are_distinct(self) -> None:
        self.assertNotEqual(RoadSegment.NONE, RoadSegment.ROAD)


# ---------------------------------------------------------------------------
# RoadNetwork — placement and querying
# ---------------------------------------------------------------------------

class TestRoadNetworkPlacement(unittest.TestCase):

    def setUp(self) -> None:
        self.net = RoadNetwork(cols=10, rows=10)

    def test_empty_network_has_no_roads(self) -> None:
        self.assertFalse(self.net.is_road(0, 0))
        self.assertFalse(self.net.is_road(5, 5))

    def test_place_road_marks_cell(self) -> None:
        self.net.place_road(3, 4)
        self.assertTrue(self.net.is_road(3, 4))

    def test_place_road_does_not_affect_other_cells(self) -> None:
        self.net.place_road(3, 4)
        self.assertFalse(self.net.is_road(3, 3))
        self.assertFalse(self.net.is_road(4, 4))

    def test_remove_road_clears_cell(self) -> None:
        self.net.place_road(2, 2)
        self.net.remove_road(2, 2)
        self.assertFalse(self.net.is_road(2, 2))

    def test_remove_road_on_empty_cell_is_idempotent(self) -> None:
        self.net.remove_road(0, 0)  # no-op; must not raise
        self.assertFalse(self.net.is_road(0, 0))

    def test_multiple_roads_independent(self) -> None:
        self.net.place_road(1, 1)
        self.net.place_road(1, 2)
        self.net.place_road(1, 3)
        self.assertTrue(self.net.is_road(1, 1))
        self.assertTrue(self.net.is_road(1, 2))
        self.assertTrue(self.net.is_road(1, 3))
        self.assertFalse(self.net.is_road(2, 2))

    def test_place_road_is_idempotent(self) -> None:
        self.net.place_road(5, 5)
        self.net.place_road(5, 5)
        self.assertTrue(self.net.is_road(5, 5))


# ---------------------------------------------------------------------------
# RoadNetwork — get_neighbours
# ---------------------------------------------------------------------------

class TestRoadNetworkNeighbours(unittest.TestCase):

    def setUp(self) -> None:
        self.net = RoadNetwork(cols=10, rows=10)

    def test_no_neighbours_when_empty(self) -> None:
        self.net.place_road(5, 5)
        nb = self.net.get_neighbours(5, 5)
        self.assertEqual(nb, {"N": False, "E": False, "S": False, "W": False})

    def test_north_neighbour_detected(self) -> None:
        self.net.place_road(5, 5)
        self.net.place_road(5, 4)  # row-1 = North
        nb = self.net.get_neighbours(5, 5)
        self.assertTrue(nb["N"])
        self.assertFalse(nb["S"])
        self.assertFalse(nb["E"])
        self.assertFalse(nb["W"])

    def test_south_neighbour_detected(self) -> None:
        self.net.place_road(5, 5)
        self.net.place_road(5, 6)  # row+1 = South
        nb = self.net.get_neighbours(5, 5)
        self.assertTrue(nb["S"])
        self.assertFalse(nb["N"])

    def test_east_neighbour_detected(self) -> None:
        self.net.place_road(5, 5)
        self.net.place_road(6, 5)  # col+1 = East
        nb = self.net.get_neighbours(5, 5)
        self.assertTrue(nb["E"])
        self.assertFalse(nb["W"])

    def test_west_neighbour_detected(self) -> None:
        self.net.place_road(5, 5)
        self.net.place_road(4, 5)  # col-1 = West
        nb = self.net.get_neighbours(5, 5)
        self.assertTrue(nb["W"])
        self.assertFalse(nb["E"])

    def test_all_four_neighbours(self) -> None:
        self.net.place_road(5, 5)
        self.net.place_road(5, 4)
        self.net.place_road(6, 5)
        self.net.place_road(5, 6)
        self.net.place_road(4, 5)
        nb = self.net.get_neighbours(5, 5)
        self.assertTrue(all(nb.values()))

    def test_neighbour_keys_present(self) -> None:
        nb = self.net.get_neighbours(0, 0)
        self.assertIn("N", nb)
        self.assertIn("E", nb)
        self.assertIn("S", nb)
        self.assertIn("W", nb)

    def test_removing_neighbour_updates_neighbours(self) -> None:
        self.net.place_road(5, 5)
        self.net.place_road(5, 4)
        self.net.remove_road(5, 4)
        nb = self.net.get_neighbours(5, 5)
        self.assertFalse(nb["N"])


# ---------------------------------------------------------------------------
# RoadTileSelector — 16-entry lookup table
# ---------------------------------------------------------------------------

class TestRoadTileSelector(unittest.TestCase):

    def setUp(self) -> None:
        self.sel = RoadTileSelector()

    def test_all_16_combinations_return_a_string(self) -> None:
        for n in (False, True):
            for e in (False, True):
                for s in (False, True):
                    for w in (False, True):
                        result = self.sel.get_sprite_id(n, e, s, w)
                        self.assertIsInstance(result, str)
                        self.assertGreater(len(result), 0)

    def test_isolated_road_returns_dot(self) -> None:
        self.assertEqual(self.sel.get_sprite_id(False, False, False, False), "road_dot")

    def test_ew_straight_returns_road_h(self) -> None:
        self.assertEqual(self.sel.get_sprite_id(False, True, False, True), "road_h")

    def test_ns_straight_returns_road_v(self) -> None:
        self.assertEqual(self.sel.get_sprite_id(True, False, True, False), "road_v")

    def test_all_neighbours_returns_cross(self) -> None:
        self.assertEqual(self.sel.get_sprite_id(True, True, True, True), "road_cross")

    def test_north_only_returns_dead_end(self) -> None:
        self.assertEqual(self.sel.get_sprite_id(True, False, False, False), "road_end_n")

    def test_east_only_returns_dead_end(self) -> None:
        self.assertEqual(self.sel.get_sprite_id(False, True, False, False), "road_end_e")

    def test_south_only_returns_dead_end(self) -> None:
        self.assertEqual(self.sel.get_sprite_id(False, False, True, False), "road_end_s")

    def test_west_only_returns_dead_end(self) -> None:
        self.assertEqual(self.sel.get_sprite_id(False, False, False, True), "road_end_w")

    def test_ne_bend(self) -> None:
        self.assertEqual(self.sel.get_sprite_id(True, True, False, False), "road_bend_ne")

    def test_nw_bend(self) -> None:
        self.assertEqual(self.sel.get_sprite_id(True, False, False, True), "road_bend_nw")

    def test_se_bend(self) -> None:
        self.assertEqual(self.sel.get_sprite_id(False, True, True, False), "road_bend_se")

    def test_sw_bend(self) -> None:
        self.assertEqual(self.sel.get_sprite_id(False, False, True, True), "road_bend_sw")

    def test_t_junction_nes(self) -> None:
        self.assertEqual(self.sel.get_sprite_id(True, True, True, False), "road_t_nes")

    def test_t_junction_new(self) -> None:
        self.assertEqual(self.sel.get_sprite_id(True, True, False, True), "road_t_new")

    def test_t_junction_nsw(self) -> None:
        self.assertEqual(self.sel.get_sprite_id(True, False, True, True), "road_t_nsw")

    def test_t_junction_esw(self) -> None:
        self.assertEqual(self.sel.get_sprite_id(False, True, True, True), "road_t_esw")

    def test_truthy_values_coerced_correctly(self) -> None:
        # Should work with any truthy/falsy inputs, not just bool
        self.assertEqual(
            self.sel.get_sprite_id(1, 1, 1, 1),  # type: ignore[arg-type]
            "road_cross",
        )
        self.assertEqual(
            self.sel.get_sprite_id(0, 0, 0, 0),  # type: ignore[arg-type]
            "road_dot",
        )

    def test_table_has_exactly_16_entries(self) -> None:
        self.assertEqual(len(self.sel._TABLE), 16)


# ---------------------------------------------------------------------------
# Integration: RoadNetwork + RoadTileSelector round-trip
# ---------------------------------------------------------------------------

class TestRoadNetworkWithSelector(unittest.TestCase):

    def setUp(self) -> None:
        self.net = RoadNetwork(cols=10, rows=10)
        self.sel = RoadTileSelector()

    def _sprite(self, col: int, row: int) -> str:
        nb = self.net.get_neighbours(col, row)
        return self.sel.get_sprite_id(nb["N"], nb["E"], nb["S"], nb["W"])

    def test_single_road_is_dot(self) -> None:
        self.net.place_road(5, 5)
        self.assertEqual(self._sprite(5, 5), "road_dot")

    def test_two_connected_ns_roads_become_straight(self) -> None:
        self.net.place_road(5, 5)
        self.net.place_road(5, 6)
        # (5,5) has S neighbour → road_end_s; (5,6) has N neighbour → road_end_n
        self.assertEqual(self._sprite(5, 5), "road_end_s")
        self.assertEqual(self._sprite(5, 6), "road_end_n")

    def test_three_in_a_row_creates_straight_middle(self) -> None:
        self.net.place_road(5, 4)
        self.net.place_road(5, 5)
        self.net.place_road(5, 6)
        # Middle (5,5) has N and S → straight vertical
        self.assertEqual(self._sprite(5, 5), "road_v")

    def test_remove_road_reverts_neighbour_sprite(self) -> None:
        self.net.place_road(5, 5)
        self.net.place_road(5, 4)
        self.net.place_road(5, 6)
        # Middle = road_v; remove north
        self.net.remove_road(5, 4)
        self.assertEqual(self._sprite(5, 5), "road_end_s")

    def test_cross_intersection(self) -> None:
        for dc, dr in ((0, 0), (1, 0), (-1, 0), (0, 1), (0, -1)):
            self.net.place_road(5 + dc, 5 + dr)
        self.assertEqual(self._sprite(5, 5), "road_cross")


if __name__ == "__main__":
    unittest.main()
