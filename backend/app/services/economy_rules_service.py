from __future__ import annotations

from dataclasses import dataclass
from typing import Callable

from fastapi import HTTPException
from sqlalchemy.orm import Session

from app.models.economy_control import EconomyRuleLevel, EconomyRuleSet
from app.models.role import RoleName
from app.models.user import User
from app.services import level_progression_service as fallback_progression
from app.services.audit_log_service import create_admin_log
from app.services.role_service import get_primary_role

SUPPORTED_TRACKS = {"vip", "svip", "send", "receive", "room"}


@dataclass(frozen=True)
class RuleLevelInput:
    level: int
    required_exp: int


def _track_key(track: str) -> str:
    key = (track or "").strip().lower()
    if key not in SUPPORTED_TRACKS:
        raise HTTPException(status_code=400, detail="Unsupported economy rule track")
    return key


def _require_rule_manager(actor: User) -> None:
    if get_primary_role(actor) not in {RoleName.FOUNDER_OWNER, RoleName.OWNER, RoleName.SUPERADMIN}:
        raise HTTPException(status_code=403, detail="Economy rule management requires owner-level control access")


def _fallback_track(track: str) -> fallback_progression.ProgressionTrack:
    if track == "send":
        return fallback_progression.ProgressionTrack.SEND
    if track == "receive":
        return fallback_progression.ProgressionTrack.RECEIVE
    return fallback_progression.ProgressionTrack(track)


def _default_levels(track: str) -> list[RuleLevelInput]:
    safe_track = _fallback_track(track)
    explicit = fallback_progression.level_thresholds_payload(safe_track)
    if explicit:
        return [
            RuleLevelInput(level=int(row["level"]), required_exp=int(row["required_exp"]))
            for row in explicit
        ]
    max_level = fallback_progression.max_level_for_track(safe_track)
    return [
        RuleLevelInput(
            level=level,
            required_exp=fallback_progression.exp_required_for_level(level, safe_track),
        )
        for level in range(1, max_level + 1)
    ]


def ensure_default_rule_sets(db: Session) -> None:
    for track in sorted(SUPPORTED_TRACKS):
        existing = active_rule_set(db, track, create_missing=False)
        if existing is not None:
            continue
        fallback_track = _fallback_track(track)
        rule_set = EconomyRuleSet(
            track_key=track,
            version=1,
            title=f"{track.replace('_', ' ').title()} Levels",
            max_level=fallback_progression.max_level_for_track(fallback_track),
            curve_type="explicit_threshold_table",
            rule_payload_json={
                "source": "seeded_from_legacy_progression_service",
                "inr_to_coin_exp_rate": fallback_progression.INR_TO_COIN_EXP_RATE,
                "max_total_exp": fallback_progression.max_exp_for_track(fallback_track),
            },
            reason="Initial canonical rule-set seed",
            is_active=True,
            is_published=True,
        )
        db.add(rule_set)
        db.flush()
        for item in _default_levels(track):
            db.add(
                EconomyRuleLevel(
                    rule_set_id=rule_set.id,
                    level=item.level,
                    required_exp=item.required_exp,
                    required_coin_value=item.required_exp,
                    sort_order=item.level,
                )
            )
    db.flush()


def active_rule_set(db: Session, track: str, *, create_missing: bool = True) -> EconomyRuleSet | None:
    safe_track = _track_key(track)
    rule_set = (
        db.query(EconomyRuleSet)
        .filter(EconomyRuleSet.track_key == safe_track, EconomyRuleSet.is_active.is_(True), EconomyRuleSet.is_published.is_(True))
        .order_by(EconomyRuleSet.version.desc(), EconomyRuleSet.id.desc())
        .first()
    )
    if rule_set is None and create_missing:
        ensure_default_rule_sets(db)
        rule_set = (
            db.query(EconomyRuleSet)
            .filter(EconomyRuleSet.track_key == safe_track, EconomyRuleSet.is_active.is_(True), EconomyRuleSet.is_published.is_(True))
            .order_by(EconomyRuleSet.version.desc(), EconomyRuleSet.id.desc())
            .first()
        )
    return rule_set


def _levels_for_set(db: Session, rule_set: EconomyRuleSet) -> list[EconomyRuleLevel]:
    return (
        db.query(EconomyRuleLevel)
        .filter(EconomyRuleLevel.rule_set_id == rule_set.id)
        .order_by(EconomyRuleLevel.level.asc())
        .all()
    )


def list_rule_sets(db: Session) -> list[dict]:
    ensure_default_rule_sets(db)
    db.commit()
    rows = (
        db.query(EconomyRuleSet)
        .order_by(EconomyRuleSet.track_key.asc(), EconomyRuleSet.version.desc())
        .all()
    )
    return [rule_set_payload(db, row) for row in rows]


def rule_set_payload(db: Session, rule_set: EconomyRuleSet) -> dict:
    levels = _levels_for_set(db, rule_set)
    return {
        "id": rule_set.id,
        "track_key": rule_set.track_key,
        "version": rule_set.version,
        "title": rule_set.title,
        "max_level": rule_set.max_level,
        "curve_type": rule_set.curve_type,
        "is_active": rule_set.is_active,
        "is_published": rule_set.is_published,
        "levels": [
            {
                "level": row.level,
                "required_exp": row.required_exp,
                "required_coin_value": row.required_coin_value,
                "reward_payload": row.reward_payload_json or {},
            }
            for row in levels
        ],
        "updated_at": rule_set.updated_at,
    }


def replace_rule_set(
    db: Session,
    *,
    actor: User,
    track_key: str,
    title: str,
    levels: list[dict],
    reason: str,
) -> dict:
    _require_rule_manager(actor)
    safe_track = _track_key(track_key)
    if not levels:
        raise HTTPException(status_code=400, detail="At least one rule level is required")
    parsed_levels = []
    for item in levels:
        level = int(item.get("level") or 0)
        required_exp = int(item.get("required_exp") or item.get("required_coin_value") or 0)
        if level <= 0 or required_exp < 0:
            raise HTTPException(status_code=400, detail="Rule levels must use positive levels and non-negative EXP")
        parsed_levels.append(RuleLevelInput(level=level, required_exp=required_exp))
    parsed_levels.sort(key=lambda item: item.level)
    for previous, current in zip(parsed_levels, parsed_levels[1:]):
        if current.level <= previous.level or current.required_exp < previous.required_exp:
            raise HTTPException(status_code=400, detail="Rule levels must be strictly ordered")

    existing = active_rule_set(db, safe_track)
    next_version = int(existing.version if existing else 0) + 1
    if existing is not None:
        existing.is_active = False
        db.add(existing)
    rule_set = EconomyRuleSet(
        track_key=safe_track,
        version=next_version,
        title=title.strip() or f"{safe_track.title()} Levels",
        max_level=max(item.level for item in parsed_levels),
        curve_type="explicit_threshold_table",
        rule_payload_json={"source": "control_center"},
        created_by_user_id=actor.id,
        updated_by_user_id=actor.id,
        reason=reason,
        is_active=True,
        is_published=True,
    )
    db.add(rule_set)
    db.flush()
    for item in parsed_levels:
        db.add(
            EconomyRuleLevel(
                rule_set_id=rule_set.id,
                level=item.level,
                required_exp=item.required_exp,
                required_coin_value=item.required_exp,
                sort_order=item.level,
            )
        )
    db.commit()
    create_admin_log(
        db=db,
        action="ECONOMY_RULE_SET_UPDATED",
        actor_user_id=actor.id,
        resource_type="economy_rule_set",
        resource_id=str(rule_set.id),
        reason=reason,
        metadata_json={"track_key": safe_track, "version": next_version},
    )
    return rule_set_payload(db, rule_set)


def _fallback_payload(track: str, total_exp: int) -> dict:
    safe_track = _fallback_track(track)
    return fallback_progression.progress_payload(total_exp, safe_track)


def progress_payload(db: Session, total_exp: int, track: str) -> dict:
    safe_track = _track_key(track)
    rule_set = active_rule_set(db, safe_track)
    if rule_set is None:
        return _fallback_payload(safe_track, total_exp)

    levels = _levels_for_set(db, rule_set)
    if not levels:
        return _fallback_payload(safe_track, total_exp)

    safe_exp = max(int(total_exp or 0), 0)
    current = None
    for row in levels:
        if safe_exp >= int(row.required_exp or 0):
            current = row
        else:
            break
    level = int(current.level) if current else 0
    current_start = int(current.required_exp) if current else 0
    next_row = next((row for row in levels if int(row.level) > level), None)
    is_max = next_row is None
    next_exp = int(next_row.required_exp) if next_row else int(levels[-1].required_exp)
    needed = 0 if is_max else max(next_exp - current_start, 1)
    into = 0 if is_max else max(min(safe_exp - current_start, needed), 0)
    return {
        "track": safe_track,
        "label": f"{safe_track.replace('_', ' ').title()} Lv",
        "level": level,
        "max_level": int(rule_set.max_level or levels[-1].level),
        "total_exp": safe_exp,
        "current_level_start_exp": current_start,
        "next_level_exp": next_exp,
        "exp_into_level": into,
        "exp_needed_for_next_level": needed,
        "progress": 1.0 if is_max else into / needed,
        "is_max_level": is_max,
        "max_total_exp": int(levels[-1].required_exp),
        "curve_type": rule_set.curve_type,
        "rule_set_id": rule_set.id,
        "rule_set_version": rule_set.version,
        "level_thresholds": [
            {"level": row.level, "required_exp": row.required_exp, "required_coin_value": row.required_coin_value}
            for row in levels
        ],
    }


def level_for_exp(db: Session, total_exp: int, track: str) -> int:
    return int(progress_payload(db, total_exp, track).get("level") or 0)
