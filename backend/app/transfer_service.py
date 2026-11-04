"""Account and transfer operations backed by SQLite."""

import sqlite3
from typing import Any

from app.database import get_connection


class AccountNotFoundError(Exception):
    """Raised when an account cannot be found."""


class InsufficientFundsError(Exception):
    """Raised when an account cannot cover a transfer."""


class SelfTransferError(Exception):
    """Raised when an account attempts to transfer to itself."""


def get_account(user_id: int) -> dict[str, Any]:
    """Return the authenticated user's account and current balance."""
    with get_connection() as connection:
        row = connection.execute(
            """
            SELECT account_number, balance_cents, created_at
            FROM accounts
            WHERE user_id = ?
            """,
            (user_id,),
        ).fetchone()

    if row is None:
        raise AccountNotFoundError("Account not found")
    return dict(row)


def list_transfers(user_id: int) -> list[dict[str, Any]]:
    """Return transfers sent or received by the authenticated user."""
    with get_connection() as connection:
        account = connection.execute(
            "SELECT id FROM accounts WHERE user_id = ?",
            (user_id,),
        ).fetchone()
        if account is None:
            raise AccountNotFoundError("Account not found")

        rows = connection.execute(
            """
            SELECT transfer.id, transfer.created_at,
                   transfer.amount_cents AS amount,
                   sender.account_number AS sender_account_number,
                   recipient.account_number AS recipient_account_number
            FROM transfers AS transfer
            JOIN accounts AS sender
                ON sender.id = transfer.sender_account_id
            JOIN accounts AS recipient
                ON recipient.id = transfer.recipient_account_id
            WHERE transfer.sender_account_id = ?
               OR transfer.recipient_account_id = ?
            ORDER BY transfer.id
            """,
            (account["id"], account["id"]),
        ).fetchall()

    return [dict(row) for row in rows]


def create_transfer(
    sender_user_id: int,
    recipient_account_number: str,
    amount_cents: int,
) -> dict[str, Any]:
    """Atomically debit the sender, credit the recipient, and record the transfer."""
    with get_connection() as connection:
        connection.execute("BEGIN IMMEDIATE")
        sender = connection.execute(
            "SELECT id, account_number, balance_cents FROM accounts WHERE user_id = ?",
            (sender_user_id,),
        ).fetchone()
        if sender is None:
            raise AccountNotFoundError("Sender account not found")

        recipient = connection.execute(
            "SELECT id, account_number FROM accounts WHERE account_number = ?",
            (recipient_account_number,),
        ).fetchone()
        if recipient is None:
            raise AccountNotFoundError("Recipient account not found")
        if sender["id"] == recipient["id"]:
            raise SelfTransferError("Cannot transfer to your own account")
        if sender["balance_cents"] < amount_cents:
            raise InsufficientFundsError("Insufficient funds")

        debit = connection.execute(
            """
            UPDATE accounts
            SET balance_cents = balance_cents - ?
            WHERE id = ? AND balance_cents >= ?
            """,
            (amount_cents, sender["id"], amount_cents),
        )
        if debit.rowcount != 1:
            raise InsufficientFundsError("Insufficient funds")

        connection.execute(
            """
            UPDATE accounts
            SET balance_cents = balance_cents + ?
            WHERE id = ?
            """,
            (amount_cents, recipient["id"]),
        )
        cursor = connection.execute(
            """
            INSERT INTO transfers (
                sender_account_id, recipient_account_id, amount_cents
            )
            VALUES (?, ?, ?)
            """,
            (sender["id"], recipient["id"], amount_cents),
        )

        row = connection.execute(
            """
            SELECT transfer.id, transfer.created_at,
                   transfer.amount_cents AS amount,
                   sender.account_number AS sender_account_number,
                   recipient.account_number AS recipient_account_number
            FROM transfers AS transfer
            JOIN accounts AS sender
                ON sender.id = transfer.sender_account_id
            JOIN accounts AS recipient
                ON recipient.id = transfer.recipient_account_id
            WHERE transfer.id = ?
            """,
            (cursor.lastrowid,),
        ).fetchone()

    return dict(row)
