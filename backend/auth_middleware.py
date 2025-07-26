import os
import jwt
from fastapi import Request
from starlette.middleware.base import BaseHTTPMiddleware, RequestResponseEndpoint

SECRET_KEY = os.environ.get("SECRET_KEY", "change-me")
ALGORITHM = "HS256"

class AuthTokenMiddleware(BaseHTTPMiddleware):
    async def dispatch(self, request: Request, call_next: RequestResponseEndpoint):
        request.state.user = None
        auth_header = request.headers.get("Authorization")
        if auth_header and auth_header.lower().startswith("bearer "):
            token = auth_header.split(" ", 1)[1]
            try:
                payload = jwt.decode(token, SECRET_KEY, algorithms=[ALGORITHM])
                user_id = payload.get("id")
                if user_id is not None:
                    request.state.user = type("UserObj", (), {"id": user_id})()
            except Exception:
                # Ignore token errors and continue without user info
                pass
        response = await call_next(request)
        return response
