"""Congestion modeling for the transport subsystem."""

from __future__ import annotations

from typing import List

from src.city.transport.models import RoadGraph, RoadSegment, RoadType, RoadTypeMetrics


CONGESTION_THRESHOLD = 0.7  # segments above this are considered congested


class CongestionModel:
    """Calculates congestion metrics for network analysis."""

    def calculate_density(self, segment: RoadSegment) -> float:
        """Calculate traffic density (vehicles per km)."""
        if segment.length <= 0:
            return 0.0
        return len(segment.vehicles) / (segment.length / 1000.0)

    def calculate_flow_rate(self, segment: RoadSegment, dt: float) -> int:
        """
        Estimate flow rate (vehicles per hour) from vehicles currently on segment.

        Uses average speed and segment length as a proxy.
        """
        if segment.length <= 0 or dt <= 0:
            return 0
        speed = segment.avg_speed if segment.avg_speed > 0 else segment.speed_limit
        # Approximate: vehicles that can traverse segment per hour
        if speed <= 0:
            return 0
        traversal_time = segment.length / speed  # seconds
        vehicles_per_second = len(segment.vehicles) / traversal_time if traversal_time > 0 else 0
        return int(vehicles_per_second * 3600)

    def calculate_congestion_index(self, network: RoadGraph) -> float:
        """
        Calculate overall network congestion index (0..1).

        Weighted average of segment congestion levels (weighted by capacity).
        """
        total_weight = 0.0
        weighted_congestion = 0.0

        for segment in network.edges.values():
            weight = float(segment.capacity)
            congestion = segment.get_congestion_factor()
            weighted_congestion += congestion * weight
            total_weight += weight

        if total_weight == 0:
            return 0.0
        return weighted_congestion / total_weight

    def update_segment_metrics(self, segment: RoadSegment) -> None:
        """Recompute and store density and flow_rate on the segment."""
        segment.density = self.calculate_density(segment)
        if segment.vehicles and segment.avg_speed > 0:
            segment.flow_rate = self.calculate_flow_rate(segment, 1.0)

    def get_road_type_metrics(self, network: RoadGraph, road_type: RoadType) -> RoadTypeMetrics:
        """Aggregate metrics for all segments of a given road type."""
        segments = [s for s in network.edges.values() if s.road_type == road_type]
        if not segments:
            return RoadTypeMetrics(total_segments=0)

        total = len(segments)
        avg_speed = sum(s.avg_speed for s in segments) / total
        avg_density = sum(s.density for s in segments) / total
        avg_flow = int(sum(s.flow_rate for s in segments) / total)
        congestion = sum(s.get_congestion_factor() for s in segments) / total

        return RoadTypeMetrics(
            total_segments=total,
            avg_speed=avg_speed,
            avg_density=avg_density,
            avg_flow=avg_flow,
            congestion_index=congestion,
        )

    def count_congested_segments(self, network: RoadGraph) -> int:
        """Return number of segments above the congestion threshold."""
        return sum(
            1 for s in network.edges.values()
            if s.get_congestion_factor() > CONGESTION_THRESHOLD
        )

    def max_queue_length(self, network: RoadGraph) -> int:
        """Return the longest intersection queue across all segments."""
        max_q = 0
        for node in network.nodes.values():
            for q in node.queue_length.values():
                max_q = max(max_q, q)
        return max_q
