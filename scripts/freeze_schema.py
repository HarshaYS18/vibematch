"""Generate an immutable PostgreSQL schema snapshot for migration review.

Run once from backend with the backend dependencies installed. Never regenerate
an already released snapshot; future changes belong in new Alembic revisions.
"""
import json
import sys
from pathlib import Path

from sqlalchemy import create_mock_engine
from sqlalchemy.schema import CreateColumn, CreateTable, CreateIndex
from sqlalchemy.dialects import postgresql

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "backend"))
from app import models  # noqa: E402, F401
from app.database import Base  # noqa: E402

dialect = postgresql.dialect()
enums = {}
tables = []
for table in Base.metadata.sorted_tables:
    for column in table.columns:
        if hasattr(column.type, "enums") and column.type.native_enum:
            enums[column.type.name] = column.type.enums
    tables.append({
        "name": table.name,
        "create": str(CreateTable(table).compile(dialect=dialect)),
        "columns": {column.name: str(CreateColumn(column).compile(dialect=dialect)) for column in table.columns},
        "indexes": {index.name: str(CreateIndex(index).compile(dialect=dialect)) for index in sorted(table.indexes, key=lambda i: i.name)},
    })
target = ROOT / "backend" / "alembic" / "schema_20260921.json"
target.write_text(json.dumps({"enums": enums, "tables": tables}, indent=2) + "\n", encoding="utf-8")
print(f"Frozen {len(tables)} tables and {len(enums)} enums in {target.name}")
