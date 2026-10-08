"""Heart rate zone calculations."""

from typing import NamedTuple


class HeartRateZone(NamedTuple):
    """Represents a heart rate zone with min and max BPM."""
    zone: str
    min_bpm: int
    max_bpm: int


def calculate_heart_rate_zones(max_hr: int) -> list[HeartRateZone]:
    """
    Calculate heart rate zones Z1 to Z5 based on maximum heart rate.

    Z1: 50-60% (Very Light)
    Z2: 60-70% (Light)
    Z3: 70-80% (Moderate)
    Z4: 80-90% (Hard)
    Z5: 90-100% (Maximum)

    Args:
        max_hr: Maximum heart rate in BPM

    Returns:
        List of HeartRateZone objects for zones Z1-Z5
    """
    if max_hr <= 0:
        raise ValueError("max_hr must be greater than zero")

    zones = [
        ("Z1 Very Light", 0.50, 0.60),
        ("Z2 Light", 0.60, 0.70),
        ("Z3 Moderate", 0.70, 0.80),
        ("Z4 Hard", 0.80, 0.90),
        ("Z5 Maximum", 0.90, 1.00),
    ]

    result = []
    for zone_name, min_pct, max_pct in zones:
        min_bpm = int(max_hr * min_pct)
        max_bpm = int(max_hr * max_pct)
        result.append(HeartRateZone(zone=zone_name, min_bpm=min_bpm, max_bpm=max_bpm))

    return result


def get_heart_rate_zone_for_hr(current_hr: int, max_hr: int) -> str:
    """
    Determine which heart rate zone a current heart rate falls into.

    Args:
        current_hr: Current heart rate in BPM
        max_hr: Maximum heart rate in BPM

    Returns:
        String indicating the zone (Z1, Z2, Z3, Z4, or Z5)
    """
    if max_hr <= 0:
        raise ValueError("max_hr must be greater than zero")

    if current_hr < 0:
        raise ValueError("current_hr must be non-negative")

    percentage = current_hr / max_hr * 100

    if percentage < 50:
        return "Below Z1 (Very Light)"
    elif percentage < 60:
        return "Z1 Very Light"
    elif percentage < 70:
        return "Z2 Light"
    elif percentage < 80:
        return "Z3 Moderate"
    elif percentage < 90:
        return "Z4 Hard"
    elif percentage <= 100:
        return "Z5 Maximum"
    else:
        return "Above Z5 (Maximum)"