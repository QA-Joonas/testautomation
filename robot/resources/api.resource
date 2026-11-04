*** Settings ***
Library    ../keywords/api_keywords.py    WITH NAME    ApiKeywords

*** Variables ***
${BASE_URL}                 http://localhost:8000
${DOCKER_CONTAINER_NAME}    testautomation-robot-api
${HEALTH_PATH}              /health
${TRANSACTIONS_PATH}        /api/v1/transactions

*** Keywords ***
Reset Transaction State
    [Documentation]    Initializes the per-test transaction ID so teardown can safely detect created data.
    Set Test Variable    ${TRANSACTION_ID}    ${EMPTY}

Create Transaction For Test
    [Documentation]    Creates a standard expense transaction and stores its ID for the current test.
    Reset Transaction State
    ${body}=    Create Dictionary
    ...    description=Test transaction
    ...    amount=${1250}
    ...    type=expense
    ...    category=food
    ${response}=    Request API    POST    ${TRANSACTIONS_PATH}    ${body}
    Should Be Equal As Integers    ${response}[status_code]    201
    ${transaction}=    Set Variable    ${response}[body]
    Set Test Variable    ${TRANSACTION_ID}    ${transaction}[id]
    Transaction Response Should Match    ${transaction}    Test transaction    1250    expense    food

Delete Transaction If Created
    [Documentation]    Deletes the current test's transaction if setup or the test created one.
    IF    $TRANSACTION_ID != ''
        ${response}=    Request API    DELETE    ${TRANSACTIONS_PATH}/${TRANSACTION_ID}
        Should Be True    $response["status_code"] in (204, 404)
    END

Transaction Response Should Match
    [Arguments]    ${transaction}    ${description}    ${amount}    ${type}    ${category}
    [Documentation]    Verifies the transaction's business fields and that a creation timestamp is present.
    Should Be Equal    ${transaction}[description]    ${description}
    Should Be True    isinstance($transaction["amount"], int)
    Should Be Equal As Integers    ${transaction}[amount]    ${amount}
    Should Be Equal    ${transaction}[type]    ${type}
    Should Be Equal    ${transaction}[category]    ${category}
    Should Not Be Empty    ${transaction}[created_at]
