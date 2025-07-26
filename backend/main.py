import os
import json
from langchain_core.messages import BaseMessage
from typing import List, Optional
from datetime import datetime
import posthog

import jwt
from fastapi import FastAPI, HTTPException, Depends, status, Request
from fastapi.responses import JSONResponse
from fastapi.security import OAuth2PasswordBearer
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel
from sqlalchemy.orm import Session
from sqlalchemy import inspect, text

from tradingagents.graph.trading_graph import TradingAgentsGraph
from tradingagents.default_config import DEFAULT_CONFIG
from .database import Base, engine, get_db
from .models import User, AnalysisRecord
from .analysis_result_service import (
    store_analysis_in_db,
    get_user_results_from_db,
)
from passlib.context import CryptContext
from sse_starlette.sse import EventSourceResponse, ServerSentEvent
from .posthog_middleware import PostHogMiddleware

app = FastAPI()

# Configure PostHog if a key is provided
POSTHOG_API_KEY = os.getenv("POSTHOG_API_KEY")
POSTHOG_HOST = os.getenv("POSTHOG_HOST", "https://app.posthog.com")
POSTHOG_ENABLED = bool(POSTHOG_API_KEY)
if POSTHOG_ENABLED:
    posthog.project_api_key = POSTHOG_API_KEY
    posthog.host = POSTHOG_HOST

# Global exception handler to report unexpected errors
@app.exception_handler(Exception)
async def capture_exceptions(request: Request, exc: Exception):
    if POSTHOG_API_KEY:
        try:
            import traceback
            posthog.capture(
                distinct_id="backend",
                event="error",
                properties={
                    "path": request.url.path,
                    "error": str(exc),
                    "traceback": traceback.format_exc(),
                },
            )
        except Exception:
            pass
    return JSONResponse(
        status_code=500,
        content={"detail": "Internal Server Error"},
    )

# Allow all origins for development; restrict in production
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)
app.add_middleware(PostHogMiddleware)

# Initialize database
Base.metadata.create_all(bind=engine)


def _ensure_analysis_columns():
    """Create new columns in analysis_records if they don't exist."""
    inspector = inspect(engine)
    if not inspector.has_table("analysis_records"):
        return
    existing = {col["name"] for col in inspector.get_columns("analysis_records")}
    with engine.begin() as conn:
        if "tool_calls" not in existing:
            conn.execute(
                text(
                    "ALTER TABLE analysis_records ADD COLUMN tool_calls INTEGER DEFAULT 0"
                )
            )
        if "llm_calls" not in existing:
            conn.execute(
                text(
                    "ALTER TABLE analysis_records ADD COLUMN llm_calls INTEGER DEFAULT 0"
                )
            )
        if "reports_generated" not in existing:
            conn.execute(
                text(
                    "ALTER TABLE analysis_records ADD COLUMN reports_generated INTEGER DEFAULT 0"
                )
            )


_ensure_analysis_columns()

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
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED, detail="Invalid token"
        )
    user = db.query(User).filter(User.id == user_id).first()
    if not user:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED, detail="Invalid token"
        )
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
    openai_api_key: Optional[str] = None
    finnhub_api_key: Optional[str] = None


class UserLogin(BaseModel):
    email: str
    password: str


class UpdateKeys(BaseModel):
    openai_api_key: Optional[str] = None
    finnhub_api_key: Optional[str] = None


class AnalysisResponse(BaseModel):
    """Response model for analysis result entries."""

    id: int
    query_text: str
    result_summary: str
    full_report_json: Optional[str] = None
    created_at: datetime
    user_id: Optional[str] = None
    status: Optional[str] = None

    class Config:
        orm_mode = True


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


def compute_metrics(state: dict) -> dict:
    """Return counts for tool calls, LLM calls and generated reports."""
    messages = state.get("messages", [])
    llm_calls = max(len(messages) - 1, 0)
    tool_calls = 0
    for msg in messages:
        if hasattr(msg, "tool_calls"):
            tool_calls += len(msg.tool_calls)
        elif isinstance(msg, dict) and msg.get("tool_calls"):
            tool_calls += len(msg["tool_calls"])

    report_keys = [
        "market_report",
        "fundamentals_report",
        "sentiment_report",
        "news_report",
        "investment_plan",
        "trader_investment_plan",
        "final_trade_decision",
    ]
    reports_generated = sum(1 for k in report_keys if state.get(k))
    return {
        "tool_calls": tool_calls,
        "llm_calls": llm_calls,
        "reports": reports_generated,
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
    if POSTHOG_ENABLED:
        posthog.identify(user_obj.id, {"email": user_obj.email})
    return {"id": user_obj.id}


@app.post("/login")
def login(credentials: UserLogin, db: Session = Depends(get_db)):
    user = db.query(User).filter(User.email == credentials.email).first()
    if not user or not verify_password(credentials.password, user.password_hash):
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED, detail="Invalid credentials"
        )
    token = create_access_token({"id": user.id, "email": user.email})
    if POSTHOG_ENABLED:
        posthog.identify(user.id, {"email": user.email})
    return {"token": token}


@app.get("/me")
def read_profile(current_user: User = Depends(get_current_user)):
    return {
        "id": current_user.id,
        "email": current_user.email,
        "openai_api_key": current_user.openai_api_key,
        "finnhub_api_key": current_user.finnhub_api_key,
    }


@app.put("/keys")
def update_keys(
    update: UpdateKeys,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    if update.openai_api_key is not None:
        current_user.openai_api_key = update.openai_api_key
    if update.finnhub_api_key is not None:
        current_user.finnhub_api_key = update.finnhub_api_key
    db.commit()
    db.refresh(current_user)
    return {"status": "ok"}


@app.post("/analyze", status_code=status.HTTP_201_CREATED)
def analyze(
    request: AnalyzeRequest,
    http_request: Request,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    """Run the TradingAgents analysis and return the results."""

    if not current_user.openai_api_key or not current_user.finnhub_api_key:
        raise HTTPException(status_code=400, detail="API keys not configured")

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

        metrics = compute_metrics(final_state)

        # Persist detailed and summarized results
        record = AnalysisRecord(
            user_id=current_user.id,
            ticker=request.ticker,
            date=request.date,
            decision=decision,
            full_report=json.dumps(final_state, default=_serialize_obj),
            tool_calls=metrics["tool_calls"],
            llm_calls=metrics["llm_calls"],
            reports_generated=metrics["reports"],
        )
        db.add(record)
        db.commit()
        db.refresh(record)

        new_analysis_data = {
            "query_text": request.ticker,
            "result_summary": decision,
            "full_report_json": json.dumps(final_state, default=_serialize_obj),
            "user_id": str(current_user.id),
            "status": "completed",
        }
        stored_summary = store_analysis_in_db(db=db, analysis_data=new_analysis_data)
        if stored_summary is None:
            raise RuntimeError("Failed to store summary")

        serialized_report = json.loads(json.dumps(final_state, default=_serialize_obj))
        return {
            "ticker": request.ticker,
            "date": request.date,
            "decision": decision,
            "report": serialized_report,
            "availability": compute_data_availability(serialized_report),
            "metrics": metrics,
        }
    except Exception as exc:
        if POSTHOG_ENABLED:
            import traceback
            posthog.capture(
                distinct_id=str(current_user.id),
                event="error",
                properties={
                    "path": http_request.url.path,
                    "error": str(exc),
                    "traceback": traceback.format_exc(),
                },
            )
        raise HTTPException(status_code=500, detail=str(exc))


@app.post("/analyze/stream")
def analyze_stream(
    request: AnalyzeRequest,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    """Stream progress of TradingAgents analysis via SSE."""

    if not current_user.openai_api_key or not current_user.finnhub_api_key:
        raise HTTPException(status_code=400, detail="API keys not configured")

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
            tool_calls = 0
            llm_calls = 0
            reports_generated = 0
            agent_status = {
                # Analyst Team
                "Market Analyst": "pending",
                "Social Analyst": "pending",
                "News Analyst": "pending",
                "Fundamentals Analyst": "pending",
                # Research Team
                "Bull Researcher": "pending",
                "Bear Researcher": "pending",
                "Research Manager": "pending",
                "Trader": "pending",
                # Risk Management Team
                "Risky Analyst": "pending",
                "Neutral Analyst": "pending",
                "Safe Analyst": "pending",
                # Portfolio Management Team
                "Portfolio Manager": "pending",
            }

            def update_status(agent: str, status: str):
                if agent_status.get(agent) != status:
                    agent_status[agent] = status
                    return ServerSentEvent(
                        event="status",
                        data=json.dumps({"agent": agent, "status": status}),
                    )
                return None

            def update_research_team(status: str):
                events = []
                for a in ["Bull Researcher", "Bear Researcher", "Research Manager", "Trader"]:
                    ev = update_status(a, status)
                    if ev:
                        events.append(ev)
                return events

            selected_analysts = request.analysts or ["market", "social", "news", "fundamentals"]
            seen_messages = 0
            seen_reports = set()
            report_keys = [
                "market_report",
                "fundamentals_report",
                "sentiment_report",
                "news_report",
                "investment_plan",
                "trader_investment_plan",
                "final_trade_decision",
            ]

            for chunk in graph.graph.stream(init_state, **args):
                last_state = chunk
                if chunk.get("messages"):
                    new_messages = chunk["messages"][seen_messages:]
                    seen_messages = len(chunk["messages"])
                    for msg_obj in new_messages:
                        if hasattr(msg_obj, "content"):
                            message = msg_obj.content
                        elif isinstance(msg_obj, dict):
                            message = json.dumps(msg_obj)
                        else:
                            message = str(msg_obj)
                        if hasattr(msg_obj, "tool_calls"):
                            tool_calls += len(msg_obj.tool_calls)
                        elif isinstance(msg_obj, dict) and msg_obj.get("tool_calls"):
                            tool_calls += len(msg_obj["tool_calls"])
                        llm_calls += 1
                        yield ServerSentEvent(
                            event="update",
                            data=json.dumps(
                                {
                                    "message": message,
                                    "tool_calls": tool_calls,
                                    "llm_calls": llm_calls,
                                    "reports": reports_generated,
                                }
                            ),
                        )
                # Agent status updates
                events_to_send = []
                if chunk.get("market_report"):
                    ev = update_status("Market Analyst", "completed")
                    if ev:
                        events_to_send.append(ev)
                    if "social" in selected_analysts:
                        ev = update_status("Social Analyst", "in_progress")
                        if ev:
                            events_to_send.append(ev)

                if chunk.get("sentiment_report"):
                    ev = update_status("Social Analyst", "completed")
                    if ev:
                        events_to_send.append(ev)
                    if "news" in selected_analysts:
                        ev = update_status("News Analyst", "in_progress")
                        if ev:
                            events_to_send.append(ev)

                if chunk.get("news_report"):
                    ev = update_status("News Analyst", "completed")
                    if ev:
                        events_to_send.append(ev)
                    if "fundamentals" in selected_analysts:
                        ev = update_status("Fundamentals Analyst", "in_progress")
                        if ev:
                            events_to_send.append(ev)

                if chunk.get("fundamentals_report"):
                    ev = update_status("Fundamentals Analyst", "completed")
                    if ev:
                        events_to_send.append(ev)
                    events_to_send.extend(update_research_team("in_progress"))

                if chunk.get("investment_debate_state") and chunk["investment_debate_state"].get("judge_decision"):
                    events_to_send.extend(update_research_team("completed"))
                    ev = update_status("Risky Analyst", "in_progress")
                    if ev:
                        events_to_send.append(ev)

                if chunk.get("trader_investment_plan"):
                    ev = update_status("Trader", "completed")
                    if ev:
                        events_to_send.append(ev)

                if chunk.get("risk_debate_state"):
                    risk_state = chunk["risk_debate_state"]
                    if risk_state.get("current_risky_response"):
                        ev = update_status("Risky Analyst", "in_progress")
                        if ev:
                            events_to_send.append(ev)
                    if risk_state.get("current_safe_response"):
                        ev = update_status("Safe Analyst", "in_progress")
                        if ev:
                            events_to_send.append(ev)
                    if risk_state.get("current_neutral_response"):
                        ev = update_status("Neutral Analyst", "in_progress")
                        if ev:
                            events_to_send.append(ev)
                    if risk_state.get("judge_decision"):
                        for a in ["Risky Analyst", "Safe Analyst", "Neutral Analyst", "Portfolio Manager"]:
                            ev = update_status(a, "completed")
                            if ev:
                                events_to_send.append(ev)

                for ev in events_to_send:
                    yield ev

                for key in report_keys:
                    if chunk.get(key) and key not in seen_reports:
                        reports_generated += 1
                        seen_reports.add(key)

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
                tool_calls=tool_calls,
                llm_calls=llm_calls,
                reports_generated=reports_generated,
            )
            db.add(record)
            db.commit()
            db.refresh(record)

            serialized_report = json.loads(
                json.dumps(final_state, default=_serialize_obj)
            )
            # Mark remaining agents completed
            for agent in list(agent_status.keys()):
                ev = update_status(agent, "completed")
                if ev:
                    yield ev
            yield ServerSentEvent(
                event="complete",
                data=json.dumps(
                    {
                        "ticker": request.ticker,
                        "date": request.date,
                        "decision": decision,
                        "report": serialized_report,
                        "availability": compute_data_availability(serialized_report),
                        "metrics": {
                            "tool_calls": tool_calls,
                            "llm_calls": llm_calls,
                            "reports": reports_generated,
                        },
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
def history(
    current_user: User = Depends(get_current_user), db: Session = Depends(get_db)
):
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
            "metrics": {
                "tool_calls": r.tool_calls,
                "llm_calls": r.llm_calls,
                "reports": r.reports_generated,
            },
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
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND, detail="Record not found"
        )
    return {
        "id": record.id,
        "ticker": record.ticker,
        "date": record.date,
        "decision": record.decision,
        "report": json.loads(record.full_report),
        "metrics": {
            "tool_calls": record.tool_calls,
            "llm_calls": record.llm_calls,
            "reports": record.reports_generated,
        },
    }


@app.get("/results/{user_id}", response_model=List[AnalysisResponse])
def get_user_results(user_id: str, req: Request, db: Session = Depends(get_db)):
    """Return all analysis results belonging to ``user_id``."""

    try:
        return get_user_results_from_db(db=db, user_id=user_id)
    except Exception as exc:  # pragma: no cover - simple passthrough
        if POSTHOG_ENABLED:
            import traceback
            posthog.capture(
                distinct_id=str(user_id),
                event="error",
                properties={
                    "path": req.url.path,
                    "error": str(exc),
                    "traceback": traceback.format_exc(),
                },
            )
        raise HTTPException(status_code=500, detail=str(exc))


# To run locally:
# uvicorn backend.main:app --host 0.0.0.0 --port 8000
