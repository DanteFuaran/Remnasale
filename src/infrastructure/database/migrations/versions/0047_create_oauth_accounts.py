from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa

revision: str = "0047"
down_revision: Union[str, None] = "0046"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.create_table(
        "oauth_accounts",
        sa.Column("id", sa.Integer(), nullable=False, autoincrement=True),
        sa.Column("provider", sa.String(32), nullable=False),
        sa.Column("provider_user_id", sa.String(128), nullable=False),
        sa.Column("telegram_id", sa.BigInteger(), nullable=False),
        sa.Column("email", sa.String(256), nullable=True),
        sa.Column("display_name", sa.String(256), nullable=True),
        sa.Column("created_at", sa.DateTime(), nullable=False, server_default=sa.func.now()),
        sa.Column("updated_at", sa.DateTime(), nullable=False, server_default=sa.func.now(), onupdate=sa.func.now()),
        sa.ForeignKeyConstraint(["telegram_id"], ["users.telegram_id"], ondelete="CASCADE"),
        sa.PrimaryKeyConstraint("id"),
        sa.UniqueConstraint("provider", "provider_user_id", name="uq_oauth_provider_user"),
    )
    op.create_index("ix_oauth_accounts_telegram_id", "oauth_accounts", ["telegram_id"])


def downgrade() -> None:
    op.drop_index("ix_oauth_accounts_telegram_id", table_name="oauth_accounts")
    op.drop_table("oauth_accounts")
