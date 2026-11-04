"""Helpers for generating mock account identifiers."""

import secrets


ACCOUNT_NUMBER_LENGTH = 12


def generate_account_number() -> str:
    """Return a zero-padded numeric account number."""
    return f"{secrets.randbelow(10**ACCOUNT_NUMBER_LENGTH):0{ACCOUNT_NUMBER_LENGTH}d}"
