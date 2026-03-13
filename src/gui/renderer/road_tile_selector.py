from __future__ import annotations


class RoadTileSelector:
    """
    Given the 4-neighbour bitmask (N, E, S, W), returns the correct road sprite ID.

    Uses a 16-entry lookup table covering all combinations of cardinal
    neighbours so that road segments auto-snap to the correct visual variant
    (straight, bend, T-junction, intersection, dead-end, or isolated dot).
    """

    #: Lookup table: (N, E, S, W) → sprite_id
    _TABLE: dict[tuple[bool, bool, bool, bool], str] = {
        (False, False, False, False): "road_dot",
        (True,  False, False, False): "road_end_n",
        (False, True,  False, False): "road_end_e",
        (False, False, True,  False): "road_end_s",
        (False, False, False, True):  "road_end_w",
        (True,  True,  False, False): "road_bend_ne",
        (True,  False, True,  False): "road_v",
        (True,  False, False, True):  "road_bend_nw",
        (False, True,  True,  False): "road_bend_se",
        (False, True,  False, True):  "road_h",
        (False, False, True,  True):  "road_bend_sw",
        (True,  True,  True,  False): "road_t_nes",
        (True,  True,  False, True):  "road_t_new",
        (True,  False, True,  True):  "road_t_nsw",
        (False, True,  True,  True):  "road_t_esw",
        (True,  True,  True,  True):  "road_cross",
    }

    def get_sprite_id(self, n: bool, e: bool, s: bool, w: bool) -> str:
        """Return the sprite ID for the given neighbour bitmask."""
        return self._TABLE[(bool(n), bool(e), bool(s), bool(w))]
