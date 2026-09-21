"""add user bio and user blocks

Revision ID: 1dc955ad55c7
Revises:
Create Date: 2026-05-11 14:16:45.537491
"""

from typing import Sequence, Union

from alembic import op
from legacy_snapshot import is_fresh_bootstrap


revision: str = "1dc955ad55c7"
down_revision: Union[str, Sequence[str], None] = "20260501_0000"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    if is_fresh_bootstrap(op.get_bind()):
        return
    # Add users.bio only if it does not already exist.
    op.execute(
        """
        ALTER TABLE users
        ADD COLUMN IF NOT EXISTS bio VARCHAR(240);
        """
    )

    # user_blocks already exists in your DB because the backend create_all()
    # created it before Alembic ran. So do not create it again here.
    # Later migrations will be fully controlled by Alembic.


def downgrade() -> None:
    op.execute(
        """
        ALTER TABLE users
        DROP COLUMN IF EXISTS bio;
        """
    )