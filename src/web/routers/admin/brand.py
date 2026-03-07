"""Admin brand settings routes."""

from __future__ import annotations

from fastapi import APIRouter, Depends, HTTPException, Request
from fastapi.responses import JSONResponse

from src.web.dependencies import read_brand, require_admin, write_brand

router = APIRouter(prefix="/api/settings", tags=["admin-brand"])


@router.get("/brand")
async def api_get_brand():
    return JSONResponse(read_brand())


@router.post("/brand")
async def api_set_brand(request: Request, uid: int = Depends(require_admin)):
    body = await request.json()
    brand = read_brand()
    brand["name"] = body.get("name", brand.get("name", "VPN Shop"))
    brand["logo"] = body.get("logo", brand.get("logo", "🔐"))
    brand["slogan"] = body.get("slogan", brand.get("slogan", ""))
    brand["badge"] = body.get("badge", brand.get("badge", ""))
    brand["title"] = body.get("title", brand.get("title", ""))
    brand["subtitle"] = body.get("subtitle", brand.get("subtitle", ""))
    brand["timezone"] = body.get("timezone", brand.get("timezone", "Europe/Moscow"))
    # Advantages list
    if "advantages" in body:
        brand["advantages"] = body["advantages"]
    # FAQ list
    if "faq" in body:
        brand["faq"] = body["faq"]
    write_brand(brand)
    return JSONResponse({"ok": True})
