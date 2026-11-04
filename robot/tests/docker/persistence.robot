*** Settings ***
Documentation     Docker persistence checks that restart the API container.
Resource         ../../resources/api.resource
Suite Setup      Set API Base URL    ${BASE_URL}
Test Setup       Reset Transaction State
Test Teardown    Delete Transaction If Created

*** Test Cases ***
Transaction Persists After Docker Container Restart
    [Documentation]    Creates a transaction, restarts the configured API container, and verifies the transaction is still stored.
    [Tags]    persistence    docker
    [Setup]    Create Transaction For Test
    Restart Docker Container    ${DOCKER_CONTAINER_NAME}
    ${response}=    Request API    GET    ${TRANSACTIONS_PATH}/${TRANSACTION_ID}
    Should Be Equal As Integers    ${response}[status_code]    200
    Transaction Response Should Match    ${response}[body]    Test transaction    12.5    expense    food
