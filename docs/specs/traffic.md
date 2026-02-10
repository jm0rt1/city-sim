# Specification: Transport & Traffic Subsystem

## Purpose
Define the transport network architecture, traffic flow models, pathfinding algorithms, signal control logic, vehicle movement mechanics, and congestion modeling for the city simulation. This specification provides the complete reference for implementing and extending the transport and traffic subsystem.

## Overview

The Transport & Traffic Subsystem manages all aspects of vehicle movement and road network operations:
- **Road Network Management**: Maintains graph structure of intersections and road segments
- **Pathfinding & Routing**: Computes optimal routes using A* algorithm with real-time traffic awareness
- **Traffic Flow Simulation**: Models vehicle movement, speed adjustments, and lane changes
- **Congestion Modeling**: Calculates traffic density, flow rates, and congestion indices
- **Signal Control**: Manages traffic lights at intersections with adaptive timing
- **Highway Control**: Implements ramp metering and speed harmonization
- **Vehicle Fleet Management**: Tracks and updates all vehicles in the simulation
- **Traffic Monitoring**: Collects metrics on throughput, travel times, and network performance

### Key Principles

1. **Graph Consistency**: Road network topology remains valid (connected, no orphaned nodes)
2. **Deterministic Simulation**: Same inputs and seed produce identical traffic patterns
3. **Realistic Flow**: Traffic flow respects capacity constraints and physical limitations
4. **Responsive Routing**: Pathfinding adapts to current traffic conditions
5. **Scalable Performance**: Algorithms efficient enough for real-time simulation of large networks

## Data Model

### RoadGraph

```python
class RoadGraph:
    """
    Graph representation of the transport network.
    """
    
    nodes: Dict[str, Intersection]       # Intersection ID -> Intersection
    edges: Dict[str, RoadSegment]        # Segment ID -> RoadSegment
    adjacency: Dict[str, List[str]]      # Node ID -> List of outgoing segment IDs
    
    def get_neighbors(self, node_id: str) -> List[Intersection]:
        """Get adjacent intersections from a given node."""
        
    def get_outgoing_segments(self, node_id: str) -> List[RoadSegment]:
        """Get road segments leaving an intersection."""
        
    def find_segment(self, from_id: str, to_id: str) -> Optional[RoadSegment]:
        """Find road segment connecting two intersections."""
        
    def validate(self) -> bool:
        """Verify graph integrity (no orphaned nodes, valid references)."""
```

**Graph Invariants**:
- All segment endpoints reference valid intersections
- No duplicate edges between same node pair (unless one-way streets)
- Graph is connected (all nodes reachable from all other nodes, or in well-defined components)

### Intersection

```python
class Intersection:
    """
    Junction point where road segments meet.
    """
    
    id: str                              # Unique identifier
    position: Position                   # (x, y) coordinates in meters
    type: IntersectionType              # SIGNALIZED, STOP, YIELD, ROUNDABOUT, HIGHWAY_JUNCTION
    
    incoming_segments: List[str]         # IDs of segments ending at this node
    outgoing_segments: List[str]         # IDs of segments starting from this node
    
    signal_controller: Optional[SignalController]  # Traffic light control (if signalized)
    
    # Traffic state
    queue_length: Dict[str, int]        # Segment ID -> vehicles waiting
    throughput: int                      # Vehicles processed this tick
    
    def allows_turn(self, from_segment: str, to_segment: str) -> bool:
        """Check if turn is permitted (e.g., no left on red)."""
```

**IntersectionType Values**:
- `SIGNALIZED`: Traffic lights control flow
- `STOP`: All-way stop (first-come-first-served)
- `YIELD`: Yield to main road
- `ROUNDABOUT`: Circular flow, yield to traffic already in circle
- `HIGHWAY_JUNCTION`: High-speed merge/split with acceleration lanes

### RoadSegment

```python
class RoadSegment:
    """
    Directed edge in road network (one-way segment).
    For two-way roads, create two segments (one each direction).
    """
    
    id: str                              # Unique identifier
    from_intersection: str               # Origin intersection ID
    to_intersection: str                 # Destination intersection ID
    
    lanes: List[Lane]                    # Lanes on this segment
    length: float                        # Length in meters
    speed_limit: float                   # Speed limit in m/s (e.g., 13.4 m/s = 30 mph)
    capacity: int                        # Max vehicles per hour (all lanes combined)
    
    # Segment classification
    road_type: RoadType                  # HIGHWAY, ARTERIAL, COLLECTOR, LOCAL
    
    # Current traffic state
    vehicles: List[str]                  # IDs of vehicles currently on this segment
    density: float                       # Vehicles per km
    avg_speed: float                     # Current average speed in m/s
    flow_rate: int                       # Vehicles per hour currently flowing
    
    # Incidents and conditions
    incidents: List[Incident]            # Active incidents reducing capacity
    condition: float                     # Road condition (0..1, 1=perfect)
    
    def get_travel_time(self) -> float:
        """Calculate current travel time in seconds."""
        if self.avg_speed > 0:
            return self.length / self.avg_speed
        return float('inf')
    
    def get_congestion_factor(self) -> float:
        """Calculate congestion as ratio of current density to capacity."""
        if self.capacity == 0:
            return 0.0
        vehicles_per_km = self.density
        capacity_per_km = (self.capacity / self.length) * 1000  # Convert to per km
        return min(1.0, vehicles_per_km / capacity_per_km)
```

**RoadType Values and Typical Parameters**:
- `HIGHWAY`: Speed limit 25-35 m/s (55-80 mph), capacity 2000-2400 veh/hr/lane
- `ARTERIAL`: Speed limit 13-20 m/s (30-45 mph), capacity 1200-1800 veh/hr/lane
- `COLLECTOR`: Speed limit 11-16 m/s (25-35 mph), capacity 800-1200 veh/hr/lane
- `LOCAL`: Speed limit 7-13 m/s (15-30 mph), capacity 400-800 veh/hr/lane

### Lane

```python
class Lane:
    """
    Individual lane within a road segment.
    """
    
    id: str                              # Unique identifier
    index: int                           # Lane number (0 = rightmost, 1, 2, ...)
    length: float                        # Same as parent segment length
    
    allowed_vehicle_types: List[VehicleType]  # PASSENGER, TRUCK, BUS, EMERGENCY
    allowed_movements: List[Movement]    # STRAIGHT, LEFT, RIGHT (at end of lane)
    
    # Lane-specific restrictions
    is_hov: bool                         # High-occupancy vehicle lane
    min_occupancy: int                   # Minimum passengers if HOV lane
    
    # Current state
    vehicles: List[str]                  # Vehicle IDs in this lane (ordered)
    occupancy: int                       # Number of vehicles currently in lane
```

### Vehicle

```python
class Vehicle:
    """
    Individual vehicle navigating the road network.
    """
    
    id: str                              # Unique identifier
    type: VehicleType                    # PASSENGER, TRUCK, BUS, EMERGENCY
    
    # Physical properties
    length: float                        # Vehicle length in meters (affects spacing)
    max_speed: float                     # Maximum speed in m/s
    max_acceleration: float              # Max acceleration in m/s²
    max_deceleration: float              # Max braking in m/s² (negative)
    
    # Current state
    current_segment: Optional[str]       # Current road segment ID (None if not in network)
    current_lane: Optional[int]          # Current lane index
    position: float                      # Position along segment (0..segment.length in meters)
    speed: float                         # Current speed in m/s
    
    # Route and navigation
    route: Optional[Route]               # Planned route (None if arrived/not started)
    route_progress: int                  # Index of current segment in route
    destination: Optional[str]           # Destination intersection ID
    
    # Trip tracking
    trip_start_time: Optional[int]       # Tick when trip started
    trip_distance: float                 # Total distance traveled this trip in meters
    
    def update_position(self, dt: float):
        """Update position based on current speed and time step."""
        self.position += self.speed * dt
        self.trip_distance += self.speed * dt
```

**VehicleType Characteristics**:
- `PASSENGER`: length=5m, max_speed varies, max_accel=3 m/s², max_decel=-8 m/s²
- `TRUCK`: length=15m, max_speed=25 m/s, max_accel=1.5 m/s², max_decel=-6 m/s²
- `BUS`: length=12m, max_speed=20 m/s, max_accel=2 m/s², max_decel=-7 m/s²
- `EMERGENCY`: length=6m, max_speed=40 m/s, max_accel=4 m/s², max_decel=-9 m/s²

### Route

```python
class Route:
    """
    Planned path from origin to destination.
    """
    
    origin: str                          # Starting intersection ID
    destination: str                     # Ending intersection ID
    segments: List[str]                  # Ordered list of segment IDs
    
    total_distance: float                # Sum of segment lengths in meters
    estimated_time: float                # Estimated travel time in seconds (at route planning)
    
    # Route metadata
    planned_at_tick: int                 # When route was computed
    cost: float                          # A* cost (distance + congestion penalties)
    
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
        return current_segment == self.segments[-1]
```

### TrafficDelta

```python
class TrafficDelta:
    """
    Traffic changes and metrics during a tick.
    """
    
    # Aggregates
    vehicles_entered: int                # Vehicles that entered network this tick
    vehicles_exited: int                 # Vehicles that exited network this tick
    vehicles_active: int                 # Vehicles currently in network
    
    # Performance Metrics
    avg_speed: float                     # Average speed across all vehicles (m/s)
    avg_travel_time: float               # Average time to complete trips (seconds)
    total_distance_traveled: float       # Sum of distances traveled by all vehicles (meters)
    total_throughput: int                # Total vehicles processed at intersections
    
    # Congestion Metrics
    congestion_index: float              # Overall network congestion (0..1, 0=free-flow)
    congested_segments: int              # Number of segments above congestion threshold
    max_queue_length: int                # Longest queue at any intersection
    avg_density: float                   # Average vehicles per km across all segments
    
    # Incidents
    incidents_active: int                # Number of active incidents
    incidents_resolved: int              # Incidents cleared this tick
    
    # By Road Type
    highway_metrics: RoadTypeMetrics     # Highway-specific metrics
    arterial_metrics: RoadTypeMetrics    # Arterial-specific metrics
    local_metrics: RoadTypeMetrics       # Local road metrics
    
    # Signal Performance
    signal_cycles: int                   # Total signal cycles completed
    avg_signal_delay: float              # Average delay due to signals (seconds)
    
    # Metadata
    tick_index: int
    
    def validate(self):
        """Ensure internal consistency."""
        assert self.vehicles_active >= 0
        assert 0.0 <= self.congestion_index <= 1.0
        assert self.avg_speed >= 0.0
```

### RoadTypeMetrics

```python
class RoadTypeMetrics:
    """
    Traffic metrics for a specific road type.
    """
    
    total_segments: int                  # Number of segments of this type
    avg_speed: float                     # Average speed on this road type (m/s)
    avg_density: float                   # Average density (vehicles/km)
    avg_flow: int                        # Average flow rate (vehicles/hour)
    congestion_index: float              # Congestion for this road type (0..1)
```

### SignalController

```python
class SignalController:
    """
    Traffic signal controller for an intersection.
    """
    
    intersection_id: str                 # Controlled intersection
    
    # Signal phases
    phases: List[SignalPhase]            # Signal phases (green for different movements)
    current_phase: int                   # Index of currently active phase
    phase_elapsed: float                 # Seconds elapsed in current phase
    
    # Timing parameters
    min_green_time: float                # Minimum green duration (seconds)
    max_green_time: float                # Maximum green duration (seconds)
    yellow_time: float                   # Yellow light duration (seconds)
    all_red_time: float                  # All-red clearance time (seconds)
    
    # Adaptive control
    is_adaptive: bool                    # Use traffic-responsive timing
    detector_data: Dict[str, int]        # Segment ID -> vehicle count
    
    def update(self, dt: float, network: RoadGraph):
        """
        Update signal state and advance to next phase if needed.
        
        Args:
            dt: Time step in seconds
            network: Road network for querying traffic state
        """
        
    def get_signal_state(self, from_segment: str, to_segment: str) -> SignalState:
        """Get current signal state for a specific movement."""
```

**SignalState Values**:
- `GREEN`: Movement permitted
- `YELLOW`: Caution, signal changing to red
- `RED`: Movement prohibited
- `FLASHING_YELLOW`: Proceed with caution
- `FLASHING_RED`: Treat as stop sign

### SignalPhase

```python
class SignalPhase:
    """
    One phase of traffic signal operation.
    """
    
    id: str                              # Phase identifier
    duration: float                      # Phase duration in seconds
    
    # Permitted movements
    allowed_movements: List[Movement]    # Which movements get green
    protected_left_turns: bool           # Dedicated left-turn arrow
    
    # Movement definitions
    movements: Dict[str, Movement]       # (from_segment, to_segment) -> movement type
```

### Incident

```python
class Incident:
    """
    Traffic incident affecting road capacity.
    """
    
    id: str                              # Unique identifier
    segment_id: str                      # Affected segment
    type: IncidentType                   # ACCIDENT, CONSTRUCTION, BREAKDOWN, WEATHER
    
    # Impact
    capacity_reduction: float            # Fraction of capacity lost (0..1)
    lanes_blocked: int                   # Number of lanes blocked
    
    # Duration
    start_tick: int                      # When incident occurred
    estimated_duration: int              # Expected duration in ticks
    
    def is_active(self, current_tick: int) -> bool:
        """Check if incident is still active."""
        return current_tick < self.start_tick + self.estimated_duration
```



## Interfaces

### TransportSubsystem

```python
class TransportSubsystem:
    """
    Main subsystem managing all transport and traffic operations.
    """
    
    def __init__(self, network: RoadGraph, 
                 route_planner: RoutePlanner,
                 traffic_model: TrafficFlowModel,
                 congestion_model: CongestionModel):
        """Initialize with network and models."""
        
    def update(self, city: City, context: TickContext) -> TrafficDelta:
        """
        Perform traffic updates for one tick.
        
        Execution order:
        1. Update signal controllers at all signalized intersections
        2. Update highway controllers (ramp metering, speed limits)
        3. Generate new vehicles based on demand
        4. Update vehicle positions and speeds
        5. Process vehicles at intersections (queuing, throughput)
        6. Handle vehicle routing decisions (re-routing if needed)
        7. Remove vehicles that reached destination
        8. Update traffic metrics (flow, density, congestion)
        9. Update incidents (new, resolved)
        10. Return TrafficDelta
        
        Args:
            city: City to update (contains infrastructure state)
            context: Tick context with settings and random service
            
        Returns:
            TrafficDelta describing traffic changes and metrics
            
        Side Effects:
            - Modifies vehicle positions and states
            - Updates signal controller states
            - Updates road segment traffic metrics
            - May spawn or remove vehicles
        """
```

### RoutePlanner

```python
class RoutePlanner:
    """
    Plans optimal routes through road network using A*.
    """
    
    def __init__(self, network: RoadGraph, 
                 pathfinding_service: PathfindingService):
        """Initialize with network and pathfinding algorithm."""
        
    def plan_route(self, origin: str, destination: str, 
                   vehicle_type: VehicleType,
                   context: TickContext) -> Optional[Route]:
        """
        Compute optimal route from origin to destination.
        
        Uses A* algorithm with traffic-aware cost function.
        
        Args:
            origin: Starting intersection ID
            destination: Ending intersection ID
            vehicle_type: Type of vehicle (affects allowed roads)
            context: Tick context for current traffic state
            
        Returns:
            Route object if path exists, None if no path found
            
        Raises:
            ValueError: If origin or destination not in network
        """
        
    def replan_if_needed(self, vehicle: Vehicle, network: RoadGraph) -> bool:
        """
        Check if vehicle should re-route due to congestion or incidents.
        
        Re-routing triggers:
        - Incident on upcoming segment
        - Congestion significantly worse than at planning time
        - Route blocked by signal failure
        
        Args:
            vehicle: Vehicle to potentially re-route
            network: Current network state
            
        Returns:
            True if vehicle was re-routed, False otherwise
        """
```

### PathfindingService

```python
class PathfindingService:
    """
    Core pathfinding algorithm implementation (A*).
    """
    
    def find_path(self, graph: RoadGraph, 
                  start: str, goal: str,
                  heuristic: Callable[[str, str], float],
                  cost_function: Callable[[str, str], float]) -> List[str]:
        """
        A* pathfinding on road graph.
        
        Args:
            graph: Road network graph
            start: Starting node ID
            goal: Goal node ID
            heuristic: Heuristic function h(node, goal) -> estimated cost
            cost_function: Edge cost function cost(from_node, to_node) -> actual cost
            
        Returns:
            List of node IDs from start to goal (empty if no path)
            
        Algorithm:
            1. Initialize open set with start node
            2. Initialize closed set (empty)
            3. Track g_score (cost from start), f_score (g + heuristic)
            4. While open set not empty:
                a. Select node with lowest f_score
                b. If node is goal, reconstruct path and return
                c. Move node to closed set
                d. For each neighbor:
                    - Calculate tentative g_score
                    - If better than known g_score, update
                    - Add to open set if not already explored
            5. If open set empty and goal not reached, return empty (no path)
        """
```

### TrafficFlowModel

```python
class TrafficFlowModel:
    """
    Models traffic flow dynamics and vehicle movement.
    """
    
    def calculate_speed(self, vehicle: Vehicle, segment: RoadSegment, 
                       front_vehicle: Optional[Vehicle]) -> float:
        """
        Calculate vehicle speed based on conditions.
        
        Considers:
        - Speed limit
        - Vehicle max speed
        - Following distance (car-following model)
        - Road congestion
        - Weather/condition factors
        
        Args:
            vehicle: Vehicle to calculate speed for
            segment: Current road segment
            front_vehicle: Vehicle ahead (None if no vehicle ahead)
            
        Returns:
            Target speed in m/s
        """
        
    def update_vehicle_position(self, vehicle: Vehicle, dt: float) -> float:
        """
        Update vehicle position for one time step.
        
        Args:
            vehicle: Vehicle to update
            dt: Time step in seconds
            
        Returns:
            Distance traveled in this step (meters)
        """
```

### CongestionModel

```python
class CongestionModel:
    """
    Calculates congestion metrics for network analysis.
    """
    
    def calculate_density(self, segment: RoadSegment) -> float:
        """
        Calculate traffic density (vehicles per km).
        
        density = num_vehicles / (segment.length / 1000)
        """
        
    def calculate_flow_rate(self, segment: RoadSegment, dt: float) -> int:
        """
        Calculate flow rate (vehicles per hour).
        
        flow = (vehicles_passed / dt) * 3600
        """
        
    def calculate_congestion_index(self, network: RoadGraph) -> float:
        """
        Calculate overall network congestion (0..1).
        
        Weighted average of segment congestion levels.
        0 = free flow, 1 = gridlock
        """
```

## A* Pathfinding Algorithm

### Heuristic Functions

**Euclidean Distance** (default for highway/open roads):
```python
def euclidean_heuristic(node_a: str, node_b: str, graph: RoadGraph) -> float:
    """
    Straight-line distance between two intersections.
    """
    pos_a = graph.nodes[node_a].position
    pos_b = graph.nodes[node_b].position
    
    dx = pos_a.x - pos_b.x
    dy = pos_a.y - pos_b.y
    
    return math.sqrt(dx * dx + dy * dy)
```

**Manhattan Distance** (for grid-like city streets):
```python
def manhattan_heuristic(node_a: str, node_b: str, graph: RoadGraph) -> float:
    """
    Grid distance (sum of absolute differences).
    """
    pos_a = graph.nodes[node_a].position
    pos_b = graph.nodes[node_b].position
    
    return abs(pos_a.x - pos_b.x) + abs(pos_a.y - pos_b.y)
```

### Cost Function

**Traffic-Aware Cost**:
```python
def calculate_edge_cost(from_node: str, to_node: str, 
                       graph: RoadGraph, context: TickContext) -> float:
    """
    Calculate cost to traverse edge considering traffic conditions.
    
    Cost components:
    1. Base distance cost
    2. Time cost (distance / speed)
    3. Congestion penalty
    4. Turn penalty (if not straight)
    5. Incident penalty (if incident on segment)
    """
    
    segment = graph.find_segment(from_node, to_node)
    if segment is None:
        return float('inf')
    
    # 1. Base distance
    distance_cost = segment.length
    
    # 2. Time cost (prefer faster roads)
    # Use current average speed if available, else speed limit
    speed = segment.avg_speed if segment.avg_speed > 0 else segment.speed_limit
    time_cost = segment.length / speed
    
    # 3. Congestion penalty
    congestion_factor = segment.get_congestion_factor()
    congestion_penalty = congestion_factor * segment.length * 0.5
    
    # 4. Turn penalty (requires knowing previous segment - context dependent)
    turn_penalty = 0.0  # Calculated during A* based on path
    
    # 5. Incident penalty
    incident_penalty = 0.0
    for incident in segment.incidents:
        if incident.is_active(context.tick_index):
            # Heavy penalty for incidents
            incident_penalty += segment.length * 2.0 * incident.capacity_reduction
    
    # Combine costs (weights can be tuned)
    total_cost = distance_cost + time_cost * 10 + congestion_penalty + incident_penalty
    
    return total_cost
```

### A* Implementation

```python
def a_star_search(graph: RoadGraph, start: str, goal: str, 
                 context: TickContext) -> Optional[List[str]]:
    """
    A* pathfinding implementation.
    """
    
    # Priority queue: (f_score, node_id)
    open_set = [(0.0, start)]
    
    # Track visited nodes
    closed_set = set()
    
    # Cost from start to node
    g_score = {start: 0.0}
    
    # Estimated total cost (g + h)
    f_score = {start: euclidean_heuristic(start, goal, graph)}
    
    # Track path
    came_from = {}
    
    while open_set:
        # Get node with lowest f_score
        current_f, current = heapq.heappop(open_set)
        
        # Goal reached
        if current == goal:
            return reconstruct_path(came_from, current)
        
        # Skip if already processed
        if current in closed_set:
            continue
            
        closed_set.add(current)
        
        # Examine neighbors
        for neighbor_id in graph.adjacency.get(current, []):
            neighbor_segment = graph.edges[neighbor_id]
            neighbor = neighbor_segment.to_intersection
            
            # Skip if already processed
            if neighbor in closed_set:
                continue
            
            # Calculate tentative g_score
            edge_cost = calculate_edge_cost(current, neighbor, graph, context)
            tentative_g = g_score[current] + edge_cost
            
            # Update if better path found
            if neighbor not in g_score or tentative_g < g_score[neighbor]:
                came_from[neighbor] = current
                g_score[neighbor] = tentative_g
                f = tentative_g + euclidean_heuristic(neighbor, goal, graph)
                f_score[neighbor] = f
                heapq.heappush(open_set, (f, neighbor))
    
    # No path found
    return None


def reconstruct_path(came_from: Dict[str, str], current: str) -> List[str]:
    """Reconstruct path from start to goal."""
    path = [current]
    while current in came_from:
        current = came_from[current]
        path.append(current)
    path.reverse()
    return path
```

### Pathfinding Optimizations

**Early Exit**: Stop when goal is reached (not when open set empty)
**Tie-Breaking**: Add small random factor to f_score to avoid systematic bias
**Caching**: Cache routes for common origin-destination pairs (invalidate on network changes)
**Hierarchical Routing**: Precompute routes between major intersections, then fill in local segments

## Traffic Flow Model

### Car-Following Model (Intelligent Driver Model - IDM)

```python
def calculate_idm_acceleration(vehicle: Vehicle, front_vehicle: Optional[Vehicle],
                               segment: RoadSegment) -> float:
    """
    Calculate acceleration using Intelligent Driver Model.
    
    IDM parameters:
    - v0: desired speed (speed limit)
    - T: desired time headway (1.5 seconds typical)
    - a: max acceleration
    - b: comfortable deceleration
    - δ: acceleration exponent (4 typical)
    - s0: minimum spacing (2 meters typical)
    """
    
    v0 = min(vehicle.max_speed, segment.speed_limit)
    T = 1.5  # seconds
    a = vehicle.max_acceleration
    b = 4.0  # comfortable deceleration m/s²
    delta = 4
    s0 = 2.0  # meters
    
    v = vehicle.speed
    
    # Free-flow acceleration
    free_term = a * (1 - (v / v0) ** delta)
    
    if front_vehicle is None:
        # No vehicle ahead, accelerate toward desired speed
        return free_term
    
    # Calculate spacing
    s = front_vehicle.position - vehicle.position - front_vehicle.length
    dv = v - front_vehicle.speed  # Approach rate
    
    # Desired spacing
    s_star = s0 + max(0, v * T + (v * dv) / (2 * math.sqrt(a * b)))
    
    # Interaction term
    interaction_term = a * (s_star / s) ** 2
    
    # Total acceleration
    accel = free_term - interaction_term
    
    # Clamp to vehicle limits
    return max(vehicle.max_deceleration, min(vehicle.max_acceleration, accel))
```

### Speed Adjustment

```python
def update_vehicle_speed(vehicle: Vehicle, segment: RoadSegment,
                        front_vehicle: Optional[Vehicle], dt: float):
    """
    Update vehicle speed for one time step.
    """
    
    # Calculate target acceleration
    accel = calculate_idm_acceleration(vehicle, front_vehicle, segment)
    
    # Update speed
    new_speed = vehicle.speed + accel * dt
    
    # Clamp to valid range
    new_speed = max(0.0, min(segment.speed_limit, vehicle.max_speed, new_speed))
    
    vehicle.speed = new_speed
```

### Congestion Calculation

**Level of Service (LOS)** based on density:
```python
def calculate_level_of_service(density: float, capacity_density: float) -> str:
    """
    Calculate Level of Service (A-F) based on density ratio.
    
    LOS Thresholds (density/capacity):
    A: 0.00 - 0.20 (free flow)
    B: 0.20 - 0.35 (stable flow)
    C: 0.35 - 0.50 (stable but restricted)
    D: 0.50 - 0.70 (approaching unstable)
    E: 0.70 - 1.00 (unstable flow)
    F: 1.00+       (forced/breakdown flow)
    """
    ratio = density / capacity_density if capacity_density > 0 else 0
    
    if ratio < 0.20:
        return 'A'
    elif ratio < 0.35:
        return 'B'
    elif ratio < 0.50:
        return 'C'
    elif ratio < 0.70:
        return 'D'
    elif ratio < 1.00:
        return 'E'
    else:
        return 'F'
```

**Congestion Index** (network-wide):
```python
def calculate_network_congestion(network: RoadGraph) -> float:
    """
    Calculate overall network congestion index (0..1).
    
    Weighted by segment capacity (larger roads have more influence).
    """
    total_weight = 0.0
    weighted_congestion = 0.0
    
    for segment in network.edges.values():
        weight = segment.capacity
        congestion = segment.get_congestion_factor()
        
        weighted_congestion += congestion * weight
        total_weight += weight
    
    if total_weight == 0:
        return 0.0
    
    return weighted_congestion / total_weight
```

## Signal Control Logic

### Fixed-Time Signal Control

```python
class FixedTimeSignalController(SignalController):
    """
    Traditional fixed-time traffic signal.
    """
    
    def __init__(self, intersection_id: str, cycle_length: float,
                 phase_timings: List[float]):
        """
        Initialize fixed-time controller.
        
        Args:
            intersection_id: Controlled intersection
            cycle_length: Total cycle time in seconds
            phase_timings: Duration of each phase in seconds
        """
        self.intersection_id = intersection_id
        self.cycle_length = cycle_length
        self.phases = self._create_phases(phase_timings)
        self.current_phase = 0
        self.phase_elapsed = 0.0
        
    def update(self, dt: float, network: RoadGraph):
        """Update signal state."""
        self.phase_elapsed += dt
        
        current_phase_duration = self.phases[self.current_phase].duration
        
        if self.phase_elapsed >= current_phase_duration:
            # Advance to next phase
            self.current_phase = (self.current_phase + 1) % len(self.phases)
            self.phase_elapsed = 0.0
```

### Adaptive Signal Control (Traffic-Responsive)

```python
class AdaptiveSignalController(SignalController):
    """
    Traffic-responsive signal controller.
    
    Adjusts green time based on queue lengths and traffic demand.
    """
    
    def __init__(self, intersection_id: str, min_green: float = 10.0,
                 max_green: float = 60.0):
        """Initialize adaptive controller with timing bounds."""
        self.intersection_id = intersection_id
        self.min_green_time = min_green
        self.max_green_time = max_green
        self.current_phase = 0
        self.phase_elapsed = 0.0
        
    def update(self, dt: float, network: RoadGraph):
        """Update signal with traffic-responsive logic."""
        self.phase_elapsed += dt
        
        intersection = network.nodes[self.intersection_id]
        
        # Calculate demand for each approach
        demand = self._calculate_demand(intersection, network)
        
        # Determine green time for current phase
        green_time = self._calculate_green_time(demand)
        
        if self.phase_elapsed >= green_time:
            # Select next phase based on demand
            self.current_phase = self._select_next_phase(demand)
            self.phase_elapsed = 0.0
    
    def _calculate_green_time(self, demand: Dict[int, float]) -> float:
        """
        Calculate appropriate green time for current phase.
        
        Based on queue length and arrival rate.
        """
        current_demand = demand.get(self.current_phase, 0.0)
        
        # Linear interpolation between min and max
        # Higher demand → longer green
        normalized_demand = min(1.0, current_demand / 20.0)  # 20 vehicles = max demand
        
        green_time = self.min_green_time + normalized_demand * (self.max_green_time - self.min_green_time)
        
        return green_time
```

## Highway Traffic Control

### Ramp Metering

```python
class RampMeteringController:
    """
    Controls traffic entering highway via on-ramps.
    """
    
    def __init__(self, ramp_segment_id: str, mainline_segment_id: str):
        """
        Initialize ramp meter.
        
        Args:
            ramp_segment_id: On-ramp segment ID
            mainline_segment_id: Highway mainline segment ID
        """
        self.ramp_segment_id = ramp_segment_id
        self.mainline_segment_id = mainline_segment_id
        self.metering_rate = 900  # vehicles/hour (default)
        
    def update(self, network: RoadGraph, dt: float):
        """
        Update metering rate based on mainline conditions.
        """
        mainline = network.edges[self.mainline_segment_id]
        
        # Check mainline congestion
        congestion = mainline.get_congestion_factor()
        
        if congestion < 0.5:
            # Free-flow: allow higher ramp rate
            self.metering_rate = 1200  # veh/hr
        elif congestion < 0.7:
            # Moderate: standard rate
            self.metering_rate = 900  # veh/hr
        else:
            # Heavy congestion: restrict ramp entry
            self.metering_rate = 600  # veh/hr
            
    def can_vehicle_enter(self, current_time: float) -> bool:
        """
        Check if vehicle can enter based on metering rate.
        """
        # Convert rate to time between vehicles
        seconds_per_vehicle = 3600.0 / self.metering_rate
        
        # Simple time-based metering (could be enhanced with queue management)
        return (current_time % seconds_per_vehicle) < 0.5
```

### Speed Harmonization

```python
class SpeedHarmonizationController:
    """
    Adjusts highway speed limits to smooth traffic flow.
    """
    
    def __init__(self, controlled_segments: List[str]):
        """
        Initialize speed harmonization for highway segments.
        
        Args:
            controlled_segments: List of segment IDs to control
        """
        self.controlled_segments = controlled_segments
        self.base_speed_limits = {}  # segment_id -> original speed limit
        
    def update(self, network: RoadGraph):
        """
        Adjust speed limits based on downstream conditions.
        """
        for segment_id in self.controlled_segments:
            segment = network.edges[segment_id]
            
            # Store original if not already stored
            if segment_id not in self.base_speed_limits:
                self.base_speed_limits[segment_id] = segment.speed_limit
            
            # Check downstream congestion
            downstream_congestion = self._get_downstream_congestion(segment, network)
            
            if downstream_congestion > 0.7:
                # Reduce speed to prevent shockwaves
                segment.speed_limit = self.base_speed_limits[segment_id] * 0.7
            elif downstream_congestion > 0.5:
                # Moderate reduction
                segment.speed_limit = self.base_speed_limits[segment_id] * 0.85
            else:
                # Restore normal speed
                segment.speed_limit = self.base_speed_limits[segment_id]
    
    def _get_downstream_congestion(self, segment: RoadSegment, 
                                   network: RoadGraph) -> float:
        """Calculate average congestion in downstream segments."""
        # Look ahead 2-3 segments
        # (Implementation would traverse graph to find downstream segments)
        return 0.0  # Placeholder
```



## Vehicle Movement and Updates

### Vehicle Spawning

```python
def spawn_vehicles(network: RoadGraph, demand_model: TravelDemandModel,
                   context: TickContext) -> List[Vehicle]:
    """
    Generate new vehicles based on travel demand.
    
    Args:
        network: Road network
        demand_model: Model for origin-destination demand
        context: Tick context with random service
        
    Returns:
        List of newly spawned vehicles
    """
    
    new_vehicles = []
    
    # Get OD (origin-destination) pairs for this tick
    od_pairs = demand_model.generate_od_pairs(context)
    
    for origin_id, dest_id, vehicle_type in od_pairs:
        # Plan route
        route = plan_route(origin_id, dest_id, vehicle_type, context)
        
        if route is None:
            continue  # No path available
        
        # Create vehicle
        vehicle = Vehicle(
            id=f"veh_{context.tick_index}_{len(new_vehicles)}",
            type=vehicle_type,
            length=get_vehicle_length(vehicle_type),
            max_speed=get_max_speed(vehicle_type),
            max_acceleration=get_max_acceleration(vehicle_type),
            max_deceleration=get_max_deceleration(vehicle_type),
            current_segment=route.segments[0],
            current_lane=0,
            position=0.0,
            speed=0.0,
            route=route,
            route_progress=0,
            destination=dest_id,
            trip_start_time=context.tick_index,
            trip_distance=0.0
        )
        
        new_vehicles.append(vehicle)
    
    return new_vehicles
```

### Vehicle Position Update

```python
def update_all_vehicles(vehicles: List[Vehicle], network: RoadGraph, dt: float):
    """
    Update positions and speeds for all vehicles.
    
    Args:
        vehicles: List of all active vehicles
        network: Road network
        dt: Time step in seconds
    """
    
    for vehicle in vehicles:
        if vehicle.current_segment is None:
            continue  # Vehicle not in network
        
        segment = network.edges[vehicle.current_segment]
        
        # Find vehicle ahead in same lane
        front_vehicle = find_front_vehicle(vehicle, vehicles, segment)
        
        # Update speed based on conditions
        update_vehicle_speed(vehicle, segment, front_vehicle, dt)
        
        # Update position
        old_position = vehicle.position
        vehicle.position += vehicle.speed * dt
        vehicle.trip_distance += vehicle.speed * dt
        
        # Check if reached end of segment
        if vehicle.position >= segment.length:
            advance_to_next_segment(vehicle, network)
```

### Lane Changing

```python
def consider_lane_change(vehicle: Vehicle, segment: RoadSegment,
                        all_vehicles: List[Vehicle]) -> bool:
    """
    Determine if vehicle should change lanes.
    
    Lane change motivations:
    1. Current lane ending (forced)
    2. Faster adjacent lane (discretionary)
    3. Preparing for turn (anticipatory)
    
    Args:
        vehicle: Vehicle considering lane change
        segment: Current road segment
        all_vehicles: All vehicles for gap acceptance
        
    Returns:
        True if lane change executed, False otherwise
    """
    
    if len(segment.lanes) <= 1:
        return False  # No other lanes available
    
    current_lane_idx = vehicle.current_lane
    
    # Check mandatory lane change (lane ending)
    if is_lane_ending(vehicle, segment):
        target_lane = current_lane_idx - 1 if current_lane_idx > 0 else current_lane_idx + 1
        if can_change_lane(vehicle, target_lane, segment, all_vehicles):
            vehicle.current_lane = target_lane
            return True
        return False
    
    # Discretionary lane change (seek faster lane)
    left_lane = current_lane_idx + 1
    right_lane = current_lane_idx - 1
    
    # Try left lane first (passing lane in many countries)
    if left_lane < len(segment.lanes):
        if is_lane_faster(left_lane, current_lane_idx, segment, all_vehicles):
            if can_change_lane(vehicle, left_lane, segment, all_vehicles):
                vehicle.current_lane = left_lane
                return True
    
    # Try right lane
    if right_lane >= 0:
        if is_lane_faster(right_lane, current_lane_idx, segment, all_vehicles):
            if can_change_lane(vehicle, right_lane, segment, all_vehicles):
                vehicle.current_lane = right_lane
                return True
    
    return False
```

## Integration with City Infrastructure

### Infrastructure State Impact on Traffic

```python
def apply_infrastructure_effects(network: RoadGraph, city: City):
    """
    Update road network based on city infrastructure state.
    
    Infrastructure affects:
    - Road condition (affects speed and safety)
    - Capacity (well-maintained roads handle more traffic)
    - Incidents (poor infrastructure → more breakdowns)
    """
    
    if not hasattr(city.state, 'infrastructure'):
        return
    
    transport_quality = city.state.infrastructure.transport_quality
    
    # Normalize quality (0..100) to factor (0..1)
    quality_factor = transport_quality / 100.0
    
    for segment in network.edges.values():
        # Update road condition
        segment.condition = quality_factor
        
        # Adjust effective capacity based on condition
        # Poor roads → reduced effective capacity
        base_capacity = segment.capacity
        segment.effective_capacity = base_capacity * (0.5 + 0.5 * quality_factor)
        
        # Adjust speed limit based on condition
        # Poor roads → lower safe speeds
        if quality_factor < 0.5:
            segment.safe_speed_limit = segment.speed_limit * quality_factor
        else:
            segment.safe_speed_limit = segment.speed_limit
```

### Population Impact on Travel Demand

```python
class TravelDemandModel:
    """
    Generates travel demand based on population and city structure.
    """
    
    def __init__(self, trips_per_capita: float = 2.5):
        """
        Initialize demand model.
        
        Args:
            trips_per_capita: Average daily trips per person
        """
        self.trips_per_capita = trips_per_capita
        
    def generate_od_pairs(self, city: City, context: TickContext) -> List[Tuple[str, str, VehicleType]]:
        """
        Generate origin-destination pairs for this tick.
        
        Args:
            city: City state (includes population)
            context: Tick context
            
        Returns:
            List of (origin_id, destination_id, vehicle_type) tuples
        """
        
        population = city.state.population
        
        # Calculate trips this tick
        # Assume 365 ticks per year, trips spread throughout day
        ticks_per_day = context.settings.ticks_per_day or 24
        trips_per_tick = (population * self.trips_per_capita) / ticks_per_day
        
        # Add stochastic variation
        actual_trips = context.random_service.poisson(trips_per_tick)
        
        od_pairs = []
        
        for _ in range(actual_trips):
            # Randomly select origin and destination from available zones
            origin = context.random_service.choice(city.districts).get_random_intersection()
            dest = context.random_service.choice(city.districts).get_random_intersection()
            
            if origin == dest:
                continue  # Skip same origin-destination
            
            # Vehicle type distribution (90% passenger, 8% truck, 2% bus)
            rand = context.random_service.random()
            if rand < 0.90:
                vehicle_type = VehicleType.PASSENGER
            elif rand < 0.98:
                vehicle_type = VehicleType.TRUCK
            else:
                vehicle_type = VehicleType.BUS
            
            od_pairs.append((origin, dest, vehicle_type))
        
        return od_pairs
```

## Usage Examples

### Example 1: Initialize Transport Network

```python
# Create road network
network = RoadGraph()

# Add intersections
int_1 = Intersection(id="int_1", position=Position(0, 0), type=IntersectionType.SIGNALIZED)
int_2 = Intersection(id="int_2", position=Position(1000, 0), type=IntersectionType.SIGNALIZED)
int_3 = Intersection(id="int_3", position=Position(1000, 1000), type=IntersectionType.STOP)

network.nodes["int_1"] = int_1
network.nodes["int_2"] = int_2
network.nodes["int_3"] = int_3

# Add road segments
seg_1_2 = RoadSegment(
    id="seg_1_2",
    from_intersection="int_1",
    to_intersection="int_2",
    lanes=[Lane(id="lane_1", index=0, length=1000.0)],
    length=1000.0,
    speed_limit=13.4,  # 30 mph
    capacity=1200,
    road_type=RoadType.ARTERIAL
)

network.edges["seg_1_2"] = seg_1_2
network.adjacency["int_1"] = ["seg_1_2"]

# Add signal controllers
signal_1 = FixedTimeSignalController(
    intersection_id="int_1",
    cycle_length=90.0,
    phase_timings=[30.0, 30.0, 30.0]  # Three phases, 30 seconds each
)
int_1.signal_controller = signal_1

# Initialize subsystem
route_planner = RoutePlanner(network, PathfindingService())
traffic_model = TrafficFlowModel()
congestion_model = CongestionModel()

transport_subsystem = TransportSubsystem(
    network=network,
    route_planner=route_planner,
    traffic_model=traffic_model,
    congestion_model=congestion_model
)
```

### Example 2: Plan Route with A*

```python
# Plan route from int_1 to int_3
origin = "int_1"
destination = "int_3"
vehicle_type = VehicleType.PASSENGER

route = route_planner.plan_route(origin, destination, vehicle_type, context)

if route:
    print(f"Route found: {route.segments}")
    print(f"Total distance: {route.total_distance:.1f} meters")
    print(f"Estimated time: {route.estimated_time:.1f} seconds")
else:
    print("No route found")

# Example output:
# Route found: ['seg_1_2', 'seg_2_3']
# Total distance: 2000.0 meters
# Estimated time: 180.5 seconds
```

### Example 3: Simulate Traffic for One Tick

```python
# Update transport subsystem
delta = transport_subsystem.update(city, context)

# Log results
print(f"Active vehicles: {delta.vehicles_active}")
print(f"Average speed: {delta.avg_speed:.2f} m/s ({delta.avg_speed * 2.237:.1f} mph)")
print(f"Congestion index: {delta.congestion_index:.2%}")
print(f"Vehicles entered: {delta.vehicles_entered}")
print(f"Vehicles exited: {delta.vehicles_exited}")

# Example output:
# Active vehicles: 1523
# Average speed: 11.34 m/s (25.4 mph)
# Congestion index: 42.30%
# Vehicles entered: 87
# Vehicles exited: 82
```

### Example 4: Adaptive Signal Control

```python
# Create adaptive signal controller
adaptive_signal = AdaptiveSignalController(
    intersection_id="int_1",
    min_green=10.0,
    max_green=60.0
)

int_1.signal_controller = adaptive_signal

# Simulate multiple ticks
for tick in range(100):
    context = create_tick_context(tick)
    
    # Update signal based on traffic conditions
    adaptive_signal.update(dt=1.0, network=network)
    
    # Update vehicles
    delta = transport_subsystem.update(city, context)
    
    # Monitor signal performance
    if tick % 10 == 0:
        print(f"Tick {tick}: Phase {adaptive_signal.current_phase}, " +
              f"Elapsed {adaptive_signal.phase_elapsed:.1f}s, " +
              f"Congestion {delta.congestion_index:.2%}")

# Example output:
# Tick 0: Phase 0, Elapsed 0.0s, Congestion 35.20%
# Tick 10: Phase 1, Elapsed 8.3s, Congestion 38.45%
# Tick 20: Phase 2, Elapsed 5.7s, Congestion 41.10%
# ...
```

### Example 5: Handle Traffic Incident

```python
# Create incident on segment
incident = Incident(
    id="inc_001",
    segment_id="seg_1_2",
    type=IncidentType.ACCIDENT,
    capacity_reduction=0.5,  # 50% capacity lost
    lanes_blocked=1,
    start_tick=context.tick_index,
    estimated_duration=120  # 120 ticks (~2 hours if tick = 1 min)
)

# Add to segment
segment = network.edges["seg_1_2"]
segment.incidents.append(incident)

# Re-route affected vehicles
for vehicle in active_vehicles:
    if vehicle.route and "seg_1_2" in vehicle.route.segments:
        # Check if vehicle hasn't reached incident yet
        current_idx = vehicle.route.segments.index(vehicle.current_segment)
        incident_idx = vehicle.route.segments.index("seg_1_2")
        
        if current_idx < incident_idx:
            # Re-plan route to avoid incident
            new_route = route_planner.plan_route(
                vehicle.current_segment,
                vehicle.destination,
                vehicle.type,
                context
            )
            
            if new_route:
                vehicle.route = new_route
                print(f"Vehicle {vehicle.id} re-routed around incident")

# Monitor incident impact
delta = transport_subsystem.update(city, context)
print(f"Incidents active: {delta.incidents_active}")
print(f"Congestion increased to: {delta.congestion_index:.2%}")

# Example output:
# Vehicle veh_42_15 re-routed around incident
# Vehicle veh_42_28 re-routed around incident
# Incidents active: 1
# Congestion increased to: 58.75%
```

## Edge Cases

### Gridlock Detection and Resolution

**Scenario**: Circular dependency where vehicles block each other

**Detection**:
```python
def detect_gridlock(network: RoadGraph, vehicles: List[Vehicle]) -> bool:
    """
    Detect if network is in gridlock state.
    
    Gridlock indicators:
    - All intersections have full queues
    - No vehicles moving (avg speed near zero)
    - Persists for multiple ticks
    """
    
    all_queues_full = all(
        len(intersection.queue_length) > 0 and 
        max(intersection.queue_length.values()) >= 10
        for intersection in network.nodes.values()
    )
    
    no_movement = all(v.speed < 0.1 for v in vehicles)
    
    return all_queues_full and no_movement
```

**Resolution**:
```python
def resolve_gridlock(network: RoadGraph, vehicles: List[Vehicle]):
    """
    Break gridlock by temporarily removing vehicles.
    
    Strategy:
    1. Identify vehicles contributing to deadlock
    2. Remove subset of vehicles (teleport to destination)
    3. Log gridlock event for analysis
    """
    
    # Remove 10% of vehicles to break deadlock
    num_to_remove = max(1, len(vehicles) // 10)
    
    for i in range(num_to_remove):
        vehicle = vehicles[i]
        # Teleport to destination (count as completed trip)
        vehicle.current_segment = None
        vehicle.route = None
        
    logger.warning(f"Gridlock resolved by removing {num_to_remove} vehicles")
```

### No Route Available

**Scenario**: No path exists from origin to destination

**Handling**:
```python
def handle_no_route(vehicle: Vehicle, origin: str, destination: str,
                   context: TickContext) -> bool:
    """
    Handle case where no route can be found.
    
    Options:
    1. Try alternative destination in same zone
    2. Wait and retry (network may change)
    3. Cancel trip
    """
    
    # Try up to 3 alternative destinations
    for attempt in range(3):
        # Find nearby alternative destination
        alt_dest = find_nearby_intersection(destination, network, radius=500)
        
        if alt_dest:
            route = plan_route(origin, alt_dest, vehicle.type, context)
            if route:
                vehicle.destination = alt_dest
                vehicle.route = route
                return True
    
    # No alternatives found - cancel trip
    logger.warning(f"No route found for vehicle {vehicle.id} " +
                  f"from {origin} to {destination}")
    return False
```

### Empty Network (No Vehicles)

**Scenario**: No vehicles currently in network

**Handling**:
```python
def update_empty_network(network: RoadGraph, context: TickContext) -> TrafficDelta:
    """
    Handle update when no vehicles present.
    
    Still need to:
    - Update signal controllers
    - Clear segment metrics
    - Return valid delta
    """
    
    # Update signals (continue normal operation)
    for intersection in network.nodes.values():
        if intersection.signal_controller:
            intersection.signal_controller.update(dt=1.0, network=network)
    
    # Clear metrics
    for segment in network.edges.values():
        segment.vehicles = []
        segment.density = 0.0
        segment.avg_speed = segment.speed_limit  # Free-flow speed
        segment.flow_rate = 0
    
    # Return zero-traffic delta
    return TrafficDelta(
        vehicles_entered=0,
        vehicles_exited=0,
        vehicles_active=0,
        avg_speed=0.0,
        avg_travel_time=0.0,
        total_distance_traveled=0.0,
        total_throughput=0,
        congestion_index=0.0,
        congested_segments=0,
        max_queue_length=0,
        avg_density=0.0,
        incidents_active=0,
        incidents_resolved=0,
        tick_index=context.tick_index
    )
```

### Disconnected Network Components

**Scenario**: Road network has isolated components (not fully connected)

**Detection and Handling**:
```python
def find_connected_components(network: RoadGraph) -> List[Set[str]]:
    """
    Find connected components in road network.
    
    Uses DFS to identify separate subgraphs.
    """
    
    visited = set()
    components = []
    
    for node_id in network.nodes.keys():
        if node_id in visited:
            continue
        
        # DFS to find component
        component = set()
        stack = [node_id]
        
        while stack:
            current = stack.pop()
            if current in visited:
                continue
            
            visited.add(current)
            component.add(current)
            
            # Add neighbors
            for segment_id in network.adjacency.get(current, []):
                segment = network.edges[segment_id]
                neighbor = segment.to_intersection
                if neighbor not in visited:
                    stack.append(neighbor)
        
        components.append(component)
    
    return components


def validate_route_reachability(origin: str, destination: str,
                                network: RoadGraph) -> bool:
    """
    Check if destination is reachable from origin.
    
    Uses connected components to quickly reject impossible routes.
    """
    
    components = find_connected_components(network)
    
    for component in components:
        if origin in component and destination in component:
            return True
    
    return False
```

### Vehicle Collisions (Simulation Error)

**Scenario**: Two vehicles occupy same space (should never happen)

**Detection**:
```python
def detect_collisions(vehicles: List[Vehicle]) -> List[Tuple[str, str]]:
    """
    Detect if any vehicles occupy same position (error condition).
    """
    
    collisions = []
    
    # Group by segment and lane
    by_location = {}
    for vehicle in vehicles:
        if vehicle.current_segment is None:
            continue
        
        key = (vehicle.current_segment, vehicle.current_lane)
        if key not in by_location:
            by_location[key] = []
        by_location[key].append(vehicle)
    
    # Check for overlaps
    for vehicles_in_lane in by_location.values():
        for i, v1 in enumerate(vehicles_in_lane):
            for v2 in vehicles_in_lane[i+1:]:
                # Check if positions overlap (considering vehicle length)
                if abs(v1.position - v2.position) < max(v1.length, v2.length):
                    collisions.append((v1.id, v2.id))
                    
    return collisions
```

**Recovery**:
```python
def resolve_collision(v1: Vehicle, v2: Vehicle):
    """
    Resolve collision by adjusting positions.
    
    Place rear vehicle behind front vehicle with safe gap.
    """
    
    if v1.position > v2.position:
        front, rear = v1, v2
    else:
        front, rear = v2, v1
    
    # Place rear vehicle behind with 2-meter gap
    rear.position = front.position - front.length - 2.0
    rear.speed = min(rear.speed, front.speed)
    
    logger.error(f"Collision detected between {v1.id} and {v2.id} - positions adjusted")
```

## Performance Considerations

### Graph Algorithm Optimization

**Priority Queue Efficiency**:
- Use binary heap (`heapq`) for O(log n) operations
- Consider Fibonacci heap for better theoretical bounds (complex implementation)

**A* Optimizations**:
1. **Bidirectional Search**: Search from both origin and destination simultaneously
2. **Landmark Heuristics**: Precompute distances to landmark nodes for better heuristic
3. **Contraction Hierarchies**: Preprocess graph to create shortcuts for faster queries
4. **Caching**: Store frequently used routes (invalidate on network changes)

```python
class RouteCache:
    """
    Cache for storing computed routes.
    """
    
    def __init__(self, max_size: int = 10000):
        self.cache = {}
        self.max_size = max_size
        self.access_count = {}
        
    def get(self, origin: str, destination: str) -> Optional[Route]:
        """Retrieve cached route."""
        key = (origin, destination)
        if key in self.cache:
            self.access_count[key] = self.access_count.get(key, 0) + 1
            return self.cache[key]
        return None
    
    def put(self, origin: str, destination: str, route: Route):
        """Store route in cache."""
        if len(self.cache) >= self.max_size:
            # Evict least-recently-used
            lru_key = min(self.access_count.keys(), key=lambda k: self.access_count[k])
            del self.cache[lru_key]
            del self.access_count[lru_key]
        
        key = (origin, destination)
        self.cache[key] = route
        self.access_count[key] = 0
    
    def invalidate_segment(self, segment_id: str):
        """Invalidate all routes using a segment."""
        to_remove = []
        for key, route in self.cache.items():
            if segment_id in route.segments:
                to_remove.append(key)
        
        for key in to_remove:
            del self.cache[key]
            del self.access_count[key]
```

### Real-Time Constraints

**Time Budget per Tick**:
- Target: Complete update in <100ms for interactive simulation
- Allocation:
  - Pathfinding: 30ms (with caching, amortized)
  - Vehicle updates: 40ms
  - Signal updates: 10ms
  - Metrics calculation: 10ms
  - Overhead: 10ms

**Scaling Strategies**:
1. **Spatial Partitioning**: Divide network into regions, update independently
2. **Level of Detail**: Update distant vehicles less frequently
3. **Parallel Processing**: Update independent components in parallel
4. **Incremental Updates**: Spread expensive calculations across multiple ticks

```python
class SpatialPartitioner:
    """
    Partition network into regions for efficient updates.
    """
    
    def __init__(self, network: RoadGraph, grid_size: float = 5000.0):
        """
        Partition network into grid cells.
        
        Args:
            network: Road network to partition
            grid_size: Size of each grid cell in meters
        """
        self.grid_size = grid_size
        self.cells = self._partition_network(network)
    
    def _partition_network(self, network: RoadGraph) -> Dict[Tuple[int, int], List[str]]:
        """Assign segments to grid cells."""
        cells = {}
        
        for segment_id, segment in network.edges.items():
            # Get segment midpoint
            from_pos = network.nodes[segment.from_intersection].position
            to_pos = network.nodes[segment.to_intersection].position
            
            mid_x = (from_pos.x + to_pos.x) / 2
            mid_y = (from_pos.y + to_pos.y) / 2
            
            # Determine cell
            cell_x = int(mid_x // self.grid_size)
            cell_y = int(mid_y // self.grid_size)
            cell = (cell_x, cell_y)
            
            if cell not in cells:
                cells[cell] = []
            cells[cell].append(segment_id)
        
        return cells
    
    def get_nearby_segments(self, position: Position, radius: float) -> List[str]:
        """Get segments within radius of position."""
        # Calculate cell range
        cell_radius = int(math.ceil(radius / self.grid_size))
        
        center_x = int(position.x // self.grid_size)
        center_y = int(position.y // self.grid_size)
        
        nearby_segments = []
        
        for dx in range(-cell_radius, cell_radius + 1):
            for dy in range(-cell_radius, cell_radius + 1):
                cell = (center_x + dx, center_y + dy)
                if cell in self.cells:
                    nearby_segments.extend(self.cells[cell])
        
        return nearby_segments
```

### Memory Management

**Large Network Handling**:
- Avoid storing full vehicle history (keep only current state + summary stats)
- Use efficient data structures (arrays over objects where possible)
- Limit active vehicles (cap based on network capacity)

## Testing Strategy

### Unit Tests

**Pathfinding Tests**:
- Test A* correctness on known graphs
- Test heuristic admissibility (never overestimates)
- Test handling of disconnected components
- Test cost function accuracy

**Traffic Flow Tests**:
- Test IDM car-following model
- Test speed adjustment (acceleration/deceleration)
- Test position update accuracy
- Test lane change logic

**Signal Control Tests**:
- Test fixed-time controller phase progression
- Test adaptive controller response to demand
- Test signal state queries

**Congestion Tests**:
- Test density calculation
- Test flow rate calculation
- Test congestion index accuracy
- Test Level of Service classification

### Integration Tests

**Full Traffic Update**:
- Test complete update cycle with vehicles and signals
- Verify all subsystems interact correctly
- Test over multiple ticks (vehicle trips complete)

**Route Planning Integration**:
- Test pathfinding with real network topology
- Test re-routing on incidents
- Test route caching and invalidation

**Infrastructure Integration**:
- Test transport quality affecting road conditions
- Test population affecting travel demand
- Test finance affecting infrastructure maintenance

### Edge Case Tests

**Gridlock**:
- Create scenario with circular dependencies
- Verify detection triggers
- Verify resolution breaks deadlock

**No Route**:
- Create disconnected network
- Verify pathfinding fails gracefully
- Test alternative destination logic

**Empty Network**:
- Initialize with zero vehicles
- Verify update succeeds
- Verify metrics are zero/valid

**High Congestion**:
- Saturate network with vehicles
- Verify congestion index approaches 1.0
- Verify vehicles still move (no complete freeze)

**Incidents**:
- Create incidents on critical segments
- Verify capacity reduction applied
- Verify re-routing occurs
- Verify incident expiration

### Property-Based Tests

**Conservation of Vehicles**:
- Track vehicles_active, vehicles_entered, vehicles_exited
- Verify: vehicles_active[t+1] = vehicles_active[t] + entered - exited

**Speed Limits Respected**:
- Verify all vehicles: speed <= min(vehicle.max_speed, segment.speed_limit)

**Position Validity**:
- Verify all vehicles: 0 <= position <= segment.length

**Route Consistency**:
- Verify vehicle's current_segment is in vehicle.route.segments

**Determinism**:
- Run same scenario twice with same seed
- Verify identical vehicle trajectories and metrics

### Performance Tests

**Pathfinding Performance**:
- Measure time to compute routes on networks of various sizes
- Target: <10ms for typical urban network (1000 nodes)

**Update Performance**:
- Measure tick time with varying vehicle counts
- Target: <100ms for 10,000 active vehicles

**Memory Usage**:
- Track memory consumption with large vehicle fleets
- Target: <1 GB for 50,000 vehicles

## Acceptance Criteria

A compliant Transport & Traffic Subsystem implementation must satisfy:

1. **Graph Integrity**
   - Road network topology remains valid (no orphaned nodes)
   - All segment endpoints reference valid intersections
   - Verified via graph validation every tick

2. **Deterministic Simulation**
   - Same city state + context + seed → identical traffic outcomes
   - Stochastic elements (vehicle spawning, demand) use seeded RNG
   - Verified via determinism tests

3. **Valid Pathfinding**
   - A* finds optimal or near-optimal routes when path exists
   - Returns None when no path exists (disconnected components)
   - Re-routes around incidents and heavy congestion
   - Verified via pathfinding tests with known graphs

4. **Realistic Traffic Flow**
   - Vehicles respect speed limits and vehicle max speeds
   - Car-following model prevents collisions
   - Traffic flow respects capacity constraints
   - Verified via flow model tests

5. **Congestion Metrics Accurate**
   - Congestion index in range [0, 1]
   - Density = vehicles / length
   - Flow rate matches vehicle throughput
   - Verified via congestion model tests

6. **Signal Controllers Function**
   - Fixed-time controllers cycle through phases
   - Adaptive controllers respond to traffic demand
   - Signal states correctly allow/prohibit movements
   - Verified via signal controller tests

7. **Vehicle Conservation**
   - vehicles_active = previous_active + entered - exited
   - All vehicles accounted for
   - Verified via delta validation

8. **Edge Cases Handled**
   - Gridlock detected and resolved
   - No-route failures handled gracefully
   - Empty network updates without errors
   - Incidents reduce capacity and trigger re-routing
   - Verified via edge case tests

9. **Performance Requirements Met**
   - Tick update completes in <100ms for realistic scenarios
   - Pathfinding completes in <10ms for typical routes
   - Memory usage scales linearly with vehicle count
   - Verified via performance tests

10. **Integration with City State**
    - Infrastructure quality affects road conditions
    - Population affects travel demand
    - Traffic metrics contribute to overall city KPIs
    - Verified via integration tests

## Related Documentation

- **[Architecture Overview](../architecture/overview.md)**: Transport component in system architecture
- **[City Specification](city.md)**: City infrastructure state affecting traffic
- **[Simulation Specification](simulation.md)**: Transport subsystem in tick loop
- **[Logging Specification](logging.md)**: Traffic fields in logs
- **[Population Specification](population.md)**: Population affects travel demand
- **[Finance Specification](finance.md)**: Budget affects infrastructure maintenance
- **[Glossary](../guides/glossary.md)**: Traffic and transport term definitions

## References

### Traffic Engineering
- Highway Capacity Manual (HCM): Defines Level of Service metrics
- Intelligent Driver Model (IDM): Car-following behavior model
- TRANSIMS: Agent-based traffic simulation framework

### Algorithms
- A* Search Algorithm: Optimal pathfinding with heuristics
- Dijkstra's Algorithm: Shortest path baseline
- Floyd-Warshall: All-pairs shortest paths (for preprocessing)

### Signal Control
- Webster's Method: Optimal fixed-time signal timing
- SCOOT (Split, Cycle, Offset Optimization Technique): Adaptive control
- SCATS (Sydney Coordinated Adaptive Traffic System): Traffic-responsive system
