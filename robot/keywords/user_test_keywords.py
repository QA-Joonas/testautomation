"""Private Docker-backed test-user setup for Robot Framework."""

import json
import secrets
import subprocess

import requests
from robot.api.deco import keyword, library
from robot.libraries.BuiltIn import BuiltIn


@library(scope="SUITE")
class UserTestKeywords:
    """Provision isolated users privately and authenticate without logging secrets."""

    def __init__(self) -> None:
        self.username: str | None = None
        self.container_name: str | None = None

    @keyword
    def create_and_authenticate_test_user(self, role: str) -> None:
        """Create a disposable user in Docker, log in, and keep credentials out of Robot logs."""
        if role not in {"owner", "read_only"}:
            raise ValueError(f"Unsupported test user role: {role}")

        builtin = BuiltIn()
        container_name = builtin.get_variable_value("${DOCKER_CONTAINER_NAME}")
        base_url = builtin.get_variable_value("${BASE_URL}")
        if not container_name or not base_url:
            raise RuntimeError("Docker container name and API base URL must be configured")

        username = f"robot_{secrets.token_hex(8)}"
        password = secrets.token_urlsafe(24)
        self._run_user_cli(
            container_name,
            "create",
            username,
            role=role,
            password=password,
        )

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
            self.username = username
            self.container_name = container_name
        except (requests.RequestException, ValueError, RuntimeError) as error:
            self._run_user_cli(container_name, "delete", username)
            raise RuntimeError("Could not authenticate the provisioned test user") from error

    @keyword
    def delete_test_user(self) -> None:
        """Delete the current disposable user and clear the in-memory API token."""
        try:
            if self.username is not None and self.container_name is not None:
                self._run_user_cli(
                    self.container_name,
                    "delete",
                    self.username,
                )
        finally:
            BuiltIn().get_library_instance("ApiKeywords").set_api_access_token(None)
            self.username = None
            self.container_name = None

    @staticmethod
    def _run_user_cli(
        container_name: str,
        operation: str,
        username: str,
        role: str | None = None,
        password: str | None = None,
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
