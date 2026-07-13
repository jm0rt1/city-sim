"""Main TransportSubsystem: orchestrates traffic for one simulation tick."""

from __future__ import annotations

import random
from typing import Dict, List, Optional

from src.city.transport.congestion import CongestionModel
from src.city.transport.models import (
    Incident, IntersectionType, RoadGraph, RoadType,
    Route, TrafficDelta, Vehicle, VehicleType,
)
from src.city.transport.pathfinding import RoutePlanner
from src.city.transport.signals import SignalController
from src.city.transport.traffic_flow import TrafficFlowModel


class TransportSubsystem:
    """
    Main subsystem managing all transport and traffic operations.

    Executes one tick update covering:
      1. Update signal controllers
      2. Update highway controllers (ramp metering placeholder)
      3. Generate new vehicles based on demand
      4. Update vehicle positions and speeds
      5. Process vehicles at intersections (queuing, throughput)
      6. Handle re-routing decisions
      7. Remove arrived vehicles
      8. Update traffic metrics
      9. Update incidents
     10. Return TrafficDelta
    """

    def __init__(
        self,
        network: RoadGraph,
        route_planner: Optional[RoutePlanner] = None,
        traffic_model: Optional[TrafficFlowModel] = None,
        congestion_model: Optional[CongestionModel] = None,
        rng: Optional[random.Random] = None,
    ) -> None:
        self.network = network
        self.route_planner = route_planner or RoutePlanner(network)
        self.traffic_model = traffic_model or TrafficFlowModel()
        self.congestion_model = congestion_model or CongestionModel()
        self._rng = rng or random.Random(42)

        # Active vehicles keyed by vehicle ID
        self.vehicles: Dict[str, Vehicle] = {}

        # Completed trips this run
        self._completed_trips: List[float] = []  # travel times

        # Time step (seconds per tick)
        self.dt: float = 60.0  # 1 minute per tick by default

    # ------------------------------------------------------------------
    # Public update entry point
    # ------------------------------------------------------------------

    def update(self, tick_index: int) -> TrafficDelta:
        """
        Perform all traffic updates for one tick.

        Args:
            tick_index: Current simulation tick number.

        Returns:
            TrafficDelta with metrics for this tick.
        """
        delta = TrafficDelta(tick_index=tick_index)

        # 1. Update signal controllers
        self._update_signals()

        # 2. Highway ramp metering (placeholder – extend as needed)
        # self._update_highway_controllers()

        # 3. Generate new vehicles
        entered = self._spawn_vehicles(tick_index)
        delta.vehicles_entered = entered

        # 4 & 5. Update vehicle positions and handle intersections
        arrived_ids = self._update_vehicles(tick_index)

        # 6. Re-routing check
        for vehicle in list(self.vehicles.values()):
            self.route_planner.replan_if_needed(vehicle, tick_index)

        # 7. Remove arrived vehicles
        exited = len(arrived_ids)
        for vid in arrived_ids:
            v = self.vehicles.pop(vid, None)
            if v and v.trip_start_time is not None:
                travel_time = tick_index - v.trip_start_time
                self._completed_trips.append(float(travel_time))
        delta.vehicles_exited = exited

        # 8. Update segment metrics
        for seg in self.network.edges.values():
            self.congestion_model.update_segment_metrics(seg)

        # 9. Incident updates (resolve expired incidents)
        incidents_resolved = 0
        for seg in self.network.edges.values():
            before = len(seg.incidents)
            seg.incidents = [i for i in seg.incidents if i.is_active(tick_index)]
            incidents_resolved += before - len(seg.incidents)
        delta.incidents_resolved = incidents_resolved
        delta.incidents_active = sum(
            len(seg.incidents) for seg in self.network.edges.values()
        )

        # 10. Aggregate metrics
        delta.vehicles_active = len(self.vehicles)

        speeds = [v.speed for v in self.vehicles.values()]
        delta.avg_speed = sum(speeds) / len(speeds) if speeds else 0.0

        delta.avg_travel_time = (
            sum(self._completed_trips) / len(self._completed_trips)
            if self._completed_trips else 0.0
        )
        delta.total_distance_traveled = sum(v.trip_distance for v in self.vehicles.values())
        delta.total_throughput = sum(n.throughput for n in self.network.nodes.values())

        delta.congestion_index = self.congestion_model.calculate_congestion_index(self.network)
        delta.congested_segments = self.congestion_model.count_congested_segments(self.network)
        delta.max_queue_length = self.congestion_model.max_queue_length(self.network)

        densities = [seg.density for seg in self.network.edges.values()]
        delta.avg_density = sum(densities) / len(densities) if densities else 0.0

        delta.highway_metrics = self.congestion_model.get_road_type_metrics(
            self.network, RoadType.HIGHWAY
        )
        delta.arterial_metrics = self.congestion_model.get_road_type_metrics(
            self.network, RoadType.ARTERIAL
        )
        delta.local_metrics = self.congestion_model.get_road_type_metrics(
            self.network, RoadType.LOCAL
        )

        # Signal cycle count
        delta.signal_cycles = sum(
            node.signal_controller.cycles_completed
            for node in self.network.nodes.values()
            if node.signal_controller is not None
        )

        delta.validate()
        return delta

    # ------------------------------------------------------------------
    # Internal helpers
    # ------------------------------------------------------------------

    def _update_signals(self) -> None:
        """Advance all signal controllers by one time step."""
        for node in self.network.nodes.values():
            if node.type == IntersectionType.SIGNALIZED and node.signal_controller:
                node.signal_controller.update(self.dt, node.queue_length)

    def _spawn_vehicles(self, tick_index: int) -> int:
        """
        Generate new vehicles based on simple demand model.

        Each node pair has a small probability of generating a vehicle.
        Returns number of vehicles spawned.
        """
        node_ids = list(self.network.nodes.keys())
        if len(node_ids) < 2:
            return 0

        spawned = 0
        # Simple: with 20% chance per tick, spawn one vehicle from random O to D
        if self._rng.random() < 0.20:
            origin = self._rng.choice(node_ids)
            destination = self._rng.choice(node_ids)
            if origin == destination:
                return 0
            try:
                route = self.route_planner.plan_route(origin, destination, tick_index=tick_index)
            except ValueError:
                return 0
            if route is None or not route.segments:
                return 0

            vid = f"v_{tick_index}_{spawned}_{self._rng.randint(0, 9999)}"
            vehicle = Vehicle(
                id=vid,
                type=VehicleType.PASSENGER,
                destination=destination,
                route=route,
                trip_start_time=tick_index,
            )
            # Place vehicle at start of first segment
            first_seg = self.network.edges.get(route.segments[0])
            if first_seg:
                vehicle.current_segment = first_seg.id
                vehicle.position = 0.0
                vehicle.speed = first_seg.speed_limit * 0.5
                first_seg.vehicles.append(vid)

            self.vehicles[vid] = vehicle
            spawned += 1

        return spawned

    def _update_vehicles(self, tick_index: int) -> List[str]:
        """
        Move all vehicles forward; return IDs of vehicles that arrived.
        """
        arrived: List[str] = []

        for vid, vehicle in list(self.vehicles.items()):
            if vehicle.current_segment is None or vehicle.route is None:
                arrived.append(vid)
                continue

            seg = self.network.edges.get(vehicle.current_segment)
            if seg is None:
                arrived.append(vid)
                continue

            # Check signal at destination intersection before proceeding
            dest_node = self.network.nodes.get(seg.to_intersection)
            if dest_node and dest_node.type == IntersectionType.SIGNALIZED:
                ctrl = dest_node.signal_controller
                if ctrl and not ctrl.is_green(vehicle.current_segment, ""):
                    # Hold vehicle at red; update queue
                    dest_node.queue_length[vehicle.current_segment] = (
                        dest_node.queue_length.get(vehicle.current_segment, 0) + 1
                    )
                    vehicle.speed = 0.0
                    continue

            # Move vehicle
            self.traffic_model.update_vehicle_position(vehicle, seg, self.dt)

            # Check if vehicle has left the segment
            if vehicle.position >= seg.length:
                vehicle.position = 0.0
                # Remove from current segment
                if vid in seg.vehicles:
                    seg.vehicles.remove(vid)
                # Update intersection throughput
                if dest_node:
                    dest_node.throughput += 1
                    dest_node.queue_length.pop(vehicle.current_segment, None)

                # Check route completion
                if vehicle.route.is_complete(vehicle.current_segment):
                    arrived.append(vid)
                    continue

                # Advance to next segment
                next_seg_id = vehicle.route.get_next_segment(vehicle.current_segment)
                if next_seg_id is None:
                    arrived.append(vid)
                    continue

                vehicle.current_segment = next_seg_id
                next_seg = self.network.edges.get(next_seg_id)
                if next_seg:
                    next_seg.vehicles.append(vid)
                    vehicle.speed = min(vehicle.speed, next_seg.speed_limit)
                else:
                    arrived.append(vid)

            # Update segment avg_speed
            seg_vehicles = [
                self.vehicles[v] for v in seg.vehicles if v in self.vehicles
            ]
            if seg_vehicles:
                seg.avg_speed = sum(v.speed for v in seg_vehicles) / len(seg_vehicles)

        return arrived

    def add_incident(self, incident: Incident) -> None:
        """Add a traffic incident to the network."""
        seg = self.network.edges.get(incident.segment_id)
        if seg:
            seg.incidents.append(incident)

    def get_signal_controller(self, intersection_id: str) -> Optional[SignalController]:
        """Return signal controller for a signalized intersection."""
        node = self.network.nodes.get(intersection_id)
        if node:
            return node.signal_controller  # type: ignore[return-value]
        return None
