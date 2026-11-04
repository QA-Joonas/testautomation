*** Settings ***
Documentation     Happy-path authentication and current-user profile tests.
Resource         ../../resources/api.resource
Library          Collections
Suite Setup      Set API Base URL    ${BASE_URL}
Test Setup       Create And Authenticate Test User    user
Test Teardown    Delete Test User

*** Test Cases ***
Customer Can Read Their Authenticated Profile
    [Documentation]    Logs in a privately provisioned user and verifies the protected profile response.
    [Tags]    smoke    happy-path    authentication
    ${response}=    Request API    GET    /api/v1/users/me
    Should Be Equal As Integers    ${response}[status_code]    200
    Should Be Equal    ${response}[body][username]    ${TEST_USERNAME}
    Should Be Equal    ${response}[body][role]    user
    ${profile_fields}=    Get Dictionary Keys    ${response}[body]
    Should Not Contain    ${profile_fields}    password
    Should Not Contain    ${profile_fields}    password_hash

Administrator Can Read Their Authenticated Profile
    [Documentation]    Logs in a privately provisioned administrator and verifies the protected profile response.
    [Tags]    happy-path    authentication
    [Setup]    Create And Authenticate Test User    administrator
    ${response}=    Request API    GET    /api/v1/users/me
    Should Be Equal As Integers    ${response}[status_code]    200
    Should Be Equal    ${response}[body][username]    ${TEST_USERNAME}
    Should Be Equal    ${response}[body][role]    administrator
    ${profile_fields}=    Get Dictionary Keys    ${response}[body]
    Should Not Contain    ${profile_fields}    password
    Should Not Contain    ${profile_fields}    password_hash
