"""JWT authentication for protected API routes."""

import os
from datetime import datetime, timedelta, timezone
from typing import Annotated, Any

import jwt
from fastapi import Depends, HTTPException, status
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer
from jwt.exceptions import InvalidTokenError

from app.user_service import get_user_by_id


ACCESS_TOKEN_LIFETIME_SECONDS = 15 * 60
TOKEN_ISSUER = "testautomation-api"
bearer_scheme = HTTPBearer(auto_error=False)


def get_jwt_secret() -> str:
    """Return a configured signing secret or fail explicitly."""
    secret = os.getenv("JWT_SECRET_KEY", "")
    if len(secret.encode("utf-8")) < 32 or secret.startswith("replace-"):
        raise RuntimeError(
            "JWT_SECRET_KEY must be configured with at least 32 random bytes"
        )
    return secret


def create_access_token(user_id: int) -> str:
    """Create a short-lived signed access token for a user."""
    now = datetime.now(timezone.utc)
    return jwt.encode(
        {
            "sub": str(user_id),
            "iss": TOKEN_ISSUER,
            "iat": now,
            "exp": now + timedelta(seconds=ACCESS_TOKEN_LIFETIME_SECONDS),
        },
        get_jwt_secret(),
        algorithm="HS256",
    )


def get_current_user(
    credentials: Annotated[
        HTTPAuthorizationCredentials | None,
        Depends(bearer_scheme),
    ],
) -> dict[str, Any]:
    """Authenticate a bearer token and return the current user's public fields."""
    unauthorized = HTTPException(
        status_code=status.HTTP_401_UNAUTHORIZED,
        detail="Authentication required",
        headers={"WWW-Authenticate": "Bearer"},
    )
    if credentials is None:
        raise unauthorized

    try:
        claims = jwt.decode(
            credentials.credentials,
            get_jwt_secret(),
            algorithms=["HS256"],
            issuer=TOKEN_ISSUER,
            options={"require": ["exp", "iat", "iss", "sub"]},
        )
        user_id = int(claims["sub"])
    except (InvalidTokenError, TypeError, ValueError):
        raise unauthorized from None

    user = get_user_by_id(user_id)
    if user is None:
        raise unauthorized
    return dict(user)
