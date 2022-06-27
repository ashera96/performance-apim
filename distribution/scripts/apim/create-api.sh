#!/bin/bash -e
# Copyright 2017 WSO2 Inc. (http://wso2.org)
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#
# ----------------------------------------------------------------------------
# Create APIs in WSO2 API Manager
# ----------------------------------------------------------------------------

script_dir=$(dirname "$0")
apim_host=""
api_name=""
api_description=""
backend_endpoint_url=""
default_backend_endpoint_type="http"
backend_endpoint_type="$default_backend_endpoint_type"
token_type="JWT"

function usage() {
    echo ""
    echo "Usage: "
    echo "$0 -a <apim_host> -n <api_name> -d <api_description> -b <backend_endpoint_url>"
    echo "   [-t <backend_endpoint_type>] [-h]"
    echo ""
    echo "-a: Hostname of WSO2 API Manager."
    echo "-n: API Name."
    echo "-d: API Description."
    echo "-b: Backend endpoint URL."
    echo "-t: Backend endpoint type. Default: $default_backend_endpoint_type."
    echo "-k: Token type."
    echo "-h: Display this help and exit."
    echo ""
}

while getopts "a:n:d:b:t:k:h" opt; do
    case "${opt}" in
    a)
        apim_host=${OPTARG}
        ;;
    n)
        api_name=${OPTARG}
        ;;
    d)
        api_description=${OPTARG}
        ;;
    b)
        backend_endpoint_url=${OPTARG}
        ;;
    t)
        backend_endpoint_type=${OPTARG}
        ;;
    k)
        token_type=${OPTARG}
        ;;
    h)
        usage
        exit 0
        ;;
    \?)
        usage
        exit 1
        ;;
    *)
        opts+=("-${opt}")
        [[ -n "$OPTARG" ]] && opts+=("$OPTARG")
        ;;
    esac
done
shift "$((OPTIND - 1))"

if [[ -z $apim_host ]]; then
    echo "Please provide the Hostname of WSO2 API Manager."
    exit 1
fi

if [[ -z $api_name ]]; then
    echo "Please provide the API Name."
    exit 1
fi

if [[ -z $api_description ]]; then
    echo "Please provide the API description."
    exit 1
fi

if [[ -z $backend_endpoint_url ]]; then
    echo "Please provide the backend endpoint URL."
    exit 1
fi

if [[ -z $backend_endpoint_type ]]; then
    echo "Please provide the backend endpoint type."
    exit 1
fi

base_https_url="https://${apim_host}:9443"
nio_https_url="https://${apim_host}:8243"

curl_command="curl -sk"

#Check whether jq command exsits
if ! command -v jq >/dev/null 2>&1; then
    echo "Please install jq."
    exit 1
fi

confirm() {
    # call with a prompt string or use a default
    read -r -p "${1:-Are you sure?} [y/N] " response
    case $response in
    [yY][eE][sS] | [yY])
        true
        ;;
    *)
        false
        ;;
    esac
}

# Register Client and Get Access Token
client_request() {
    cat <<EOF
{
    "callbackUrl": "wso2.org",
    "clientName": "setup_apim_script",
    "tokenScope": "Production",
    "owner": "admin",
    "grantType": "password refresh_token",
    "saasApp": true
}
EOF
}

# Create application request payload
app_request() {
    cat <<EOF
{ 
   "name":"PerformanceTestAPP",
   "throttlingPolicy":"Unlimited",
   "description":"PerformanceTestAPP",
   "tokenType":"$token_type",
   "attributes":{ 
   }
}
EOF
}

client_credentials=$($curl_command -u admin:admin -H "Content-Type: application/json" -d "$(client_request)" ${base_https_url}/client-registration/v0.17/register | jq -r '.clientId + ":" + .clientSecret')

get_access_token() {
    local access_token=$($curl_command -d "grant_type=password&username=admin&password=admin&scope=apim:$1" -u $client_credentials ${base_https_url}/oauth2/token | jq -r '.access_token')
    echo $access_token
}

get_admin_access_token() {
    local access_token=$($curl_command -d "grant_type=password&username=admin&password=admin&scope=apim:admin+apim:api_create+apim:api_delete+apim:api_generate_key+apim:api_import_export+apim:api_product_import_export+apim:api_publish+apim:api_view+apim:app_import_export+apim:client_certificates_add+apim:client_certificates_update+apim:client_certificates_view+apim:comment_view+apim:comment_write+apim:document_create+apim:document_manage+apim:ep_certificates_add+apim:ep_certificates_update+apim:ep_certificates_view+apim:mediation_policy_create+apim:mediation_policy_manage+apim:mediation_policy_view+apim:common_operation_policy_manage+apim:pub_alert_manage+apim:publisher_settings+apim:shared_scope_manage+apim:subscription_block+apim:subscription_view+apim:threat_protection_policy_create+apim:threat_protection_policy_manage+openid+service_catalog:service_view+service_catalog:service_write" -u $client_credentials ${base_https_url}/oauth2/token | jq -r '.access_token')
    echo $access_token
}

view_access_token=$(get_access_token api_view)
create_access_token=$(get_access_token api_create)
publish_access_token=$(get_access_token api_publish)
subscribe_access_token=$(get_access_token subscribe)
app_access_token=$(get_access_token app_manage)
mediation_policy_create_token=$(get_access_token mediation_policy_create) 
sub_manage_token=$(get_access_token sub_manage) 
admin_token=$(get_admin_access_token)

# Find "PerformanceTestAPP" ID
echo "Getting PerformanceTestAPP ID"
application_id=$($curl_command -H "Authorization: Bearer $subscribe_access_token" "${base_https_url}/api/am/devportal/v2/applications?query=PerformanceTestAPP" | jq -r '.list[0] | .applicationId')

if [ ! -z $application_id ] && [ ! $application_id = "null" ]; then
    echo "Found application id for \"PerformanceTestAPP\": $application_id"
else
    echo "Creating \"PerformanceTestAPP\" application"
    application_id=$($curl_command -X POST -H "Authorization: Bearer $app_access_token" -H "Content-Type: application/json" -d "$(app_request)" "${base_https_url}/api/am/devportal/applications" | jq -r '.applicationId')
    if [ ! -z $application_id ] && [ ! $application_id = "null" ]; then
        echo "Found application id for \"PerformanceTestAPP\": $application_id"
    else
        echo "Failed to find application id for \"PerformanceTestAPP\""
        exit 1
    fi
fi

echo -ne "\n"

generate_keys_request() {
    cat <<EOF
{ 
   "keyType":"PRODUCTION",
   "grantTypesToBeSupported":[ 
      "refresh_token",
      "password",
      "client_credentials",
      "urn:ietf:params:oauth:grant-type:jwt-bearer"
   ],
   "callbackUrl":"wso2.org"
}
EOF
}

echo "Finding Consumer Key for PerformanceTestAPP"

# Check if keys exists
keys_response=$($curl_command -H "Authorization: Bearer $subscribe_access_token" "${base_https_url}/api/am/devportal/v2/applications/$application_id/keys/PRODUCTION")
consumer_key=$(echo $keys_response | jq -r '.consumerKey')
if [ ! -z $consumer_key ] && [ ! $consumer_key = "null" ]; then
    echo "Keys already generated for \"PerformanceTestAPP\". Consumer key is $consumer_key"
else
    echo "Keys not generated for \"PerformanceTestAPP\". Generating keys"
    # temp fix
    get_keymanager=$($curl_command -H "Authorization: Bearer $app_access_token" "${base_https_url}/api/am/devportal/v2/key-managers")

    # Generate Keys
    keys_response=$($curl_command -H "Authorization: Bearer $app_access_token" -H "Content-Type: application/json" -d "$(generate_keys_request)" "${base_https_url}/api/am/devportal/v2/applications/$application_id/generate-keys")
    consumer_key=$(echo $keys_response | jq -r '.consumerKey')
    if [ ! -z $consumer_key ] && [ ! $consumer_key = "null" ]; then
        echo "Keys generated for \"PerformanceTestAPP\". Consumer key is $consumer_key"
    else
        echo "Failed to generate keys for \"PerformanceTestAPP\""
        # Get Key from application
        keys_response=$($curl_command -H "Authorization: Bearer $subscribe_access_token" "${base_https_url}/api/am/devportal/v2/applications/$application_id")
        consumer_key=$(echo $keys_response | jq -r '.keys[0] | .consumerKey')
        if [ ! -z $consumer_key ] && [ ! $consumer_key = "null" ]; then
            echo "Retrieved keys for \"PerformanceTestAPP\". Consumer key is $consumer_key"
        else
            echo "Failed to retrieve keys for \"PerformanceTestAPP\""
            exit 1
        fi
    fi
fi

#Write consumer key to file
mkdir -p "$script_dir/target"
echo $consumer_key >"$script_dir/target/consumer_key"
#Write application id to file
echo $application_id >"$script_dir/target/application_id"
echo -ne "\n"

# Create GraphQL API
api_create_request() {
    cat <<EOF
{
    "name": "$1API",
    "description": "$2",
    "context": "/$1",
    "version": "1.0.0",
    "provider": "admin",
    "lifeCycleStatus": "CREATED",
    "wsdlInfo": null,
    "wsdlUrl": null,
    "responseCachingEnabled": false,
    "cacheTimeout": 300,
    "hasThumbnail": false,
    "isDefaultVersion": false,
    "isRevision": false,
    "revisionedApiId": null,
    "revisionId": 0,
    "enableSchemaValidation": false,
    "type": "GRAPHQL",
    "transport": [
        "http",
        "https"
    ],
    "tags": [],
    "policies": [
        "Unlimited"
    ],
    "apiThrottlingPolicy": null,
    "authorizationHeader": "Authorization",
    "securityScheme": [
        "oauth2",
        "oauth_basic_auth_api_key_mandatory"
    ],
    "maxTps": null,
    "visibility": "PUBLIC",
    "visibleRoles": [
        ""
    ],
    "visibleTenants": [],
    "mediationPolicies": [],
    "subscriptionAvailability": "CURRENT_TENANT",
    "subscriptionAvailableTenants": [
        ""
    ],
    "additionalProperties": [],
    "monetization": null,
    "accessControl": "NONE",
    "accessControlRoles": [],
    "businessInformation": {
        "businessOwner": null,
        "businessOwnerEmail": null,
        "technicalOwner": null,
        "technicalOwnerEmail": null
    },
    "corsConfiguration": {
        "corsConfigurationEnabled": false,
        "accessControlAllowOrigins": [
            "*"
        ],
        "accessControlAllowCredentials": false,
        "accessControlAllowHeaders": [
            "authorization",
            "Access-Control-Allow-Origin",
            "Content-Type",
            "SOAPAction",
            "apikey",
            "Internal-Key"
        ],
        "accessControlAllowMethods": [
            "GET",
            "PUT",
            "POST",
            "DELETE",
            "PATCH",
            "OPTIONS"
        ]
    },
    "websubSubscriptionConfiguration": {
        "enable": false,
        "secret": "",
        "signingAlgorithm": "SHA1",
        "signatureHeader": "x-hub-signature"
    },
    "workflowStatus": null,
    "createdTime": "2022-06-26 20:49:14.814",
    "lastUpdatedTime": null,
    "endpointConfig": {
        "endpoint_type": "${backend_endpoint_type}",
        "sandbox_endpoints": {
            "url": "${backend_endpoint_url}"
        },
        "production_endpoints": {
            "url": "${backend_endpoint_url}"
        }
    },
    "endpointImplementationType": "ENDPOINT",
    "scopes": [],
    "operations": [
        {
            "id": "",
            "target": "hero",
            "verb": "QUERY",
            "authType": "Application & Application User",
            "throttlingPolicy": null,
            "scopes": [],
            "usedProductIds": [],
            "amznResourceName": null,
            "amznResourceTimeout": null,
            "payloadSchema": null,
            "uriMapping": null
        },
        {
            "id": "",
            "target": "reviews",
            "verb": "QUERY",
            "authType": "Application & Application User",
            "throttlingPolicy": null,
            "scopes": [],
            "usedProductIds": [],
            "amznResourceName": null,
            "amznResourceTimeout": null,
            "payloadSchema": null,
            "uriMapping": null
        },
        {
            "id": "",
            "target": "search",
            "verb": "QUERY",
            "authType": "Application & Application User",
            "throttlingPolicy": null,
            "scopes": [],
            "usedProductIds": [],
            "amznResourceName": null,
            "amznResourceTimeout": null,
            "payloadSchema": null,
            "uriMapping": null
        },
        {
            "id": "",
            "target": "character",
            "verb": "QUERY",
            "authType": "Application & Application User",
            "throttlingPolicy": null,
            "scopes": [],
            "usedProductIds": [],
            "amznResourceName": null,
            "amznResourceTimeout": null,
            "payloadSchema": null,
            "uriMapping": null
        },
        {
            "id": "",
            "target": "droid",
            "verb": "QUERY",
            "authType": "Application & Application User",
            "throttlingPolicy": null,
            "scopes": [],
            "usedProductIds": [],
            "amznResourceName": null,
            "amznResourceTimeout": null,
            "payloadSchema": null,
            "uriMapping": null
        },
        {
            "id": "",
            "target": "human",
            "verb": "QUERY",
            "authType": "Application & Application User",
            "throttlingPolicy": null,
            "scopes": [],
            "usedProductIds": [],
            "amznResourceName": null,
            "amznResourceTimeout": null,
            "payloadSchema": null,
            "uriMapping": null
        },
        {
            "id": "",
            "target": "allHumans",
            "verb": "QUERY",
            "authType": "Application & Application User",
            "throttlingPolicy": null,
            "scopes": [],
            "usedProductIds": [],
            "amznResourceName": null,
            "amznResourceTimeout": null,
            "payloadSchema": null,
            "uriMapping": null
        },
        {
            "id": "",
            "target": "allDroids",
            "verb": "QUERY",
            "authType": "Application & Application User",
            "throttlingPolicy": null,
            "scopes": [],
            "usedProductIds": [],
            "amznResourceName": null,
            "amznResourceTimeout": null,
            "payloadSchema": null,
            "uriMapping": null
        },
        {
            "id": "",
            "target": "allCharacters",
            "verb": "QUERY",
            "authType": "Application & Application User",
            "throttlingPolicy": null,
            "scopes": [],
            "usedProductIds": [],
            "amznResourceName": null,
            "amznResourceTimeout": null,
            "payloadSchema": null,
            "uriMapping": null
        },
        {
            "id": "",
            "target": "starship",
            "verb": "QUERY",
            "authType": "Application & Application User",
            "throttlingPolicy": null,
            "scopes": [],
            "usedProductIds": [],
            "amznResourceName": null,
            "amznResourceTimeout": null,
            "payloadSchema": null,
            "uriMapping": null
        },
        {
            "id": "",
            "target": "createReview",
            "verb": "MUTATION",
            "authType": "Application & Application User",
            "throttlingPolicy": null,
            "scopes": [],
            "usedProductIds": [],
            "amznResourceName": null,
            "amznResourceTimeout": null,
            "payloadSchema": null,
            "uriMapping": null
        },
        {
            "id": "",
            "target": "reviewAdded",
            "verb": "SUBSCRIPTION",
            "authType": "Application & Application User",
            "throttlingPolicy": null,
            "scopes": [],
            "usedProductIds": [],
            "amznResourceName": null,
            "amznResourceTimeout": null,
            "payloadSchema": null,
            "uriMapping": null
        }
    ],
    "threatProtectionPolicies": null,
    "categories": [],
    "keyManagers": [
        "all"
    ],
    "serviceInfo": null,
    "advertiseInfo": {
        "advertised": false,
        "originalDevPortalUrl": null,
        "apiOwner": "admin",
        "vendor": "WSO2"
    }
}
EOF
}

subscription_request() {
    cat <<EOF
{ 
   "apiId":"$1",
   "applicationId":"$application_id",
   "throttlingPolicy":"Unlimited"
}
EOF
}

create_api() {
    local api_name="$1"
    local api_desc="$2"
    echo "Creating $api_name API..."
    # Check whether API exists
    local existing_api_id=$($curl_command -H "Authorization: Bearer $view_access_token" ${base_https_url}/api/am/publisher/v2/apis?query=name:$api_name\$ | jq -r '.list[0] | .id')
    if [ ! -z $existing_api_id ] && [ ! $existing_api_id = "null" ]; then
        echo "$api_name API already exists with ID $existing_api_id"
        echo -ne "\n"
        if (confirm "Delete $api_name API?"); then
            # Check subscriptions first
            local subscription_id=$($curl_command -H "Authorization: Bearer $subscribe_access_token" "${base_https_url}/api/am/devportal/v2/subscriptions?apiId=$existing_api_id" | jq -r '.list[0] | .subscriptionId')
            if [ ! -z $subscription_id ] && [ ! $subscription_id = "null" ]; then
                echo "Subscription found for $api_name API. Subscription ID is $subscription_id"
                # Delete subscription
                local delete_subscription_status=$($curl_command -w "%{http_code}" -o /dev/null -H "Authorization: Bearer $subscribe_access_token" -X DELETE "${base_https_url}/api/am/devportal/v2/subscriptions/$subscription_id")
                if [ $delete_subscription_status -eq 200 ]; then
                    echo "Subscription $subscription_id deleted!"
                    echo -ne "\n"
                else
                    echo "Failed to delete subscription $subscription_id"
                    echo -ne "\n"
                    return
                fi
            else
                echo "No suscriptions found for $api_name API"
                echo -ne "\n"
            fi

            local delete_api_status=$($curl_command -w "%{http_code}" -o /dev/null -H "Authorization: Bearer $create_access_token" -X DELETE "${base_https_url}/api/am/publisher/v2/apis/$existing_api_id")
            if [ $delete_api_status -eq 200 ]; then
                echo "$api_name API deleted!"
                echo -ne "\n"
            else
                echo "Failed to delete $api_name API"
                echo -ne "\n"
                return
            fi
        else
            return
        fi
    fi
    local api_id=$($curl_command -H "Authorization: Bearer $create_access_token" -F file=@$script_dir/schema/starwars-schema.graphql -F additionalProperties="$(api_create_request $api_name $api_desc)" ${base_https_url}/api/am/publisher/v2/apis/import-graphql-schema | jq -r '.id')
    if [ ! -z $api_id ] && [ ! $api_id = "null" ]; then
        echo "Created $api_name API with ID $api_id"
        echo -ne "\n"
    else
        echo "Failed to create $api_name API"
        echo -ne "\n"
        return
    fi

    local rev_id=$($curl_command -H "Authorization: Bearer $create_access_token" -H "Content-Type: application/json" -X POST -d '{"description": "first revision"}' ${base_https_url}/api/am/publisher/v2/apis/${api_id}/revisions | jq -r '.id')
    local revisionUuid=$($curl_command -H "Authorization: Bearer $create_access_token" -H "Content-Type: application/json" -X POST -d '[{"name": "Default", "vhost": "localhost" ,"displayOnDevportal": true}]' ${base_https_url}/api/am/publisher/v2/apis/${api_id}/deploy-revision?revisionId=${rev_id} | jq -r '.[0] | .revisionUuid')

    echo "Publishing $api_name API"
    local publish_api_status=$($curl_command -w "%{http_code}" -o /dev/null -H "Authorization: Bearer $publish_access_token" -X POST "${base_https_url}/api/am/publisher/v2/apis/change-lifecycle?action=Publish&apiId=${api_id}")
    if [ $publish_api_status -eq 200 ]; then
        echo "$api_name API Published!"
        echo -ne "\n"
    else
        echo "Failed to publish $api_name API"
        echo -ne "\n"
        return
    fi
    echo "Subscribing $api_name API to PerformanceTestAPP"
    local subscription_id=$($curl_command -H "Authorization: Bearer $sub_manage_token" -H "Content-Type: application/json" -d "$(subscription_request $api_id)" "${base_https_url}/api/am/devportal/v2/subscriptions" | jq -r '.subscriptionId')
    if [ ! -z $subscription_id ] && [ ! $subscription_id = "null" ]; then
        echo "Successfully subscribed $api_name API to PerformanceTestAPP. Subscription ID is $subscription_id"
        echo -ne "\n"
    else
        echo "Failed to subscribe $api_name API to PerformanceTestAPP"
        echo -ne "\n"
        return
    fi
}

create_api "$api_name" "$api_description"
