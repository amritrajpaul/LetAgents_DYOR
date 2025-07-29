# LetAgents_DYOR 📈🤖

**LetAgents_DYOR** is a mobile-first application for intelligent stock analysis. Powered by OpenAI GPT APIs and market data from providers like Finnhub, it wraps the original CLI in a FastAPI backend and exposes a secure REST API that can be consumed by Flutter-based apps.
Originally a command-line tool, it is now under active development as a cross-platform mobile app by Amritraj Paul.
LetAgents_DYOR ("Do Your Own Research") aims to make stock insights accessible from anywhere with a secure API and Flutter UI.

## 🧠 Project Overview

LetAgents_DYOR orchestrates multiple AI agents to help you analyze equities with depth and speed. The backend offers a simple REST interface while the front-end Flutter app provides an intuitive experience on both Android and iOS. This project is currently deployed on the free tier of Oracle Cloud Infrastructure (OCI).

For details on how the agents work together, see [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md).

## 📱 Features

- Intelligent multi-agent analysis for stocks
- User authentication and per-user OpenAI and Finnhub API key management
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
    export TRADINGAGENTS_DATA_DIR=/path/to/your/data
    # Optional analytics with PostHog
    export POSTHOG_API_KEY=phc_xxx
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
   flutter run --dart-define=BACKEND_URL=http://<your-ip>:8000
   ```
Replace `<your-ip>` with the backend host. Use `localhost` for the iOS Simulator, `10.0.2.2` for the Android Emulator, or your computer's network IP for a physical device.

5. (Optional) Save your OpenAI and Finnhub keys after logging in:
   ```bash
   curl -X PUT http://<your-ip>:8000/keys \
        -H 'Authorization: Bearer <token>' \
        -d '{"openai_api_key":"sk-...","finnhub_api_key":"fh-..."}'
   ```

## 📦 Building a Release APK

To distribute the Flutter app you need to sign it and then build a release APK.

1. Generate a release keystore:
   ```bash
   keytool -genkey -v -keystore my-release-key.jks \
     -alias my-key-alias -keyalg RSA -keysize 2048 -validity 10000
   ```
2. Create `mobile/android/key.properties` with your credentials:
   ```
   storePassword=<your-store-password>
   keyPassword=<your-key-password>
   keyAlias=my-key-alias
   storeFile=../my-release-key.jks
   ```
3. Build the APK from the `mobile/` directory:
   ```bash
   flutter build apk --release
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
 - Environment variables can be set in `backend/.env` or exported before running the server. `TRADINGAGENTS_DATA_DIR` controls where the backend reads its data files.
- Start the FastAPI server locally with:
  ```bash
  pip install -r backend/requirements.txt
  uvicorn backend.main:app --host 0.0.0.0 --port 8000
- Mobile code lives under `mobile/` and uses Flutter 3.x.
- SQLite is used by default; set Oracle DB credentials in `.env` to use Autonomous DB.

## 📲 Screenshots

![screenshot](path/to/image.png)

## 💡 Vision & Roadmap

The goal is to become a full-fledged B2C financial insight app powered by a multi-agent trading framework that mirrors the operations of real-world trading firms. Future plans include:

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
