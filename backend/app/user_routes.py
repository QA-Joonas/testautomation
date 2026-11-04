"""Authentication and current-user API routes."""

from typing import Any

from fastapi import APIRouter, Depends, HTTPException, Request, status

from app.auth import (
    ACCESS_TOKEN_LIFETIME_SECONDS,
    create_access_token,
    get_current_user,
)
from app.login_rate_limit import login_rate_limiter
from app.schemas import AccessTokenResponse, UserLogin, UserResponse
from app.user_service import verify_user_password


router = APIRouter(prefix="/api/v1")


@router.post("/auth/login", response_model=AccessTokenResponse)
def login(request: Request, credentials: UserLogin) -> AccessTokenResponse:
    """Authenticate a provisioned user and issue a short-lived bearer token."""
    client_ip = request.client.host if request.client is not None else "unknown"
    retry_after = login_rate_limiter.try_record_attempt(
        client_ip,
        credentials.username,
    )
    if retry_after is not None:
        raise HTTPException(
            status_code=status.HTTP_429_TOO_MANY_REQUESTS,
            detail="Too many failed login attempts",
            headers={"Retry-After": str(retry_after)},
        )

    user = verify_user_password(credentials.username, credentials.password)
    if user is None:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid username or password",
            headers={"WWW-Authenticate": "Bearer"},
        )

    login_rate_limiter.clear(client_ip, credentials.username)
    return AccessTokenResponse(
        access_token=create_access_token(user["id"]),
        expires_in=ACCESS_TOKEN_LIFETIME_SECONDS,
    )


@router.get("/users/me", response_model=UserResponse)
def read_current_user(
    user: dict[str, Any] = Depends(get_current_user),
) -> UserResponse:
    """Return the authenticated user's public profile."""
    return UserResponse.model_validate(user)
