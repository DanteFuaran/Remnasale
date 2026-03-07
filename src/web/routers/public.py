"""Public API routes — no authentication required (for the landing website)."""

from __future__ import annotations

from dishka import AsyncContainer, Scope
from fastapi import APIRouter, Request
from fastapi.responses import JSONResponse

from src.core.enums import PlanAvailability
from src.services.plan import PlanService

router = APIRouter(prefix="/api/public", tags=["public"])


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
