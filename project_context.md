# Project Context - Test Automation For Python API Backend

## Purpose

This project demonstrates professional API testing
and test automation skills.

Backend runs in a Docker container

## Technologies

- Python
- FastAPI
- Pydantic
- Docker
- Robot Framework
- RequestsLibrary
- pytest
- SQLite/PostgreSQL

## Architecture

Robot Framework
    ↓
REST API
    ↓
FastAPI backend
    ↓
Database

## Backend

The backend provides REST API endpoints for:

- authentication
- users
- accounts
- expenses

## Testing

Tests cover:

- functional testing
- negative testing
- API validation
- authentication
- authorization
- security testing
- error handling
- HTTP status codes

## Security

The API must consider:

- authentication
- authorization
- IDOR
- input validation
- SQL injection
- rate limiting
- information disclosure
- secure error handling
- secrets management
- Docker security