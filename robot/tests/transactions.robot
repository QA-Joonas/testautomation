*** Settings ***
Documentation     Happy-path API checks for health and transaction endpoints.
Resource         ../resources/api.resource
Suite Setup      Set API Base URL    ${BASE_URL}
Test Setup       Reset Transaction State
Test Teardown    Delete Transaction If Created

*** Test Cases ***
Health Endpoint Returns Healthy Status
    [Documentation]    Confirms the health endpoint responds with HTTP 200 and status "ok".
    [Tags]    smoke    happy-path
    ${response}=    Request API    GET    ${HEALTH_PATH}
    Should Be Equal As Integers    ${response}[status_code]    200
    Should Be Equal    ${response}[body][status]    ok

Transaction Can Be Created
    [Documentation]    Creates an income transaction and verifies its response fields.
    [Tags]    smoke    happy-path
    ${create_body}=    Create Dictionary
    ...    description=Monthly salary
    ...    amount=${2500.0}
    ...    type=income
    ...    category=salary
    ${create_response}=    Request API    POST    ${TRANSACTIONS_PATH}    ${create_body}
    Should Be Equal As Integers    ${create_response}[status_code]    201
    ${created}=    Set Variable    ${create_response}[body]
    Set Test Variable    ${TRANSACTION_ID}    ${created}[id]
    Transaction Response Should Match    ${created}    Monthly salary    2500.0    income    salary

Transaction Can Be Retrieved By ID
    [Documentation]    Creates a transaction in setup, retrieves it by ID, and verifies its fields.
    [Tags]    smoke    happy-path
    [Setup]    Create Transaction For Test
    ${response}=    Request API    GET    ${TRANSACTIONS_PATH}/${TRANSACTION_ID}
    Should Be Equal As Integers    ${response}[status_code]    200
    Transaction Response Should Match    ${response}[body]    Test transaction    12.5    expense    food

Transaction Appears In The Transaction List
    [Documentation]    Creates a transaction in setup and confirms its ID appears in the list response.
    [Tags]    happy-path
    [Setup]    Create Transaction For Test
    ${response}=    Request API    GET    ${TRANSACTIONS_PATH}
    Should Be Equal As Integers    ${response}[status_code]    200
    ${listed_ids}=    Evaluate    [item["id"] for item in $response["body"]]
    Should Contain    ${listed_ids}    ${TRANSACTION_ID}

Transaction Can Be Updated
    [Documentation]    Creates a transaction in setup, replaces its values, and verifies the persisted update.
    [Tags]    smoke    happy-path
    [Setup]    Create Transaction For Test
    ${update_body}=    Create Dictionary
    ...    description=Updated transaction
    ...    amount=${48.25}
    ...    type=expense
    ...    category=food
    ${update_response}=    Request API    PUT    ${TRANSACTIONS_PATH}/${TRANSACTION_ID}    ${update_body}
    Should Be Equal As Integers    ${update_response}[status_code]    200
    Transaction Response Should Match    ${update_response}[body]    Updated transaction    48.25    expense    food
    ${get_response}=    Request API    GET    ${TRANSACTIONS_PATH}/${TRANSACTION_ID}
    Should Be Equal As Integers    ${get_response}[status_code]    200
    Transaction Response Should Match    ${get_response}[body]    Updated transaction    48.25    expense    food

Transaction Can Be Deleted
    [Documentation]    Creates a transaction in setup, deletes it, and confirms it can no longer be retrieved.
    [Tags]    smoke    happy-path
    [Setup]    Create Transaction For Test
    ${delete_response}=    Request API    DELETE    ${TRANSACTIONS_PATH}/${TRANSACTION_ID}
    Should Be Equal As Integers    ${delete_response}[status_code]    204
    ${get_response}=    Request API    GET    ${TRANSACTIONS_PATH}/${TRANSACTION_ID}
    Should Be Equal As Integers    ${get_response}[status_code]    404
    Set Test Variable    ${TRANSACTION_ID}    ${EMPTY}

Transaction Persists After Docker Container Restart
    [Documentation]    Creates a transaction, restarts the configured API container, and verifies the transaction is still stored.
    [Tags]    persistence    docker
    [Setup]    Create Transaction For Test
    Restart Docker Container    ${DOCKER_CONTAINER_NAME}
    ${response}=    Request API    GET    ${TRANSACTIONS_PATH}/${TRANSACTION_ID}
    Should Be Equal As Integers    ${response}[status_code]    200
    Transaction Response Should Match    ${response}[body]    Test transaction    12.5    expense    food
