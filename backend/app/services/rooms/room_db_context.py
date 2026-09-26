"""Room-control session indirection.

HTTP dependencies use FastAPI overrides, but room command transactions and
post-commit snapshot work also need the extracted service's isolated DB engine.
Core defaults to app.database.SessionLocal; room-control configures its own
factory at startup.
"""

from __future__ import annotations

from collections.abc import Callable, Iterator
from contextlib import contextmanager

from sqlalchemy.orm import Session


_room_session_factory: Callable[[], Session] | None = None


def configure_room_session_factory(factory: Callable[[], Session] | None) -> None:
    global _room_session_factory
    _room_session_factory = factory


def _session_factory() -> Callable[[], Session]:
    if _room_session_factory is not None:
        return _room_session_factory
    from app.database import SessionLocal

    return SessionLocal


@contextmanager
def room_session() -> Iterator[Session]:
    db = _session_factory()()
    try:
        yield db
    finally:
        db.close()
