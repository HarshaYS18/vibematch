from sqlalchemy.exc import IntegrityError
from sqlalchemy.orm import Session


def get_or_create_unique(db: Session, model, column, value):
    """Create one row for a unique column even when two requests race."""
    row = db.query(model).filter(column == value).first()
    if row is not None:
        return row
    try:
        # A savepoint lets the losing request continue its outer transaction.
        with db.begin_nested():
            row = model(**{column.key: value})
            db.add(row)
            db.flush()
    except IntegrityError:
        return db.query(model).filter(column == value).one()
    return row


def get_or_create_unique_with_created(db: Session, model, column, value):
    """Race-safe unique insert that also reports whether this transaction created it."""
    row = db.query(model).filter(column == value).first()
    if row is not None:
        return row, False
    try:
        with db.begin_nested():
            row = model(**{column.key: value})
            db.add(row)
            db.flush()
        return row, True
    except IntegrityError:
        return db.query(model).filter(column == value).one(), False
