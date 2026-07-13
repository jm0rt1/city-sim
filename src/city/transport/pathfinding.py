"""A* pathfinding and route planning for the transport subsystem."""

from __future__ import annotations

import heapq
import math
from typing import Callable, Dict, List, Optional

from src.city.transport.models import (
    RoadGraph, RoadSegment, Route, Vehicle, VehicleType,
)


# ---------------------------------------------------------------------------
# Heuristic functions
# ---------------------------------------------------------------------------

def euclidean_heuristic(node_a: str, node_b: str, graph: RoadGraph) -> float:
    """Straight-line distance between two intersections."""
    pos_a = graph.nodes[node_a].position
    pos_b = graph.nodes[node_b].position
    return pos_a.distance_to(pos_b)


def manhattan_heuristic(node_a: str, node_b: str, graph: RoadGraph) -> float:
    """Grid distance (sum of absolute differences in coordinates)."""
    pos_a = graph.nodes[node_a].position
    pos_b = graph.nodes[node_b].position
    return abs(pos_a.x - pos_b.x) + abs(pos_a.y - pos_b.y)


# ---------------------------------------------------------------------------
# Edge cost function
# ---------------------------------------------------------------------------

def calculate_edge_cost(
    from_node: str,
    to_node: str,
    graph: RoadGraph,
    tick_index: int = 0,
) -> float:
    """
    Calculate cost to traverse an edge considering traffic conditions.

    Components: base distance + time cost + congestion penalty + incident penalty.
    """
    segment = graph.find_segment(from_node, to_node)
    if segment is None:
        return float('inf')

    # 1. Base distance
    distance_cost = segment.length

    # 2. Time cost (prefer faster roads)
    speed = segment.avg_speed if segment.avg_speed > 0 else segment.speed_limit
    time_cost = segment.length / speed if speed > 0 else float('inf')

    # 3. Congestion penalty
    congestion_factor = segment.get_congestion_factor()
    congestion_penalty = congestion_factor * segment.length * 0.5

    # 4. Incident penalty
    incident_penalty = 0.0
    for incident in segment.incidents:
        if incident.is_active(tick_index):
            incident_penalty += segment.length * 2.0 * incident.capacity_reduction

    return distance_cost + time_cost * 10 + congestion_penalty + incident_penalty


# ---------------------------------------------------------------------------
# Path reconstruction helper
# ---------------------------------------------------------------------------

def _reconstruct_path(came_from: Dict[str, str], current: str) -> List[str]:
    """Reconstruct node path from A* came_from map."""
    path = [current]
    while current in came_from:
        current = came_from[current]
        path.append(current)
    path.reverse()
    return path


def _nodes_to_segments(node_path: List[str], graph: RoadGraph) -> List[str]:
    """Convert a list of node IDs into a list of segment IDs."""
    segments: List[str] = []
    for i in range(len(node_path) - 1):
        seg = graph.find_segment(node_path[i], node_path[i + 1])
        if seg is None:
            return []
        segments.append(seg.id)
    return segments


# ---------------------------------------------------------------------------
# Core PathfindingService
# ---------------------------------------------------------------------------

class PathfindingService:
    """Core A* pathfinding algorithm implementation."""

    def find_path(
        self,
        graph: RoadGraph,
        start: str,
        goal: str,
        heuristic: Callable[[str, str], float],
        cost_function: Callable[[str, str], float],
    ) -> List[str]:
        """
        A* pathfinding on road graph.

        Returns list of node IDs from start to goal, or empty list if no path.
        """
        if start not in graph.nodes or goal not in graph.nodes:
            return []

        if start == goal:
            return [start]

        # Priority queue: (f_score, tie_breaker, node_id)
        counter = 0
        open_set: list = []
        heapq.heappush(open_set, (0.0, counter, start))

        closed_set: set = set()
        g_score: Dict[str, float] = {start: 0.0}
        came_from: Dict[str, str] = {}

        while open_set:
            _, _, current = heapq.heappop(open_set)

            if current == goal:
                return _reconstruct_path(came_from, current)

            if current in closed_set:
                continue
            closed_set.add(current)

            for seg_id in graph.adjacency.get(current, []):
                seg = graph.edges.get(seg_id)
                if seg is None:
                    continue
                neighbor = seg.to_intersection
                if neighbor in closed_set:
                    continue

                edge_cost = cost_function(current, neighbor)
                tentative_g = g_score[current] + edge_cost

                if neighbor not in g_score or tentative_g < g_score[neighbor]:
                    came_from[neighbor] = current
                    g_score[neighbor] = tentative_g
                    f = tentative_g + heuristic(neighbor, goal)
                    counter += 1
                    heapq.heappush(open_set, (f, counter, neighbor))

        return []  # No path found


# ---------------------------------------------------------------------------
# RoutePlanner
# ---------------------------------------------------------------------------

class RoutePlanner:
    """Plans optimal routes through the road network using A*."""

    def __init__(self, network: RoadGraph, pathfinding_service: Optional[PathfindingService] = None) -> None:
        self.network = network
        self._service = pathfinding_service or PathfindingService()

    def plan_route(
        self,
        origin: str,
        destination: str,
        vehicle_type: VehicleType = VehicleType.PASSENGER,
        tick_index: int = 0,
    ) -> Optional[Route]:
        """
        Compute optimal route from origin to destination using A*.

        Returns Route object if path exists, None otherwise.
        Raises ValueError if origin or destination not in network.
        """
        if origin not in self.network.nodes:
            raise ValueError(f"Origin '{origin}' not in network")
        if destination not in self.network.nodes:
            raise ValueError(f"Destination '{destination}' not in network")

        heuristic = lambda a, b: euclidean_heuristic(a, b, self.network)
        cost_fn = lambda a, b: calculate_edge_cost(a, b, self.network, tick_index)

        node_path = self._service.find_path(
            self.network, origin, destination, heuristic, cost_fn
        )

        if not node_path:
            return None

        segments = _nodes_to_segments(node_path, self.network)
        total_distance = sum(
            self.network.edges[s].length for s in segments if s in self.network.edges
        )
        estimated_time = sum(
            self.network.edges[s].get_travel_time()
            for s in segments
            if s in self.network.edges
        )
        cost = sum(
            cost_fn(node_path[i], node_path[i + 1])
            for i in range(len(node_path) - 1)
        )

        return Route(
            origin=origin,
            destination=destination,
            segments=segments,
            total_distance=total_distance,
            estimated_time=estimated_time,
            planned_at_tick=tick_index,
            cost=cost,
        )

    def replan_if_needed(self, vehicle: Vehicle, tick_index: int = 0) -> bool:
        """
        Re-route vehicle if current route has incident or heavy congestion.

        Returns True if vehicle was re-routed, False otherwise.
        """
        if vehicle.route is None or vehicle.destination is None:
            return False

        # Determine current origin (next intersection ahead)
        if vehicle.current_segment and vehicle.current_segment in self.network.edges:
            seg = self.network.edges[vehicle.current_segment]
            current_node = seg.to_intersection
        else:
            return False

        # Check if remaining route has a blocked/congested segment
        needs_reroute = False
        if vehicle.route.segments:
            try:
                progress_idx = vehicle.route.segments.index(vehicle.current_segment)
                remaining = vehicle.route.segments[progress_idx + 1:]
            except ValueError:
                remaining = vehicle.route.segments

            for seg_id in remaining:
                seg = self.network.edges.get(seg_id)
                if seg is None:
                    continue
                if any(i.is_active(tick_index) for i in seg.incidents):
                    needs_reroute = True
                    break
                if seg.get_congestion_factor() > 0.85:
                    needs_reroute = True
                    break

        if not needs_reroute:
            return False

        new_route = self.plan_route(current_node, vehicle.destination, vehicle.type, tick_index)
        if new_route:
            vehicle.route = new_route
            return True
        return False
