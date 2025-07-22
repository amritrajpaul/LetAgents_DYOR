# Utility functions for working with AnalysisResult objects.

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
