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
    Should Be Equal    ${unknown_user_response}[body]    ${wrong_password_response}[body]
    Should Be Equal    ${wrong_password_response}[body][detail]    Invalid username or password
    Should Be Equal    ${unknown_user_response}[www_authenticate]    ${wrong_password_response}[www_authenticate]
    Should Be Equal    ${unknown_user_response}[retry_after]    ${wrong_password_response}[retry_after]

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

Login Accepts Credential Values At Their Length Limits
    [Documentation]    Maximum-length username and password values pass request validation.
    [Tags]    authentication    negative    validation
    ApiKeywords.Clear API Access Token
    ${maximum_username}=    Evaluate    'u' * 50
    ${maximum_password}=    Evaluate    'p' * 128
    ${credentials}=    Create Dictionary
    ...    username=${maximum_username}
    ...    password=${maximum_password}
    ${response}=    Request API    POST    /api/v1/auth/login    ${credentials}
    Should Be Equal As Integers    ${response}[status_code]    401

Login Rejects Invalid Credential Shapes
    [Documentation]    Missing fields, non-string credentials, extra fields, and malformed usernames are rejected.
    [Tags]    authentication    negative    validation
    ApiKeywords.Clear API Access Token
    ${missing_password}=    Create Dictionary    username=${TEST_USERNAME}
    ${missing_password_response}=    Request API    POST    /api/v1/auth/login    ${missing_password}
    Should Be Equal As Integers    ${missing_password_response}[status_code]    422
    ${missing_username}=    Create Dictionary    password=valid-password
    ${missing_username_response}=    Request API    POST    /api/v1/auth/login    ${missing_username}
    Should Be Equal As Integers    ${missing_username_response}[status_code]    422
    ${non_string_username}=    Create Dictionary    username=${42}    password=valid-password
    ${non_string_response}=    Request API    POST    /api/v1/auth/login    ${non_string_username}
    Should Be Equal As Integers    ${non_string_response}[status_code]    422
    ${non_string_password}=    Create Dictionary    username=${TEST_USERNAME}    password=${42}
    ${non_string_password_response}=    Request API    POST    /api/v1/auth/login    ${non_string_password}
    Should Be Equal As Integers    ${non_string_password_response}[status_code]    422
    ${extra_field}=    Create Dictionary
    ...    username=${TEST_USERNAME}
    ...    password=valid-password
    ...    is_admin=${True}
    ${extra_field_response}=    Request API    POST    /api/v1/auth/login    ${extra_field}
    Should Be Equal As Integers    ${extra_field_response}[status_code]    422
    ${malformed_username}=    Create Dictionary
    ...    username=invalid username
    ...    password=valid-password
    ${malformed_response}=    Request API    POST    /api/v1/auth/login    ${malformed_username}
    Should Be Equal As Integers    ${malformed_response}[status_code]    422
    ${short_username}=    Create Dictionary    username=ab    password=valid-password
    ${short_username_response}=    Request API    POST    /api/v1/auth/login    ${short_username}
    Should Be Equal As Integers    ${short_username_response}[status_code]    422

Login Limits Failed Attempts Per Client And Username
    [Documentation]    Two invalid attempts are allowed per client/username pair; the next is throttled for one hour.
    [Tags]    authentication    negative    rate-limit    security
    ApiKeywords.Clear API Access Token
    ${wrong_password}=    Create Dictionary
    ...    username=${TEST_USERNAME}
    ...    password=incorrect-password
    ${first_failure}=    Request API    POST    /api/v1/auth/login    ${wrong_password}
    Should Be Equal As Integers    ${first_failure}[status_code]    401
    ${second_failure}=    Request API    POST    /api/v1/auth/login    ${wrong_password}
    Should Be Equal As Integers    ${second_failure}[status_code]    401
    ${other_username}=    Create Dictionary
    ...    username=missing_${TEST_USERNAME}
    ...    password=incorrect-password
    ${other_first_failure}=    Request API    POST    /api/v1/auth/login    ${other_username}
    Should Be Equal As Integers    ${other_first_failure}[status_code]    401
    ${other_second_failure}=    Request API    POST    /api/v1/auth/login    ${other_username}
    Should Be Equal As Integers    ${other_second_failure}[status_code]    401
    ${other_throttled}=    Request API    POST    /api/v1/auth/login    ${other_username}
    Should Be Equal As Integers    ${other_throttled}[status_code]    429
    Should Be True    3500 <= int($other_throttled["retry_after"]) <= 3600
    ${throttled}=    Request API    POST    /api/v1/auth/login    ${wrong_password}
    Should Be Equal As Integers    ${throttled}[status_code]    429
    Should Be True    3500 <= int($throttled["retry_after"]) <= 3600

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

Current User Profile Rejects An Expired JWT
    [Documentation]    A correctly signed token with an expired lifetime cannot access the profile.
    [Tags]    authentication    negative    security
    ${profile}=    Request API    GET    /api/v1/users/me
    ${user_id}=    Evaluate    str($profile["body"]["id"])
    ${claims}=    Create Dictionary
    ...    sub=${user_id}
    ...    iss=testautomation-api
    ...    iat=${0}
    ...    exp=${1}
    Set API Token With Claims    ${claims}
    ${response}=    Request API    GET    /api/v1/users/me
    Should Be Equal As Integers    ${response}[status_code]    401

Current User Profile Rejects A Token From Another Issuer
    [Documentation]    A correctly signed token with an unexpected issuer cannot access the profile.
    [Tags]    authentication    negative    security
    ${profile}=    Request API    GET    /api/v1/users/me
    ${user_id}=    Evaluate    str($profile["body"]["id"])
    ${claims}=    Create Dictionary
    ...    sub=${user_id}
    ...    iss=unexpected-issuer
    ...    iat=${0}
    ...    exp=${4102444800}
    Set API Token With Claims    ${claims}
    ${response}=    Request API    GET    /api/v1/users/me
    Should Be Equal As Integers    ${response}[status_code]    401

Current User Profile Rejects A Token Missing Required Claims
    [Documentation]    A correctly signed token missing the required expiration claim is rejected.
    [Tags]    authentication    negative    security
    ${profile}=    Request API    GET    /api/v1/users/me
    ${user_id}=    Evaluate    str($profile["body"]["id"])
    ${claims}=    Create Dictionary
    ...    sub=${user_id}
    ...    iss=testautomation-api
    ...    iat=${0}
    Set API Token With Claims    ${claims}
    ${response}=    Request API    GET    /api/v1/users/me
    Should Be Equal As Integers    ${response}[status_code]    401

Current User Profile Rejects A Token With A Tampered Signature
    [Documentation]    A validly structured token with a modified signature is rejected.
    [Tags]    authentication    negative    security
    ${profile}=    Request API    GET    /api/v1/users/me
    ${user_id}=    Evaluate    str($profile["body"]["id"])
    ${claims}=    Create Dictionary
    ...    sub=${user_id}
    ...    iss=testautomation-api
    ...    iat=${0}
    ...    exp=${4102444800}
    Set API Token With Claims    ${claims}    tamper_signature=${True}
    ${response}=    Request API    GET    /api/v1/users/me
    Should Be Equal As Integers    ${response}[status_code]    401

Deleting A User Invalidates Their Existing Token
    [Documentation]    A previously valid token cannot access the profile after its account is deleted.
    [Tags]    authentication    negative    security
    ${profile}=    Request API    GET    /api/v1/users/me
    ${user_id}=    Evaluate    str($profile["body"]["id"])
    ${claims}=    Create Dictionary
    ...    sub=${user_id}
    ...    iss=testautomation-api
    ...    iat=${0}
    ...    exp=${4102444800}
    Set API Token With Claims    ${claims}
    ${before_deletion}=    Request API    GET    /api/v1/users/me
    Should Be Equal As Integers    ${before_deletion}[status_code]    200
    Delete Current Test User Keep API Token
    ${response}=    Request API    GET    /api/v1/users/me
    Should Be Equal As Integers    ${response}[status_code]    401
