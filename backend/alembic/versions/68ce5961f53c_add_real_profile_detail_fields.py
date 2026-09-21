"""add real profile detail fields

Revision ID: 68ce5961f53c
Revises: 1dc955ad55c7
Create Date: 2026-05-11 15:18:54.691242
"""

from typing import Sequence, Union

from alembic import op
from legacy_snapshot import is_fresh_bootstrap


revision: str = "68ce5961f53c"
down_revision: Union[str, Sequence[str], None] = "1dc955ad55c7"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    if is_fresh_bootstrap(op.get_bind()):
        return
    op.execute("ALTER TABLE users ADD COLUMN IF NOT EXISTS date_of_birth DATE;")
    op.execute("ALTER TABLE users ADD COLUMN IF NOT EXISTS gender VARCHAR(30);")
    op.execute("ALTER TABLE users ADD COLUMN IF NOT EXISTS profession VARCHAR(80);")
    op.execute("ALTER TABLE users ADD COLUMN IF NOT EXISTS marital_status VARCHAR(30);")
    op.execute("ALTER TABLE users ADD COLUMN IF NOT EXISTS friend_gender_preference VARCHAR(30);")
    op.execute("ALTER TABLE users ADD COLUMN IF NOT EXISTS friend_marital_preference VARCHAR(30);")
    op.execute("ALTER TABLE users ADD COLUMN IF NOT EXISTS interests JSON;")


def downgrade() -> None:
    op.execute("ALTER TABLE users DROP COLUMN IF EXISTS interests;")
    op.execute("ALTER TABLE users DROP COLUMN IF EXISTS friend_marital_preference;")
    op.execute("ALTER TABLE users DROP COLUMN IF EXISTS friend_gender_preference;")
    op.execute("ALTER TABLE users DROP COLUMN IF EXISTS marital_status;")
    op.execute("ALTER TABLE users DROP COLUMN IF EXISTS profession;")
    op.execute("ALTER TABLE users DROP COLUMN IF EXISTS gender;")
    op.execute("ALTER TABLE users DROP COLUMN IF EXISTS date_of_birth;")