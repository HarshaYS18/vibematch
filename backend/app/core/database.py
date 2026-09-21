"""Compatibility aliases for the canonical database module.

New code imports from :mod:`app.database`. This module deliberately creates no
engine or session of its own.
"""

from app.database import Base, SessionLocal, engine, get_db

__all__ = ["Base", "SessionLocal", "engine", "get_db"]
