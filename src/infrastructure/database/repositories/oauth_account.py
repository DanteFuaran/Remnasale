from typing import Optional

from src.infrastructure.database.models.sql.oauth_account import OAuthAccount

from .base import BaseRepository


class OAuthAccountRepository(BaseRepository):
    async def create(self, account: OAuthAccount) -> OAuthAccount:
        return await self.create_instance(account)

    async def get_by_provider(self, provider: str, provider_user_id: str) -> Optional[OAuthAccount]:
        return await self._get_one(
            OAuthAccount,
            OAuthAccount.provider == provider,
            OAuthAccount.provider_user_id == provider_user_id,
        )
