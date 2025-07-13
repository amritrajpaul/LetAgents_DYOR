import os
from typing import List, Optional

import jwt
from fastapi import FastAPI, HTTPException, Depends, status
from fastapi.security import OAuth2PasswordBearer
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel
from sqlalchemy.orm import Session

from tradingagents.graph.trading_graph import TradingAgentsGraph
from tradingagents.default_config import DEFAULT_CONFIG
from .database import Base, engine, get_db
from .models import User
from passlib.context import CryptContext

app = FastAPI()

# Allow all origins for development; restrict in production
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Initialize database
Base.metadata.create_all(bind=engine)

pwd_context = CryptContext(schemes=["bcrypt"], deprecated="auto")
SECRET_KEY = os.environ.get("SECRET_KEY", "change-me")
ALGORITHM = "HS256"

oauth2_scheme = OAuth2PasswordBearer(tokenUrl="login")


def get_password_hash(password: str) -> str:
    return pwd_context.hash(password)


def verify_password(password: str, password_hash: str) -> bool:
    return pwd_context.verify(password, password_hash)


def create_access_token(data: dict) -> str:
    return jwt.encode(data, SECRET_KEY, algorithm=ALGORITHM)


def get_current_user(
    token: str = Depends(oauth2_scheme), db: Session = Depends(get_db)
) -> User:
    try:
        payload = jwt.decode(token, SECRET_KEY, algorithms=[ALGORITHM])
        user_id: int = payload.get("id")
    except Exception:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Invalid token")
    user = db.query(User).filter(User.id == user_id).first()
    if not user:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Invalid token")
    return user


class AnalyzeRequest(BaseModel):
    """Request model for /analyze endpoint."""

    ticker: str
    date: str
    research_depth: int = 1
    analysts: Optional[List[str]] = None


class UserCreate(BaseModel):
    email: str
    password: str
    openai_api_key: str
    finnhub_api_key: str


class UserLogin(BaseModel):
    email: str
    password: str


@app.get("/")
def read_root():
    """Health check route."""
    return {"message": "Backend up"}


@app.post("/register")
def register(user: UserCreate, db: Session = Depends(get_db)):
    if db.query(User).filter(User.email == user.email).first():
        raise HTTPException(status_code=400, detail="Email already registered")
    user_obj = User(
        email=user.email,
        password_hash=get_password_hash(user.password),
        openai_api_key=user.openai_api_key,
        finnhub_api_key=user.finnhub_api_key,
    )
    db.add(user_obj)
    db.commit()
    db.refresh(user_obj)
    return {"id": user_obj.id}


@app.post("/login")
def login(credentials: UserLogin, db: Session = Depends(get_db)):
    user = db.query(User).filter(User.email == credentials.email).first()
    if not user or not verify_password(credentials.password, user.password_hash):
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Invalid credentials")
    token = create_access_token({"id": user.id, "email": user.email})
    return {"token": token}


@app.post("/analyze")
def analyze(
    request: AnalyzeRequest, current_user: User = Depends(get_current_user)
):
    """Run the TradingAgents analysis and return the results."""

    try:
        # Use user-specific API keys for this request
        os.environ["OPENAI_API_KEY"] = current_user.openai_api_key
        os.environ["FINNHUB_API_KEY"] = current_user.finnhub_api_key

        # Configure graph based on research depth
        config = DEFAULT_CONFIG.copy()
        config["max_debate_rounds"] = request.research_depth
        config["max_risk_discuss_rounds"] = request.research_depth

        # Initialize graph with selected analysts (if provided)
        graph = TradingAgentsGraph(
            request.analysts or ["market", "social", "news", "fundamentals"],
            debug=True,
            config=config,
        )

        final_state, decision = graph.propagate(request.ticker, request.date)

        return {
            "ticker": request.ticker,
            "date": request.date,
            "decision": decision,
            "report": final_state,
        }
    except Exception as exc:
        raise HTTPException(status_code=500, detail=str(exc))

# To run locally:
# uvicorn backend.main:app --host 0.0.0.0 --port 8000
