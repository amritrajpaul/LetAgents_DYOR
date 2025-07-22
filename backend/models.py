from sqlalchemy import Column, Integer, String, Text, ForeignKey, DateTime, Sequence
from sqlalchemy.sql import func
from .database import Base


class AnalysisRecord(Base):
    """Persist results of each analysis run."""

    __tablename__ = "analysis_records"

    id = Column(Integer, primary_key=True, index=True)
    user_id = Column(Integer, ForeignKey("users.id"), index=True, nullable=False)
    ticker = Column(String, nullable=False)
    date = Column(String, nullable=False)
    decision = Column(Text, nullable=False)
    full_report = Column(Text, nullable=False)
    tool_calls = Column(Integer, default=0)
    llm_calls = Column(Integer, default=0)
    reports_generated = Column(Integer, default=0)


class User(Base):
    __tablename__ = "users"

    id = Column(Integer, primary_key=True, index=True)
    email = Column(String, unique=True, index=True, nullable=False)
    password_hash = Column(String, nullable=False)
    openai_api_key = Column(String, nullable=True)
    finnhub_api_key = Column(String, nullable=True)


class AnalysisResult(Base):
    """Store summarized analysis results."""

    __tablename__ = "analysis_results"

    id = Column(Integer, Sequence("analysis_results_id_seq"), primary_key=True)
    query_text = Column(String(500), nullable=False)
    result_summary = Column(Text, nullable=False)
    full_report_json = Column(Text, nullable=True)
    created_at = Column(DateTime, server_default=func.now(), nullable=False)
    user_id = Column(String(100), nullable=True)
    status = Column(String(50), nullable=True)
