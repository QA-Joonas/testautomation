"""User provisioning and authentication services."""

import sqlite3
from typing import Any

from pwdlib import PasswordHash

from app.database import get_connection
from app.schemas import UserCredentials, UserRole


PASSWORD_HASHER = PasswordHash.recommended()
DUMMY_PASSWORD_HASH = PASSWORD_HASHER.hash(
    "not-a-real-user-password-for-timing-equalization"
)


def create_user(username: str, password: str, role: UserRole) -> dict[str, Any]:
    """Privately provision a user with an Argon2id password hash."""
    credentials = UserCredentials.model_validate(
        {"username": username, "password": password}
    )
    with get_connection() as connection:
        try:
            cursor = connection.execute(
                """
                INSERT INTO users (username, password_hash, role)
                VALUES (?, ?, ?)
                """,
                (
                    credentials.username,
                    PASSWORD_HASHER.hash(credentials.password),
                    role,
                ),
            )
        except sqlite3.IntegrityError as error:
            raise ValueError("Username already exists or user data is invalid") from error

        row = connection.execute(
            """
            SELECT id, username, role, created_at
            FROM users
            WHERE id = ?
            """,
            (cursor.lastrowid,),
        ).fetchone()

    return dict(row)


def get_user_by_username(username: str) -> sqlite3.Row | None:
    """Look up a user by their case-insensitive username."""
    with get_connection() as connection:
        return connection.execute(
            """
            SELECT id, username, password_hash, role, created_at
            FROM users
            WHERE username = ?
            """,
            (username.strip().lower(),),
        ).fetchone()


def get_user_by_id(user_id: int) -> sqlite3.Row | None:
    """Look up a user by their database ID."""
    with get_connection() as connection:
        return connection.execute(
            """
            SELECT id, username, role, created_at
            FROM users
            WHERE id = ?
            """,
            (user_id,),
        ).fetchone()


def delete_user(username: str) -> bool:
    """Delete a privately provisioned user by username."""
    with get_connection() as connection:
        cursor = connection.execute(
            "DELETE FROM users WHERE username = ?",
            (username.strip().lower(),),
        )
    return cursor.rowcount == 1


def verify_user_password(username: str, password: str) -> sqlite3.Row | None:
    """Verify credentials without distinguishing an unknown username in the response."""
    user = get_user_by_username(username)
    password_hash = user["password_hash"] if user is not None else DUMMY_PASSWORD_HASH
    password_is_valid = PASSWORD_HASHER.verify(password, password_hash)

    if user is None or not password_is_valid:
        return None

    return user
