"""Private CLI for creating and removing application users."""

import argparse
import json
import sys
from typing import cast

from app.database import init_db
from app.schemas import UserRole
from app.user_service import create_user, delete_user


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    commands = parser.add_subparsers(dest="command", required=True)

    create_parser = commands.add_parser("create", help="privately provision a user")
    create_parser.add_argument("--username", required=True)
    create_parser.add_argument(
        "--role",
        choices=("user", "administrator"),
        required=True,
    )

    delete_parser = commands.add_parser("delete", help="remove a provisioned user")
    delete_parser.add_argument("--username", required=True)

    arguments = parser.parse_args()
    init_db()

    if arguments.command == "create":
        password = sys.stdin.readline().rstrip("\r\n")
        if not password:
            parser.error("read a password from standard input")

        user = create_user(
            arguments.username,
            password,
            cast(UserRole, arguments.role),
        )
        print(json.dumps(user))
        return

    if not delete_user(arguments.username):
        parser.error("user does not exist")
    print(json.dumps({"deleted": True}))


if __name__ == "__main__":
    main()
