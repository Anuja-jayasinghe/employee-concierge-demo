"""Mock parking data for the WSO2 Colombo HQ office car park.

Real, public, harmless fact used for flavor (WSO2's HQ is in Colombo); the
spots, occupancy, and reservations themselves are entirely fictional.
"""

from dataclasses import dataclass, field


@dataclass
class Spot:
    spot_id: str
    level: str
    free: bool
    reserved_by_task_id: str | None = None


SPOTS: dict[str, Spot] = {
    s.spot_id: s
    for s in [
        Spot('A01', 'Level 1', True),
        Spot('A02', 'Level 1', False),
        Spot('A03', 'Level 1', True),
        Spot('A04', 'Level 1', True),
        Spot('B01', 'Level 2', True),
        Spot('B02', 'Level 2', False),
        Spot('B03', 'Level 2', True),
        Spot('B04', 'Level 2', True),
    ]
}


def find_mentioned_spot(text: str) -> Spot | None:
    """Finds the first known spot id mentioned in free-form text, case-insensitive."""
    upper = text.upper()
    for spot_id, spot in SPOTS.items():
        if spot_id in upper:
            return spot
    return None
