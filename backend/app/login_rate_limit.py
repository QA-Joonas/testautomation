"""Database-backed throttling for repeated failed login attempts."""

from collections.abc import Callable
from math import ceil
from time import time

from app.database import get_connection

FAILED_LOGIN_LIMIT = 2
FAILED_LOGIN_WINDOW_SECONDS = 60 * 60


class LoginRateLimiter:
    """Track login attempts by client address and normalized username in SQLite."""

    def __init__(
        self,
        limit: int = FAILED_LOGIN_LIMIT,
        window_seconds: int = FAILED_LOGIN_WINDOW_SECONDS,
        clock: Callable[[], float] = time,
    ) -> None:
        self.limit = limit
        self.window_seconds = window_seconds
        self._clock = clock

    def try_record_attempt(self, client_ip: str, username: str) -> int | None:
        """Record an allowed attempt, or return cooldown seconds when limited."""
        now = self._clock()
        cutoff = now - self.window_seconds

        with get_connection() as connection:
            connection.execute("BEGIN IMMEDIATE")
            connection.execute(
                "DELETE FROM login_attempts WHERE attempted_at <= ?",
                (cutoff,),
            )
            attempts = connection.execute(
                """
                SELECT COUNT(*) AS count, MIN(attempted_at) AS oldest
                FROM login_attempts
                WHERE client_ip = ? AND username = ? AND attempted_at > ?
                """,
                (client_ip, username, cutoff),
            ).fetchone()

            if attempts["count"] >= self.limit:
                return max(
                    1,
                    ceil(attempts["oldest"] + self.window_seconds - now),
                )

            connection.execute(
                """
                INSERT INTO login_attempts (client_ip, username, attempted_at)
                VALUES (?, ?, ?)
                """,
                (client_ip, username, now),
            )
            return None

    def clear(self, client_ip: str, username: str) -> None:
        """Clear attempts after a successful login."""
        with get_connection() as connection:
            connection.execute(
                "DELETE FROM login_attempts WHERE client_ip = ? AND username = ?",
                (client_ip, username),
            )


login_rate_limiter = LoginRateLimiter()
