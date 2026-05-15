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
# VIP max: VIP 50 costs 50,000,000,000 lifetime recharge coins total.
# SVIP max: SVIP 10 costs 2,000,000,000 monthly recharge coins total.
INR_TO_COIN_EXP_RATE = 1_000
VIP_MAX_LEVEL = 50
SVIP_MAX_LEVEL = 10
STANDARD_MAX_LEVEL = 100
VIP_MAX_TOTAL_EXP = 50_000_000_000
SVIP_MAX_TOTAL_EXP = 2_000_000_000
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

# Exponent > 1 makes level requirements get harder as level increases.
# Same curve shape for all tracks; each track has its own max level and max cost.
DEFAULT_CURVE_EXPONENT = 2.35


def _track(track: str | ProgressionTrack) -> ProgressionTrack:
    if isinstance(track, ProgressionTrack):
        return track
    return ProgressionTrack(track)


def max_level_for_track(track: str | ProgressionTrack) -> int:
    return TRACK_MAX_LEVELS[_track(track)]


def max_exp_for_track(track: str | ProgressionTrack) -> int:
    return TRACK_TARGET_EXP[_track(track)]


def exp_required_for_level(level: int, track: str | ProgressionTrack = ProgressionTrack.SEND) -> int:
    safe_track = _track(track)
    max_level = max_level_for_track(safe_track)
    safe_level = max(1, min(int(level or 1), max_level))
    if safe_level <= 1:
        return 0
    if safe_level >= max_level:
        return max_exp_for_track(safe_track)

    ratio = (safe_level - 1) / (max_level - 1)
    return int(round(max_exp_for_track(safe_track) * (ratio ** DEFAULT_CURVE_EXPONENT)))


def exp_needed_for_level(level: int, track: str | ProgressionTrack = ProgressionTrack.SEND) -> int:
    safe_track = _track(track)
    safe_level = max(2, min(int(level or 2), max_level_for_track(safe_track)))
    return exp_required_for_level(safe_level, safe_track) - exp_required_for_level(safe_level - 1, safe_track)


def level_for_exp(total_exp: int, track: str | ProgressionTrack = ProgressionTrack.SEND) -> int:
    safe_track = _track(track)
    safe_exp = max(int(total_exp or 0), 0)
    if safe_exp <= 0:
        return 0
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


def progress_payload(
    total_exp: int,
    track: str | ProgressionTrack = ProgressionTrack.SEND,
) -> dict:
    safe_track = _track(track)
    safe_exp = max(int(total_exp or 0), 0)
    max_level = max_level_for_track(safe_track)
    level = level_for_exp(safe_exp, safe_track)
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
            "curve_exponent": DEFAULT_CURVE_EXPONENT,
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
        "curve_exponent": DEFAULT_CURVE_EXPONENT,
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
