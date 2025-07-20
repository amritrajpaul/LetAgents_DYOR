from sqlalchemy import Column, Integer, String, Text, ForeignKey
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


class User(Base):
    __tablename__ = "users"

    id = Column(Integer, primary_key=True, index=True)
    email = Column(String, unique=True, index=True, nullable=False)
    password_hash = Column(String, nullable=False)
    openai_api_key = Column(String, nullable=True)
    finnhub_api_key = Column(String, nullable=True)
