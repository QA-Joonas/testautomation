*** Settings ***
Documentation     Authentication and current-user profile security tests.
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

Login Rejects Invalid Credentials Without Revealing Whether User Exists
    [Documentation]    Wrong passwords and unknown usernames receive the same generic unauthorized response.
    [Tags]    authentication    negative    security
    ApiKeywords.Clear API Access Token
    ${wrong_password}=    Create Dictionary
    ...    username=${TEST_USERNAME}
    ...    password=incorrect-password
    ${wrong_password_response}=    Request API    POST    /api/v1/auth/login    ${wrong_password}
    Should Be Equal As Integers    ${wrong_password_response}[status_code]    401
    ${unknown_user}=    Create Dictionary
    ...    username=missing_${TEST_USERNAME}
    ...    password=incorrect-password
    ${unknown_user_response}=    Request API    POST    /api/v1/auth/login    ${unknown_user}
    Should Be Equal As Integers    ${unknown_user_response}[status_code]    401
    Should Be Equal    ${unknown_user_response}[body][detail]    ${wrong_password_response}[body][detail]

Login Rejects A Username Longer Than The Maximum
    [Documentation]    Usernames longer than the 50-character limit are rejected before authentication.
    [Tags]    authentication    negative    validation
    ApiKeywords.Clear API Access Token
    ${long_username}=    Evaluate    'u' * 51
    ${credentials}=    Create Dictionary
    ...    username=${long_username}
    ...    password=not-a-valid-password
    ${response}=    Request API    POST    /api/v1/auth/login    ${credentials}
    Should Be Equal As Integers    ${response}[status_code]    422

Login Rejects A Password Longer Than The Maximum
    [Documentation]    Passwords longer than the 128-character limit are rejected before password verification.
    [Tags]    authentication    negative    validation
    ApiKeywords.Clear API Access Token
    ${long_password}=    Evaluate    'p' * 129
    ${credentials}=    Create Dictionary
    ...    username=${TEST_USERNAME}
    ...    password=${long_password}
    ${response}=    Request API    POST    /api/v1/auth/login    ${credentials}
    Should Be Equal As Integers    ${response}[status_code]    422

Current User Profile Requires Authentication
    [Documentation]    Requests without a bearer token are rejected.
    [Tags]    authentication    negative    security
    ApiKeywords.Clear API Access Token
    ${response}=    Request API    GET    /api/v1/users/me
    Should Be Equal As Integers    ${response}[status_code]    401

Current User Profile Rejects A Malformed Token
    [Documentation]    Requests with a malformed bearer token are rejected.
    [Tags]    authentication    negative    security
    ApiKeywords.Set API Access Token    not-a-jwt
    ${response}=    Request API    GET    /api/v1/users/me
    Should Be Equal As Integers    ${response}[status_code]    401

Current User Profile Rejects An Invalid JWT
    [Documentation]    Requests with a JWT using an unsupported algorithm are rejected.
    [Tags]    authentication    negative    security
    ApiKeywords.Set API Access Token    eyJhbGciOiJub25lIn0.eyJzdWIiOiIxIn0.
    ${response}=    Request API    GET    /api/v1/users/me
    Should Be Equal As Integers    ${response}[status_code]    401
