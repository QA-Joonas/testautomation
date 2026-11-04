"""Tests for atomic mock-account transfers."""

import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch

from app import database
from app.transfer_service import (
    AccountNotFoundError,
    InsufficientFundsError,
    SelfTransferError,
    create_transfer,
    get_account,
    list_transfers,
)
from app.user_service import create_user, get_user_by_username


class TransferServiceTests(unittest.TestCase):
    def setUp(self) -> None:
        temporary_directory = tempfile.TemporaryDirectory()
        self.addCleanup(temporary_directory.cleanup)
        database_path = Path(temporary_directory.name) / "test.db"
        database_path_patch = patch.object(database, "DATABASE_PATH", database_path)
        database_path_patch.start()
        self.addCleanup(database_path_patch.stop)
        database.init_db()

        self.sender = self._create_user("sender", 5000)
        self.recipient = self._create_user("recipient", 1000)
        self.sender_account = get_account(self.sender["id"])
        self.recipient_account = get_account(self.recipient["id"])

    def test_transfer_debits_and_credits_accounts_and_is_visible_to_both(self) -> None:
        transfer = create_transfer(
            self.sender["id"],
            self.recipient_account["account_number"],
            1250,
        )

        self.assertEqual(transfer["amount"], 1250)
        self.assertEqual(
            transfer["sender_account_number"],
            self.sender_account["account_number"],
        )
        self.assertEqual(
            transfer["recipient_account_number"],
            self.recipient_account["account_number"],
        )
        self.assertEqual(get_account(self.sender["id"])["balance_cents"], 3750)
        self.assertEqual(get_account(self.recipient["id"])["balance_cents"], 2250)
        self.assertEqual(list_transfers(self.sender["id"]), [transfer])
        self.assertEqual(list_transfers(self.recipient["id"]), [transfer])

    def test_insufficient_funds_leave_balances_and_history_unchanged(self) -> None:
        with self.assertRaises(InsufficientFundsError):
            create_transfer(
                self.sender["id"],
                self.recipient_account["account_number"],
                5001,
            )

        self.assertEqual(get_account(self.sender["id"])["balance_cents"], 5000)
        self.assertEqual(get_account(self.recipient["id"])["balance_cents"], 1000)
        self.assertEqual(list_transfers(self.sender["id"]), [])
        self.assertEqual(list_transfers(self.recipient["id"]), [])

    def test_unknown_recipient_leaves_balances_unchanged(self) -> None:
        known_account_numbers = {
            self.sender_account["account_number"],
            self.recipient_account["account_number"],
        }
        unknown_account_number = next(
            candidate
            for candidate in ("000000000000", "999999999999", "111111111111")
            if candidate not in known_account_numbers
        )
        with self.assertRaises(AccountNotFoundError):
            create_transfer(self.sender["id"], unknown_account_number, 100)

        self.assertEqual(get_account(self.sender["id"])["balance_cents"], 5000)
        self.assertEqual(list_transfers(self.sender["id"]), [])

    def test_self_transfer_is_rejected_without_changing_balance(self) -> None:
        with self.assertRaises(SelfTransferError):
            create_transfer(
                self.sender["id"],
                self.sender_account["account_number"],
                100,
            )

        self.assertEqual(get_account(self.sender["id"])["balance_cents"], 5000)
        self.assertEqual(list_transfers(self.sender["id"]), [])

    def test_migration_creates_zero_balance_accounts_for_existing_users(self) -> None:
        with database.get_connection() as connection:
            connection.execute("DROP TABLE transfers")
            connection.execute("DROP TABLE accounts")
            connection.execute("PRAGMA user_version = 1")

        database.init_db()

        migrated_account = get_account(self.sender["id"])
        self.assertEqual(migrated_account["balance_cents"], 0)
        self.assertRegex(migrated_account["account_number"], r"^\d{12}$")

    @staticmethod
    def _create_user(username: str, initial_balance_cents: int) -> dict[str, int | str]:
        create_user(
            username,
            "correct horse battery staple",
            "user",
            initial_balance_cents,
        )
        user = get_user_by_username(username)
        if user is None:
            raise AssertionError("Created user could not be retrieved")
        return {"id": user["id"], "username": user["username"]}


if __name__ == "__main__":
    unittest.main()
