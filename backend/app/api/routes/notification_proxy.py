from __future__ import annotations
import asyncio
import requests
from fastapi import APIRouter, Request
from fastapi.responses import Response
from app.core.config import settings

router=APIRouter(tags=["Notification Service Proxy"])
_HEADERS={"authorization","content-type","accept","idempotency-key","traceparent","tracestate","x-request-id"}

async def _proxy(request:Request,relative_path:str)->Response:
    body=await request.body()
    headers={k:v for k,v in request.headers.items() if k.lower() in _HEADERS}
    def execute():
        return requests.request(request.method,settings.NOTIFICATION_SERVICE_URL.rstrip("/")+"/"+relative_path.lstrip("/"),params=list(request.query_params.multi_items()),headers=headers,data=body or None,timeout=settings.NOTIFICATION_SERVICE_TIMEOUT_SECONDS,allow_redirects=False)
    try: upstream=await asyncio.to_thread(execute)
    except requests.RequestException:
        return Response(content=b'{"detail":"Notification service unavailable"}',status_code=503,media_type="application/json")
    return Response(content=upstream.content,status_code=upstream.status_code,headers={k:v for k,v in upstream.headers.items() if k.lower() in {"content-type","cache-control","etag","x-request-id"}})

async def notifications_root(request:Request)->Response: return await _proxy(request,"notifications")
async def notifications_child(request:Request,path:str)->Response: return await _proxy(request,f"notifications/{path}")
async def push_root(request:Request)->Response: return await _proxy(request,"push")
async def push_child(request:Request,path:str)->Response: return await _proxy(request,f"push/{path}")

router.add_api_route("/notifications",notifications_root,methods=["GET","POST","PUT","PATCH","DELETE","OPTIONS"])
router.add_api_route("/notifications/{path:path}",notifications_child,methods=["GET","POST","PUT","PATCH","DELETE","OPTIONS"])
router.add_api_route("/push",push_root,methods=["GET","POST","PUT","PATCH","DELETE","OPTIONS"])
router.add_api_route("/push/{path:path}",push_child,methods=["GET","POST","PUT","PATCH","DELETE","OPTIONS"])
