# Test Automation Demo API

A small FastAPI service for managing income and expense transactions, with
Robot Framework tests that exercise the HTTP API.

## Project layout

- `backend/app/` contains the FastAPI application, Pydantic schemas, and SQLite
  setup.
- `robot/tests/api/` contains routine API test cases.
- `robot/tests/docker/` contains Docker tests that restart the API container.
- `robot/resources/` contains shared Robot Framework variables and keywords.
- `robot/keywords/` contains the Python HTTP client keyword library.

## Run the API with Docker

Run these commands from the repository root. Docker Desktop must be running.
The API requires a private JWT signing key. Create the local environment file
from the example, then replace its placeholder with a random value:

```powershell
Copy-Item backend\.env.example backend\.env
python -c "import secrets; print(secrets.token_urlsafe(48))"
docker build -t testautomation-backend ./backend
docker volume create testautomation-data
docker run --rm --name testautomation-robot-api --env-file backend/.env -p 8000:8000 -e DATABASE_PATH=/data/testautomation.db -v testautomation-data:/data testautomation-backend
```

Paste the generated key into `backend/.env` as the value of `JWT_SECRET_KEY`.
The `.env` file is ignored by Git; do not commit real signing keys or passwords.
The tracked `.env.example` contains only a placeholder.

The named volume stores the SQLite database across container restarts. The API
is available at `http://localhost:8000`; interactive OpenAPI documentation is
at `http://localhost:8000/docs`.

To stop the API, press `Ctrl+C` in the terminal running the container. To start
it again, run the `docker run` command above. The volume is retained when the
container stops.

Alternatively, run the API locally from the `backend` directory:

```powershell
$env:JWT_SECRET_KEY = python -c "import secrets; print(secrets.token_urlsafe(48))"
python -m uvicorn app.main:app --reload
```

## API endpoints

| Method | Path | Purpose | Success status |
| --- | --- | --- | --- |
| `GET` | `/health` | Check API health | `200` |
| `GET` | `/api/v1/transactions` | List transactions | `200` |
| `POST` | `/api/v1/transactions` | Create a transaction | `201` |
| `GET` | `/api/v1/transactions/{transaction_id}` | Get a transaction | `200` |
| `PUT` | `/api/v1/transactions/{transaction_id}` | Replace a transaction | `200` |
| `DELETE` | `/api/v1/transactions/{transaction_id}` | Delete a transaction | `204` |
| `POST` | `/api/v1/auth/login` | Authenticate a provisioned user | `200` |
| `GET` | `/api/v1/users/me` | Get the authenticated user's profile | `200` |

Transaction request bodies contain `description`, `amount` (a positive integer
number of cents), `type` (`income` or `expense`), and `category`. For example,
`"amount": 1234` represents EUR 12.34. Responses use the same integer-cents
representation. A request example:

```json
{
  "description": "Groceries",
  "amount": 1234,
  "type": "expense",
  "category": "food"
}
```

The API accepts and returns only integer cents; it does not accept a currency
or an alternate euro-denominated amount. Clients can format the integer cents
as euros for display. The API and SQLite store amounts as integer cents, with
no floating-point conversion. The API validates the fields and whether a
category is valid for the selected type. Missing transaction IDs return `404`;
invalid request data returns `422`.

## Users and authentication

There is no public registration endpoint. Create accounts through the private
provisioning CLI inside the running API container; the password is read from
standard input, not supplied as a command-line argument:

```powershell
docker exec -i testautomation-robot-api python -m app.users create --username alice --role owner
```

The supported roles are `owner` and `read_only`. The login endpoint accepts a
JSON username and password and returns a short-lived (15-minute) JWT bearer
token. Send it as `Authorization: Bearer <token>` to access
`/api/v1/users/me`. User responses expose only the ID, username, role, and
creation timestamp; password hashes are never returned. User passwords are
hashed with Argon2id.

The API requires `JWT_SECRET_KEY` to be configured with at least 32 random
bytes before it will start. Keep the key private and stable across restarts so
tokens remain verifiable. Changing the key invalidates existing tokens.

The user happy-path tests privately create a disposable owner or read-only
account inside the configured Docker container, log in, inspect the profile,
and delete the account in teardown. Run them explicitly:

```powershell
python -m robot robot/tests/users
```

These tests require the updated API image, a running container with the
configured JWT secret, and the matching container name and API URL. Passwords
and access tokens are kept inside the Python keyword library and are not passed
through Robot test arguments or returned in Robot logs.

At this stage, authentication is implemented for the user profile endpoint;
transaction endpoints are not yet protected or scoped to user ownership. That
is the next authorization integration step. The health endpoint and login
endpoint are intentionally available without a token.

## Run the Robot Framework tests

Install the test dependencies in the Python environment you intend to use:

```powershell
python -m pip install -r robot/requirements.txt
```

With the API running at `http://localhost:8000`, run the suite from the
repository root. This runs the regular API tests and does not restart Docker:

```powershell
python -m robot robot/tests/api
```

The API suite checks health, transaction creation, retrieval, listing,
updating, and deletion, and verifies fractional-cent amounts are rejected.
Retrieval, listing, updating, and deletion tests create their own transaction
during test setup; test teardown removes transactions created by each test.
The tests use the API rather than querying SQLite directly.

The persistence test is separate and must be run explicitly. It restarts the
configured Docker container, so run it only when Docker is available and the
container name and API URL match the running service:

```powershell
python -m robot robot/tests/docker
```

The default container name is `testautomation-robot-api`; override it when needed:

```powershell
python -m robot --variable DOCKER_CONTAINER_NAME:my-api-container robot/tests/docker
```

The test verifies persistence across an API container restart with the same
database volume. It does not stop or restart Docker Desktop itself.

The base URL can be changed without editing the resource file:

```powershell
python -m robot --variable BASE_URL:http://localhost:8000 robot/tests/api
```
