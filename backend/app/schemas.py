from datetime import datetime
from typing import Annotated, Literal

from pydantic import (
    BaseModel,
    ConfigDict,
    Field,
    field_validator,
)


TransactionType = Literal["income", "expense"]

TransactionCategory = Literal[
    "food",
    "housing",
    "transport",
    "health",
    "entertainment",
    "shopping",
    "salary",
    "benefits",
    "refund",
    "other",
]

UserRole = Literal["user", "administrator"]
USER_PASSWORD_MAX_LENGTH = 128


class UserCredentials(BaseModel):
    """Credentials used by the private provisioning tool and login endpoint."""

    model_config = ConfigDict(extra="forbid")

    username: Annotated[
        str,
        Field(
            min_length=3,
            max_length=50,
            strict=True,
            pattern=r"^[a-zA-Z0-9][a-zA-Z0-9_.-]*$",
        ),
    ]
    password: Annotated[
        str,
        Field(min_length=12, max_length=USER_PASSWORD_MAX_LENGTH, strict=True),
    ]

    @field_validator("username")
    @classmethod
    def normalize_username(cls, value: str) -> str:
        return value.strip().lower()


class UserLogin(UserCredentials):
    """Request schema for logging in with a username and password."""

    password: Annotated[
        str,
        Field(max_length=USER_PASSWORD_MAX_LENGTH, strict=True),
    ]


class UserResponse(BaseModel):
    """Public user information; password hashes are never included."""

    id: int
    username: str
    role: UserRole
    created_at: datetime


class AccessTokenResponse(BaseModel):
    """Bearer access token returned after successful authentication."""

    access_token: str
    token_type: Literal["bearer"] = "bearer"
    expires_in: int


class TransactionCreate(BaseModel):
    """Request schema for creating a transaction."""

    model_config = ConfigDict(extra="forbid")

    description: Annotated[
        str,
        Field(min_length=1, max_length=100, strict=True),
    ]
    amount: Annotated[
        int,
        Field(
            gt=0,
            le=10_000_000,
            strict=True,
            description="Transaction amount in integer cents.",
        ),
    ]
    type: TransactionType
    category: TransactionCategory

    @field_validator("description")
    @classmethod
    def validate_description(cls, value: str) -> str:
        value = value.strip()

        if not value:
            raise ValueError("Description must not be blank")

        return value

    @field_validator("category")
    @classmethod
    def validate_category_for_type(
        cls,
        value: str,
        info,
    ) -> str:
        transaction_type = info.data.get("type")

        income_categories = {
            "salary",
            "benefits",
            "refund",
            "other",
        }

        expense_categories = {
            "food",
            "housing",
            "transport",
            "health",
            "entertainment",
            "shopping",
            "refund",
            "other",
        }

        if transaction_type == "income":
            if value not in income_categories:
                raise ValueError(
                    "Category is not valid for an income transaction"
                )

        elif transaction_type == "expense":
            if value not in expense_categories:
                raise ValueError(
                    "Category is not valid for an expense transaction"
                )

        return value


class TransactionUpdate(TransactionCreate):
    """Request schema for replacing an existing transaction."""


class TransactionResponse(BaseModel):
    """Response schema for a transaction."""

    model_config = ConfigDict(from_attributes=True)

    id: int
    description: str
    amount: Annotated[
        int,
        Field(
            gt=0,
            le=10_000_000,
            strict=True,
            description="Transaction amount in integer cents.",
        ),
    ]
    type: TransactionType
    category: TransactionCategory
    created_at: datetime
