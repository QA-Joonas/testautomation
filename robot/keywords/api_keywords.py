"""HTTP keywords used by the Robot Framework API suites."""

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
