# Utility functions for working with AnalysisResult objects.

import logging
from typing import Optional

from sqlalchemy.orm import Session
from sqlalchemy.exc import SQLAlchemyError

from .models import AnalysisResult


def create_analysis_result(new_analysis_data: dict, db: Session) -> AnalysisResult:
    """Create and persist an AnalysisResult from a data dictionary.

    Parameters
    ----------
    new_analysis_data : dict
        Mapping of column names to values for the new AnalysisResult.
    db : Session
        SQLAlchemy session used to persist the object.

    Returns
    -------
    AnalysisResult
        The persisted AnalysisResult instance.
    """
    try:
        result = AnalysisResult(**new_analysis_data)
        db.add(result)
        db.commit()
        db.refresh(result)
        return result
    except SQLAlchemyError:
        db.rollback()
        raise


def get_analysis_result(analysis_id: int, db: Session) -> Optional[AnalysisResult]:
    """Retrieve a single AnalysisResult by its primary key.

    Parameters
    ----------
    analysis_id : int
        ID of the AnalysisResult to fetch.
    db : Session
        SQLAlchemy session used for the query.

    Returns
    -------
    Optional[AnalysisResult]
        The AnalysisResult if found, otherwise ``None``.
    """
    try:
        return db.get(AnalysisResult, analysis_id)
    except SQLAlchemyError as exc:
        logging.error("Failed to fetch AnalysisResult %s: %s", analysis_id, exc)
        raise
