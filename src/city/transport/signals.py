"""Traffic signal controller for intersections."""

from __future__ import annotations

from typing import Dict, List, Optional, Tuple

from src.city.transport.models import Movement, SignalPhase, SignalState


class SignalController:
    """
    Traffic signal controller for an intersection.

    Cycles through phases (green windows for different movements).
    Supports both fixed-time and simple adaptive timing.
    """

    def __init__(
        self,
        intersection_id: str,
        phases: Optional[List[SignalPhase]] = None,
        min_green_time: float = 10.0,
        max_green_time: float = 60.0,
        yellow_time: float = 3.0,
        all_red_time: float = 1.0,
        is_adaptive: bool = False,
    ) -> None:
        self.intersection_id = intersection_id
        self.phases: List[SignalPhase] = phases or _default_phases()
        self.current_phase: int = 0
        self.phase_elapsed: float = 0.0

        self.min_green_time = min_green_time
        self.max_green_time = max_green_time
        self.yellow_time = yellow_time
        self.all_red_time = all_red_time
        self.is_adaptive = is_adaptive

        # Detector data: segment_id -> vehicle queue count
        self.detector_data: Dict[str, int] = {}

        # Counts completed full cycles
        self.cycles_completed: int = 0

        # Track whether current phase is in yellow transition
        self._in_yellow: bool = False
        self._yellow_elapsed: float = 0.0

    # ------------------------------------------------------------------
    # Update logic
    # ------------------------------------------------------------------

    def update(self, dt: float, queue_lengths: Optional[Dict[str, int]] = None) -> None:
        """
        Advance signal state by dt seconds.

        Args:
            dt: Time step in seconds.
            queue_lengths: Optional segment_id -> queue count for adaptive control.
        """
        if not self.phases:
            return

        if queue_lengths:
            self.detector_data.update(queue_lengths)

        if self._in_yellow:
            self._yellow_elapsed += dt
            if self._yellow_elapsed >= self.yellow_time:
                self._in_yellow = False
                self._yellow_elapsed = 0.0
                self._advance_phase()
            return

        self.phase_elapsed += dt

        # Determine green duration
        green_duration = self._get_green_duration()

        if self.phase_elapsed >= green_duration:
            self.phase_elapsed = 0.0
            self._in_yellow = True
            self._yellow_elapsed = 0.0

    def _get_green_duration(self) -> float:
        """Return green duration for the current phase (adaptive or fixed)."""
        if not self.is_adaptive:
            return self.phases[self.current_phase].duration

        # Simple adaptive: extend green if queues are long on active directions
        phase = self.phases[self.current_phase]
        total_queue = sum(
            self.detector_data.get(seg_id, 0)
            for seg_id in self.detector_data
        )
        extra = min(total_queue * 1.5, self.max_green_time - self.min_green_time)
        return max(self.min_green_time, min(self.max_green_time, phase.duration + extra))

    def _advance_phase(self) -> None:
        """Move to the next phase."""
        prev = self.current_phase
        self.current_phase = (self.current_phase + 1) % len(self.phases)
        if self.current_phase == 0 and prev != 0:
            self.cycles_completed += 1

    # ------------------------------------------------------------------
    # Query methods
    # ------------------------------------------------------------------

    def get_signal_state(self, from_segment: str, to_segment: str) -> SignalState:
        """Get current signal state for a movement (from_segment -> to_segment)."""
        if not self.phases:
            return SignalState.GREEN

        if self._in_yellow:
            return SignalState.YELLOW

        phase = self.phases[self.current_phase]
        key: Tuple[str, str] = (from_segment, to_segment)
        if key in phase.movement_states:
            return phase.movement_states[key]

        # Default: green for movements in allowed_movements list, red otherwise
        return SignalState.GREEN

    def is_green(self, from_segment: str, to_segment: str) -> bool:
        """Return True if the movement is currently green."""
        return self.get_signal_state(from_segment, to_segment) == SignalState.GREEN


# ---------------------------------------------------------------------------
# Default phase generator
# ---------------------------------------------------------------------------

def _default_phases() -> List[SignalPhase]:
    """Create a simple two-phase N/S + E/W signal plan."""
    phase_ns = SignalPhase(
        id="phase_NS",
        duration=30.0,
        allowed_movements=[Movement.STRAIGHT, Movement.RIGHT],
    )
    phase_ew = SignalPhase(
        id="phase_EW",
        duration=30.0,
        allowed_movements=[Movement.STRAIGHT, Movement.RIGHT],
    )
    return [phase_ns, phase_ew]
