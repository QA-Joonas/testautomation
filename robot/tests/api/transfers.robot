*** Settings ***
Documentation     API checks for mock accounts and transfers.
Resource          ../../resources/transfer.resource
Suite Setup       Set API Base URL    ${BASE_URL}
Test Setup        Set Up Transfer Test Accounts
Test Teardown     Delete Test User

*** Test Cases ***
User Can Transfer Funds To Another Account
    [Documentation]    Debits the sender, credits the recipient, and exposes the transfer to both participants.
    [Tags]    smoke    happy-path    transfers
    ${body}=    Transfer Request Body    ${TRANSFER_RECIPIENT_ACCOUNT_NUMBER}    ${3250}
    ${response}=    Request API    POST    ${TRANSFERS_PATH}    ${body}
    Should Be Equal As Integers    ${response}[status_code]    201
    ${transfer}=    Set Variable    ${response}[body]
    Transfer Response Should Match
    ...    ${transfer}
    ...    ${TRANSFER_SENDER_ACCOUNT_NUMBER}
    ...    ${TRANSFER_RECIPIENT_ACCOUNT_NUMBER}
    ...    3250
    Current Account Balance Should Be    6750
    ${expected_history}=    Create List    ${transfer}
    ${sender_history}=    Request API    GET    ${TRANSFERS_PATH}
    Should Be Equal As Integers    ${sender_history}[status_code]    200
    Should Be Equal    ${sender_history}[body]    ${expected_history}
    Authenticate Test User    ${TRANSFER_RECIPIENT_USERNAME}
    Current Account Balance Should Be    3250
    ${recipient_history}=    Request API    GET    ${TRANSFERS_PATH}
    Should Be Equal As Integers    ${recipient_history}[status_code]    200
    Should Be Equal    ${recipient_history}[body]    ${expected_history}

Transfer Rejects Invalid Request Fields Without Side Effects
    [Documentation]    Rejects missing, malformed, out-of-range, and spoofed transfer fields.
    [Tags]    negative    validation    security    transfers
    ${invalid_payloads}=    Create List
    ${missing_recipient}=    Create Dictionary    amount=${100}
    Append To List    ${invalid_payloads}    ${missing_recipient}
    ${missing_amount}=    Create Dictionary    recipient_account_number=${TRANSFER_RECIPIENT_ACCOUNT_NUMBER}
    Append To List    ${invalid_payloads}    ${missing_amount}
    ${malformed_recipient}=    Create Dictionary
    ...    recipient_account_number=not-an-account
    ...    amount=${100}
    Append To List    ${invalid_payloads}    ${malformed_recipient}
    ${spoofed_sender}=    Transfer Request Body    ${TRANSFER_RECIPIENT_ACCOUNT_NUMBER}    ${100}
    Set To Dictionary    ${spoofed_sender}
    ...    sender_account_number=${TRANSFER_RECIPIENT_ACCOUNT_NUMBER}
    Append To List    ${invalid_payloads}    ${spoofed_sender}
    ${invalid_amounts}=    Create List
    ...    ${None}    ${0}    ${-1}    ${10000001}    ${True}    ${12.34}    not-an-amount
    FOR    ${amount}    IN    @{invalid_amounts}
        ${invalid_body}=    Transfer Request Body    ${TRANSFER_RECIPIENT_ACCOUNT_NUMBER}    ${amount}
        Append To List    ${invalid_payloads}    ${invalid_body}
    END
    FOR    ${payload}    IN    @{invalid_payloads}
        ${response}=    Request API    POST    ${TRANSFERS_PATH}    ${payload}
        Should Be Equal As Integers    ${response}[status_code]    422
        Should Not Be Empty    ${response}[body][detail]
    END
    Current Account Balance Should Be    10000
    ${history}=    Request API    GET    ${TRANSFERS_PATH}
    Should Be Equal As Integers    ${history}[status_code]    200
    Should Be Empty    ${history}[body]
    Authenticate Test User    ${TRANSFER_RECIPIENT_USERNAME}
    Current Account Balance Should Be    0
    ${recipient_history}=    Request API    GET    ${TRANSFERS_PATH}
    Should Be Empty    ${recipient_history}[body]

Transfer Rejects Insufficient Funds Without Side Effects
    [Documentation]    Rejects a transfer above the sender's balance and leaves both accounts unchanged.
    [Tags]    negative    transfers    data-integrity
    ${body}=    Transfer Request Body    ${TRANSFER_RECIPIENT_ACCOUNT_NUMBER}    ${10001}
    ${response}=    Request API    POST    ${TRANSFERS_PATH}    ${body}
    Should Be Equal As Integers    ${response}[status_code]    409
    Should Be Equal    ${response}[body][detail]    Insufficient funds
    Current Account Balance Should Be    10000
    ${history}=    Request API    GET    ${TRANSFERS_PATH}
    Should Be Empty    ${history}[body]
    Authenticate Test User    ${TRANSFER_RECIPIENT_USERNAME}
    Current Account Balance Should Be    0
    ${recipient_history}=    Request API    GET    ${TRANSFERS_PATH}
    Should Be Empty    ${recipient_history}[body]

Transfer Rejects Unknown And Own Accounts
    [Documentation]    Rejects transfers to nonexistent and self-owned account numbers without changing state.
    [Tags]    negative    transfers    validation
    ${unknown_candidates}=    Create List
    ...    000000000000    999999999999    111111111111
    FOR    ${known_account_number}    IN
    ...    ${TRANSFER_SENDER_ACCOUNT_NUMBER}    ${TRANSFER_RECIPIENT_ACCOUNT_NUMBER}
        ${known_index}=    Get Index From List
        ...    ${unknown_candidates}    ${known_account_number}
        IF    ${known_index} >= 0
            Remove From List    ${unknown_candidates}    ${known_index}
        END
    END
    ${unknown_number}=    Get From List    ${unknown_candidates}    0
    ${unknown_body}=    Transfer Request Body    ${unknown_number}    ${100}
    ${unknown_response}=    Request API    POST    ${TRANSFERS_PATH}    ${unknown_body}
    Should Be Equal As Integers    ${unknown_response}[status_code]    404
    Should Be Equal    ${unknown_response}[body][detail]    Recipient account not found
    ${self_body}=    Transfer Request Body    ${TRANSFER_SENDER_ACCOUNT_NUMBER}    ${100}
    ${self_response}=    Request API    POST    ${TRANSFERS_PATH}    ${self_body}
    Should Be Equal As Integers    ${self_response}[status_code]    422
    Should Be Equal    ${self_response}[body][detail]    Cannot transfer to your own account
    Current Account Balance Should Be    10000
    ${history}=    Request API    GET    ${TRANSFERS_PATH}
    Should Be Empty    ${history}[body]

Only Transfer Participants Can See A Transfer
    [Documentation]    Keeps transfer listings limited to the authenticated account's own sent and received transfers.
    [Tags]    authorization    security    transfers
    ${body}=    Transfer Request Body    ${TRANSFER_RECIPIENT_ACCOUNT_NUMBER}    ${250}
    ${send_response}=    Request API    POST    ${TRANSFERS_PATH}    ${body}
    Should Be Equal As Integers    ${send_response}[status_code]    201
    Create And Authenticate Test User    user
    ${unrelated_history}=    Request API    GET    ${TRANSFERS_PATH}
    Should Be Equal As Integers    ${unrelated_history}[status_code]    200
    Should Be Empty    ${unrelated_history}[body]
    Current Account Balance Should Be    0

Accounts And Transfers Require Authentication
    [Documentation]    Requires a valid bearer token for account details and transfer operations.
    [Tags]    authentication    authorization    transfers
    ApiKeywords.Clear API Access Token
    ${list_response}=    Request API    GET    ${TRANSFERS_PATH}
    Should Be Equal As Integers    ${list_response}[status_code]    401
    Should Not Be Empty    ${list_response}[www_authenticate]
    ${account_response}=    Request API    GET    ${ACCOUNTS_PATH}
    Should Be Equal As Integers    ${account_response}[status_code]    401
    ${body}=    Transfer Request Body    ${TRANSFER_RECIPIENT_ACCOUNT_NUMBER}    ${100}
    ${create_response}=    Request API    POST    ${TRANSFERS_PATH}    ${body}
    Should Be Equal As Integers    ${create_response}[status_code]    401
