"""Shared PostHog analytics client initialized from environment variables."""

from __future__ import annotations

import os

from posthog import Posthog

PROJECT_API_KEY = os.environ["POSTHOG_PROJECT_API_KEY"]
HOST = os.getenv("POSTHOG_HOST", "https://app.posthog.com")

posthog_client = Posthog(project_api_key=PROJECT_API_KEY, host=HOST)
