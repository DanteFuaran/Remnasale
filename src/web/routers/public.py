"""Public API routes — no authentication required (for the landing website)."""

from __future__ import annotations

import pathlib as _pl
import secrets
from typing import Optional

from fastapi import File, UploadFile

_UPLOADS_DIR = _pl.Path("/opt/remnasale/assets/ticket_uploads")
_UPLOADS_DIR.mkdir(parents=True, exist_ok=True)
_ALLOWED_MIME = {"image/jpeg", "image/png", "image/gif", "image/webp"}
_MAX_IMG_SIZE = 5 * 1024 * 1024  # 5 MB

from dishka import AsyncContainer, Scope
from fastapi import APIRouter, Cookie, HTTPException, Request
from fastapi.responses import JSONResponse

from src.core.config import AppConfig
from src.core.enums import PlanAvailability, UserRole
from src.core.storage.key_builder import AdminTypingKey, GuestTicketKey, GuestTypingKey
from src.infrastructure.database import UnitOfWork
from src.infrastructure.redis.repository import RedisRepository
from src.services.plan import PlanService
from src.services.referral import ReferralService
from src.services.ticket import TicketService
from src.web.dependencies import read_brand
from src.web.routers.tickets import ticket_to_dict

router = APIRouter(prefix="/api/public", tags=["public"])

_GUEST_COOKIE = "guest_support_token"
_GUEST_TTL = 60 * 60 * 24 * 30  # 30 days
_GUEST_TG_ID = 0  # sentinel for guest users
_TYPING_TTL = 6  # seconds


def _set_guest_cookie(response: JSONResponse, token: str) -> None:
    response.set_cookie(
        key=_GUEST_COOKIE,
        value=token,
        max_age=_GUEST_TTL,
        httponly=True,
        samesite="lax",
        path="/",
        secure=False,
    )


async def _resolve_guest_token(
    token: Optional[str],
    container: AsyncContainer,
) -> Optional[int]:
    """Resolve guest token → ticket_id from Redis. Returns None if not found."""
    if not token:
        return None
    async with container(scope=Scope.REQUEST) as req_container:
        redis: RedisRepository = await req_container.get(RedisRepository)
        key = GuestTicketKey(token=token)
        ticket_id = await redis.get(key, int)
        return ticket_id


# ── Public config / plans ──────────────────────────────────────────


@router.get("/config")
async def api_public_config(request: Request):
    """Return public bot configuration for the landing website."""
    config: AppConfig = request.app.state.config
    bot_username = ReferralService._bot_username or ""
    bot_url = f"https://t.me/{bot_username}" if bot_username else ""
    oauth_providers = {
        "google": bool(config.google_client_id.get_secret_value()),
        "github": bool(config.github_client_id.get_secret_value()),
    }
    return JSONResponse({
        "bot_username": bot_username,
        "bot_url": bot_url,
        "oauth_providers": oauth_providers,
        "brand": read_brand(),
    })


@router.get("/plans")
async def api_public_plans(request: Request):
    """Return active plans available to all users (for the public website)."""
    container: AsyncContainer = request.app.state.dishka_container
    async with container(scope=Scope.REQUEST) as req_container:
        plan_service: PlanService = await req_container.get(PlanService)
        all_plans = await plan_service.get_all()

        result = []
        for p in all_plans:
            if not p.is_active:
                continue
            if p.availability not in (PlanAvailability.ALL, PlanAvailability.NEW):
                continue

            durations = []
            for d in (p.durations or []):
                prices = []
                for pr in (d.prices or []):
                    prices.append({
                        "currency": pr.currency.value if hasattr(pr.currency, "value") else str(pr.currency),
                        "amount": str(pr.price),
                    })
                durations.append({"days": d.days, "prices": prices})

            result.append({
                "id": p.id,
                "name": p.name,
                "description": p.description or "",
                "traffic_limit": p.traffic_limit,
                "device_limit": p.device_limit,
                "is_unlimited_traffic": p.is_unlimited_traffic,
                "is_unlimited_devices": p.is_unlimited_devices,
                "durations": durations,
            })

        return JSONResponse(result)


# ── Guest ticket (chat) endpoints ──────────────────────────────────


@router.post("/tickets/guest")
async def api_guest_ticket(request: Request):
    """Create a support ticket from a guest. Sets a cookie-based session token."""
    body = await request.json()
    name = (body.get("name") or "").strip()[:100]
    subject = (body.get("subject") or "").strip()[:200]
    text = (body.get("text") or "").strip()[:2000]

    if not name or not subject or not text:
        raise HTTPException(status_code=400, detail="Заполните имя, тему и сообщение")

    full_text = f"👤 Гость: {name}\n\n{text}"

    container: AsyncContainer = request.app.state.dishka_container
    async with container(scope=Scope.REQUEST) as req_container:
        ticket_svc: TicketService = await req_container.get(TicketService)
        uow: UnitOfWork = await req_container.get(UnitOfWork)
        ticket = await ticket_svc.create_ticket(uow, _GUEST_TG_ID, subject, full_text)

        token = secrets.token_urlsafe(32)
        redis: RedisRepository = await req_container.get(RedisRepository)
        await redis.set(GuestTicketKey(token=token), ticket.id, ex=_GUEST_TTL)

        try:
            from src.services.notification import NotificationService
            from src.services.user import UserService
            from src.core.utils.message_payload import MessagePayload

            ntf: NotificationService = await req_container.get(NotificationService)
            user_service: UserService = await req_container.get(UserService)
            ticket_text = (
                f"🎫 Новый тикет #{ticket.id} (гость)\n\n"
                f"👤 {name}\n📝 {subject}\n\n{text[:300]}"
            )
            payload = MessagePayload.not_deleted(text=ticket_text)
            devs = await user_service.get_by_role(role=UserRole.DEV)
            admins = await user_service.get_by_role(role=UserRole.ADMIN)
            recipients = {u.telegram_id: u for u in (devs or []) + (admins or [])}
            for recipient in recipients.values():
                try:
                    await ntf.notify_user(user=recipient, payload=payload)
                except Exception:
                    pass
        except Exception:
            pass

        resp = JSONResponse({"ok": True, "ticket_id": ticket.id, **ticket_to_dict(ticket)})
        _set_guest_cookie(resp, token)
        return resp


@router.get("/tickets/guest/check")
async def api_guest_check(
    request: Request,
    guest_support_token: Optional[str] = Cookie(default=None),
):
    """Check if guest has an active ticket session."""
    container: AsyncContainer = request.app.state.dishka_container
    ticket_id = await _resolve_guest_token(guest_support_token, container)
    return JSONResponse({"has_ticket": ticket_id is not None, "ticket_id": ticket_id})


@router.get("/tickets/guest/me")
async def api_guest_get_ticket(
    request: Request,
    guest_support_token: Optional[str] = Cookie(default=None),
):
    """Get guest's own ticket thread (identified by cookie)."""
    container: AsyncContainer = request.app.state.dishka_container
    ticket_id = await _resolve_guest_token(guest_support_token, container)
    if not ticket_id:
        raise HTTPException(status_code=404, detail="Чат не найден")

    async with container(scope=Scope.REQUEST) as req_container:
        ticket_svc: TicketService = await req_container.get(TicketService)
        uow: UnitOfWork = await req_container.get(UnitOfWork)
        ticket = await ticket_svc.get_ticket(uow, ticket_id)
        if not ticket:
            raise HTTPException(status_code=404, detail="Чат не найден")
        await ticket_svc.mark_read_by_user(uow, ticket_id)
        # Check if admin is currently typing
        redis: RedisRepository = await req_container.get(RedisRepository)
        admin_typing = bool(await redis.get(AdminTypingKey(ticket_id=ticket_id), str))
        data = ticket_to_dict(ticket)
        data["admin_typing"] = admin_typing
        return JSONResponse(data)


@router.post("/tickets/guest/me/typing")
async def api_guest_typing(
    request: Request,
    guest_support_token: Optional[str] = Cookie(default=None),
):
    """Guest signals they are currently typing — stored in Redis with short TTL."""
    container: AsyncContainer = request.app.state.dishka_container
    ticket_id = await _resolve_guest_token(guest_support_token, container)
    if not ticket_id:
        raise HTTPException(status_code=404, detail="Чат не найден")
    async with container(scope=Scope.REQUEST) as req_container:
        redis: RedisRepository = await req_container.get(RedisRepository)
        await redis.set(GuestTypingKey(ticket_id=ticket_id), "1", ex=_TYPING_TTL)
    return JSONResponse({"ok": True})


@router.post("/tickets/guest/me/reply")
async def api_guest_reply(
    request: Request,
    guest_support_token: Optional[str] = Cookie(default=None),
):
    """Guest replies in their own ticket thread."""
    body = await request.json()
    text = (body.get("text") or "").strip()[:2000]
    if not text:
        raise HTTPException(status_code=400, detail="Введите сообщение")

    container: AsyncContainer = request.app.state.dishka_container
    ticket_id = await _resolve_guest_token(guest_support_token, container)
    if not ticket_id:
        raise HTTPException(status_code=404, detail="Чат не найден")

    async with container(scope=Scope.REQUEST) as req_container:
        ticket_svc: TicketService = await req_container.get(TicketService)
        uow: UnitOfWork = await req_container.get(UnitOfWork)
        ticket = await ticket_svc.get_ticket(uow, ticket_id)
        if not ticket:
            raise HTTPException(status_code=404, detail="Чат не найден")
        status_val = ticket.status.value if hasattr(ticket.status, "value") else ticket.status
        if status_val == "CLOSED":
            raise HTTPException(status_code=400, detail="Чат закрыт")
        updated = await ticket_svc.add_reply(uow, ticket_id, _GUEST_TG_ID, text, is_admin=False)
        return JSONResponse(ticket_to_dict(updated))


@router.post("/image-upload")
async def api_image_upload(file: UploadFile = File(...)):
    """Upload an image attachment for a chat message."""
    if file.content_type not in _ALLOWED_MIME:
        raise HTTPException(status_code=400, detail="Только изображения (JPEG, PNG, GIF, WebP)")
    data = await file.read()
    if len(data) > _MAX_IMG_SIZE:
        raise HTTPException(status_code=400, detail="Файл слишком большой (макс. 5МБ)")
    raw_ext = (file.filename or "").rsplit(".", 1)[-1].lower() if "." in (file.filename or "") else ""
    ext = raw_ext if raw_ext in {"jpg", "jpeg", "png", "gif", "webp"} else "jpg"
    filename = f"{secrets.token_hex(16)}.{ext}"
    (_UPLOADS_DIR / filename).write_bytes(data)
    return JSONResponse({"url": f"/ticket-uploads/{filename}"})
