import os
import posthog

POSTHOG_API_KEY = os.getenv("POSTHOG_API_KEY")
POSTHOG_HOST = os.getenv("POSTHOG_HOST", "https://app.posthog.com")
POSTHOG_ENABLED = bool(POSTHOG_API_KEY)

if POSTHOG_ENABLED:
    posthog.project_api_key = POSTHOG_API_KEY
    posthog.host = POSTHOG_HOST

def capture_error(distinct_id: str, path: str, exc: Exception) -> None:
    """Send error details to PostHog if analytics are enabled."""
    if not POSTHOG_ENABLED:
        return
    import traceback
    posthog.capture(
        distinct_id=distinct_id,
        event="error",
        properties={
            "path": path,
            "error": str(exc),
            "traceback": traceback.format_exc(),
        },
    )

