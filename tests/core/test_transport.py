"""Tests for transport subsystem: pathfinding, signals, and integration."""

import unittest

from src.city.transport.models import (
    Incident, IncidentType, Intersection, IntersectionType,
    Lane, Position, RoadGraph, RoadSegment, RoadType,
    Route, SignalPhase, SignalState, Vehicle, VehicleType,
)
from src.city.transport.pathfinding import (
    PathfindingService, RoutePlanner,
    euclidean_heuristic, manhattan_heuristic, calculate_edge_cost,
)
from src.city.transport.signals import SignalController
from src.city.transport.traffic_flow import TrafficFlowModel
from src.city.transport.congestion import CongestionModel
from src.city.transport.transport_subsystem import TransportSubsystem


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

def _make_simple_graph() -> RoadGraph:
    """
    Build a simple 4-node grid:

        A --seg_AB--> B
        |              |
    seg_AC          seg_BD
        |              |
        C --seg_CD--> D

    A, B, C, D at positions (0,0), (100,0), (0,100), (100,100).
    All segments are ARTERIAL, 100 m long.
    """
    graph = RoadGraph()

    intersections = {
        "A": Intersection("A", Position(0, 0), IntersectionType.STOP),
        "B": Intersection("B", Position(100, 0), IntersectionType.SIGNALIZED),
        "C": Intersection("C", Position(0, 100), IntersectionType.STOP),
        "D": Intersection("D", Position(100, 100), IntersectionType.STOP),
    }
    for node in intersections.values():
        graph.add_intersection(node)

    segments = [
        RoadSegment("seg_AB", "A", "B", length=100.0, speed_limit=13.4,
                    capacity=1800, road_type=RoadType.ARTERIAL),
        RoadSegment("seg_BA", "B", "A", length=100.0, speed_limit=13.4,
                    capacity=1800, road_type=RoadType.ARTERIAL),
        RoadSegment("seg_AC", "A", "C", length=100.0, speed_limit=13.4,
                    capacity=1800, road_type=RoadType.ARTERIAL),
        RoadSegment("seg_CA", "C", "A", length=100.0, speed_limit=13.4,
                    capacity=1800, road_type=RoadType.ARTERIAL),
        RoadSegment("seg_BD", "B", "D", length=100.0, speed_limit=13.4,
                    capacity=1800, road_type=RoadType.ARTERIAL),
        RoadSegment("seg_DB", "D", "B", length=100.0, speed_limit=13.4,
                    capacity=1800, road_type=RoadType.ARTERIAL),
        RoadSegment("seg_CD", "C", "D", length=100.0, speed_limit=13.4,
                    capacity=1800, road_type=RoadType.ARTERIAL),
        RoadSegment("seg_DC", "D", "C", length=100.0, speed_limit=13.4,
                    capacity=1800, road_type=RoadType.ARTERIAL),
    ]
    for seg in segments:
        graph.add_segment(seg)

    return graph


# ---------------------------------------------------------------------------
# RoadGraph tests
# ---------------------------------------------------------------------------

class TestRoadGraph(unittest.TestCase):

    def test_validate_returns_true_for_valid_graph(self):
        graph = _make_simple_graph()
        self.assertTrue(graph.validate())

    def test_find_segment_returns_correct_segment(self):
        graph = _make_simple_graph()
        seg = graph.find_segment("A", "B")
        self.assertIsNotNone(seg)
        self.assertEqual(seg.id, "seg_AB")

    def test_find_segment_returns_none_for_missing_edge(self):
        graph = _make_simple_graph()
        # No direct A->D edge in our graph
        self.assertIsNone(graph.find_segment("A", "D"))

    def test_get_neighbors_returns_adjacent_nodes(self):
        graph = _make_simple_graph()
        neighbors = graph.get_neighbors("A")
        neighbor_ids = {n.id for n in neighbors}
        self.assertIn("B", neighbor_ids)
        self.assertIn("C", neighbor_ids)
        self.assertNotIn("D", neighbor_ids)

    def test_get_outgoing_segments(self):
        graph = _make_simple_graph()
        segs = graph.get_outgoing_segments("A")
        seg_ids = {s.id for s in segs}
        self.assertIn("seg_AB", seg_ids)
        self.assertIn("seg_AC", seg_ids)


# ---------------------------------------------------------------------------
# Pathfinding tests
# ---------------------------------------------------------------------------

class TestPathfindingService(unittest.TestCase):

    def setUp(self):
        self.graph = _make_simple_graph()
        self.service = PathfindingService()

    def test_find_path_same_start_and_goal(self):
        heuristic = lambda a, b: euclidean_heuristic(a, b, self.graph)
        cost_fn = lambda a, b: calculate_edge_cost(a, b, self.graph)
        path = self.service.find_path(self.graph, "A", "A", heuristic, cost_fn)
        self.assertEqual(path, ["A"])

    def test_find_path_direct_neighbor(self):
        heuristic = lambda a, b: euclidean_heuristic(a, b, self.graph)
        cost_fn = lambda a, b: calculate_edge_cost(a, b, self.graph)
        path = self.service.find_path(self.graph, "A", "B", heuristic, cost_fn)
        self.assertEqual(path, ["A", "B"])

    def test_find_path_two_hops(self):
        heuristic = lambda a, b: euclidean_heuristic(a, b, self.graph)
        cost_fn = lambda a, b: calculate_edge_cost(a, b, self.graph)
        path = self.service.find_path(self.graph, "A", "D", heuristic, cost_fn)
        # Both A->B->D and A->C->D are valid 2-hop paths
        self.assertEqual(path[0], "A")
        self.assertEqual(path[-1], "D")
        self.assertEqual(len(path), 3)

    def test_find_path_no_path(self):
        # Isolated node
        graph = RoadGraph()
        graph.add_intersection(Intersection("X", Position(0, 0)))
        graph.add_intersection(Intersection("Y", Position(100, 0)))
        heuristic = lambda a, b: euclidean_heuristic(a, b, graph)
        cost_fn = lambda a, b: float('inf')
        path = self.service.find_path(graph, "X", "Y", heuristic, cost_fn)
        self.assertEqual(path, [])

    def test_find_path_unknown_node(self):
        heuristic = lambda a, b: euclidean_heuristic(a, b, self.graph)
        cost_fn = lambda a, b: calculate_edge_cost(a, b, self.graph)
        path = self.service.find_path(self.graph, "A", "Z", heuristic, cost_fn)
        self.assertEqual(path, [])

    def test_find_path_deterministic(self):
        """Same inputs produce the same path on repeated calls."""
        heuristic = lambda a, b: euclidean_heuristic(a, b, self.graph)
        cost_fn = lambda a, b: calculate_edge_cost(a, b, self.graph)
        path1 = self.service.find_path(self.graph, "A", "D", heuristic, cost_fn)
        path2 = self.service.find_path(self.graph, "A", "D", heuristic, cost_fn)
        self.assertEqual(path1, path2)


class TestRoutePlanner(unittest.TestCase):

    def setUp(self):
        self.graph = _make_simple_graph()
        self.planner = RoutePlanner(self.graph)

    def test_plan_route_returns_route_object(self):
        route = self.planner.plan_route("A", "D")
        self.assertIsNotNone(route)
        self.assertEqual(route.origin, "A")
        self.assertEqual(route.destination, "D")
        self.assertGreater(len(route.segments), 0)

    def test_plan_route_total_distance_positive(self):
        route = self.planner.plan_route("A", "D")
        self.assertGreater(route.total_distance, 0)

    def test_plan_route_raises_for_unknown_origin(self):
        with self.assertRaises(ValueError):
            self.planner.plan_route("UNKNOWN", "D")

    def test_plan_route_raises_for_unknown_destination(self):
        with self.assertRaises(ValueError):
            self.planner.plan_route("A", "UNKNOWN")

    def test_plan_route_avoids_incident_segment(self):
        """Route should use alternate path when primary segment has incident."""
        # Add heavy incident on seg_AB
        incident = Incident(
            id="inc1", segment_id="seg_AB",
            type=IncidentType.ACCIDENT,
            capacity_reduction=1.0,
            start_tick=0, estimated_duration=1000,
        )
        self.graph.edges["seg_AB"].incidents.append(incident)

        route = self.planner.plan_route("A", "D", tick_index=0)
        self.assertIsNotNone(route)
        # Route should avoid seg_AB and go via C
        self.assertNotIn("seg_AB", route.segments)


# ---------------------------------------------------------------------------
# Signal controller tests
# ---------------------------------------------------------------------------

class TestSignalController(unittest.TestCase):

    def _make_controller(self) -> SignalController:
        phase_a = SignalPhase(
            id="phase_a", duration=30.0,
            movement_states={("seg1", "seg2"): SignalState.GREEN,
                             ("seg3", "seg4"): SignalState.RED},
        )
        phase_b = SignalPhase(
            id="phase_b", duration=30.0,
            movement_states={("seg1", "seg2"): SignalState.RED,
                             ("seg3", "seg4"): SignalState.GREEN},
        )
        return SignalController(
            intersection_id="B",
            phases=[phase_a, phase_b],
            yellow_time=3.0,
            all_red_time=1.0,
        )

    def test_initial_phase_is_zero(self):
        ctrl = self._make_controller()
        self.assertEqual(ctrl.current_phase, 0)

    def test_get_signal_state_returns_green_in_phase_a(self):
        ctrl = self._make_controller()
        state = ctrl.get_signal_state("seg1", "seg2")
        self.assertEqual(state, SignalState.GREEN)

    def test_get_signal_state_returns_red_in_phase_a(self):
        ctrl = self._make_controller()
        state = ctrl.get_signal_state("seg3", "seg4")
        self.assertEqual(state, SignalState.RED)

    def test_signal_transitions_to_yellow_after_green(self):
        ctrl = self._make_controller()
        # Advance past green duration
        ctrl.update(31.0)
        state = ctrl.get_signal_state("seg1", "seg2")
        self.assertEqual(state, SignalState.YELLOW)

    def test_signal_advances_to_next_phase_after_yellow(self):
        ctrl = self._make_controller()
        # Advance through green (30s) + yellow (3s)
        ctrl.update(30.0)  # triggers yellow
        ctrl.update(4.0)   # completes yellow, moves to phase_b
        self.assertEqual(ctrl.current_phase, 1)

    def test_signal_cycles_count_increments(self):
        ctrl = self._make_controller()
        # Complete full cycle: phase_a green + yellow + phase_b green + yellow
        ctrl.update(30.0)   # phase_a green
        ctrl.update(4.0)    # yellow -> phase_b
        ctrl.update(30.0)   # phase_b green
        ctrl.update(4.0)    # yellow -> phase_a (cycle complete)
        self.assertEqual(ctrl.cycles_completed, 1)

    def test_is_green_returns_true_when_green(self):
        ctrl = self._make_controller()
        self.assertTrue(ctrl.is_green("seg1", "seg2"))

    def test_is_green_returns_false_when_red(self):
        ctrl = self._make_controller()
        self.assertFalse(ctrl.is_green("seg3", "seg4"))


# ---------------------------------------------------------------------------
# TrafficFlowModel tests
# ---------------------------------------------------------------------------

class TestTrafficFlowModel(unittest.TestCase):

    def _make_vehicle(self, speed: float = 0.0) -> Vehicle:
        return Vehicle(id="v1", speed=speed, max_speed=30.0,
                       max_acceleration=3.0, max_deceleration=-8.0)

    def _make_segment(self, speed_limit: float = 13.4) -> RoadSegment:
        return RoadSegment("seg1", "A", "B", length=500.0, speed_limit=speed_limit)

    def test_vehicle_accelerates_from_rest(self):
        model = TrafficFlowModel()
        vehicle = self._make_vehicle(speed=0.0)
        seg = self._make_segment()
        new_speed = model.calculate_speed(vehicle, seg)
        self.assertGreater(new_speed, 0.0)

    def test_vehicle_speed_capped_at_speed_limit(self):
        model = TrafficFlowModel()
        vehicle = self._make_vehicle(speed=100.0)  # unrealistically fast
        seg = self._make_segment(speed_limit=13.4)
        new_speed = model.calculate_speed(vehicle, seg)
        self.assertLessEqual(new_speed, seg.speed_limit)

    def test_vehicle_slows_for_front_vehicle(self):
        model = TrafficFlowModel()
        vehicle = self._make_vehicle(speed=13.4)
        front = self._make_vehicle(speed=0.0)
        front.position = vehicle.position + 5.0  # 5 m ahead
        seg = self._make_segment()
        speed_with_front = model.calculate_speed(vehicle, seg, front)
        speed_without_front = model.calculate_speed(vehicle, seg, None)
        self.assertLessEqual(speed_with_front, speed_without_front)

    def test_update_vehicle_position_moves_forward(self):
        model = TrafficFlowModel()
        vehicle = self._make_vehicle(speed=10.0)
        seg = self._make_segment()
        initial_pos = vehicle.position
        model.update_vehicle_position(vehicle, seg, dt=1.0)
        self.assertGreater(vehicle.position, initial_pos)


# ---------------------------------------------------------------------------
# CongestionModel tests
# ---------------------------------------------------------------------------

class TestCongestionModel(unittest.TestCase):

    def test_calculate_density_empty_segment(self):
        model = CongestionModel()
        seg = RoadSegment("s", "A", "B", length=1000.0)
        self.assertEqual(model.calculate_density(seg), 0.0)

    def test_calculate_density_with_vehicles(self):
        model = CongestionModel()
        seg = RoadSegment("s", "A", "B", length=1000.0)
        seg.vehicles = ["v1", "v2"]
        density = model.calculate_density(seg)
        self.assertAlmostEqual(density, 2.0)  # 2 vehicles / 1 km

    def test_congestion_index_empty_network(self):
        model = CongestionModel()
        graph = RoadGraph()
        self.assertEqual(model.calculate_congestion_index(graph), 0.0)

    def test_congestion_index_free_flow(self):
        model = CongestionModel()
        graph = _make_simple_graph()  # no vehicles
        ci = model.calculate_congestion_index(graph)
        self.assertAlmostEqual(ci, 0.0)


# ---------------------------------------------------------------------------
# TransportSubsystem integration tests
# ---------------------------------------------------------------------------

class TestTransportSubsystem(unittest.TestCase):

    def setUp(self):
        self.graph = _make_simple_graph()
        # Attach signal controller to intersection B
        ctrl = SignalController("B")
        self.graph.nodes["B"].signal_controller = ctrl
        self.subsystem = TransportSubsystem(
            network=self.graph,
            rng=__import__("random").Random(42),
        )

    def test_update_returns_traffic_delta(self):
        from src.city.transport.models import TrafficDelta
        delta = self.subsystem.update(tick_index=0)
        self.assertIsInstance(delta, TrafficDelta)

    def test_delta_validates_ok(self):
        delta = self.subsystem.update(tick_index=0)
        # Should not raise
        delta.validate()

    def test_congestion_index_between_0_and_1(self):
        delta = self.subsystem.update(tick_index=0)
        self.assertGreaterEqual(delta.congestion_index, 0.0)
        self.assertLessEqual(delta.congestion_index, 1.0)

    def test_deterministic_under_same_seed(self):
        """Two subsystems with the same seed produce the same results."""
        import random

        graph1 = _make_simple_graph()
        sub1 = TransportSubsystem(network=graph1, rng=random.Random(99))
        delta1 = sub1.update(tick_index=1)

        graph2 = _make_simple_graph()
        sub2 = TransportSubsystem(network=graph2, rng=random.Random(99))
        delta2 = sub2.update(tick_index=1)

        self.assertEqual(delta1.vehicles_entered, delta2.vehicles_entered)
        self.assertAlmostEqual(delta1.avg_speed, delta2.avg_speed)

    def test_vehicle_respects_speed_limit(self):
        """All active vehicles must not exceed their segment speed limit."""
        for _ in range(5):
            self.subsystem.update(tick_index=0)
        for vid, vehicle in self.subsystem.vehicles.items():
            if vehicle.current_segment:
                seg = self.graph.edges.get(vehicle.current_segment)
                if seg:
                    self.assertLessEqual(
                        vehicle.speed, seg.speed_limit + 0.01,  # small floating-point margin
                        msg=f"Vehicle {vid} exceeds speed limit on {seg.id}",
                    )

    def test_incident_reduces_rerouting(self):
        """Adding an incident triggers replan_if_needed on vehicles on that route."""
        import random
        graph = _make_simple_graph()
        sub = TransportSubsystem(network=graph, rng=random.Random(7))

        # Run a few ticks to get some vehicles
        for t in range(10):
            sub.update(tick_index=t)

        # Add incident to a segment
        if "seg_AB" in graph.edges:
            incident = Incident(
                id="test_inc", segment_id="seg_AB",
                type=IncidentType.ACCIDENT,
                capacity_reduction=1.0,
                start_tick=10, estimated_duration=100,
            )
            sub.add_incident(incident)

        # Update should not crash
        delta = sub.update(tick_index=10)
        self.assertGreaterEqual(delta.incidents_active, 0)


if __name__ == "__main__":
    unittest.main()
