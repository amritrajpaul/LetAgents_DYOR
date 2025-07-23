import os
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker, declarative_base
import cx_Oracle
from sqlalchemy.exc import SQLAlchemyError

DATABASE_URL = os.getenv("DATABASE_URL", "sqlite:///./users.db")
WALLET_PATH = os.getenv("ORACLE_WALLET_PATH")

if DATABASE_URL.startswith("oracle+cx_oracle") and WALLET_PATH:
    # Initialize Oracle client so it can locate the wallet files
    os.environ.setdefault("TNS_ADMIN", WALLET_PATH)
    try:
        cx_Oracle.init_oracle_client(config_dir=WALLET_PATH)
    except cx_Oracle.ProgrammingError:
        # init_oracle_client() can only be called once per process
        pass
    except Exception as exc:
        raise RuntimeError(f"Oracle client initialization failed: {exc}") from exc


try:
    engine = create_engine(
        DATABASE_URL,
        pool_pre_ping=True,
        connect_args={"check_same_thread": False}
        if DATABASE_URL.startswith("sqlite")
        else {},
    )
except SQLAlchemyError as exc:
    raise RuntimeError(f"Could not create SQLAlchemy engine: {exc}") from exc

SessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)

Base = declarative_base()

def get_db():
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()
