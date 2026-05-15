from fastapi import APIRouter, HTTPException

router = APIRouter(prefix="/lucky-coins", tags=["Lucky Coins Reserved"])


def _reserved() -> None:
    raise HTTPException(
        status_code=501,
        detail="Reserved endpoint skeleton. Implementation will be completed by the project team.",
    )


@router.post("/wager")
def create_lucky_coin_wager_placeholder():
    _reserved()


@router.post("/settle")
def settle_lucky_coin_placeholder():
    _reserved()
