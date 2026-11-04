# Project Context - Test Automation Demo API

## Purpose

This project demonstrates API development and automated API testing. The
current application is a small income and expense transaction API.

The API can run in a Docker container and stores data in SQLite.

## Technologies

- Python
- FastAPI
- Pydantic
- Docker
- Robot Framework
- Requests (used by the Python Robot Framework keyword library)
- SQLite

## Architecture

Robot Framework tests -> HTTP API -> FastAPI backend -> SQLite database

## Backend

The backend currently provides:

- health check
- transaction listing, creation, retrieval, update, and deletion
- income and expense transaction validation
- strict integer-cent transaction amounts in the API and SQLite database

## Testing

Robot Framework tests are organized under `robot/`:

- `robot/tests/` contains test suites.
- `robot/resources/` contains shared variables and Robot Framework keywords.
- `robot/keywords/` contains Python keyword libraries.

The current tests cover happy paths for the health endpoint and transaction
create, list, retrieve, update, and delete operations. Each test that needs an
existing transaction creates one during setup and removes it during teardown.
Tests exercise the HTTP API; they do not query SQLite directly.

Run the API and test suite using the instructions in `README.md`.

## Future scope

Authentication, users, accounts, PostgreSQL support, negative/API validation
tests, and security testing are not currently implemented. They may be added
as the project scope expands.