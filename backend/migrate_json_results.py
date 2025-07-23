"""Migrate analysis result JSON files into the database."""

import json
import logging
from datetime import datetime
from pathlib import Path

from .database import SessionLocal
from .models import AnalysisResult


DATA_DIR = Path("./data/results")
DEFAULT_STATUS = "migrated"


def migrate_results(data_dir: Path = DATA_DIR) -> None:
    """Load JSON files from ``data_dir`` and insert into the database."""
    session = SessionLocal()
    migrated = 0
    for json_file in data_dir.glob("*.json"):
        print(f"Processing {json_file.name}...")
        try:
            with json_file.open("r", encoding="utf-8") as f:
                payload = json.load(f)
        except Exception as exc:  # pragma: no cover - simple script
            logging.error("Failed to read %s: %s", json_file, exc)
            continue

        try:
            created_at = datetime.fromisoformat(payload.get("timestamp"))
        except Exception as exc:
            logging.error("Invalid timestamp in %s: %s", json_file, exc)
            continue

        record = AnalysisResult(
            query_text=payload.get("query", ""),
            result_summary=payload.get("summary", ""),
            full_report_json=json.dumps(payload.get("report", {})),
            created_at=created_at,
            user_id=payload.get("user"),
            status=DEFAULT_STATUS,
        )
        try:
            session.add(record)
            session.commit()
            migrated += 1
        except Exception as exc:  # pragma: no cover - simple script
            session.rollback()
            logging.error("Failed to insert %s: %s", json_file, exc)
    session.close()
    print(f"Migrated {migrated} records.")


if __name__ == "__main__":  # pragma: no cover - script
    migrate_results()
