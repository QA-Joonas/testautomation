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
- test-only disposable user accounts, password hashing, login, and
  JWT-protected profile
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
customers. User authentication tests cover profile access, credential
validation, rejected JWTs, token invalidation after user deletion, and login
throttling. Test users and their transactions are removed during teardown.

There is no public registration endpoint or manual account-creation workflow.
Only automated tests create the disposable customer and administrator
accounts they need; accounts should not be created manually through Docker or
a CLI. The user happy-path tests authenticate, verify the protected user
profile, and remove the accounts during teardown. JWT signing secrets belong
in ignored local environment files, never in source control. The tests are in
`robot/tests/users/`; passwords and access tokens are kept out of Robot test
arguments and logs.

Customers (`user`) can create and read their own transactions but cannot
update or delete transactions or access another customer's transactions.
Administrators can list, create, read, update, and delete transactions across
all customers. Every transaction endpoint requires authentication; the health
and login endpoints are public.

Login is throttled after two failed attempts per client IP and normalized
username in a rolling one-hour window. Attempt timestamps are stored in
SQLite, return `429` with `Retry-After`, and are shared by API processes using
the same database file. Successful login clears that pair's attempts; expired
records are removed as login requests arrive. The state survives API container
restarts when the database volume is retained.

Deleting a user cascades to that user's transactions.

Run the API and test suite using the instructions in `README.md`.

## Future scope

PostgreSQL support, broader negative/API validation tests, and additional
security testing are not currently implemented. They may be added as the
project scope expands.