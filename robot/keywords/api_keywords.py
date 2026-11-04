"""HTTP keywords used by the Robot Framework API suites."""

import subprocess
import time
from typing import Any

import requests
from robot.api.deco import keyword, library


@library(scope="SUITE")
class ApiKeywords:
    """Provide configurable HTTP access to the demo API."""

    def __init__(self) -> None:
        self.base_url = "http://localhost:8000"

    @keyword
    def set_api_base_url(self, base_url: str) -> None:
        """Set the root URL used by subsequent API requests."""
        self.base_url = base_url.rstrip("/")

    @keyword
    def request_api(
        self,
        method: str,
        path: str,
        body: dict[str, Any] | None = None,
    ) -> dict[str, Any]:
        """Send an HTTP request and return its status code and decoded JSON body.

        An empty response body is returned as ``None``. Network errors and
        non-JSON response bodies are allowed to fail explicitly.
        """
        response = requests.request(
            method,
            f"{self.base_url}/{path.lstrip('/')}",
            json=body,
            timeout=10,
        )

        return {
            "status_code": response.status_code,
            "body": response.json() if response.content else None,
        }

    @keyword
    def restart_docker_container(
        self,
        container_name: str,
        timeout_seconds: int = 60,
    ) -> None:
        """Restart a named Docker container and wait for this API to become healthy."""
        subprocess.run(
            ["docker", "restart", container_name],
            check=True,
            capture_output=True,
            text=True,
            timeout=timeout_seconds,
        )

        deadline = time.monotonic() + timeout_seconds
        last_error: requests.RequestException | None = None
        while time.monotonic() < deadline:
            try:
                response = requests.get(f"{self.base_url}/health", timeout=2)
                response.raise_for_status()
            except requests.RequestException as error:
                last_error = error
                time.sleep(1)
                continue

            if response.json().get("status") != "ok":
                raise RuntimeError(
                    f"API health check returned an unexpected response: {response.text}"
                )
            return

        raise TimeoutError(
            f"API at {self.base_url} did not become healthy after restarting "
            f"Docker container {container_name!r}"
        ) from last_error
