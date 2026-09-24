from fastapi import APIRouter, Depends, HTTPException, Query
from sqlalchemy.orm import Session

from app.api.routes.users import get_current_user
from app.database import get_db
from app.models.user import User
from app.services import economy_service_client, experience_service
from app.services import level_progression_service as progression

router = APIRouter(prefix="/experience", tags=["Experience"])


@router.get("/me")
def get_my_experience(current_user: User = Depends(get_current_user), db: Session = Depends(get_db)):
    """Return current user's Send Lv and Receive Lv EXP details.

    This is intentionally not a ranking endpoint. The frontend Send Lv / Receive Lv
    pages should use this payload to show total EXP, current level progress,
    next-level requirement, and task guidance only.
    """
    return experience_service.details_for_user(db, current_user)


@router.get("/users/public/{public_user_id}")
def get_user_experience_by_public_id(public_user_id: int, db: Session = Depends(get_db)):
    payload = experience_service.details_for_public_user_id(db, public_user_id)
    if payload is None:
        raise HTTPException(status_code=404, detail="User not found")
    return payload


@router.get("/rooms/public/{room_public_id}")
def get_room_experience_by_public_id(room_public_id: str, db: Session = Depends(get_db)):
    payload = experience_service.details_for_room_public_id(db, room_public_id)
    if payload is None:
        raise HTTPException(status_code=404, detail="Room not found")
    return payload



@router.get("/vip-svip/preview")
def preview_vip_svip_progression(
    lifetime_recharge_coin_exp: int = Query(default=0, ge=0),
    monthly_recharge_coin_exp: int = Query(default=0, ge=0),
):
    """Preview VIP/SVIP level math before recharge history is fully wired.

    VIP = lifetime recharge coin EXP.
    SVIP = monthly recharge coin EXP.
    Max target = ₹5 crore worth of coins.
    """
    return experience_service.vip_svip_payload(
        lifetime_recharge_coin_exp=lifetime_recharge_coin_exp,
        monthly_recharge_coin_exp=monthly_recharge_coin_exp,
    )


@router.get("/tasks")
def get_experience_tasks():
    return {
        "send_tasks": [
            {"id": "send_gifts", "title": "Send gifts", "description": "Every coin spent on gifts adds Send EXP instantly.", "exp_rule": "1 coin gift value = 1 Send EXP"},
            {"id": "send_combo", "title": "Use gift combos", "description": "Combo quantity increases total gift value and Send EXP.", "exp_rule": "coin_value × quantity"},
        ],
        "receive_tasks": [
            {"id": "receive_gifts", "title": "Receive gifts", "description": "Every coin value received as gifts adds Receive EXP instantly.", "exp_rule": "1 received coin value = 1 Receive EXP"},
            {"id": "earn_rubies", "title": "Earn rubies from gifts", "description": "Gift receiver earns rubies from the ruby algorithm while Receive EXP grows.", "exp_rule": "rubies = 30% of received gift coin value"},
        ],
        "room_tasks": [
            {"id": "room_gifts", "title": "Grow room activity", "description": "Gifts sent inside a room add Room EXP instantly.", "exp_rule": "1 room gift coin value = 1 Room EXP"},
            {"id": "room_events", "title": "Host events", "description": "Future room events can add bonus Room EXP after backend task rules are enabled.", "exp_rule": "coming later"},
        ],
        "vip_tasks": [
            {"id": "lifetime_recharge", "title": "Recharge coins", "description": "Lifetime recharge coin value grows VIP Lv.", "exp_rule": "1 recharge coin value = 1 VIP EXP"},
        ],
        "svip_tasks": [
            {"id": "monthly_recharge", "title": "Monthly recharge", "description": "Current-month recharge coin value grows SVIP Lv for that month.", "exp_rule": "1 monthly recharge coin value = 1 SVIP EXP"},
        ],
        "level_rule": {
            "summary": "Gradual curve that gets harder and harder as levels increase.",
            "max_rupee_value": progression.MAX_RUPEE_VALUE,
            "max_total_exp": progression.MAX_TOTAL_EXP,
            "inr_to_coin_exp_rate": progression.INR_TO_COIN_EXP_RATE,
            "curve_exponent": progression.DEFAULT_CURVE_EXPONENT,
            "tracks": {
                "vip": {"max_level": progression.max_level_for_track(progression.ProgressionTrack.VIP)},
                "svip": {"max_level": progression.max_level_for_track(progression.ProgressionTrack.SVIP)},
                "send": {"max_level": progression.max_level_for_track(progression.ProgressionTrack.SEND)},
                "receive": {"max_level": progression.max_level_for_track(progression.ProgressionTrack.RECEIVE)},
                "room": {"max_level": progression.max_level_for_track(progression.ProgressionTrack.ROOM)},
            },
        },
    }


@router.get("/community-events")
def get_community_events(
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    return experience_service.community_events_for_user(db, current_user)


@router.get("/social-missions")
def get_social_missions(
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    return {
        "cycle_key": experience_service.social_mission_cycle_key(),
        "missions": experience_service.social_missions_for_user(db, current_user),
    }


@router.post("/social-missions/{mission_id}/claim")
def claim_social_mission(
    mission_id: str,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    missions = experience_service.social_missions_for_user(db, current_user)
    mission = next((item for item in missions if item["id"] == mission_id), None)
    if mission is None:
        raise HTTPException(status_code=404, detail="Social mission not found")
    if not mission["completed"]:
        raise HTTPException(status_code=409, detail="Complete this social mission before claiming its reward")
    reward = mission["reward"]
    cycle_key = str(mission["cycle_key"])
    try:
        result = economy_service_client.claim_mission_reward(
            user_id=current_user.id,
            mission_id=mission_id,
            cycle_key=cycle_key,
            reward_coin_amount=int(reward["amount"]),
        )
    except economy_service_client.EconomyServiceUnavailable as exc:
        raise HTTPException(status_code=503, detail=str(exc)) from exc
    except economy_service_client.EconomyServiceError as exc:
        raise HTTPException(status_code=exc.status_code, detail=exc.detail) from exc

    refreshed = experience_service.social_missions_for_user(db, current_user)
    return {
        "credited": bool(result.get("credited")),
        "coin_balance": int(result.get("coin_balance") or 0),
        "mission": next(item for item in refreshed if item["id"] == mission_id),
    }
