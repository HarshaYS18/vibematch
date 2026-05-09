from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session

from app.api.routes.users import get_current_user
from app.database import get_db
from app.models.mvp_feature import MvpFeatureState
from app.models.user import User
from app.schemas.mvp_feature import MvpFeatureCreate
from app.services.mvp_feature_service import create_feature_item, list_feature_items

router = APIRouter(prefix="/internal-test", tags=["Internal Test"])


def _sample_item(item_type: str, title: str, payload: dict, amount: int = 0, currency: str | None = None) -> MvpFeatureCreate:
    return MvpFeatureCreate(
        item_type=item_type,
        title=title,
        description="Internal testing sample data",
        amount=amount,
        currency=currency,
        payload=payload,
    )


@router.get("/status")
def internal_test_status(current_user: User = Depends(get_current_user)):
    return {
        "ok": True,
        "mode": "internal_testing",
        "message": "Internal testing endpoints are available.",
        "current_user_id": current_user.id,
        "public_user_id": current_user.public_user_id,
    }


@router.post("/seed")
def seed_internal_test_data(
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    existing = list_feature_items(db, feature="vibes", owner_user_id=current_user.id, limit=1)
    if existing:
        return {
            "ok": True,
            "message": "Sample data already exists for this user. Use /internal-test/reset-my-samples first if you want a clean seed.",
            "created_count": 0,
        }

    samples: list[tuple[str, MvpFeatureCreate]] = [
        (
            "wallet",
            _sample_item(
                "recharge",
                "Starter Coin Recharge",
                {"method": "internal_test", "transaction_kind": "recharge", "balance_after": 5000},
                amount=5000,
                currency="coins",
            ),
        ),
        (
            "gifts",
            _sample_item(
                "gift_catalog_item",
                "Love Rocket",
                {"gift_id": "love_rocket", "category": "premium", "animation": "video"},
                amount=99,
                currency="coins",
            ),
        ),
        (
            "gifts",
            _sample_item(
                "gift_send",
                "Love Rocket sent in room",
                {"gift_id": "love_rocket", "combo": 1, "room_public_id": "VM1001"},
                amount=99,
                currency="coins",
            ),
        ),
        (
            "store",
            _sample_item(
                "store_item",
                "Aqua Neon Avatar Frame",
                {"item_id": "frame_aqua_neon", "category": "avatar_frame", "duration_days": 30},
                amount=299,
                currency="coins",
            ),
        ),
        (
            "vip",
            _sample_item(
                "vip_state",
                "VIP 25 Active",
                {"vip_level": 25, "status": "active", "source": "recharge_based"},
            ),
        ),
        (
            "vibes",
            _sample_item(
                "post",
                "First Internal Test Vibe",
                {"caption": "Hello from VibeMatch backend", "media_type": "text", "like_count": 12, "comment_count": 3},
            ),
        ),
        (
            "relationships",
            _sample_item(
                "relationship_request",
                "Best Friend Request",
                {"relationship_type": "best_friend", "workflow": "pending_acceptance"},
            ),
        ),
        (
            "family",
            _sample_item(
                "family",
                "Moon Fam",
                {"family_level": 12, "member_count": 32, "rank": 4},
            ),
        ),
        (
            "agency",
            _sample_item(
                "agency_request",
                "Host Agency Join Request",
                {"agency_name": "Moon Agency", "workflow": "pending"},
            ),
        ),
        (
            "events",
            _sample_item(
                "app_event",
                "Weekend Vibe Party",
                {"event_type": "room_event", "reward": "badge", "status": "active"},
            ),
        ),
        (
            "rankings",
            _sample_item(
                "ranking_snapshot",
                "Today Sent Ranking Snapshot",
                {"ranking_type": "sent", "period": "today", "top_count": 10},
            ),
        ),
        (
            "watch_party",
            _sample_item(
                "watch_party_session",
                "YouTube Watch Party Test",
                {"room_public_id": "VM1001", "video_id": "demo", "sync_state": "paused"},
            ),
        ),
        (
            "cricket_mode",
            _sample_item(
                "cricket_session",
                "Cricket Mode Test Match",
                {"room_public_id": "VM1001", "score": {"team_a": 24, "team_b": 18}, "innings": 1},
            ),
        ),
        (
            "assets",
            _sample_item(
                "custom_room_background",
                "Pending Custom Room Background",
                {"room_public_id": "VM1001", "review_status": "pending", "image_url": "internal-test-background.png"},
            ),
        ),
        (
            "reports",
            _sample_item(
                "user_report",
                "Internal Test Report",
                {"workflow_status": "submitted", "category": "test"},
            ),
        ),
        (
            "earnings",
            _sample_item(
                "payout_request",
                "Creator Payout Test",
                {"review_status": "pending", "source": "gift_earnings"},
                amount=1200,
                currency="coins",
            ),
        ),
        (
            "control_center",
            _sample_item(
                "control_action",
                "Control Center Pending Action",
                {"panel": "owner", "action_type": "review_sample"},
            ),
        ),
    ]

    created = [
        create_feature_item(db, feature=feature, owner_user_id=current_user.id, data=data)
        for feature, data in samples
    ]

    return {
        "ok": True,
        "message": "Internal testing sample data created.",
        "created_count": len(created),
        "features": sorted({item.feature for item in created}),
    }


@router.delete("/reset-my-samples")
def reset_my_internal_samples(
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    items = db.query(MvpFeatureState).filter(MvpFeatureState.owner_user_id == current_user.id).all()
    count = len(items)
    for item in items:
        db.delete(item)
    db.commit()
    return {"ok": True, "message": "Internal sample data reset for current user.", "deleted_count": count}
