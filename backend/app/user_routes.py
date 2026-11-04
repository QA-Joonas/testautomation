"""Authentication and current-user API routes."""

from typing import Any

from fastapi import APIRouter, Depends, HTTPException, status

from app.auth import (
    ACCESS_TOKEN_LIFETIME_SECONDS,
    create_access_token,
    get_current_user,
)
from app.schemas import AccessTokenResponse, UserLogin, UserResponse
from app.user_service import verify_user_password


router = APIRouter(prefix="/api/v1")


@router.post("/auth/login", response_model=AccessTokenResponse)
def login(credentials: UserLogin) -> AccessTokenResponse:
    """Authenticate a provisioned user and issue a short-lived bearer token."""
    user = verify_user_password(credentials.username, credentials.password)
    if user is None:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid username or password",
            headers={"WWW-Authenticate": "Bearer"},
        )

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
