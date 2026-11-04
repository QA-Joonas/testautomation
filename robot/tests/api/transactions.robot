*** Settings ***
Documentation     API checks for health, transaction operations, and authorization.
Resource         ../../resources/api.resource
Library          Collections
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
    Error Response Should Match    ${list_response}    401    Authentication required
    Should Be Equal    ${list_response}[www_authenticate]    Bearer
    ${get_response}=    Request API    GET    ${TRANSACTIONS_PATH}/1
    Error Response Should Match    ${get_response}    401    Authentication required
    ${create_response}=    Request API    POST    ${TRANSACTIONS_PATH}    ${body}
    Error Response Should Match    ${create_response}    401    Authentication required
    ${update_response}=    Request API    PUT    ${TRANSACTIONS_PATH}/1    ${body}
    Error Response Should Match    ${update_response}    401    Authentication required
    ${delete_response}=    Request API    DELETE    ${TRANSACTIONS_PATH}/1
    Error Response Should Match    ${delete_response}    401    Authentication required

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
    Validation Error Response Should Be Well Formed    ${response}

Transaction Creation Rejects Invalid Data
    [Documentation]    Checks missing, malformed, out-of-range, and privileged fields in every create payload.
    [Tags]    negative    validation    security
    ${invalid_payloads}=    Invalid Transaction Payloads
    ${before}=    Request API    GET    ${TRANSACTIONS_PATH}
    Should Be Equal As Integers    ${before}[status_code]    200
    ${before_ids}=    Evaluate    [item["id"] for item in $before["body"]]
    FOR    ${payload}    IN    @{invalid_payloads}
        ${response}=    Request API    POST    ${TRANSACTIONS_PATH}    ${payload}
        Validation Error Response Should Be Well Formed    ${response}
    END
    ${after}=    Request API    GET    ${TRANSACTIONS_PATH}
    Should Be Equal As Integers    ${after}[status_code]    200
    ${after_ids}=    Evaluate    [item["id"] for item in $after["body"]]
    Should Be Equal    ${after_ids}    ${before_ids}

Transaction Field Boundaries Are Accepted Across Create And Update
    [Documentation]    Verifies inclusive description and amount limits remain valid for create and full replacement.
    [Tags]    validation    boundary
    [Setup]    Set Up Transaction Test User    administrator
    ${maximum_description}=    Evaluate    'x' * 100
    ${maximum_body}=    Create Dictionary
    ...    description=${maximum_description}
    ...    amount=${10000000}
    ...    type=income
    ...    category=benefits
    ${create_response}=    Request API    POST    ${TRANSACTIONS_PATH}    ${maximum_body}
    Should Be Equal As Integers    ${create_response}[status_code]    201
    ${created}=    Set Variable    ${create_response}[body]
    Set Test Variable    ${TRANSACTION_ID}    ${created}[id]
    Transaction Response Should Match    ${created}    ${maximum_description}    10000000    income    benefits
    ${minimum_body}=    Create Dictionary
    ...    description=x
    ...    amount=${1}
    ...    type=expense
    ...    category=shopping
    ${update_response}=    Request API    PUT    ${TRANSACTIONS_PATH}/${TRANSACTION_ID}    ${minimum_body}
    Should Be Equal As Integers    ${update_response}[status_code]    200
    Transaction Response Should Match    ${update_response}[body]    x    1    expense    shopping

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

Transaction Update Rejects Invalid Data Without Changing The Record
    [Documentation]    Checks every invalid and privileged replacement payload is rejected without changing the record.
    [Tags]    negative    validation    security
    [Setup]    Set Up Transaction Test With Administrator Fixture
    ${invalid_payloads}=    Invalid Transaction Payloads
    FOR    ${payload}    IN    @{invalid_payloads}
        ${response}=    Request API    PUT    ${TRANSACTIONS_PATH}/${TRANSACTION_ID}    ${payload}
        Validation Error Response Should Be Well Formed    ${response}
        ${current}=    Request API    GET    ${TRANSACTIONS_PATH}/${TRANSACTION_ID}
        Should Be Equal As Integers    ${current}[status_code]    200
        Transaction Response Should Match    ${current}[body]    Test transaction    1250    expense    food
    END

Transaction Endpoints Return Not Found For Missing IDs
    [Documentation]    Confirms get, update, and delete return 404 for a valid but nonexistent transaction ID.
    [Tags]    negative    not-found
    [Setup]    Set Up Transaction Test User    administrator
    ${before}=    Request API    GET    ${TRANSACTIONS_PATH}
    Should Be Equal As Integers    ${before}[status_code]    200
    ${before_ids}=    Evaluate    [item["id"] for item in $before["body"]]
    ${missing_id}=    Evaluate    int($TEST_USERNAME[-8:], 16) + 1000000000
    ${get_response}=    Request API    GET    ${TRANSACTIONS_PATH}/${missing_id}
    Error Response Should Match    ${get_response}    404    Transaction not found
    ${body}=    Create Dictionary
    ...    description=Missing transaction update
    ...    amount=${2500}
    ...    type=expense
    ...    category=food
    ${update_response}=    Request API    PUT    ${TRANSACTIONS_PATH}/${missing_id}    ${body}
    Error Response Should Match    ${update_response}    404    Transaction not found
    ${delete_response}=    Request API    DELETE    ${TRANSACTIONS_PATH}/${missing_id}
    Error Response Should Match    ${delete_response}    404    Transaction not found
    ${after}=    Request API    GET    ${TRANSACTIONS_PATH}
    Should Be Equal As Integers    ${after}[status_code]    200
    ${after_ids}=    Evaluate    [item["id"] for item in $after["body"]]
    Should Be Equal    ${after_ids}    ${before_ids}

Transaction Endpoints Reject Noninteger IDs
    [Documentation]    Confirms get, update, and delete reject malformed IDs instead of treating them as SQL input.
    [Tags]    negative    validation    security
    [Setup]    Set Up Transaction Test User    administrator
    ${body}=    Create Dictionary
    ...    description=Invalid transaction ID
    ...    amount=${2500}
    ...    type=expense
    ...    category=food
    ${get_response}=    Request API    GET    ${TRANSACTIONS_PATH}/not-an-id
    Validation Error Response Should Be Well Formed    ${get_response}
    ${update_response}=    Request API    PUT    ${TRANSACTIONS_PATH}/not-an-id    ${body}
    Validation Error Response Should Be Well Formed    ${update_response}
    ${delete_response}=    Request API    DELETE    ${TRANSACTIONS_PATH}/not-an-id
    Validation Error Response Should Be Well Formed    ${delete_response}
    ${get_negative_id}=    Request API    GET    ${TRANSACTIONS_PATH}/-1
    Error Response Should Match    ${get_negative_id}    404    Transaction not found
    ${update_negative_id}=    Request API    PUT    ${TRANSACTIONS_PATH}/-1    ${body}
    Error Response Should Match    ${update_negative_id}    404    Transaction not found
    ${delete_negative_id}=    Request API    DELETE    ${TRANSACTIONS_PATH}/-1
    Error Response Should Match    ${delete_negative_id}    404    Transaction not found
    ${get_zero_id}=    Request API    GET    ${TRANSACTIONS_PATH}/0
    Error Response Should Match    ${get_zero_id}    404    Transaction not found
    ${update_zero_id}=    Request API    PUT    ${TRANSACTIONS_PATH}/0    ${body}
    Error Response Should Match    ${update_zero_id}    404    Transaction not found
    ${delete_zero_id}=    Request API    DELETE    ${TRANSACTIONS_PATH}/0
    Error Response Should Match    ${delete_zero_id}    404    Transaction not found

Unsupported Transaction Methods Return Method Not Allowed
    [Documentation]    Confirms unused standard methods return 405 on both collection and item routes without mutation.
    [Tags]    negative    validation    security
    [Setup]    Set Up Transaction Test With Administrator Fixture
    ${before}=    Request API    GET    ${TRANSACTIONS_PATH}
    Should Be Equal As Integers    ${before}[status_code]    200
    ${before_transactions}=    Set Variable    ${before}[body]
    ${body}=    Create Dictionary
    ...    description=Unsupported method
    ...    amount=${2500}
    ...    type=expense
    ...    category=food
    ${unsupported_methods}=    Create List    PATCH    OPTIONS    HEAD    TRACE    CONNECT
    ${routes}=    Create List    ${TRANSACTIONS_PATH}    ${TRANSACTIONS_PATH}/${TRANSACTION_ID}
    FOR    ${route}    IN    @{routes}
        FOR    ${method}    IN    @{unsupported_methods}
            ${response}=    Request API    ${method}    ${route}    ${body}
            Should Be Equal As Integers    ${response}[status_code]    405
            IF    $method == 'HEAD'
                Should Be Equal    ${response}[body]    ${None}
            ELSE
                Error Response Should Match    ${response}    405    Method Not Allowed
            END
        END
    END
    ${after}=    Request API    GET    ${TRANSACTIONS_PATH}
    Should Be Equal As Integers    ${after}[status_code]    200
    Should Be Equal    ${after}[body]    ${before_transactions}

Transaction Can Be Deleted
    [Documentation]    An administrator deletes a transaction and confirms it can no longer be retrieved.
    [Tags]    smoke    happy-path
    [Setup]    Set Up Transaction Test User    administrator
    Create Transaction For Test
    ${delete_response}=    Request API    DELETE    ${TRANSACTIONS_PATH}/${TRANSACTION_ID}
    Should Be Equal As Integers    ${delete_response}[status_code]    204
    Should Be Equal    ${delete_response}[body]    ${None}
    ${get_response}=    Request API    GET    ${TRANSACTIONS_PATH}/${TRANSACTION_ID}
    Error Response Should Match    ${get_response}    404    Transaction not found
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
    Error Response Should Match    ${update_response}    403    Administrator role required
    ${delete_response}=    Request API    DELETE    ${TRANSACTIONS_PATH}/${TRANSACTION_ID}
    Error Response Should Match    ${delete_response}    403    Administrator role required
    ${still_exists}=    Request API    GET    ${TRANSACTIONS_PATH}/${TRANSACTION_ID}
    Should Be Equal As Integers    ${still_exists}[status_code]    200
    Transaction Response Should Match    ${still_exists}[body]    Test transaction    1250    expense    food

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
    Error Response Should Match    ${get_response}    404    Transaction not found
    ${body}=    Create Dictionary
    ...    description=Cross-user update
    ...    amount=${2500}
    ...    type=expense
    ...    category=food
    ${update_response}=    Request API    PUT    ${TRANSACTIONS_PATH}/${customer_transaction_id}    ${body}
    Error Response Should Match    ${update_response}    403    Administrator role required
    ${delete_response}=    Request API    DELETE    ${TRANSACTIONS_PATH}/${customer_transaction_id}
    Error Response Should Match    ${delete_response}    403    Administrator role required

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

*** Keywords ***
Error Response Should Match
    [Arguments]    ${response}    ${status_code}    ${detail}
    Should Be Equal As Integers    ${response}[status_code]    ${status_code}
    ${expected_body}=    Create Dictionary    detail=${detail}
    Should Be Equal    ${response}[body]    ${expected_body}

Validation Error Response Should Be Well Formed
    [Arguments]    ${response}
    Should Be Equal As Integers    ${response}[status_code]    422
    Should Be True    isinstance($response["body"], dict)
    ${top_level_keys}=    Get Dictionary Keys    ${response}[body]
    Should Be Equal    ${top_level_keys}    ${{["detail"]}}
    Should Be True    isinstance($response["body"]["detail"], list)
    Should Not Be Empty    ${response}[body][detail]
    FOR    ${error}    IN    @{response}[body][detail]
        Should Be True    isinstance($error, dict)
        ${error_keys}=    Get Dictionary Keys    ${error}
        Should Contain    ${error_keys}    loc
        Should Contain    ${error_keys}    msg
        Should Contain    ${error_keys}    type
        Should Be True    isinstance($error["loc"], list)
        Should Not Be Empty    ${error}[loc]
        Should Not Be Empty    ${error}[msg]
        Should Not Be Empty    ${error}[type]
        Should Not Contain    ${error_keys}    traceback
        Should Not Contain    ${error_keys}    stack
    END

Set Up Transaction Test With Administrator Fixture
    Set Up Transaction Test User    administrator
    Create Transaction For Test

Invalid Transaction Payloads
    [Documentation]    Returns malformed field values, missing fields, and mass-assignment attempts.
    ${long_description}=    Evaluate    'x' * 101
    ${description_object}=    Create Dictionary    nested=value
    ${amount_array}=    Create List    ${1250}
    ${amount_object}=    Create Dictionary    value=${1250}
    ${type_array}=    Create List    expense
    ${type_object}=    Create Dictionary    value=expense
    ${category_array}=    Create List    food
    ${category_object}=    Create Dictionary    value=food
    ${description_values}=    Create List
    ...    ${None}    ${42}    ${True}    ${amount_array}    ${description_object}
    ...    ${EMPTY}    ${SPACE}    ${long_description}
    ${amount_values}=    Create List
    ...    ${None}    1250    ${12.34}    ${0}    ${-1}    ${10000001}
    ...    ${True}    ${amount_array}    ${amount_object}
    ${type_values}=    Create List
    ...    ${None}    ${1}    ${True}    ${type_array}    ${type_object}    transfer
    ${category_values}=    Create List
    ...    ${None}    ${1}    ${True}    ${category_array}    ${category_object}
    ...    utilities    salary
    ${invalid_values}=    Create Dictionary
    ...    description=${description_values}
    ...    amount=${amount_values}
    ...    type=${type_values}
    ...    category=${category_values}
    ${baseline}=    Create Dictionary
    ...    description=Valid transaction
    ...    amount=${1250}
    ...    type=expense
    ...    category=food
    ${invalid_payloads}=    Create List
    FOR    ${field}    ${values}    IN    &{invalid_values}
        FOR    ${value}    IN    @{values}
            ${payload}=    Copy Dictionary    ${baseline}
            Set To Dictionary    ${payload}    ${field}    ${value}
            Append To List    ${invalid_payloads}    ${payload}
        END
        ${missing_payload}=    Copy Dictionary    ${baseline}
        Remove From Dictionary    ${missing_payload}    ${field}
        Append To List    ${invalid_payloads}    ${missing_payload}
    END
    ${incompatible_category}=    Copy Dictionary    ${baseline}
    Set To Dictionary    ${incompatible_category}    type    income
    Append To List    ${invalid_payloads}    ${incompatible_category}
    ${mass_assignment_fields}=    Create Dictionary
    ...    id=${999}
    ...    user_id=${999}
    ...    created_at=2000-01-01T00:00:00Z
    ...    role=administrator
    ...    owner=another-user
    FOR    ${field}    ${value}    IN    &{mass_assignment_fields}
        ${mass_assignment_payload}=    Copy Dictionary    ${baseline}
        Set To Dictionary    ${mass_assignment_payload}    ${field}    ${value}
        Append To List    ${invalid_payloads}    ${mass_assignment_payload}
    END
    ${top_level_array}=    Create List    invalid
    ${top_level_scalar}=    Set Variable    invalid
    ${top_level_number}=    Set Variable    ${42}
    ${top_level_boolean}=    Set Variable    ${True}
    ${top_level_null}=    Set Variable    ${None}
    Append To List    ${invalid_payloads}    ${top_level_array}
    Append To List    ${invalid_payloads}    ${top_level_scalar}
    Append To List    ${invalid_payloads}    ${top_level_number}
    Append To List    ${invalid_payloads}    ${top_level_boolean}
    Append To List    ${invalid_payloads}    ${top_level_null}
    RETURN    ${invalid_payloads}
