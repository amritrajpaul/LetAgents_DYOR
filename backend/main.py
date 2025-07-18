import os
import json
from langchain_core.messages import BaseMessage
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
from .models import User, AnalysisRecord
from passlib.context import CryptContext
from sse_starlette.sse import EventSourceResponse, ServerSentEvent

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


def _serialize_obj(obj):
    """Helper to make objects JSON serializable."""
    if isinstance(obj, BaseMessage):
        return obj.to_json()
    return str(obj)


class AnalyzeRequest(BaseModel):
    """Request model for /analyze endpoint."""

    ticker: str
    date: str
    research_depth: int = 1
    analysts: Optional[List[str]] = None
    llm_provider: Optional[str] = None
    backend_url: Optional[str] = None
    quick_model: Optional[str] = None
    deep_model: Optional[str] = None


class UserCreate(BaseModel):
    email: str
    password: str
    openai_api_key: str
    finnhub_api_key: str


class UserLogin(BaseModel):
    email: str
    password: str


def compute_data_availability(state: dict) -> dict:
    """Return flags indicating which sections contain useful data."""
    return {
        "macro_news": bool(state.get("news_report")),
        "analyst_breakdown": bool(
            state.get("investment_debate_state", {}).get("history")
        ),
        "risk_assessment": bool(state.get("risk_debate_state", {}).get("history")),
        "bullish_momentum": bool(state.get("market_report")),
        "inflow_up": bool(state.get("fundamentals_report")),
    }


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
    request: AnalyzeRequest,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    """Run the TradingAgents analysis and return the results."""

    try:

        # Configure graph based on research depth
        config = DEFAULT_CONFIG.copy()
        config["max_debate_rounds"] = request.research_depth
        config["max_risk_discuss_rounds"] = request.research_depth
        if request.llm_provider is not None:
            config["llm_provider"] = request.llm_provider
        if request.backend_url is not None:
            config["backend_url"] = request.backend_url
        if request.quick_model is not None:
            config["quick_think_llm"] = request.quick_model
        if request.deep_model is not None:
            config["deep_think_llm"] = request.deep_model

        # Initialize graph with selected analysts (if provided)
        graph = TradingAgentsGraph(
            request.analysts or ["market", "social", "news", "fundamentals"],
            debug=True,
            config=config,
            openai_api_key=current_user.openai_api_key,
            finnhub_api_key=current_user.finnhub_api_key,
        )

        final_state, decision = graph.propagate(request.ticker, request.date)

        # Persist the result
        record = AnalysisRecord(
            user_id=current_user.id,
            ticker=request.ticker,
            date=request.date,
            decision=decision,
            full_report=json.dumps(final_state, default=_serialize_obj),
        )
        db.add(record)
        db.commit()
        db.refresh(record)

        serialized_report = json.loads(
            json.dumps(final_state, default=_serialize_obj)
        )
        return {
            "ticker": request.ticker,
            "date": request.date,
            "decision": decision,
            "report": serialized_report,
            "availability": compute_data_availability(serialized_report),
        }
    except Exception as exc:
        raise HTTPException(status_code=500, detail=str(exc))


@app.post("/analyze/stream")
def analyze_stream(
    request: AnalyzeRequest,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    """Stream progress of TradingAgents analysis via SSE."""

    def event_generator():
        try:

            config = DEFAULT_CONFIG.copy()
            config["max_debate_rounds"] = request.research_depth
            config["max_risk_discuss_rounds"] = request.research_depth
            if request.llm_provider is not None:
                config["llm_provider"] = request.llm_provider
            if request.backend_url is not None:
                config["backend_url"] = request.backend_url
            if request.quick_model is not None:
                config["quick_think_llm"] = request.quick_model
            if request.deep_model is not None:
                config["deep_think_llm"] = request.deep_model

            graph = TradingAgentsGraph(
                request.analysts or ["market", "social", "news", "fundamentals"],
                debug=True,
                config=config,
                openai_api_key=current_user.openai_api_key,
                finnhub_api_key=current_user.finnhub_api_key,
            )

            init_state = graph.propagator.create_initial_state(
                request.ticker, request.date
            )
            args = graph.propagator.get_graph_args()
            last_state = None
            for chunk in graph.graph.stream(init_state, **args):
                last_state = chunk
                if chunk.get("messages"):
                    msg_obj = chunk["messages"][-1]
                    if hasattr(msg_obj, "content"):
                        message = msg_obj.content
                    elif isinstance(msg_obj, dict):
                        message = json.dumps(msg_obj)
                    else:
                        message = str(msg_obj)
                    yield ServerSentEvent(
                        event="update",
                        data=json.dumps({"message": message}),
                    )


            if last_state is None:
                raise RuntimeError("Analysis produced no output")

            final_state = last_state
            decision = graph.process_signal(final_state["final_trade_decision"])

            record = AnalysisRecord(
                user_id=current_user.id,
                ticker=request.ticker,
                date=request.date,
                decision=decision,
                full_report=json.dumps(final_state, default=_serialize_obj),
            )
            db.add(record)
            db.commit()
            db.refresh(record)

            serialized_report = json.loads(
                json.dumps(final_state, default=_serialize_obj)
            )
            yield ServerSentEvent(
                event="complete",
                data=json.dumps(
                    {
                        "ticker": request.ticker,
                        "date": request.date,
                        "decision": decision,
                        "report": serialized_report,
                        "availability": compute_data_availability(
                            serialized_report
                        ),
                    }
                ),
            )
        except Exception as exc:
            yield ServerSentEvent(
                event="error",
                data=json.dumps({"detail": str(exc)}),
            )

    return EventSourceResponse(event_generator())


@app.get("/history")
def history(current_user: User = Depends(get_current_user), db: Session = Depends(get_db)):
    """Return a list of previous analyses for the authenticated user."""
    records = (
        db.query(AnalysisRecord)
        .filter(AnalysisRecord.user_id == current_user.id)
        .order_by(AnalysisRecord.id.desc())
        .all()
    )
    return [
        {
            "id": r.id,
            "ticker": r.ticker,
            "date": r.date,
            "decision": r.decision,
        }
        for r in records
    ]


@app.get("/history/{record_id}")
def history_detail(
    record_id: int,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    """Return full details of a past analysis."""
    record = db.query(AnalysisRecord).filter(AnalysisRecord.id == record_id).first()
    if not record or record.user_id != current_user.id:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Record not found")
    return {
        "id": record.id,
        "ticker": record.ticker,
        "date": record.date,
        "decision": record.decision,
"report": json.loads(record.full_report),
    }

# To run locally:
# uvicorn backend.main:app --host 0.0.0.0 --port 8000
