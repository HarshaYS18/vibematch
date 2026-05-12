"""add room cover photo url

Revision ID: 20260513_0100
Revises: 
Create Date: 2026-05-13 01:00:00.000000
"""

from alembic import op
import sqlalchemy as sa


revision = "20260513_0100"
down_revision = None
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.add_column("rooms", sa.Column("cover_photo_url", sa.String(length=500), nullable=True))


def downgrade() -> None:
    op.drop_column("rooms", "cover_photo_url")
