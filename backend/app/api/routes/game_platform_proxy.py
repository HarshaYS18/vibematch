from __future__ import annotations

import asyncio

import requests
from fastapi import APIRouter, Request
from fastapi.responses import Response

from app.core.config import settings

router = APIRouter(tags=["Game Platform Proxy"])
admin_router = APIRouter(tags=["Game Platform Admin Proxy"])

_HEADERS = {
    "authorization",
    "content-type",
    "accept",
    "idempotency-key",
    "traceparent",
    "tracestate",
    "x-request-id",
}


async def _proxy(request: Request, relative_path: str) -> Response:
    body = await request.body()
    headers = {
        key: value
        for key, value in request.headers.items()
        if key.lower() in _HEADERS
    }

    def execute() -> requests.Response:
        return requests.request(
            request.method,
            settings.GAME_PLATFORM_SERVICE_URL.rstrip("/")
            + "/"
            + relative_path.lstrip("/"),
            params=list(request.query_params.multi_items()),
            headers=headers,
            data=body or None,
            timeout=settings.GAME_PLATFORM_SERVICE_TIMEOUT_SECONDS,
            allow_redirects=False,
        )

    try:
        upstream = await asyncio.to_thread(execute)
    except requests.RequestException:
        return Response(
            content=b'{"detail":"Game Platform service unavailable"}',
            status_code=503,
            media_type="application/json",
        )

    return Response(
        content=upstream.content,
        status_code=upstream.status_code,
        headers={
            key: value
            for key, value in upstream.headers.items()
            if key.lower()
            in {
                "content-type",
                "cache-control",
                "etag",
                "last-modified",
                "x-request-id",
            }
        },
    )


# Keep canonical live-game and admin paths explicit for OpenAPI/contracts. These
# are registered before the fallback catch-alls, while the proxy still supports
# future Game Platform paths without a core release.
async def catalog(request: Request) -> Response:
    return await _proxy(request, "games/catalog")


async def catalog_game(request: Request, game_key: str) -> Response:
    return await _proxy(request, f"games/catalog/{game_key}")


async def open_session(request: Request, game_key: str) -> Response:
    return await _proxy(request, f"games/{game_key}/sessions")


async def close_session(request: Request, session_id: str) -> Response:
    return await _proxy(request, f"games/sessions/{session_id}/close")


async def create_round(request: Request, game_key: str) -> Response:
    return await _proxy(request, f"games/{game_key}/rounds")


async def get_round(request: Request, round_id: int) -> Response:
    return await _proxy(request, f"games/rounds/{round_id}")


async def place_bet(request: Request, round_id: int) -> Response:
    return await _proxy(request, f"games/rounds/{round_id}/bets")


async def settle_round(request: Request, round_id: int) -> Response:
    return await _proxy(request, f"games/rounds/{round_id}/settle-test")


async def jungle_history(request: Request) -> Response:
    return await _proxy(request, "games/global/jungle-hunt/history")


async def seed_defaults(request: Request) -> Response:
    return await _proxy(request, "admin/games/seed-defaults")


async def admin_catalog_game(request: Request, game_key: str) -> Response:
    return await _proxy(request, f"admin/games/catalog/{game_key}")


router.add_api_route("/games/catalog", catalog, methods=["GET"])
router.add_api_route("/games/catalog/{game_key}", catalog_game, methods=["GET"])
router.add_api_route("/games/{game_key}/sessions", open_session, methods=["POST"])
router.add_api_route(
    "/games/sessions/{session_id}/close",
    close_session,
    methods=["POST"],
)
router.add_api_route("/games/{game_key}/rounds", create_round, methods=["POST"])
router.add_api_route("/games/rounds/{round_id}", get_round, methods=["GET"])
router.add_api_route("/games/rounds/{round_id}/bets", place_bet, methods=["POST"])
router.add_api_route(
    "/games/rounds/{round_id}/settle-test",
    settle_round,
    methods=["POST"],
)
router.add_api_route(
    "/games/global/jungle-hunt/history",
    jungle_history,
    methods=["GET"],
)

admin_router.add_api_route(
    "/admin/games/seed-defaults",
    seed_defaults,
    methods=["POST"],
)
admin_router.add_api_route(
    "/admin/games/catalog/{game_key}",
    admin_catalog_game,
    methods=["PUT"],
)


async def games_root(request: Request) -> Response:
    return await _proxy(request, "games")


async def games_child(request: Request, path: str) -> Response:
    return await _proxy(request, f"games/{path}")


async def admin_games_root(request: Request) -> Response:
    return await _proxy(request, "admin/games")


async def admin_games_child(request: Request, path: str) -> Response:
    return await _proxy(request, f"admin/games/{path}")


router.add_api_route(
    "/games",
    games_root,
    methods=["GET", "POST", "PUT", "PATCH", "DELETE", "OPTIONS"],
)
router.add_api_route(
    "/games/{path:path}",
    games_child,
    methods=["GET", "POST", "PUT", "PATCH", "DELETE", "OPTIONS"],
)
admin_router.add_api_route(
    "/admin/games",
    admin_games_root,
    methods=["GET", "POST", "PUT", "PATCH", "DELETE", "OPTIONS"],
)
admin_router.add_api_route(
    "/admin/games/{path:path}",
    admin_games_child,
    methods=["GET", "POST", "PUT", "PATCH", "DELETE", "OPTIONS"],
)
