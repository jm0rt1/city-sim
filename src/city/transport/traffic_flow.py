"""Traffic flow model using a simplified Intelligent Driver Model (IDM)."""

from __future__ import annotations

import math
from typing import Optional

from src.city.transport.models import RoadSegment, Vehicle


class TrafficFlowModel:
    """
    Models traffic flow dynamics and vehicle movement using IDM.
    """

    # IDM parameters (can be overridden per vehicle type if desired)
    T: float = 1.5     # desired time headway (seconds)
    b: float = 4.0     # comfortable deceleration (m/s²)
    delta: int = 4     # acceleration exponent
    s0: float = 2.0    # minimum spacing (meters)

    def calculate_speed(
        self,
        vehicle: Vehicle,
        segment: RoadSegment,
        front_vehicle: Optional[Vehicle] = None,
    ) -> float:
        """
        Calculate target speed for vehicle based on conditions (IDM-inspired).

        Returns target speed in m/s.
        """
        v0 = min(vehicle.max_speed, segment.speed_limit)
        if v0 <= 0:
            return 0.0

        v = vehicle.speed

        # Free-flow acceleration
        free_term = vehicle.max_acceleration * (1 - (v / v0) ** self.delta)

        if front_vehicle is None:
            accel = free_term
        else:
            s = front_vehicle.position - vehicle.position - front_vehicle.length
            s = max(s, 0.1)  # prevent division by zero
            dv = v - front_vehicle.speed

            s_star = self.s0 + max(
                0.0,
                v * self.T + (v * dv) / (2 * math.sqrt(vehicle.max_acceleration * self.b)),
            )

            interaction_term = vehicle.max_acceleration * (s_star / s) ** 2
            accel = free_term - interaction_term

        accel = max(vehicle.max_deceleration, min(vehicle.max_acceleration, accel))

        # Apply a simple dt=1 step to estimate next speed (callers pass dt separately)
        new_speed = v + accel
        return max(0.0, min(v0, new_speed))

    def update_vehicle_position(
        self,
        vehicle: Vehicle,
        segment: RoadSegment,
        dt: float,
        front_vehicle: Optional[Vehicle] = None,
    ) -> float:
        """
        Update vehicle position for one time step.

        Returns distance traveled (meters).
        """
        target_speed = self.calculate_speed(vehicle, segment, front_vehicle)

        # Smooth speed change
        speed_delta = target_speed - vehicle.speed
        max_change = vehicle.max_acceleration * dt
        speed_delta = max(-abs(vehicle.max_deceleration) * dt, min(max_change, speed_delta))

        vehicle.speed = max(0.0, vehicle.speed + speed_delta)

        distance = vehicle.speed * dt
        vehicle.position += distance
        vehicle.trip_distance += distance
        return distance
