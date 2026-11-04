*** Settings ***
Documentation     API checks for health, transaction operations, and authorization.
Resource         ../../resources/api.resource
Suite Setup      Set API Base URL    ${BASE_URL}
Test Setup       Set Up Transaction Test User
Test Teardown    Clean Up Transaction Test

*** Test Cases ***
Transaction Endpoints Require Authentication
    [Documentation]    Confirms every transaction endpoint rejects unauthenticated requests.
    [Tags]    authentication    authorization
    [Setup]    Set Up Unauthenticated Transaction Test
    ${body}=    Create Dictionary
    ...    description=Unauthenticated transaction
    ...    amount=${1250}
    ...    type=expense
    ...    category=food
    ${list_response}=    Request API    GET    ${TRANSACTIONS_PATH}
    Should Be Equal As Integers    ${list_response}[status_code]    401
    ${get_response}=    Request API    GET    ${TRANSACTIONS_PATH}/1
    Should Be Equal As Integers    ${get_response}[status_code]    401
    ${create_response}=    Request API    POST    ${TRANSACTIONS_PATH}    ${body}
    Should Be Equal As Integers    ${create_response}[status_code]    401
    ${update_response}=    Request API    PUT    ${TRANSACTIONS_PATH}/1    ${body}
    Should Be Equal As Integers    ${update_response}[status_code]    401
    ${delete_response}=    Request API    DELETE    ${TRANSACTIONS_PATH}/1
    Should Be Equal As Integers    ${delete_response}[status_code]    401

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
    ...    amount=${250000}
    ...    type=income
    ...    category=salary
    ${create_response}=    Request API    POST    ${TRANSACTIONS_PATH}    ${create_body}
    Should Be Equal As Integers    ${create_response}[status_code]    201
    ${created}=    Set Variable    ${create_response}[body]
    Set Test Variable    ${TRANSACTION_ID}    ${created}[id]
    Transaction Response Should Match    ${created}    Monthly salary    250000    income    salary

Fractional Transaction Amount Is Rejected
    [Documentation]    Confirms amounts with fractional cents are rejected instead of rounded.
    [Tags]    validation
    ${body}=    Create Dictionary
    ...    description=Fractional amount
    ...    amount=${12.34}
    ...    type=expense
    ...    category=food
    ${response}=    Request API    POST    ${TRANSACTIONS_PATH}    ${body}
    Should Be Equal As Integers    ${response}[status_code]    422

Transaction Can Be Retrieved By ID
    [Documentation]    Creates a transaction in setup, retrieves it by ID, and verifies its fields.
    [Tags]    smoke    happy-path
    [Setup]    Set Up Transaction Test With Fixture
    ${response}=    Request API    GET    ${TRANSACTIONS_PATH}/${TRANSACTION_ID}
    Should Be Equal As Integers    ${response}[status_code]    200
    Transaction Response Should Match    ${response}[body]    Test transaction    1250    expense    food

Transaction Appears In The Transaction List
    [Documentation]    Creates a transaction in setup and confirms its ID appears in the list response.
    [Tags]    happy-path
    [Setup]    Set Up Transaction Test With Fixture
    ${response}=    Request API    GET    ${TRANSACTIONS_PATH}
    Should Be Equal As Integers    ${response}[status_code]    200
    ${listed_ids}=    Evaluate    [item["id"] for item in $response["body"]]
    Should Contain    ${listed_ids}    ${TRANSACTION_ID}

Transaction Can Be Updated
    [Documentation]    An administrator updates a transaction and verifies the persisted values.
    [Tags]    smoke    happy-path
    [Setup]    Set Up Transaction Test User    administrator
    Create Transaction For Test
    ${update_body}=    Create Dictionary
    ...    description=Updated transaction
    ...    amount=${4825}
    ...    type=expense
    ...    category=food
    ${update_response}=    Request API    PUT    ${TRANSACTIONS_PATH}/${TRANSACTION_ID}    ${update_body}
    Should Be Equal As Integers    ${update_response}[status_code]    200
    Transaction Response Should Match    ${update_response}[body]    Updated transaction    4825    expense    food
    ${get_response}=    Request API    GET    ${TRANSACTIONS_PATH}/${TRANSACTION_ID}
    Should Be Equal As Integers    ${get_response}[status_code]    200
    Transaction Response Should Match    ${get_response}[body]    Updated transaction    4825    expense    food

Transaction Can Be Deleted
    [Documentation]    An administrator deletes a transaction and confirms it can no longer be retrieved.
    [Tags]    smoke    happy-path
    [Setup]    Set Up Transaction Test User    administrator
    Create Transaction For Test
    ${delete_response}=    Request API    DELETE    ${TRANSACTIONS_PATH}/${TRANSACTION_ID}
    Should Be Equal As Integers    ${delete_response}[status_code]    204
    ${get_response}=    Request API    GET    ${TRANSACTIONS_PATH}/${TRANSACTION_ID}
    Should Be Equal As Integers    ${get_response}[status_code]    404
    Set Test Variable    ${TRANSACTION_ID}    ${EMPTY}

Customer Can Create And Read Their Transactions But Cannot Update Or Delete
    [Documentation]    Confirms customers can create/read their own transactions but only administrators can update/delete.
    [Tags]    authorization    roles
    Create Transaction For Test
    ${list_response}=    Request API    GET    ${TRANSACTIONS_PATH}
    Should Be Equal As Integers    ${list_response}[status_code]    200
    ${listed_ids}=    Evaluate    [item["id"] for item in $list_response["body"]]
    Should Contain    ${listed_ids}    ${TRANSACTION_ID}
    ${get_response}=    Request API    GET    ${TRANSACTIONS_PATH}/${TRANSACTION_ID}
    Should Be Equal As Integers    ${get_response}[status_code]    200
    Transaction Response Should Match    ${get_response}[body]    Test transaction    1250    expense    food
    ${body}=    Create Dictionary
    ...    description=Unauthorized write
    ...    amount=${2500}
    ...    type=expense
    ...    category=food
    ${update_response}=    Request API    PUT    ${TRANSACTIONS_PATH}/${TRANSACTION_ID}    ${body}
    Should Be Equal As Integers    ${update_response}[status_code]    403
    ${delete_response}=    Request API    DELETE    ${TRANSACTIONS_PATH}/${TRANSACTION_ID}
    Should Be Equal As Integers    ${delete_response}[status_code]    403
    ${still_exists}=    Request API    GET    ${TRANSACTIONS_PATH}/${TRANSACTION_ID}
    Should Be Equal As Integers    ${still_exists}[status_code]    200

Customers Cannot Read Or Modify Another Customers Transactions
    [Documentation]    Confirms transactions are private to the user who created them.
    [Tags]    authorization    ownership
    [Setup]    Set Up Transaction Test User
    Create Transaction For Test
    ${customer_transaction_id}=    Set Variable    ${TRANSACTION_ID}
    Create And Authenticate Test User    user
    ${list_response}=    Request API    GET    ${TRANSACTIONS_PATH}
    Should Be Equal As Integers    ${list_response}[status_code]    200
    Should Be Empty    ${list_response}[body]
    ${get_response}=    Request API    GET    ${TRANSACTIONS_PATH}/${customer_transaction_id}
    Should Be Equal As Integers    ${get_response}[status_code]    404
    ${body}=    Create Dictionary
    ...    description=Cross-user update
    ...    amount=${2500}
    ...    type=expense
    ...    category=food
    ${update_response}=    Request API    PUT    ${TRANSACTIONS_PATH}/${customer_transaction_id}    ${body}
    Should Be Equal As Integers    ${update_response}[status_code]    403
    ${delete_response}=    Request API    DELETE    ${TRANSACTIONS_PATH}/${customer_transaction_id}
    Should Be Equal As Integers    ${delete_response}[status_code]    403

Administrator Can View And Manage Any Customer Transaction
    [Documentation]    Confirms administrators can list, retrieve, update, and delete transactions across customers.
    [Tags]    authorization    administrator
    [Setup]    Set Up Transaction Test User
    Create Transaction For Test
    ${customer_transaction_id}=    Set Variable    ${TRANSACTION_ID}
    Create And Authenticate Test User    administrator
    ${list_response}=    Request API    GET    ${TRANSACTIONS_PATH}
    Should Be Equal As Integers    ${list_response}[status_code]    200
    ${listed_ids}=    Evaluate    [item["id"] for item in $list_response["body"]]
    Should Contain    ${listed_ids}    ${customer_transaction_id}
    ${get_response}=    Request API    GET    ${TRANSACTIONS_PATH}/${customer_transaction_id}
    Should Be Equal As Integers    ${get_response}[status_code]    200
    ${body}=    Create Dictionary
    ...    description=Administrator correction
    ...    amount=${2500}
    ...    type=expense
    ...    category=food
    ${update_response}=    Request API    PUT    ${TRANSACTIONS_PATH}/${customer_transaction_id}    ${body}
    Should Be Equal As Integers    ${update_response}[status_code]    200
    Transaction Response Should Match    ${update_response}[body]    Administrator correction    2500    expense    food
    ${delete_response}=    Request API    DELETE    ${TRANSACTIONS_PATH}/${customer_transaction_id}
    Should Be Equal As Integers    ${delete_response}[status_code]    204
