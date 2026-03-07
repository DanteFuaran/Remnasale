from __future__ import annotations

from typing import Optional

from sqlalchemy import BigInteger, ForeignKey, String, UniqueConstraint
from sqlalchemy.orm import Mapped, mapped_column

from .base import BaseSql
from .timestamp import TimestampMixin


class OAuthAccount(BaseSql, TimestampMixin):
    """Maps an external OAuth provider account to a local user (by telegram_id).

    For Telegram Widget users: telegram_id is the real Telegram ID.
    For Google / GitHub users: telegram_id is a synthetic negative ID.
    """

    __tablename__ = "oauth_accounts"
    __table_args__ = (
        UniqueConstraint("provider", "provider_user_id", name="uq_oauth_provider_user"),
    )

    id: Mapped[int] = mapped_column(primary_key=True, autoincrement=True)
    provider: Mapped[str] = mapped_column(String(32), nullable=False)  # "telegram", "google", "github"
    provider_user_id: Mapped[str] = mapped_column(String(128), nullable=False)
    telegram_id: Mapped[int] = mapped_column(
        BigInteger,
        ForeignKey("users.telegram_id", ondelete="CASCADE"),
        nullable=False,
    )
    email: Mapped[Optional[str]] = mapped_column(String(256), nullable=True)
    display_name: Mapped[Optional[str]] = mapped_column(String(256), nullable=True)
