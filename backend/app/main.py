
from contextlib import asynccontextmanager
from decimal import Decimal, ROUND_HALF_UP

from fastapi import FastAPI, HTTPException, Response, status

from app.database import get_connection, init_db
from app.schemas import TransactionCreate, TransactionResponse, TransactionUpdate


def to_cents(amount: float) -> int:
    """Convert an amount in euros to an integer number of cents."""
    return int(
        (Decimal(str(amount)) * 100).quantize(
            Decimal("1"),
            rounding=ROUND_HALF_UP,
        )
    )


def to_euros(amount_cents: int) -> float:
    """Convert an integer number of cents to euros."""
    return float(Decimal(amount_cents) / 100)


def transaction_from_row(row) -> TransactionResponse:
    """Convert a database row to an API response."""
    return TransactionResponse(
        id=row["id"],
        description=row["description"],
        amount=to_euros(row["amount_cents"]),
        type=row["type"],
        category=row["category"],
        created_at=row["created_at"],
    )


@asynccontextmanager
async def lifespan(app: FastAPI):
    init_db()
    yield


app = FastAPI(
    title="Test Automation Demo API",
    version="1.0.0",
    lifespan=lifespan,
)


@app.get("/health")
def health():
    return {"status": "ok"}


@app.get(
    "/api/v1/transactions",
    response_model=list[TransactionResponse],
)
def list_transactions():
    with get_connection() as connection:
        rows = connection.execute(
            """
            SELECT id, description, amount_cents, type, category, created_at
            FROM transactions
            ORDER BY id
            """
        ).fetchall()

    return [transaction_from_row(row) for row in rows]


@app.post(
    "/api/v1/transactions",
    response_model=TransactionResponse,
    status_code=status.HTTP_201_CREATED,
)
def create_transaction(transaction: TransactionCreate):
    amount_cents = to_cents(transaction.amount)

    if amount_cents < 1 or amount_cents > 10_000_000:
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
            detail="Amount must be between 0.01 and 100000.00 euros",
        )

    with get_connection() as connection:
        cursor = connection.execute(
            """
            INSERT INTO transactions (
                description, amount_cents, type, category
            )
            VALUES (?, ?, ?, ?)
            """,
            (
                transaction.description,
                amount_cents,
                transaction.type,
                transaction.category,
            ),
        )

        row = connection.execute(
            """
            SELECT id, description, amount_cents, type, category, created_at
            FROM transactions
            WHERE id = ?
            """,
            (cursor.lastrowid,),
        ).fetchone()

    return transaction_from_row(row)


@app.get(
    "/api/v1/transactions/{transaction_id}",
    response_model=TransactionResponse,
)
def get_transaction(transaction_id: int):
    with get_connection() as connection:
        row = connection.execute(
            """
            SELECT id, description, amount_cents, type, category, created_at
            FROM transactions
            WHERE id = ?
            """,
            (transaction_id,),
        ).fetchone()

    if row is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Transaction not found",
        )

    return transaction_from_row(row)


@app.put(
    "/api/v1/transactions/{transaction_id}",
    response_model=TransactionResponse,
)
def update_transaction(
    transaction_id: int,
    transaction: TransactionUpdate,
):
    amount_cents = to_cents(transaction.amount)

    if amount_cents < 1 or amount_cents > 10_000_000:
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
            detail="Amount must be between 0.01 and 100000.00 euros",
        )

    with get_connection() as connection:
        cursor = connection.execute(
            """
            UPDATE transactions
            SET description = ?, amount_cents = ?, type = ?, category = ?
            WHERE id = ?
            """,
            (
                transaction.description,
                amount_cents,
                transaction.type,
                transaction.category,
                transaction_id,
            ),
        )

        if cursor.rowcount == 0:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="Transaction not found",
            )

        row = connection.execute(
            """
            SELECT id, description, amount_cents, type, category, created_at
            FROM transactions
            WHERE id = ?
            """,
            (transaction_id,),
        ).fetchone()

    return transaction_from_row(row)


@app.delete(
    "/api/v1/transactions/{transaction_id}",
    status_code=status.HTTP_204_NO_CONTENT,
)
def delete_transaction(transaction_id: int):
    with get_connection() as connection:
        cursor = connection.execute(
            "DELETE FROM transactions WHERE id = ?",
            (transaction_id,),
        )

        if cursor.rowcount == 0:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="Transaction not found",
            )

    return Response(status_code=status.HTTP_204_NO_CONTENT)
