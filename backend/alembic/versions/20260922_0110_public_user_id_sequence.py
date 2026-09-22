"""expand public user ID allocation capacity

Revision ID: 20260922_0110
Revises: 20260922_0100
Create Date: 2026-09-22
"""

from alembic import op


revision = "20260922_0110"
down_revision = "20260922_0100"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.execute(
        """
        CREATE SEQUENCE IF NOT EXISTS funkey_public_user_id_seq
        AS BIGINT
        INCREMENT BY 1
        MINVALUE 1
        MAXVALUE 999999999
        START WITH 1
        NO CYCLE
        """
    )


def downgrade() -> None:
    op.execute("DROP SEQUENCE IF EXISTS funkey_public_user_id_seq")
