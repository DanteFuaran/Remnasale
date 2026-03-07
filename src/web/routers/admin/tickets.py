"""Admin ticket management routes."""

from __future__ import annotations

from typing import Any, Optional

from dishka import AsyncContainer, Scope
from fastapi import APIRouter, Depends, HTTPException, Request
from fastapi.responses import JSONResponse

from src.core.storage.key_builder import AdminTypingKey, GuestTypingKey
from src.infrastructure.database import UnitOfWork
from src.infrastructure.redis.repository import RedisRepository
from src.services.ticket import TicketService
from src.services.user import UserService
from src.web.dependencies import require_admin
from src.web.routers.tickets import ticket_to_dict

router = APIRouter(prefix="/api/admin/tickets", tags=["admin-tickets"])

_TYPING_TTL = 6  # seconds


async def _enrich_ticket(ticket_dict: dict, ticket_id: int, container: AsyncContainer) -> dict:
    """Add guest_typing + user_name fields to a ticket dict."""
    async with container(scope=Scope.REQUEST) as req_container:
        redis: RedisRepository = await req_container.get(RedisRepository)
        guest_typing = bool(await redis.get(GuestTypingKey(ticket_id=ticket_id), str))
        ticket_dict["guest_typing"] = guest_typing

        tg_id: int = ticket_dict.get("user_telegram_id", 0)
        if tg_id == 0:
            # Extract name from first message: "\u{1F464} Гость: {name}\n\n{text}"
            messages = ticket_dict.get("messages", [])
            guest_name = "Гость"
            if messages:
                first_text = messages[0].get("text", "")
                prefix = "\U0001f464 Гость: "
                if first_text.startswith(prefix):
                    first_line = first_text.split("\n")[0]
                    extracted = first_line[len(prefix):].strip()
                    if extracted:
                        guest_name = extracted
            ticket_dict["user_name"] = guest_name
        else:
            try:
                user_svc: UserService = await req_container.get(UserService)
                user = await user_svc.get(tg_id)
                if user:
                    parts = []
                    if getattr(user, "first_name", None):
                        parts.append(user.first_name)
                    if getattr(user, "last_name", None):
                        parts.append(user.last_name)
                    name = " ".join(parts).strip() or getattr(user, "username", "") or ""
                    ticket_dict["user_name"] = name or f"TG {tg_id}"
                else:
                    ticket_dict["user_name"] = f"TG {tg_id}"
            except Exception:
                ticket_dict["user_name"] = f"TG {tg_id}"
    return ticket_dict


@router.get("/unread-count")
async def api_admin_unread_count(request: Request, uid: int = Depends(require_admin)):
    """Admin: count of tickets with unread user messages."""
    container: AsyncContainer = request.app.state.dishka_container
    async with container(scope=Scope.REQUEST) as req_container:
        ticket_svc: TicketService = await req_container.get(TicketService)
        uow: UnitOfWork = await req_container.get(UnitOfWork)
        count = await ticket_svc.count_unread_admin(uow)
        return JSONResponse({"count": count})


@router.get("")
async def api_admin_get_tickets(request: Request, uid: int = Depends(require_admin)):
    container: AsyncContainer = request.app.state.dishka_container
    async with container(scope=Scope.REQUEST) as req_container:
        ticket_svc: TicketService = await req_container.get(TicketService)
        uow: UnitOfWork = await req_container.get(UnitOfWork)
        tickets = await ticket_svc.get_all_tickets(uow)
        return JSONResponse([ticket_to_dict(t) for t in tickets])


@router.get("/{ticket_id}")
async def api_admin_get_ticket(
    ticket_id: int,
    request: Request,
    uid: int = Depends(require_admin),
    silent: bool = False,
):
    container: AsyncContainer = request.app.state.dishka_container
    async with container(scope=Scope.REQUEST) as req_container:
        ticket_svc: TicketService = await req_container.get(TicketService)
        uow: UnitOfWork = await req_container.get(UnitOfWork)
        ticket = await ticket_svc.get_ticket(uow, ticket_id)
        if not ticket:
            raise HTTPException(status_code=404, detail="Тикет не найден")
        if not silent:
            await ticket_svc.mark_read_by_admin(uow, ticket_id)
    d = ticket_to_dict(ticket)
    d = await _enrich_ticket(d, ticket_id, container)
    return JSONResponse(d)


@router.post("/{ticket_id}/typing")
async def api_admin_typing(ticket_id: int, request: Request, uid: int = Depends(require_admin)):
    """Admin signals they're typing in a ticket."""
    container: AsyncContainer = request.app.state.dishka_container
    async with container(scope=Scope.REQUEST) as req_container:
        redis: RedisRepository = await req_container.get(RedisRepository)
        await redis.set(AdminTypingKey(ticket_id=ticket_id), "1", ex=_TYPING_TTL)
    return JSONResponse({"ok": True})


@router.post("/{ticket_id}/reply")
async def api_admin_reply_ticket(ticket_id: int, request: Request, uid: int = Depends(require_admin)):
    body = await request.json()
    text = (body.get("text") or "").strip()
    if not text:
        raise HTTPException(status_code=400, detail="Введите сообщение")

    container: AsyncContainer = request.app.state.dishka_container
    async with container(scope=Scope.REQUEST) as req_container:
        ticket_svc: TicketService = await req_container.get(TicketService)
        uow: UnitOfWork = await req_container.get(UnitOfWork)
        updated = await ticket_svc.add_reply(uow, ticket_id, uid, text, is_admin=True)
        if not updated:
            raise HTTPException(status_code=404, detail="Тикет не найден")

        return JSONResponse(ticket_to_dict(updated))


@router.post("/{ticket_id}/close")
async def api_admin_close_ticket(ticket_id: int, request: Request, uid: int = Depends(require_admin)):
    container: AsyncContainer = request.app.state.dishka_container
    async with container(scope=Scope.REQUEST) as req_container:
        ticket_svc: TicketService = await req_container.get(TicketService)
        uow: UnitOfWork = await req_container.get(UnitOfWork)
        closed = await ticket_svc.close_ticket(uow, ticket_id)
        if not closed:
            raise HTTPException(status_code=404, detail="Тикет не найден")
        return JSONResponse(ticket_to_dict(closed))


@router.delete("/{ticket_id}")
async def api_admin_delete_ticket(ticket_id: int, request: Request, uid: int = Depends(require_admin)):
    container: AsyncContainer = request.app.state.dishka_container
    async with container(scope=Scope.REQUEST) as req_container:
        ticket_svc: TicketService = await req_container.get(TicketService)
        uow: UnitOfWork = await req_container.get(UnitOfWork)
        deleted = await ticket_svc.delete_ticket(uow, ticket_id)
        if not deleted:
            raise HTTPException(status_code=404, detail="Тикет не найден")
        return JSONResponse({"ok": True})


@router.patch("/{ticket_id}/messages/{msg_id}")
async def api_admin_edit_ticket_message(
    ticket_id: int, msg_id: int, request: Request, uid: int = Depends(require_admin),
):
    """Admin: edit own (admin) message in any ticket."""
    body = await request.json()
    text = (body.get("text") or "").strip()
    if not text:
        raise HTTPException(status_code=400, detail="Текст не может быть пустым")
    container: AsyncContainer = request.app.state.dishka_container
    async with container(scope=Scope.REQUEST) as req_container:
        ticket_svc: TicketService = await req_container.get(TicketService)
        uow: UnitOfWork = await req_container.get(UnitOfWork)
        msg = await ticket_svc.edit_message(uow, msg_id, text, uid, is_admin=True)
        if not msg:
            raise HTTPException(status_code=403, detail="Нет доступа")
        return JSONResponse({"ok": True, "id": msg.id, "text": msg.text})


@router.delete("/{ticket_id}/messages/{msg_id}")
async def api_admin_delete_ticket_message(
    ticket_id: int, msg_id: int, request: Request, uid: int = Depends(require_admin),
):
    """Admin: delete any message in any ticket."""
    container: AsyncContainer = request.app.state.dishka_container
    async with container(scope=Scope.REQUEST) as req_container:
        uow: UnitOfWork = await req_container.get(UnitOfWork)
        # Admin can delete any message
        msg = await uow.repository.tickets.get_message_by_id(msg_id)
        if not msg:
            raise HTTPException(status_code=404, detail="Сообщение не найдено")
        await uow.repository.tickets.delete_message_by_id(msg_id)
        await uow.commit()
        return JSONResponse({"ok": True})
