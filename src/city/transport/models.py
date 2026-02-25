"""Data models for the Transport & Traffic subsystem."""

from __future__ import annotations

import math
from dataclasses import dataclass, field
from enum import Enum, auto
from typing import Dict, List, Optional


# ---------------------------------------------------------------------------
# Enumerations
# ---------------------------------------------------------------------------

class IntersectionType(Enum):
    SIGNALIZED = auto()
    STOP = auto()
    YIELD = auto()
    ROUNDABOUT = auto()
    HIGHWAY_JUNCTION = auto()


class RoadType(Enum):
    HIGHWAY = auto()
    ARTERIAL = auto()
    COLLECTOR = auto()
    LOCAL = auto()


class VehicleType(Enum):
    PASSENGER = auto()
    TRUCK = auto()
    BUS = auto()
    EMERGENCY = auto()


class SignalState(Enum):
    GREEN = auto()
    YELLOW = auto()
    RED = auto()
    FLASHING_YELLOW = auto()
    FLASHING_RED = auto()


class IncidentType(Enum):
    ACCIDENT = auto()
    CONSTRUCTION = auto()
    BREAKDOWN = auto()
    WEATHER = auto()


class Movement(Enum):
    STRAIGHT = auto()
    LEFT = auto()
    RIGHT = auto()


# ---------------------------------------------------------------------------
# Geometric primitive
# ---------------------------------------------------------------------------

@dataclass
class Position:
    """(x, y) coordinates in meters."""
    x: float
    y: float

    def distance_to(self, other: "Position") -> float:
        """Euclidean distance to another position."""
        dx = self.x - other.x
        dy = self.y - other.y
        return math.sqrt(dx * dx + dy * dy)


# ---------------------------------------------------------------------------
# Road network primitives
# ---------------------------------------------------------------------------

@dataclass
class Lane:
    """Individual lane within a road segment."""
    id: str
    index: int
    length: float

    allowed_vehicle_types: List[VehicleType] = field(default_factory=lambda: list(VehicleType))
    allowed_movements: List[Movement] = field(default_factory=lambda: [Movement.STRAIGHT])

    is_hov: bool = False
    min_occupancy: int = 1

    vehicles: List[str] = field(default_factory=list)

    @property
    def occupancy(self) -> int:
        return len(self.vehicles)


@dataclass
class Incident:
    """Traffic incident affecting road capacity."""
    id: str
    segment_id: str
    type: IncidentType

    capacity_reduction: float = 0.5   # fraction of capacity lost (0..1)
    lanes_blocked: int = 1

    start_tick: int = 0
    estimated_duration: int = 10

    def is_active(self, current_tick: int) -> bool:
        """Check if incident is still active."""
        return current_tick < self.start_tick + self.estimated_duration


@dataclass
class RoadSegment:
    """Directed edge in road network (one-way segment)."""
    id: str
    from_intersection: str
    to_intersection: str

    lanes: List[Lane] = field(default_factory=list)
    length: float = 500.0          # meters
    speed_limit: float = 13.4      # m/s (~30 mph)
    capacity: int = 1800           # vehicles/hour (all lanes combined)
    road_type: RoadType = RoadType.ARTERIAL

    # Current traffic state
    vehicles: List[str] = field(default_factory=list)
    density: float = 0.0           # vehicles/km
    avg_speed: float = 0.0         # m/s
    flow_rate: int = 0             # vehicles/hour

    # Incidents and conditions
    incidents: List[Incident] = field(default_factory=list)
    condition: float = 1.0         # road condition (0..1)

    def get_travel_time(self) -> float:
        """Calculate current travel time in seconds."""
        speed = self.avg_speed if self.avg_speed > 0 else self.speed_limit
        if speed > 0:
            return self.length / speed
        return float('inf')

    def get_congestion_factor(self) -> float:
        """Calculate congestion as ratio of current density to capacity density."""
        if self.capacity == 0 or self.length == 0:
            return 0.0
        capacity_per_km = (self.capacity / self.length) * 1000
        return min(1.0, self.density / capacity_per_km) if capacity_per_km > 0 else 0.0

    def effective_capacity(self) -> int:
        """Capacity reduced by active incidents."""
        reduction = sum(
            i.capacity_reduction for i in self.incidents
            if i.is_active(0)   # caller passes tick; simplified here
        )
        return max(0, int(self.capacity * (1.0 - min(1.0, reduction))))


@dataclass
class SignalPhase:
    """One phase of traffic signal operation."""
    id: str
    duration: float  # seconds

    allowed_movements: List[Movement] = field(default_factory=lambda: [Movement.STRAIGHT])
    protected_left_turns: bool = False

    # (from_segment_id, to_segment_id) -> SignalState
    movement_states: Dict[tuple, SignalState] = field(default_factory=dict)


@dataclass
class Intersection:
    """Junction point where road segments meet."""
    id: str
    position: Position
    type: IntersectionType = IntersectionType.STOP

    incoming_segments: List[str] = field(default_factory=list)
    outgoing_segments: List[str] = field(default_factory=list)

    # signal_controller added lazily by SignalController
    signal_controller: Optional[object] = field(default=None, repr=False)

    # Traffic state
    queue_length: Dict[str, int] = field(default_factory=dict)  # segment_id -> queue
    throughput: int = 0

    def allows_turn(self, from_segment: str, to_segment: str) -> bool:
        """Check if turn is permitted (simplified: all turns allowed)."""
        return True


# ---------------------------------------------------------------------------
# Road graph
# ---------------------------------------------------------------------------

@dataclass
class RoadGraph:
    """Graph representation of the transport network."""
    nodes: Dict[str, Intersection] = field(default_factory=dict)
    edges: Dict[str, RoadSegment] = field(default_factory=dict)
    # node_id -> list of outgoing segment IDs
    adjacency: Dict[str, List[str]] = field(default_factory=dict)

    def add_intersection(self, intersection: Intersection) -> None:
        self.nodes[intersection.id] = intersection
        if intersection.id not in self.adjacency:
            self.adjacency[intersection.id] = []

    def add_segment(self, segment: RoadSegment) -> None:
        self.edges[segment.id] = segment
        # Register in adjacency list
        if segment.from_intersection not in self.adjacency:
            self.adjacency[segment.from_intersection] = []
        self.adjacency[segment.from_intersection].append(segment.id)
        # Update intersection references
        if segment.from_intersection in self.nodes:
            node = self.nodes[segment.from_intersection]
            if segment.id not in node.outgoing_segments:
                node.outgoing_segments.append(segment.id)
        if segment.to_intersection in self.nodes:
            node = self.nodes[segment.to_intersection]
            if segment.id not in node.incoming_segments:
                node.incoming_segments.append(segment.id)

    def get_neighbors(self, node_id: str) -> List[Intersection]:
        """Get adjacent intersections reachable from node_id."""
        result = []
        for seg_id in self.adjacency.get(node_id, []):
            seg = self.edges.get(seg_id)
            if seg and seg.to_intersection in self.nodes:
                result.append(self.nodes[seg.to_intersection])
        return result

    def get_outgoing_segments(self, node_id: str) -> List[RoadSegment]:
        """Get road segments leaving a node."""
        return [
            self.edges[seg_id]
            for seg_id in self.adjacency.get(node_id, [])
            if seg_id in self.edges
        ]

    def find_segment(self, from_id: str, to_id: str) -> Optional[RoadSegment]:
        """Find road segment connecting two intersections."""
        for seg_id in self.adjacency.get(from_id, []):
            seg = self.edges.get(seg_id)
            if seg and seg.to_intersection == to_id:
                return seg
        return None

    def validate(self) -> bool:
        """Verify graph integrity."""
        for seg in self.edges.values():
            if seg.from_intersection not in self.nodes:
                return False
            if seg.to_intersection not in self.nodes:
                return False
        return True


# ---------------------------------------------------------------------------
# Vehicle & Route
# ---------------------------------------------------------------------------

@dataclass
class Route:
    """Planned path from origin to destination."""
    origin: str
    destination: str
    segments: List[str]               # ordered segment IDs

    total_distance: float = 0.0
    estimated_time: float = 0.0

    planned_at_tick: int = 0
    cost: float = 0.0

    def get_next_segment(self, current_segment: str) -> Optional[str]:
        """Get next segment after current one in route."""
        try:
            idx = self.segments.index(current_segment)
            if idx + 1 < len(self.segments):
                return self.segments[idx + 1]
        except ValueError:
            pass
        return None

    def is_complete(self, current_segment: str) -> bool:
        """Check if vehicle has completed the route."""
        if not self.segments:
            return False
        return current_segment == self.segments[-1]


@dataclass
class Vehicle:
    """Individual vehicle navigating the road network."""
    id: str
    type: VehicleType = VehicleType.PASSENGER

    # Physical properties
    length: float = 5.0             # meters
    max_speed: float = 30.0         # m/s
    max_acceleration: float = 3.0   # m/s²
    max_deceleration: float = -8.0  # m/s²

    # Current state
    current_segment: Optional[str] = None
    current_lane: Optional[int] = None
    position: float = 0.0          # meters along segment
    speed: float = 0.0             # m/s

    # Route and navigation
    route: Optional[Route] = None
    route_progress: int = 0
    destination: Optional[str] = None

    # Trip tracking
    trip_start_time: Optional[int] = None
    trip_distance: float = 0.0

    def update_position(self, dt: float) -> None:
        """Update position based on current speed and time step."""
        self.position += self.speed * dt
        self.trip_distance += self.speed * dt


# ---------------------------------------------------------------------------
# Metrics
# ---------------------------------------------------------------------------

@dataclass
class RoadTypeMetrics:
    """Traffic metrics for a specific road type."""
    total_segments: int = 0
    avg_speed: float = 0.0
    avg_density: float = 0.0
    avg_flow: int = 0
    congestion_index: float = 0.0


@dataclass
class TrafficDelta:
    """Traffic changes and metrics during a tick."""
    tick_index: int = 0

    # Vehicle counts
    vehicles_entered: int = 0
    vehicles_exited: int = 0
    vehicles_active: int = 0

    # Performance metrics
    avg_speed: float = 0.0
    avg_travel_time: float = 0.0
    total_distance_traveled: float = 0.0
    total_throughput: int = 0

    # Congestion metrics
    congestion_index: float = 0.0
    congested_segments: int = 0
    max_queue_length: int = 0
    avg_density: float = 0.0

    # Incidents
    incidents_active: int = 0
    incidents_resolved: int = 0

    # By road type
    highway_metrics: RoadTypeMetrics = field(default_factory=RoadTypeMetrics)
    arterial_metrics: RoadTypeMetrics = field(default_factory=RoadTypeMetrics)
    local_metrics: RoadTypeMetrics = field(default_factory=RoadTypeMetrics)

    # Signal performance
    signal_cycles: int = 0
    avg_signal_delay: float = 0.0

    def validate(self) -> None:
        """Ensure internal consistency."""
        assert self.vehicles_active >= 0, "vehicles_active must be non-negative"
        assert 0.0 <= self.congestion_index <= 1.0, "congestion_index must be in [0,1]"
        assert self.avg_speed >= 0.0, "avg_speed must be non-negative"
