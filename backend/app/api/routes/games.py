from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session

from app.api.routes.users import get_current_user
from app.database import get_db
from app.models.user import User
from app.schemas.game_history import GameRoundHistoryResponse
from app.schemas.games import (
    GameAdminUpsertRequest,
    GameBetRequest,
    GameBetResponse,
    GameCatalogResponse,
    GameDefinitionResponse,
    GameRoundCreateRequest,
    GameRoundResponse,
    GameRoundResultResponse,
)
from app.services import global_jungle_game_service_v2 as game_service
from app.services import role_service

router = APIRouter(prefix="/games", tags=["Games"])


def _require_owner_or_above(user: User) -> None:
    if not role_service.is_owner_or_above(user):
        from fastapi import HTTPException
        raise HTTPException(status_code=403, detail="Only Owner or Super Owner can manage game configs.")


@router.get("/catalog", response_model=GameCatalogResponse)
def get_game_catalog(db: Session = Depends(get_db)):
    return GameCatalogResponse(games=[GameDefinitionResponse(**item) for item in game_service.list_catalog(db)])


@router.get("/catalog/{game_key}", response_model=GameDefinitionResponse)
def get_game_definition(game_key: str, db: Session = Depends(get_db)):
    return GameDefinitionResponse(**game_service._definition_payload(game_service.get_definition(db, game_key)))


@router.get("/global/jungle-hunt/history", response_model=GameRoundHistoryResponse)
def get_jungle_hunt_history(limit: int = 30, db: Session = Depends(get_db), current_user: User = Depends(get_current_user)):
    return GameRoundHistoryResponse(**game_service.get_history(db, limit=limit))


@router.post("/admin/seed-defaults", response_model=GameDefinitionResponse)
def seed_default_games(db: Session = Depends(get_db), current_user: User = Depends(get_current_user)):
    _require_owner_or_above(current_user)
    definition = game_service.seed_default_games(db, current_user)
    return GameDefinitionResponse(**game_service._definition_payload(definition))


@router.put("/admin/catalog/{game_key}", response_model=GameDefinitionResponse)
def upsert_game_definition(game_key: str, payload: GameAdminUpsertRequest, db: Session = Depends(get_db), current_user: User = Depends(get_current_user)):
    _require_owner_or_above(current_user)
    definition = game_service.upsert_definition(db, current_user, game_key, payload.model_dump())
    return GameDefinitionResponse(**game_service._definition_payload(definition))


@router.post("/{game_key}/rounds", response_model=GameRoundResponse)
def create_game_round(game_key: str, payload: GameRoundCreateRequest, db: Session = Depends(get_db), current_user: User = Depends(get_current_user)):
    round_obj = game_service.create_round(db, game_key, current_user, payload.room_id)
    return GameRoundResponse(**game_service.get_round_payload(db, round_obj.id, current_user))


@router.get("/rounds/{round_id}", response_model=GameRoundResponse)
def get_game_round(round_id: int, db: Session = Depends(get_db), current_user: User = Depends(get_current_user)):
    return GameRoundResponse(**game_service.get_round_payload(db, round_id, current_user))


@router.post("/rounds/{round_id}/bets", response_model=GameBetResponse)
def place_game_bet(round_id: int, payload: GameBetRequest, db: Session = Depends(get_db), current_user: User = Depends(get_current_user)):
    return GameBetResponse(**game_service.place_bet(db, round_id, current_user, payload.target_id, payload.amount))


@router.post("/rounds/{round_id}/settle-test", response_model=GameRoundResultResponse)
def settle_game_round_for_internal_test(round_id: int, db: Session = Depends(get_db), current_user: User = Depends(get_current_user)):
    return GameRoundResultResponse(**game_service.settle_round(db, round_id, current_user))
