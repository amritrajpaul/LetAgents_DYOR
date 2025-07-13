import os
from typing import List, Optional

from fastapi import FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel

from tradingagents.graph.trading_graph import TradingAgentsGraph
from tradingagents.default_config import DEFAULT_CONFIG

app = FastAPI()

# Allow all origins for development; restrict in production
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Read API keys at startup
OPENAI_API_KEY = os.environ.get("OPENAI_API_KEY")
FINNHUB_API_KEY = os.environ.get("FINNHUB_API_KEY")

if not OPENAI_API_KEY or not FINNHUB_API_KEY:
    raise RuntimeError(
        "OPENAI_API_KEY and FINNHUB_API_KEY must be set as environment variables"
    )


class AnalyzeRequest(BaseModel):
    """Request model for /analyze endpoint."""

    ticker: str
    date: str
    research_depth: int = 1
    analysts: Optional[List[str]] = None


@app.get("/")
def read_root():
    """Health check route."""
    return {"message": "Backend up"}


@app.post("/analyze")
def analyze(request: AnalyzeRequest):
    """Run the TradingAgents analysis and return the results."""

    try:
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
