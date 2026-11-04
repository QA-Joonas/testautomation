"""Private Docker-backed test-user setup for Robot Framework."""

import json
import secrets
import subprocess
from typing import Any

import requests
from robot.api.deco import keyword, library
from robot.libraries.BuiltIn import BuiltIn


@library(scope="SUITE")
class UserTestKeywords:
    """Provision isolated users privately and authenticate without logging secrets."""

    def __init__(self) -> None:
        self.usernames: list[str] = []
        self.test_usernames: set[str] = set()
        self.passwords: dict[str, str] = {}
        self.container_name: str | None = None

    @keyword
    def create_and_authenticate_test_user(
        self,
        role: str,
        initial_balance_cents: int = 0,
    ) -> None:
        """Create a disposable user in Docker, log in, and keep credentials out of Robot logs."""
        if role not in {"user", "administrator"}:
            raise ValueError(f"Unsupported test user role: {role}")
        if (
            type(initial_balance_cents) is not int
            or initial_balance_cents < 0
            or initial_balance_cents > 10_000_000
        ):
            raise ValueError("Initial test balance must be between 0 and 10000000 cents")

        builtin = BuiltIn()
        container_name = builtin.get_variable_value("${DOCKER_CONTAINER_NAME}")
        base_url = builtin.get_variable_value("${BASE_URL}")
        if not container_name or not base_url:
            raise RuntimeError("Docker container name and API base URL must be configured")

        username = f"robot_{secrets.token_hex(8)}"
        password = secrets.token_urlsafe(24)
        if self.container_name not in (None, container_name):
            raise RuntimeError(
                "Test users must be provisioned in the same container"
            )

        self._run_user_cli(
            container_name,
            "create",
            username,
            role=role,
            initial_balance_cents=initial_balance_cents,
            password=password,
        )
        self.usernames.append(username)
        self.test_usernames.add(username)
        self.passwords[username] = password
        self.container_name = container_name

        try:
            response = requests.post(
                f"{base_url.rstrip('/')}/api/v1/auth/login",
                json={"username": username, "password": password},
                timeout=10,
            )
            if response.status_code != 200:
                raise RuntimeError(
                    f"Test user login returned HTTP {response.status_code}"
                )

            access_token = response.json().get("access_token")
            if not isinstance(access_token, str) or not access_token:
                raise RuntimeError("Login response did not contain an access token")

            api_library = builtin.get_library_instance("ApiKeywords")
            api_library.set_api_access_token(access_token)
            builtin.set_test_variable("${TEST_USERNAME}", username)
            builtin.set_test_variable("${TEST_USER_ROLE}", role)
        except (requests.RequestException, ValueError, RuntimeError) as error:
            self._run_user_cli(container_name, "delete", username)
            self.usernames.remove(username)
            self.test_usernames.discard(username)
            self.passwords.pop(username, None)
            if not self.usernames:
                self.container_name = None
            raise RuntimeError("Could not authenticate the provisioned test user") from error

    @keyword
    def delete_test_user(self) -> None:
        """Delete all disposable users and clear the in-memory API token."""
        try:
            if self.container_name is not None:
                container_name = self.container_name
                while self.usernames:
                    username = self.usernames[-1]
                    self._run_user_cli(
                        container_name,
                        "delete",
                        username,
                    )
                    self.usernames.pop()
                if self.test_usernames:
                    self._clear_login_attempts(
                        container_name,
                        self.test_usernames,
                    )
                    self.test_usernames.clear()
                    self.passwords.clear()
                self.container_name = None
        finally:
            BuiltIn().get_library_instance("ApiKeywords").set_api_access_token(None)

    @keyword
    def authenticate_current_test_user(self) -> None:
        """Log in the newest fixture user without exposing its password to Robot."""
        if not self.usernames:
            raise RuntimeError("There is no current test user to authenticate")

        self.authenticate_test_user(self.usernames[-1])

    @keyword
    def authenticate_test_user(self, username: str) -> None:
        """Log in a provisioned test user without exposing its password to Robot."""
        if username not in self.passwords:
            raise RuntimeError("The requested user is not a provisioned test user")

        password = self.passwords[username]
        base_url = BuiltIn().get_variable_value("${BASE_URL}")
        if not base_url:
            raise RuntimeError("API base URL must be configured")

        try:
            response = requests.post(
                f"{base_url.rstrip('/')}/api/v1/auth/login",
                json={"username": username, "password": password},
                timeout=10,
            )
            if response.status_code != 200:
                raise RuntimeError(
                    f"Test user login returned HTTP {response.status_code}"
                )
            access_token = response.json().get("access_token")
            if not isinstance(access_token, str) or not access_token:
                raise RuntimeError("Login response did not contain an access token")
        except (requests.RequestException, ValueError, RuntimeError) as error:
            raise RuntimeError("Could not authenticate the provisioned test user") from error

        BuiltIn().get_library_instance("ApiKeywords").set_api_access_token(access_token)

    @keyword
    def delete_current_test_user_keep_api_token(self) -> None:
        """Delete the newest disposable user without clearing its current token."""
        if self.container_name is None or not self.usernames:
            raise RuntimeError("There is no current test user to delete")

        self._run_user_cli(
            self.container_name,
            "delete",
            self.usernames[-1],
        )
        self.usernames.pop()

    @keyword
    def set_api_token_with_claims(
        self,
        claims: dict[str, Any],
        tamper_signature: bool = False,
    ) -> None:
        """Install a test JWT without returning or logging its token value."""
        builtin = BuiltIn()
        container_name = builtin.get_variable_value("${DOCKER_CONTAINER_NAME}")
        if not container_name:
            raise RuntimeError("Docker container name must be configured")

        script = """
import json
import sys
import jwt
from app.auth import get_jwt_secret

claims = json.loads(sys.argv[1])
print(jwt.encode(claims, get_jwt_secret(), algorithm="HS256"))
"""
        result = subprocess.run(
            [
                "docker",
                "exec",
                container_name,
                "python",
                "-c",
                script,
                json.dumps(claims, separators=(",", ":")),
            ],
            capture_output=True,
            text=True,
            check=False,
            timeout=30,
        )
        if result.returncode != 0:
            raise RuntimeError(
                f"Could not create authentication test token: {result.stderr.strip()}"
            )

        token = result.stdout.strip()
        if not token:
            raise RuntimeError("Authentication test token generation returned no token")
        if tamper_signature:
            header, payload, _ = token.split(".")
            token = f"{header}.{payload}.invalidsignature"

        builtin.get_library_instance("ApiKeywords").set_api_access_token(token)

    @staticmethod
    def _run_user_cli(
        container_name: str,
        operation: str,
        username: str,
        role: str | None = None,
        password: str | None = None,
        initial_balance_cents: int | None = None,
    ) -> None:
        command = [
            "docker",
            "exec",
            "-i",
            container_name,
            "python",
            "-m",
            "app.users",
            operation,
            "--username",
            username,
        ]
        if role is not None:
            command.extend(["--role", role])
        if initial_balance_cents is not None:
            command.extend(
                ["--initial-balance-cents", str(initial_balance_cents)]
            )

        result = subprocess.run(
            command,
            input=f"{password}\n" if password is not None else None,
            capture_output=True,
            text=True,
            check=False,
            timeout=30,
        )
        if result.returncode != 0:
            raise RuntimeError(
                f"Private user {operation} failed: {result.stderr.strip()}"
            )
        if operation == "create":
            created_user = json.loads(result.stdout)
            if created_user.get("username") != username:
                raise RuntimeError("Private user provisioner returned an unexpected user")

    @staticmethod
    def _clear_login_attempts(
        container_name: str,
        usernames: set[str],
    ) -> None:
        script = """
import sys
from app.database import get_connection

with get_connection() as connection:
    for username in sys.argv[1:]:
        connection.execute(
            "DELETE FROM login_attempts WHERE username = ?",
            (username,),
        )
"""
        attempt_usernames = {
            candidate
            for username in usernames
            for candidate in (
                username,
                f"missing_{username}",
                username.ljust(50, "u"),
            )
        }
        result = subprocess.run(
            [
                "docker",
                "exec",
                container_name,
                "python",
                "-c",
                script,
                *sorted(attempt_usernames),
            ],
            capture_output=True,
            text=True,
            check=False,
            timeout=30,
        )
        if result.returncode != 0:
            raise RuntimeError(
                f"Could not clear test login attempts: {result.stderr.strip()}"
            )


# Robot's file-based importer discovers the class by its module name.
user_test_keywords = UserTestKeywords
