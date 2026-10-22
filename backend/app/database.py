import os
import sqlite3
from pathlib import Path


BASE_DIR = Path(__file__).resolve().parent.parent
DEFAULT_DATABASE_PATH = BASE_DIR / "data" / "testautomation.db"
DATABASE_PATH = Path(os.getenv("DATABASE_PATH", str(DEFAULT_DATABASE_PATH)))


def get_connection() -> sqlite3.Connection:
    """Create and return a connection to the SQLite database."""
    DATABASE_PATH.parent.mkdir(parents=True, exist_ok=True)

    connection = sqlite3.connect(
        DATABASE_PATH,
        timeout=5.0,
    )
    connection.row_factory = sqlite3.Row
    connection.execute("PRAGMA foreign_keys = ON")
    connection.execute("PRAGMA journal_mode = WAL")

    return connection


def init_db() -> None:
    """Create the database schema and indexes if they do not already exist."""
    with get_connection() as connection:
        connection.execute(
            """
            CREATE TABLE IF NOT EXISTS transactions (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                description TEXT NOT NULL
                    CHECK (
                        length(trim(description)) BETWEEN 1 AND 100
                    ),
                amount_cents INTEGER NOT NULL
                    CHECK (amount_cents BETWEEN 1 AND 10000000),
                type TEXT NOT NULL
                    CHECK (type IN ('income', 'expense')),
                category TEXT NOT NULL
                    CHECK (length(trim(category)) BETWEEN 1 AND 30),
                created_at TEXT NOT NULL DEFAULT (
                    strftime('%Y-%m-%dT%H:%M:%fZ', 'now')
                )
            )
            """
        )

        connection.execute(
            "CREATE INDEX IF NOT EXISTS idx_transactions_type ON transactions(type)"
        )
        connection.execute(
            "CREATE INDEX IF NOT EXISTS idx_transactions_category ON transactions(category)"
        )
        connection.execute(
            "CREATE INDEX IF NOT EXISTS idx_transactions_created_at ON transactions(created_at)"
        )
