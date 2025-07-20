# Architecture Overview

This document outlines the high-level design of **LetAgents_DYOR** so future developers and AI agents can quickly understand how the pieces fit together.

## Directory Layout

```
backend/       FastAPI application exposing REST endpoints
mobile/        Flutter app that consumes the backend
tradingagents/ Core multi-agent trading framework
cli/           Command line interface built on the trading framework
```

Results produced by the agents are saved under `results/` and images used by the app live in `assets/`.

## Multi-Agent Framework

The `tradingagents` package models the workflow of a small trading firm. The key components are:

- **Researchers** – gather raw market data and news.
- **Analysts** – process the data and generate insights.
- **Risk Managers** – evaluate the risk of proposed trades.
- **Traders** – produce final trading actions or summaries.

Agents communicate through a graph defined in `tradingagents/graph`. Data flows into the agents using helper utilities from `tradingagents/dataflows`. Configuration defaults are provided in `tradingagents/default_config.py` and can be overridden via environment variables.

## Backend

The FastAPI backend (under `backend/`) exposes endpoints such as `/analyze` which execute the agent workflow. The server stores analysis history and serves as the API consumed by the mobile app.

## Mobile App

Flutter code in `mobile/` presents a user-friendly interface. The app sends requests to the backend and displays the agent results. When running locally you can pass `--dart-define=BACKEND_URL=<url>` to point the app at your backend instance.

## Extending the System

Additional agents or data sources can be added by creating new modules under `tradingagents/agents` or `tradingagents/dataflows`. The trading graph is flexible and can be updated to reflect new roles or decision logic.

This modular design allows the project to scale toward the long-term goal of a B2C financial insight platform that mirrors the operations of a real-world trading firm.
