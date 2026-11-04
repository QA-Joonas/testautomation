"""In-memory throttling for repeated failed login attempts."""

from collections import deque
from math import ceil
from threading import Lock
from time import monotonic


FAILED_LOGIN_LIMIT = 2
FAILED_LOGIN_WINDOW_SECONDS = 60 * 60


class LoginRateLimiter:
    """Track login attempts by client address and normalized username."""

    def __init__(
        self,
        limit: int = FAILED_LOGIN_LIMIT,
        window_seconds: int = FAILED_LOGIN_WINDOW_SECONDS,
    ) -> None:
        self.limit = limit
        self.window_seconds = window_seconds
        self._attempts: dict[tuple[str, str], deque[float]] = {}
        self._lock = Lock()
        self._next_cleanup = 0.0

    def try_record_attempt(self, client_ip: str, username: str) -> int | None:
        """Record an allowed attempt, or return cooldown seconds when limited."""
        key = (client_ip, username)
        now = monotonic()
        with self._lock:
            if now >= self._next_cleanup:
                self._remove_expired_keys(now)
                self._next_cleanup = now + min(self.window_seconds, 60)

            attempts = self._attempts.get(key)
            if attempts is not None:
                self._remove_expired(attempts, now)
                if not attempts:
                    del self._attempts[key]
                    attempts = None

            if attempts is None:
                attempts = self._attempts.setdefault(key, deque())
            elif len(attempts) >= self.limit:
                return max(
                    1,
                    ceil(attempts[0] + self.window_seconds - now),
                )

            attempts.append(now)
            return None

    def clear(self, client_ip: str, username: str) -> None:
        """Clear attempts after a successful login."""
        with self._lock:
            self._attempts.pop((client_ip, username), None)

    def _remove_expired(self, attempts: deque[float], now: float) -> None:
        cutoff = now - self.window_seconds
        while attempts and attempts[0] <= cutoff:
            attempts.popleft()

    def _remove_expired_keys(self, now: float) -> None:
        for key, attempts in list(self._attempts.items()):
            self._remove_expired(attempts, now)
            if not attempts:
                del self._attempts[key]


login_rate_limiter = LoginRateLimiter()
