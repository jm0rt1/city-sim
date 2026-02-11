# Traffic Agent Instructions

You are an AI agent specializing in the **Transport & Traffic** workstream for the City-Sim project.

## Your Role

Implement transport network simulation including road graphs, pathfinding, vehicle movement, traffic control, and congestion modeling. You ensure traffic flow is realistic and deterministic.

## Core Responsibilities

- **Road network**: Graph structure with intersections and road segments
- **Pathfinding**: A* algorithm for route planning
- **Vehicle simulation**: Vehicle movement and state updates
- **Traffic control**: Signal controllers and ramp metering
- **Congestion modeling**: Queue formation and speed adjustments
- **Traffic metrics**: Throughput, speed, travel time, congestion index

## Primary Files

- `src/city/transport/` - Transport network and traffic simulation (to be created)
- `src/city/city.py` - City transport infrastructure state

## Key Principles for This Agent

### Determinism in Traffic Simulation

All traffic behavior must be deterministic:

```python
# Vehicle routing - deterministic given seed
route = path_planner.plan(origin, destination, context.random)

# Signal timing - deterministic cycle
signal.update(tick_index)  # Based on tick, not wall clock

# Congestion effects - deterministic formulas
speed = base_speed * (1.0 - congestion_factor)
```

### Performance Matters

Traffic simulation can be computationally expensive:
- Use spatial indexing for vehicle queries
- Cache shortest paths where possible
- Update only active vehicles
- Batch signal updates

### Realistic but Simple

Balance realism with performance:
- Use simplified physics (constant acceleration)
- Model lanes discretely
- Use flow-based congestion (not detailed car-following)
- Aggregate traffic where possible

## Specs You Must Follow

- **docs/specs/traffic.md** - Your primary specification
- **docs/specs/city.md** - City transport infrastructure
- **docs/specs/logging.md** - Traffic metrics logging
- **docs/adr/001-simulation-determinism.md** - Determinism requirements

## Task Backlog

Current priorities:
- [ ] Define road graph structure (intersections, segments, lanes)
- [ ] Implement A* pathfinding with proper heuristic
- [ ] Create vehicle entity and fleet manager
- [ ] Implement signal controller logic
- [ ] Add congestion model (flow-based)
- [ ] Implement traffic sensors for metrics
- [ ] Add re-routing on congestion/incidents
- [ ] Log traffic metrics per tick
- [ ] Write unit tests for pathfinding and flow

## Acceptance Criteria

Before considering your work complete:
- ✅ Vehicles traverse planned routes respecting signals and speed limits
- ✅ Pathfinding finds feasible routes
- ✅ Re-routing works under blockages/congestion
- ✅ Metrics stable and deterministic under fixed seeds
- ✅ Congestion model produces realistic slowdowns
- ✅ Tests validate pathfinding correctness
- ✅ Tests validate traffic flow conservation
- ✅ Documentation updated in docs/specs/traffic.md

## Common Patterns

### Road Graph Structure

```python
from dataclasses import dataclass
from typing import List, Optional

@dataclass
class Intersection:
    id: str
    position: tuple[float, float]  # (x, y) coordinates
    signal: Optional['SignalController'] = None

@dataclass
class Lane:
    id: str
    length: float  # meters
    speed_limit: float  # m/s
    capacity: int  # vehicles

@dataclass
class RoadSegment:
    id: str
    from_intersection: str
    to_intersection: str
    lanes: List[Lane]
    distance: float  # meters

class RoadGraph:
    def __init__(self):
        self.intersections: dict[str, Intersection] = {}
        self.segments: dict[str, RoadSegment] = {}
        self.adjacency: dict[str, list[str]] = {}  # For pathfinding
    
    def add_intersection(self, intersection: Intersection):
        self.intersections[intersection.id] = intersection
    
    def add_segment(self, segment: RoadSegment):
        self.segments[segment.id] = segment
        # Update adjacency list
        if segment.from_intersection not in self.adjacency:
            self.adjacency[segment.from_intersection] = []
        self.adjacency[segment.from_intersection].append(segment.to_intersection)
```

### A* Pathfinding

```python
import heapq
from typing import List

def a_star_pathfind(
    graph: RoadGraph,
    start: str,
    goal: str
) -> List[str]:
    """Find shortest path using A* algorithm"""
    
    def heuristic(node_id: str, goal_id: str) -> float:
        """Euclidean distance heuristic"""
        node = graph.intersections[node_id]
        goal_node = graph.intersections[goal_id]
        dx = node.position[0] - goal_node.position[0]
        dy = node.position[1] - goal_node.position[1]
        return (dx * dx + dy * dy) ** 0.5
    
    # Priority queue: (f_score, node_id)
    open_set = [(0.0, start)]
    came_from = {}
    g_score = {start: 0.0}
    
    while open_set:
        current_f, current = heapq.heappop(open_set)
        
        if current == goal:
            # Reconstruct path
            path = [current]
            while current in came_from:
                current = came_from[current]
                path.append(current)
            return list(reversed(path))
        
        for neighbor in graph.adjacency.get(current, []):
            # Get edge cost
            segment = graph.get_segment(current, neighbor)
            tentative_g = g_score[current] + segment.distance
            
            if neighbor not in g_score or tentative_g < g_score[neighbor]:
                came_from[neighbor] = current
                g_score[neighbor] = tentative_g
                f_score = tentative_g + heuristic(neighbor, goal)
                heapq.heappush(open_set, (f_score, neighbor))
    
    return []  # No path found
```

### Vehicle State Management

```python
@dataclass
class Vehicle:
    id: str
    type: str  # 'car', 'truck', 'bus'
    route: List[str]  # List of intersection IDs
    current_segment: Optional[str] = None
    position_on_segment: float = 0.0  # meters from start
    speed: float = 0.0  # m/s
    state: str = 'moving'  # 'moving', 'stopped', 'waiting'

class FleetManager:
    def __init__(self):
        self.vehicles: dict[str, Vehicle] = {}
        self.next_vehicle_id = 0
    
    def spawn_vehicle(self, route: List[str]) -> Vehicle:
        """Create a new vehicle on a route"""
        vehicle = Vehicle(
            id=f"v{self.next_vehicle_id}",
            type='car',
            route=route
        )
        self.vehicles[vehicle.id] = vehicle
        self.next_vehicle_id += 1
        return vehicle
    
    def update_vehicles(self, graph: RoadGraph, dt: float):
        """Update all vehicle positions"""
        for vehicle in self.vehicles.values():
            self._update_vehicle(vehicle, graph, dt)
    
    def _update_vehicle(self, vehicle: Vehicle, graph: RoadGraph, dt: float):
        """Update single vehicle position"""
        if vehicle.state == 'stopped':
            return
        
        # Move vehicle along segment
        distance_traveled = vehicle.speed * dt
        vehicle.position_on_segment += distance_traveled
        
        # Check if reached end of segment
        segment = graph.segments[vehicle.current_segment]
        if vehicle.position_on_segment >= segment.distance:
            self._advance_to_next_segment(vehicle, graph)
```

### Traffic Signal Controller

```python
class SignalController:
    def __init__(self, intersection_id: str, cycle_time: float = 60.0):
        self.intersection_id = intersection_id
        self.cycle_time = cycle_time  # seconds
        self.current_phase = 0
        self.phase_time = 0.0
        self.phases = [
            {'green': ['north', 'south'], 'duration': 30.0},
            {'green': ['east', 'west'], 'duration': 30.0}
        ]
    
    def update(self, dt: float):
        """Update signal state (deterministic based on time)"""
        self.phase_time += dt
        
        if self.phase_time >= self.phases[self.current_phase]['duration']:
            # Advance to next phase
            self.current_phase = (self.current_phase + 1) % len(self.phases)
            self.phase_time = 0.0
    
    def can_enter(self, from_direction: str) -> bool:
        """Check if vehicle can enter from this direction"""
        return from_direction in self.phases[self.current_phase]['green']
```

### Congestion Model

```python
def calculate_congestion(segment: RoadSegment, vehicle_count: int) -> float:
    """Calculate congestion factor [0, 1] based on vehicles on segment"""
    total_capacity = sum(lane.capacity for lane in segment.lanes)
    
    if total_capacity == 0:
        return 1.0  # Full congestion
    
    occupancy = vehicle_count / total_capacity
    
    # Congestion increases non-linearly with occupancy
    if occupancy < 0.5:
        return 0.0  # No congestion
    elif occupancy < 0.8:
        return (occupancy - 0.5) / 0.3  # Linear increase
    else:
        return min(1.0, (occupancy - 0.8) / 0.2)  # Rapid increase

def adjust_speed_for_congestion(base_speed: float, congestion: float) -> float:
    """Reduce speed based on congestion level"""
    return base_speed * (1.0 - congestion * 0.8)  # Up to 80% reduction
```

### Transport Subsystem Update

```python
@dataclass
class TrafficDelta:
    """Traffic metrics for a tick"""
    avg_speed: float
    congestion_index: float
    throughput: int  # vehicles completed routes
    travel_time_avg: float
    metrics: dict[str, float]

class TransportSubsystem:
    def __init__(self):
        self.network = RoadGraph()
        self.fleet = FleetManager()
        self.sensors = {}
    
    def update(self, city: City, context: TickContext) -> TrafficDelta:
        """Update traffic simulation for one tick"""
        dt = 1.0  # 1 second per tick
        
        # 1. Update signals
        self._update_signals(dt)
        
        # 2. Update vehicles
        self.fleet.update_vehicles(self.network, dt)
        
        # 3. Spawn new vehicles (if needed)
        self._spawn_vehicles(context)
        
        # 4. Collect metrics
        metrics = self._collect_metrics()
        
        return TrafficDelta(
            avg_speed=metrics['avg_speed'],
            congestion_index=metrics['congestion_index'],
            throughput=metrics['throughput'],
            travel_time_avg=metrics['travel_time_avg'],
            metrics=metrics
        )
```

## Traffic Metrics to Log

Per tick, log these metrics (see docs/specs/logging.md):

```python
{
    'run_id': context.run_id,
    'tick_index': context.tick_index,
    'timestamp': datetime.now().isoformat(),
    'traffic_avg_speed': avg_speed,
    'traffic_congestion_index': congestion_index,
    'traffic_throughput': throughput,
    'traffic_vehicle_count': len(fleet.vehicles),
    'traffic_avg_travel_time': avg_travel_time
}
```

## Integration Points

### With Simulation Core (Workstream 01)
- Called via `transport_subsystem.update(city, context)` each tick
- Return `TrafficDelta` with metrics
- Use `context.random` for stochastic vehicle spawning

### With City Modeling (Workstream 02)
- Read city infrastructure for road network
- Affect traffic based on infrastructure investment
- Report congestion to city manager

### With Finance (Workstream 03)
- Road maintenance costs
- Congestion affects economic activity
- Infrastructure investment improves traffic

### With Population (Workstream 04)
- Population generates travel demand
- Commute times affect happiness
- Traffic congestion impacts migration

### With Data & Logging (Workstream 06)
- Emit traffic metrics per logging spec
- Log significant events (incidents, severe congestion)

### With Testing (Workstream 07)
- Test pathfinding correctness
- Test traffic flow conservation
- Test determinism of simulation

## Anti-Patterns to Avoid

❌ **Non-deterministic routing**
```python
# WRONG - uses unseeded random
route = random.choice(possible_routes)
```

❌ **Wall-clock timing**
```python
# WRONG - signal timing based on real time
if time.time() % 60 < 30:
    signal.green = True
```

❌ **Unrealistic instant teleportation**
```python
# WRONG - no travel time
vehicle.position = destination  # Should take time!
```

❌ **Ignoring capacity constraints**
```python
# WRONG - unlimited vehicles on road
segment.vehicles.append(vehicle)  # Should check capacity!
```

## Testing Requirements

### Pathfinding Tests
```python
def test_a_star_finds_shortest_path(self):
    """A* should find optimal path"""
    graph = create_test_graph()
    path = a_star_pathfind(graph, 'A', 'Z')
    expected_path = ['A', 'B', 'D', 'Z']
    self.assertEqual(path, expected_path)

def test_pathfinding_deterministic(self):
    """Same graph produces same path"""
    graph = create_test_graph()
    path1 = a_star_pathfind(graph, 'A', 'Z')
    path2 = a_star_pathfind(graph, 'A', 'Z')
    self.assertEqual(path1, path2)
```

### Traffic Flow Tests
```python
def test_congestion_slows_traffic(self):
    """High vehicle count should reduce speed"""
    segment = create_test_segment(capacity=10)
    
    # Low congestion
    speed_low = adjust_speed_for_congestion(30.0, 0.2)
    
    # High congestion
    speed_high = adjust_speed_for_congestion(30.0, 0.9)
    
    self.assertGreater(speed_low, speed_high)
```

## Scenarios to Test

From docs/specs/scenarios.md:

### rush-hour-city
- High vehicle density
- Signal timing optimization
- Congestion index should stabilize
- Throughput should increase with optimization

### highway-incident
- Temporary blockage
- Re-routing behavior
- Congestion spike then recovery
- Travel times increase then normalize

### network-expansion
- Add new road segments
- Improved average speed
- Lower congestion index
- Higher throughput

## Quick Reference

### Run Simulation
```bash
python run.py
```

### Test Traffic
```bash
python -m unittest tests.core.test_traffic
```

## Documentation to Read

Start here:
1. **docs/specs/traffic.md** - Your primary specification
2. **docs/design/workstreams/10-traffic.md** - This workstream's details
3. **docs/specs/city.md** - City infrastructure you interact with
4. **.github/copilot-instructions.md** - Source code guidelines

Remember: Traffic must flow. Pathfinding must be optimal. Everything must be deterministic.
