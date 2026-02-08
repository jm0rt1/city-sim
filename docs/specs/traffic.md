# Specification: Transport & Traffic

## Purpose
Provide a transport network and traffic simulation capable of city and highway driving with pathfinding and congestion modeling.

## Components
- Road Graph: nodes (`Intersection`) and edges (`RoadSegment`), lanes, speed limits.
- Pathfinding: `RoutePlanner` using A* over `RoadGraph` (heuristic: Euclidean/Manhattan).
- Vehicles: `Vehicle` entities managed by `FleetManager`; route assignment and state updates.
- Controllers: `CityTrafficController`, `HighwayTrafficController`, `SignalController` for lights, ramps, and coordination.
- Models: `TrafficModel` and `CongestionModel` for flow, queueing, and speed adjustments.
- Sensors: `TrafficSensor` for counts, speeds, occupancy.

## Interfaces
- `TransportNetwork.update(city, ctx) -> TrafficDelta`: advances vehicle states and signals per tick.
- `RoutePlanner.plan(origin, dest, constraints) -> Route`.
- `SignalController.update(network, ctx)`; `HighwayTrafficController.update(network, ctx)`.

## Data Structures
- `Intersection { id, position, signal?: SignalController }`
- `RoadSegment { id, from, to, lanes: Lane[], speedLimit, capacity }`
- `Lane { id, length, allowedTypes }`
- `Vehicle { id, type, route, position, speed }`
- `Route { segments: RoadSegment[] }`

## Inputs
- City layout and infrastructure: [src/city/city.py](../../src/city/city.py), [src/city/city_manager.py](../../src/city/city_manager.py)
- Settings: [src/shared/settings.py](../../src/shared/settings.py) (traffic params, seeds)

## Outputs
- `TrafficDelta`: throughput, avg speed, travel time, congestion index, incident flags.
- Logs: traffic metrics per tick; summaries per scenario.

## Pathfinding
- Graph search with A*; cost combines distance, congestion, and turn penalties.
- Re-routing on incidents or heavy congestion.

## Acceptance Criteria
- Vehicles traverse planned routes respecting signals and speed limits.
- Pathfinding finds feasible routes; re-routes under blockages.
- Metrics stable and deterministic under fixed seeds.
