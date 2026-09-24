from __future__ import annotations
import asyncio
import requests
from fastapi import APIRouter, Request
from fastapi.responses import Response
from app.core.config import settings
router=APIRouter(tags=["Game Platform Proxy"])
admin_router=APIRouter(tags=["Game Platform Admin Proxy"])
_HEADERS={"authorization","content-type","accept","idempotency-key","traceparent","tracestate","x-request-id"}
async def _proxy(request:Request,relative_path:str)->Response:
    body=await request.body(); headers={k:v for k,v in request.headers.items() if k.lower() in _HEADERS}
    def execute(): return requests.request(request.method,settings.GAME_PLATFORM_SERVICE_URL.rstrip("/")+"/"+relative_path.lstrip("/"),params=list(request.query_params.multi_items()),headers=headers,data=body or None,timeout=settings.GAME_PLATFORM_SERVICE_TIMEOUT_SECONDS,allow_redirects=False)
    try: upstream=await asyncio.to_thread(execute)
    except requests.RequestException: return Response(content=b'{"detail":"Game Platform service unavailable"}',status_code=503,media_type="application/json")
    return Response(content=upstream.content,status_code=upstream.status_code,headers={k:v for k,v in upstream.headers.items() if k.lower() in {"content-type","cache-control","etag","last-modified","x-request-id"}})
async def games_root(request:Request): return await _proxy(request,"games")
async def games_child(request:Request,path:str): return await _proxy(request,f"games/{path}")
async def admin_games_root(request:Request): return await _proxy(request,"admin/games")
async def admin_games_child(request:Request,path:str): return await _proxy(request,f"admin/games/{path}")
router.add_api_route("/games",games_root,methods=["GET","POST","PUT","PATCH","DELETE","OPTIONS"])
router.add_api_route("/games/{path:path}",games_child,methods=["GET","POST","PUT","PATCH","DELETE","OPTIONS"])
admin_router.add_api_route("/admin/games",admin_games_root,methods=["GET","POST","PUT","PATCH","DELETE","OPTIONS"])
admin_router.add_api_route("/admin/games/{path:path}",admin_games_child,methods=["GET","POST","PUT","PATCH","DELETE","OPTIONS"])
