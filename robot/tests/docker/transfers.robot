*** Settings ***
Documentation     Docker persistence checks for mock account transfers.
Resource          ../../resources/transfer.resource
Suite Setup       Set API Base URL    ${BASE_URL}
Test Setup        Set Up Transfer Test Accounts
Test Teardown     Delete Test User

*** Test Cases ***
Transfer Persists After Docker Container Restart
    [Documentation]    Restarts the API container and verifies transfer history and both account balances persist.
    [Tags]    persistence    docker    transfers
    ${body}=    Transfer Request Body    ${TRANSFER_RECIPIENT_ACCOUNT_NUMBER}    ${2500}
    ${send_response}=    Request API    POST    ${TRANSFERS_PATH}    ${body}
    Should Be Equal As Integers    ${send_response}[status_code]    201
    ${transfer}=    Set Variable    ${send_response}[body]
    Restart Docker Container    ${DOCKER_CONTAINER_NAME}
    Authenticate Test User    ${TRANSFER_SENDER_USERNAME}
    Current Account Balance Should Be    7500
    ${sender_history}=    Request API    GET    ${TRANSFERS_PATH}
    Should Be Equal As Integers    ${sender_history}[status_code]    200
    ${expected_history}=    Create List    ${transfer}
    Should Be Equal    ${sender_history}[body]    ${expected_history}
    Authenticate Test User    ${TRANSFER_RECIPIENT_USERNAME}
    Current Account Balance Should Be    2500
    ${recipient_history}=    Request API    GET    ${TRANSFERS_PATH}
    Should Be Equal As Integers    ${recipient_history}[status_code]    200
    Should Be Equal    ${recipient_history}[body]    ${expected_history}
