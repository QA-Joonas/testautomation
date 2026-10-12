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


class TransactionCreate(BaseModel):
    """Request schema for creating a transaction."""

    model_config = ConfigDict(extra="forbid")

    description: Annotated[
        str,
        Field(min_length=1, max_length=100, strict=True),
    ]
    amount: Annotated[
        float,
        Field(
            gt=0,
            le=100000,
            allow_inf_nan=False,
            strict=True,
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
        float,
        Field(gt=0, le=100000),
    ]
    type: TransactionType
    category: TransactionCategory
    created_at: datetime
