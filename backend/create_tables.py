"""Utility to create all database tables."""

from .database import Base, engine
# Import models so they are registered with Base metadata
from . import models  # noqa: F401


def create_tables() -> None:
    """Create database tables defined on the Base metadata."""
    print("Starting table creation...")
    try:
        Base.metadata.create_all(bind=engine)
    except Exception as exc:  # pragma: no cover - simple script
        print(f"Failed to create tables: {exc}")
        raise
    else:
        print("Tables created successfully.")


if __name__ == "__main__":
    create_tables()
