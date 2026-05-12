"""add user cover photo urls

Revision ID: eeeb28fa72a4
Revises: 68ce5961f53c
Create Date: 2026-05-11
"""

from typing import Sequence, Union

from alembic import op


revision: str = "eeeb28fa72a4"
down_revision: Union[str, None] = "68ce5961f53c"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.execute("ALTER TABLE users ADD COLUMN IF NOT EXISTS cover_photo_urls JSON;")


def downgrade() -> None:
    op.execute("ALTER TABLE users DROP COLUMN IF EXISTS cover_photo_urls;")