"""Remnawave panel availability tracking via Redis."""

from redis.asyncio import Redis

REMNAWAVE_STATUS_KEY = "remnawave:panel_available"


async def is_remnawave_available(redis_client: Redis) -> bool:
    val = await redis_client.get(REMNAWAVE_STATUS_KEY)
    if val is None:
        return True  # Assume available if no status recorded yet
    return val in (b"1", "1")


async def set_remnawave_status(redis_client: Redis, available: bool) -> None:
    await redis_client.set(REMNAWAVE_STATUS_KEY, "1" if available else "0", ex=180)
