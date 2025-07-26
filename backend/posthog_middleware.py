import os
import uuid
from typing import Optional

from fastapi import Request
from starlette.middleware.base import BaseHTTPMiddleware, RequestResponseEndpoint
import posthog

POSTHOG_API_KEY = os.getenv("POSTHOG_API_KEY")
POSTHOG_HOST = os.getenv("POSTHOG_HOST", "https://app.posthog.com")

if POSTHOG_API_KEY:
    posthog.project_api_key = POSTHOG_API_KEY
    posthog.host = POSTHOG_HOST


class PostHogMiddleware(BaseHTTPMiddleware):
    async def dispatch(self, request: Request, call_next: RequestResponseEndpoint):
        user_id: Optional[str] = None
        if hasattr(request.state, "user") and getattr(request.state.user, "id", None):
            user_id = request.state.user.id
        else:
            user_id = str(uuid.uuid4())

        response = await call_next(request)

        if POSTHOG_API_KEY:
            posthog.capture(
                distinct_id=str(user_id),
                event="http_request",
                properties={
                    "path": request.url.path,
                    "method": request.method,
                    "status_code": response.status_code,
                },
            )
        return response
