"""Tests for persistent login attempt tracking."""

import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch

from app import database
from app.login_rate_limit import LoginRateLimiter


class LoginRateLimiterTests(unittest.TestCase):
    def setUp(self) -> None:
        temporary_directory = tempfile.TemporaryDirectory()
        self.addCleanup(temporary_directory.cleanup)
        database_path = Path(temporary_directory.name) / "test.db"
        database_path_patch = patch.object(database, "DATABASE_PATH", database_path)
        database_path_patch.start()
        self.addCleanup(database_path_patch.stop)
        database.init_db()

        self.now = 1_000.0
        self.limiter = LoginRateLimiter(clock=lambda: self.now)

    def test_limit_is_scoped_to_client_and_username(self) -> None:
        self.assertIsNone(self.limiter.try_record_attempt("192.0.2.1", "alice"))
        self.assertIsNone(self.limiter.try_record_attempt("192.0.2.1", "alice"))
        self.assertEqual(self.limiter.try_record_attempt("192.0.2.1", "alice"), 3600)
        self.assertIsNone(self.limiter.try_record_attempt("192.0.2.2", "alice"))
        self.assertIsNone(self.limiter.try_record_attempt("192.0.2.1", "bob"))

    def test_attempts_expire_after_the_rolling_window(self) -> None:
        self.limiter.try_record_attempt("192.0.2.1", "alice")
        self.limiter.try_record_attempt("192.0.2.1", "alice")
        self.now += 3600

        self.assertIsNone(self.limiter.try_record_attempt("192.0.2.1", "alice"))

    def test_successful_login_clears_attempts(self) -> None:
        self.limiter.try_record_attempt("192.0.2.1", "alice")
        self.limiter.clear("192.0.2.1", "alice")

        self.assertIsNone(self.limiter.try_record_attempt("192.0.2.1", "alice"))
        self.assertIsNone(self.limiter.try_record_attempt("192.0.2.1", "alice"))
        self.assertEqual(self.limiter.try_record_attempt("192.0.2.1", "alice"), 3600)

    def test_attempts_survive_rate_limiter_recreation(self) -> None:
        self.limiter.try_record_attempt("192.0.2.1", "alice")
        self.limiter.try_record_attempt("192.0.2.1", "alice")
        restarted_limiter = LoginRateLimiter(clock=lambda: self.now)

        self.assertEqual(
            restarted_limiter.try_record_attempt("192.0.2.1", "alice"),
            3600,
        )


if __name__ == "__main__":
    unittest.main()
