"""Authenticated account and transfer API routes."""

from typing import Annotated, Any

from fastapi import APIRouter, Depends, HTTPException, status

from app.auth import get_current_user
from app.schemas import AccountResponse, TransferCreate, TransferResponse
from app.transfer_service import (
    AccountNotFoundError,
    InsufficientFundsError,
    SelfTransferError,
    create_transfer,
    get_account,
    list_transfers,
)


CurrentUser = Annotated[dict[str, Any], Depends(get_current_user)]
router = APIRouter(prefix="/api/v1")


@router.get("/accounts/me", response_model=AccountResponse)
def read_current_account(current_user: CurrentUser) -> AccountResponse:
    """Return the authenticated user's account number and balance."""
    try:
        return AccountResponse.model_validate(get_account(current_user["id"]))
    except AccountNotFoundError as error:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Account not found",
        ) from error


@router.get("/transfers", response_model=list[TransferResponse])
def read_transfers(current_user: CurrentUser) -> list[TransferResponse]:
    """List transfers in which the authenticated user is a participant."""
    try:
        return [
            TransferResponse.model_validate(transfer)
            for transfer in list_transfers(current_user["id"])
        ]
    except AccountNotFoundError as error:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Account not found",
        ) from error


@router.post(
    "/transfers",
    response_model=TransferResponse,
    status_code=status.HTTP_201_CREATED,
)
def send_transfer(
    transfer: TransferCreate,
    current_user: CurrentUser,
) -> TransferResponse:
    """Send funds to another account, using the authenticated user as sender."""
    try:
        result = create_transfer(
            current_user["id"],
            transfer.recipient_account_number,
            transfer.amount,
        )
    except AccountNotFoundError as error:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Recipient account not found",
        ) from error
    except SelfTransferError as error:
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
            detail=str(error),
        ) from error
    except InsufficientFundsError as error:
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail=str(error),
        ) from error

    return TransferResponse.model_validate(result)
