*** Settings ***
Resource    api.resource
Library     Collections

*** Variables ***
${ACCOUNTS_PATH}     /api/v1/accounts/me
${TRANSFERS_PATH}    /api/v1/transfers
${TRANSFER_SENDER_USERNAME}                  ${EMPTY}
${TRANSFER_SENDER_ACCOUNT_NUMBER}            ${EMPTY}
${TRANSFER_RECIPIENT_USERNAME}               ${EMPTY}
${TRANSFER_RECIPIENT_ACCOUNT_NUMBER}         ${EMPTY}

*** Keywords ***
Set Up Transfer Test Accounts
    Create And Authenticate Test User    user    ${10000}
    Set Test Variable    ${TRANSFER_SENDER_USERNAME}    ${TEST_USERNAME}
    ${sender_account}=    Request API    GET    ${ACCOUNTS_PATH}
    Should Be Equal As Integers    ${sender_account}[status_code]    200
    Set Test Variable    ${TRANSFER_SENDER_ACCOUNT_NUMBER}
    ...    ${sender_account}[body][account_number]
    Should Be Equal As Integers    ${sender_account}[body][balance_cents]    10000
    Create And Authenticate Test User    user
    Set Test Variable    ${TRANSFER_RECIPIENT_USERNAME}    ${TEST_USERNAME}
    ${recipient_account}=    Request API    GET    ${ACCOUNTS_PATH}
    Should Be Equal As Integers    ${recipient_account}[status_code]    200
    Set Test Variable    ${TRANSFER_RECIPIENT_ACCOUNT_NUMBER}
    ...    ${recipient_account}[body][account_number]
    Should Be Equal As Integers    ${recipient_account}[body][balance_cents]    0
    Should Not Be Equal
    ...    ${TRANSFER_SENDER_ACCOUNT_NUMBER}
    ...    ${TRANSFER_RECIPIENT_ACCOUNT_NUMBER}
    Authenticate Test User    ${TRANSFER_SENDER_USERNAME}

Transfer Request Body
    [Arguments]    ${recipient_account_number}    ${amount}
    ${body}=    Create Dictionary
    ...    recipient_account_number=${recipient_account_number}
    ...    amount=${amount}
    RETURN    ${body}

Transfer Response Should Match
    [Arguments]    ${transfer}    ${sender_account_number}    ${recipient_account_number}    ${amount}
    Should Be True    isinstance($transfer["id"], int)
    Should Be Equal    ${transfer}[sender_account_number]    ${sender_account_number}
    Should Be Equal    ${transfer}[recipient_account_number]    ${recipient_account_number}
    Should Be Equal As Integers    ${transfer}[amount]    ${amount}
    Should Not Be Empty    ${transfer}[created_at]

Current Account Balance Should Be
    [Arguments]    ${balance_cents}
    ${response}=    Request API    GET    ${ACCOUNTS_PATH}
    Should Be Equal As Integers    ${response}[status_code]    200
    Should Be Equal As Integers    ${response}[body][balance_cents]    ${balance_cents}
