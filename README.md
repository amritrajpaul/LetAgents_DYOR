# LetAgents_DYOR 📈🤖

**LetAgents_DYOR** is a mobile-first application for intelligent stock analysis. Powered by OpenAI GPT APIs and market data from providers like Finnhub, it wraps the original CLI in a FastAPI backend and exposes a secure REST API that can be consumed by Flutter-based apps.
Originally a command-line tool, it is now under active development as a cross-platform mobile app by Amritraj Paul.
LetAgents_DYOR ("Do Your Own Research") aims to make stock insights accessible from anywhere with a secure API and Flutter UI.

## 🧠 Project Overview

LetAgents_DYOR orchestrates multiple AI agents to help you analyze equities with depth and speed. The backend offers a simple REST interface while the front-end Flutter app provides an intuitive experience on both Android and iOS. This project is currently deployed on the free tier of Oracle Cloud Infrastructure (OCI).

## 📱 Features

- Intelligent multi-agent analysis for stocks
- User authentication and per-user OpenAI API key management
- History of analyses and easy result sharing
- Deployed with Docker on OCI free tier resources
- Clean and modern UI using Flutter (Material 3)
- Built-in CLI for power users
- Planned push notifications for major market events
- Offline caching for quick analysis on the go

## 🛠️ Tech Stack

- **Backend:** Python 3.10+, FastAPI, Uvicorn
- **Database:** SQLite or Oracle Autonomous DB
- **Infrastructure:** Docker containers on OCI Free Tier Compute
- **Frontend:** Flutter 3.x with Material 3 design

## 🚀 Quick Start

1. Clone the repository
   ```bash
   git clone https://github.com/yourname/LetAgents_DYOR.git
   cd LetAgents_DYOR
   ```
2. Set up the backend
   ```bash
   cd backend
   python -m venv venv && source venv/bin/activate
   pip install -r requirements.txt
   # configure environment
   cp .env.example .env  # or export variables directly
   export OPENAI_API_KEY=your-key
   export FINNHUB_API_KEY=your-finnhub-key
   ```
3. Build and run with Docker
   ```bash
   docker build -t letagents-backend .
   docker run -p 8000:8000 letagents-backend
   ```
   Ensure your OCI VM has port **8000** open and the service is bound to `0.0.0.0`.
4. Run the Flutter app
   ```bash
   cd ../mobile
   flutter pub get
   flutter run
   ```

## 🧑‍💻 Developer Guide

```
LetAgents_DYOR/
├── backend/   # FastAPI application
├── mobile/    # Flutter app
└── ...
```

- Contributions are welcome! Open issues or submit pull requests.
- The CLI can still be executed via `python -m cli.main` or you can call `POST /analyze` from the API.
- Retrieve past analyses with `GET /history` and view details with `GET /history/{id}`.
- Environment variables can be set in `backend/.env` or exported before running the server.
- Start the FastAPI server locally with:
  ```bash
  pip install -r backend/requirements.txt
  uvicorn backend.main:app --host 0.0.0.0 --port 8000
- Mobile code lives under `mobile/` and uses Flutter 3.x.
- SQLite is used by default; set Oracle DB credentials in `.env` to use Autonomous DB.

## 📲 Screenshots

![screenshot](path/to/image.png)

## 💡 Vision & Roadmap

The goal is to become a full-fledged B2C financial insight app that leverages agentic AI workflows and a scalable cloud backend. Future plans include:

- Support for more market data providers (Yahoo Finance, Alpha Vantage, etc.)
- Portfolio tracking and personalized insights
- Continuous improvements to the mobile UX

## 📜 License

LetAgents_DYOR is released under the Apache 2.0 License.

### Credits

This project builds upon the original work published under the Apache 2.0 License. Attribution to the original author is hereby provided:

```
Copyright 2025 Yijia Xiao et al.
```

Modifications, extensions, and mobile app development © 2025 Amritraj Paul.
