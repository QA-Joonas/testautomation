# Test Automation Demo API

A small FastAPI service for managing income and expense transactions, with
Robot Framework tests that exercise the HTTP API.

## Project layout

- `backend/app/` contains the FastAPI application, Pydantic schemas, and SQLite
  setup.
- `robot/tests/` contains API test cases.
- `robot/resources/` contains shared Robot Framework variables and keywords.
- `robot/keywords/` contains the Python HTTP client keyword library.

## Run the API with Docker

Run these commands from the repository root. Docker Desktop must be running.

```powershell
docker build -t testautomation-backend ./backend
docker volume create testautomation-data
docker run --rm --name testautomation-api -p 8000:8000 -e DATABASE_PATH=/data/testautomation.db -v testautomation-data:/data testautomation-backend
```

The named volume stores the SQLite database across container restarts. The API
is available at `http://localhost:8000`; interactive OpenAPI documentation is
at `http://localhost:8000/docs`.

To stop the API, press `Ctrl+C` in the terminal running the container. To start
it again, run the `docker run` command above. The volume is retained when the
container stops.

Alternatively, run the API locally from the `backend` directory:

```powershell
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

Transaction request bodies contain `description`, `amount` (euros), `type`
(`income` or `expense`), and `category`. The API validates the fields and
whether a category is valid for the selected type. Missing transaction IDs
return `404`; invalid request data returns `422`.

## Run the Robot Framework tests

Install the test dependencies in the Python environment you intend to use:

```powershell
python -m pip install -r robot/requirements.txt
```

With the API running at `http://localhost:8000`, run the suite from the
repository root:

```powershell
python -m robot robot/tests
```

The current happy-path suite checks health, transaction creation, retrieval,
listing, updating, and deletion. Retrieval, listing, updating, and deletion
tests create their own transaction during test setup; test teardown removes
transactions created by each test. The tests use the API rather than querying
SQLite directly.

The base URL can be changed without editing the resource file:

```powershell
python -m robot --variable BASE_URL:http://localhost:8000 robot/tests
```
