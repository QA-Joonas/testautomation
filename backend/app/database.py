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
    """Create the application tables and indexes if they do not already exist."""
    with get_connection() as connection:
        connection.execute("PRAGMA foreign_keys = OFF")
        try:
            connection.execute("BEGIN")
            connection.execute(
                """
                CREATE TABLE IF NOT EXISTS users (
                    id INTEGER PRIMARY KEY AUTOINCREMENT,
                    username TEXT NOT NULL COLLATE NOCASE UNIQUE
                        CHECK (length(trim(username)) BETWEEN 3 AND 50),
                    password_hash TEXT NOT NULL,
                    role TEXT NOT NULL
                        CHECK (role IN ('user', 'administrator')),
                    created_at TEXT NOT NULL DEFAULT (
                        strftime('%Y-%m-%dT%H:%M:%fZ', 'now')
                    )
                )
                """
            )

            if connection.execute("PRAGMA user_version").fetchone()[0] < 1:
                connection.execute(
                    """
                    CREATE TABLE users_new (
                        id INTEGER PRIMARY KEY AUTOINCREMENT,
                        username TEXT NOT NULL COLLATE NOCASE UNIQUE
                            CHECK (length(trim(username)) BETWEEN 3 AND 50),
                        password_hash TEXT NOT NULL,
                        role TEXT NOT NULL
                            CHECK (role IN ('user', 'administrator')),
                        created_at TEXT NOT NULL DEFAULT (
                            strftime('%Y-%m-%dT%H:%M:%fZ', 'now')
                        )
                    )
                    """
                )
                connection.execute(
                    """
                    INSERT INTO users_new (id, username, password_hash, role, created_at)
                    SELECT id, username, password_hash,
                        CASE WHEN role IN ('owner', 'read_only')
                            THEN 'user' ELSE role END,
                        created_at
                    FROM users
                    """
                )
                connection.execute("DROP TABLE users")
                connection.execute("ALTER TABLE users_new RENAME TO users")
                connection.execute("PRAGMA user_version = 1")

            transaction_columns = connection.execute(
                "PRAGMA table_info(transactions)"
            ).fetchall()
            has_transaction_table = bool(transaction_columns)
            needs_ownership_migration = has_transaction_table and "user_id" not in {
                column["name"] for column in transaction_columns
            }
            if needs_ownership_migration:
                connection.execute("DROP TABLE transactions")

            if not has_transaction_table or needs_ownership_migration:
                connection.execute(
                    """
                    CREATE TABLE transactions (
                        id INTEGER PRIMARY KEY AUTOINCREMENT,
                        user_id INTEGER NOT NULL REFERENCES users(id)
                            ON DELETE CASCADE,
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
            connection.execute(
                "CREATE INDEX IF NOT EXISTS idx_transactions_user_id ON transactions(user_id)"
            )
            connection.commit()
        except Exception:
            connection.rollback()
            raise
        finally:
            connection.execute("PRAGMA foreign_keys = ON")

        violations = connection.execute("PRAGMA foreign_key_check").fetchall()
        if violations:
            raise sqlite3.IntegrityError(
                f"Database contains {len(violations)} foreign-key violation(s)"
            )
