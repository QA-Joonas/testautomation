# Project Context - Test Automation Demo API

## Purpose

This project demonstrates API development and automated API testing. The
current application is a small income and expense transaction API.

The API can run in a Docker container and stores data in SQLite.

## Technologies

- Python
- FastAPI
- Pydantic
- PyJWT
- pwdlib with Argon2
- Docker
- Robot Framework
- Requests (used by the Python Robot Framework keyword library)
- SQLite

## Architecture

Robot Framework tests -> HTTP API -> FastAPI backend -> SQLite database

## Backend

The backend currently provides:

- health check
- private user provisioning, password hashing, login, and JWT-protected profile
- authenticated transaction listing, creation, retrieval, update, and deletion
- customer ownership; customers create/read their records and administrators
  have cross-customer read and write access
- income and expense transaction validation
- strict integer-cent transaction amounts in the API and SQLite database; euro
  formatting is a client-side display concern

## Testing

Robot Framework tests are organized under `robot/`:

- `robot/tests/` contains test suites.
- `robot/resources/` contains shared variables and Robot Framework keywords.
- `robot/keywords/` contains Python keyword libraries.

The current tests cover health and transaction CRUD, unauthenticated access,
customer/administrator permissions, and transaction isolation between
customers. Test users and their transactions are removed during teardown.

User happy-path tests privately provision disposable customer and
administrator accounts in the Docker container, authenticate, verify the
protected user profile, and remove the accounts during teardown. JWT signing
secrets belong in ignored local environment files, never in source control.
The tests are in `robot/tests/users/`; provisioned passwords and access tokens
are kept out of Robot test arguments and logs.

The API migrates legacy transactions without owners by deleting them when it
first initializes the ownership schema. Existing `owner` and `read_only`
accounts are both migrated to `user`, never to `administrator`. User deletion
cascades to that user's transactions.

Run the API and test suite using the instructions in `README.md`.

## Future scope

Accounts, PostgreSQL support, broader negative/API validation tests, and
additional security testing are not currently implemented. They may be added
as the project scope expands.