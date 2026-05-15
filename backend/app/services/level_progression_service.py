from __future__ import annotations

from enum import Enum


class ProgressionTrack(str, Enum):
    VIP = "vip"
    SVIP = "svip"
    SEND = "send"
    RECEIVE = "receive"
    ROOM = "room"


# Product rules:
# Rs 100 recharge gives 1,00,000 coins, so Rs 1 worth of coins = 1,000 coin EXP units.
# VIP is lifetime recharge-based and cannot be purchased directly.
# SVIP is monthly recharge-based and resets/expires monthly.
# VIP/SVIP use explicit cumulative threshold tables, not the generic curve.
INR_TO_COIN_EXP_RATE = 1_000
VIP_MAX_LEVEL = 50
SVIP_MAX_LEVEL = 10
STANDARD_MAX_LEVEL = 100

VIP_LEVEL_THRESHOLDS: dict[int, int] = {
    1: 100_000,
    2: 250_000,
    3: 500_000,
    4: 1_000_000,
    5: 2_000_000,
    6: 3_500_000,
    7: 6_000_000,
    8: 10_000_000,
    9: 16_000_000,
    10: 25_000_000,
    11: 38_000_000,
    12: 55_000_000,
    13: 80_000_000,
    14: 115_000_000,
    15: 160_000_000,
    16: 220_000_000,
    17: 300_000_000,
    18: 400_000_000,
    19: 530_000_000,
    20: 700_000_000,
    21: 900_000_000,
    22: 1_150_000_000,
    23: 1_450_000_000,
    24: 1_850_000_000,
    25: 2_350_000_000,
    26: 3_000_000_000,
    27: 3_800_000_000,
    28: 4_800_000_000,
    29: 6_000_000_000,
    30: 7_500_000_000,
    31: 9_200_000_000,
    32: 11_200_000_000,
    33: 13_500_000_000,
    34: 16_000_000_000,
    35: 18_800_000_000,
    36: 21_800_000_000,
    37: 25_000_000_000,
    38: 28_500_000_000,
    39: 32_000_000_000,
    40: 35_500_000_000,
    41: 38_500_000_000,
    42: 41_000_000_000,
    43: 43_000_000_000,
    44: 44_800_000_000,
    45: 46_200_000_000,
    46: 47_400_000_000,
    47: 48_400_000_000,
    48: 49_100_000_000,
    49: 49_600_000_000,
    50: 50_000_000_000,
}

SVIP_LEVEL_THRESHOLDS: dict[int, int] = {
    1: 1_000_000,
    2: 5_000_000,
    3: 15_000_000,
    4: 40_000_000,
    5: 100_000_000,
    6: 220_000_000,
    7: 450_000_000,
    8: 850_000_000,
    9: 1_350_000_000,
    10: 2_000_000_000,
}

VIP_MAX_TOTAL_EXP = VIP_LEVEL_THRESHOLDS[VIP_MAX_LEVEL]
SVIP_MAX_TOTAL_EXP = SVIP_LEVEL_THRESHOLDS[SVIP_MAX_LEVEL]
STANDARD_MAX_TOTAL_EXP = VIP_MAX_TOTAL_EXP
MAX_RUPEE_VALUE = VIP_MAX_TOTAL_EXP // INR_TO_COIN_EXP_RATE
MAX_TOTAL_EXP = VIP_MAX_TOTAL_EXP
MAX_LEVEL = STANDARD_MAX_LEVEL

TRACK_MAX_LEVELS: dict[ProgressionTrack, int] = {
    ProgressionTrack.VIP: VIP_MAX_LEVEL,
    ProgressionTrack.SVIP: SVIP_MAX_LEVEL,
    ProgressionTrack.SEND: STANDARD_MAX_LEVEL,
    ProgressionTrack.RECEIVE: STANDARD_MAX_LEVEL,
    ProgressionTrack.ROOM: STANDARD_MAX_LEVEL,
}

TRACK_TARGET_EXP: dict[ProgressionTrack, int] = {
    ProgressionTrack.VIP: VIP_MAX_TOTAL_EXP,
    ProgressionTrack.SVIP: SVIP_MAX_TOTAL_EXP,
    ProgressionTrack.SEND: STANDARD_MAX_TOTAL_EXP,
    ProgressionTrack.RECEIVE: STANDARD_MAX_TOTAL_EXP,
    ProgressionTrack.ROOM: STANDARD_MAX_TOTAL_EXP,
}

TRACK_LABELS: dict[ProgressionTrack, str] = {
    ProgressionTrack.VIP: "VIP Lv",
    ProgressionTrack.SVIP: "SVIP Lv",
    ProgressionTrack.SEND: "Sent Lv",
    ProgressionTrack.RECEIVE: "Received Lv",
    ProgressionTrack.ROOM: "Room Lv",
}

# Exponent > 1 makes non-VIP/SVIP tracks get harder as level increases.
DEFAULT_CURVE_EXPONENT = 2.35


def _track(track: str | ProgressionTrack) -> ProgressionTrack:
    if isinstance(track, ProgressionTrack):
        return track
    return ProgressionTrack(track)


def _explicit_thresholds(track: ProgressionTrack) -> dict[int, int] | None:
    if track == ProgressionTrack.VIP:
        return VIP_LEVEL_THRESHOLDS
    if track == ProgressionTrack.SVIP:
        return SVIP_LEVEL_THRESHOLDS
    return None


def max_level_for_track(track: str | ProgressionTrack) -> int:
    return TRACK_MAX_LEVELS[_track(track)]


def max_exp_for_track(track: str | ProgressionTrack) -> int:
    return TRACK_TARGET_EXP[_track(track)]


def exp_required_for_level(level: int, track: str | ProgressionTrack = ProgressionTrack.SEND) -> int:
    safe_track = _track(track)
    max_level = max_level_for_track(safe_track)
    safe_level = max(1, min(int(level or 1), max_level))
    explicit = _explicit_thresholds(safe_track)
    if explicit is not None:
        return int(explicit[safe_level])

    if safe_level <= 1:
        return 0
    if safe_level >= max_level:
        return max_exp_for_track(safe_track)

    ratio = (safe_level - 1) / (max_level - 1)
    return int(round(max_exp_for_track(safe_track) * (ratio ** DEFAULT_CURVE_EXPONENT)))


def exp_needed_for_level(level: int, track: str | ProgressionTrack = ProgressionTrack.SEND) -> int:
    safe_track = _track(track)
    safe_level = max(1, min(int(level or 1), max_level_for_track(safe_track)))
    explicit = _explicit_thresholds(safe_track)
    if explicit is not None:
        previous_exp = 0 if safe_level <= 1 else exp_required_for_level(safe_level - 1, safe_track)
        return max(exp_required_for_level(safe_level, safe_track) - previous_exp, 0)

    safe_level = max(2, safe_level)
    return exp_required_for_level(safe_level, safe_track) - exp_required_for_level(safe_level - 1, safe_track)


def level_for_exp(total_exp: int, track: str | ProgressionTrack = ProgressionTrack.SEND) -> int:
    safe_track = _track(track)
    safe_exp = max(int(total_exp or 0), 0)
    if safe_exp <= 0:
        return 0

    explicit = _explicit_thresholds(safe_track)
    if explicit is not None:
        level = 0
        for candidate_level in range(1, max_level_for_track(safe_track) + 1):
            if safe_exp >= explicit[candidate_level]:
                level = candidate_level
            else:
                break
        return level

    max_level = max_level_for_track(safe_track)
    if safe_exp >= max_exp_for_track(safe_track):
        return max_level

    low = 1
    high = max_level
    while low < high:
        mid = (low + high + 1) // 2
        if safe_exp >= exp_required_for_level(mid, safe_track):
            low = mid
        else:
            high = mid - 1
    return low


def level_thresholds_payload(track: str | ProgressionTrack) -> list[dict]:
    safe_track = _track(track)
    explicit = _explicit_thresholds(safe_track)
    if explicit is None:
        return []
    return [
        {
            "level": level,
            "required_exp": required_exp,
            "required_coin_recharge": required_exp,
            "required_rupee_value": required_exp // INR_TO_COIN_EXP_RATE,
        }
        for level, required_exp in sorted(explicit.items())
    ]


def progress_payload(
    total_exp: int,
    track: str | ProgressionTrack = ProgressionTrack.SEND,
) -> dict:
    safe_track = _track(track)
    safe_exp = max(int(total_exp or 0), 0)
    max_level = max_level_for_track(safe_track)
    explicit = _explicit_thresholds(safe_track)
    level = level_for_exp(safe_exp, safe_track)

    if explicit is not None:
        current_start = 0 if level <= 0 else exp_required_for_level(level, safe_track)
        next_level = min(level + 1, max_level)
        next_exp = exp_required_for_level(next_level, safe_track)
        is_max = level >= max_level
        needed = 0 if is_max else max(next_exp - current_start, 1)
        into = 0 if is_max else max(min(safe_exp - current_start, needed), 0)
        return {
            "track": safe_track.value,
            "label": TRACK_LABELS[safe_track],
            "level": level,
            "max_level": max_level,
            "total_exp": safe_exp,
            "current_level_start_exp": current_start,
            "next_level_exp": next_exp,
            "exp_into_level": into,
            "exp_needed_for_next_level": needed,
            "progress": 1.0 if is_max else into / needed,
            "is_max_level": is_max,
            "max_total_exp": max_exp_for_track(safe_track),
            "max_rupee_value": max_exp_for_track(safe_track) // INR_TO_COIN_EXP_RATE,
            "inr_to_coin_exp_rate": INR_TO_COIN_EXP_RATE,
            "curve_type": "explicit_threshold_table",
            "curve_exponent": None,
            "level_thresholds": level_thresholds_payload(safe_track),
        }

    if level <= 0:
        next_exp = 1
        return {
            "track": safe_track.value,
            "label": TRACK_LABELS[safe_track],
            "level": 0,
            "max_level": max_level,
            "total_exp": safe_exp,
            "current_level_start_exp": 0,
            "next_level_exp": next_exp,
            "exp_into_level": 0,
            "exp_needed_for_next_level": max(next_exp, 1),
            "progress": 0.0,
            "is_max_level": False,
            "max_total_exp": max_exp_for_track(safe_track),
            "max_rupee_value": max_exp_for_track(safe_track) // INR_TO_COIN_EXP_RATE,
            "inr_to_coin_exp_rate": INR_TO_COIN_EXP_RATE,
            "curve_type": "exponential_curve",
            "curve_exponent": DEFAULT_CURVE_EXPONENT,
            "level_thresholds": [],
        }

    current_start = exp_required_for_level(level, safe_track)
    next_level = min(level + 1, max_level)
    next_exp = exp_required_for_level(next_level, safe_track)
    is_max = level >= max_level
    needed = 0 if is_max else max(next_exp - current_start, 1)
    into = 0 if is_max else max(min(safe_exp - current_start, needed), 0)

    return {
        "track": safe_track.value,
        "label": TRACK_LABELS[safe_track],
        "level": level,
        "max_level": max_level,
        "total_exp": safe_exp,
        "current_level_start_exp": current_start,
        "next_level_exp": next_exp,
        "exp_into_level": into,
        "exp_needed_for_next_level": needed,
        "progress": 1.0 if is_max else into / needed,
        "is_max_level": is_max,
        "max_total_exp": max_exp_for_track(safe_track),
        "max_rupee_value": max_exp_for_track(safe_track) // INR_TO_COIN_EXP_RATE,
        "inr_to_coin_exp_rate": INR_TO_COIN_EXP_RATE,
        "curve_type": "exponential_curve",
        "curve_exponent": DEFAULT_CURVE_EXPONENT,
        "level_thresholds": [],
    }


def vip_payload(total_recharge_coin_exp: int) -> dict:
    return progress_payload(total_recharge_coin_exp, ProgressionTrack.VIP)


def svip_payload(monthly_recharge_coin_exp: int) -> dict:
    return progress_payload(monthly_recharge_coin_exp, ProgressionTrack.SVIP)


def send_payload(total_sent_coin_exp: int) -> dict:
    return progress_payload(total_sent_coin_exp, ProgressionTrack.SEND)


def receive_payload(total_received_coin_exp: int) -> dict:
    return progress_payload(total_received_coin_exp, ProgressionTrack.RECEIVE)


def room_payload(total_room_coin_exp: int) -> dict:
    return progress_payload(total_room_coin_exp, ProgressionTrack.ROOM)
