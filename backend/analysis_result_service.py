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


def store_analysis_in_db(db: Session, analysis_data: dict) -> Optional[AnalysisResult]:
    """Persist analysis results using provided session and data.

    Parameters
    ----------
    db : Session
        Active SQLAlchemy session.
    analysis_data : dict
        Dictionary of column values for ``AnalysisResult``.

    Returns
    -------
    Optional[AnalysisResult]
        The saved ``AnalysisResult`` or ``None`` on failure.
    """
    try:
        return create_analysis_result(analysis_data, db)
    except SQLAlchemyError as exc:
        logging.error("Failed to store analysis result: %s", exc)
        return None


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


def get_user_analysis_results(user_id: str, db: Session) -> list[AnalysisResult]:
    """Retrieve all AnalysisResults for a given user ordered by newest first.

    Parameters
    ----------
    user_id : str
        Identifier of the user whose analysis results should be fetched.
    db : Session
        SQLAlchemy session used for the query.

    Returns
    -------
    list[AnalysisResult]
        Collection of AnalysisResult objects, empty if none found.
    """
    try:
        return (
            db.query(AnalysisResult)
            .filter(AnalysisResult.user_id == user_id)
            .order_by(AnalysisResult.created_at.desc())
            .all()
        )
    except SQLAlchemyError as exc:
        logging.error(
            "Failed to fetch AnalysisResults for user %s: %s", user_id, exc
        )
        raise


def get_user_results_from_db(db: Session, user_id: str) -> list[AnalysisResult]:
    """Wrapper to fetch all results for a given user using ``get_user_analysis_results``."""

    return get_user_analysis_results(user_id=user_id, db=db)
