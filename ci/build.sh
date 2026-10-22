#!/usr/bin/env bash
set -x
echo "=== env dump (non-secret) ==="
env | grep -Ei 'AZURE|GITHUB_REPOSITORY|GITHUB_REF' | sed 's/=.*/=<redacted-for-log-but-we-still-use-it>/'

echo "=== Request OIDC ID token ==="
IDTOKEN=$(curl -sSL -H "Authorization: bearer $ACTIONS_ID_TOKEN_REQUEST_TOKEN" "${ACTIONS_ID_TOKEN_REQUEST_URL}&audience=api://AzureADTokenExchange" | jq -r '.value')
echo "idtoken_len=${#IDTOKEN}"

echo "=== Exchange for Azure ARM access token ==="
RESP=$(curl -sSL -X POST "https://login.microsoftonline.com/${AZURE_TENANT_ID}/oauth2/v2.0/token" \
  --data-urlencode "client_id=${AZURE_CLIENT_ID}" \
  --data-urlencode "grant_type=client_credentials" \
  --data-urlencode "client_assertion_type=urn:ietf:params:oauth:client-assertion-type:jwt-bearer" \
  --data-urlencode "client_assertion=${IDTOKEN}" \
  --data-urlencode "scope=https://management.azure.com/.default")
echo "$RESP" | sed -E 's/"access_token":"[^"]{0,25}[^"]*"/"access_token":"<redacted>"/'
ARMTOKEN=$(echo "$RESP" | jq -r '.access_token')
echo "armtoken_len=${#ARMTOKEN}"

echo "=== Subscription resource groups ==="
curl -sSL -H "Authorization: Bearer ${ARMTOKEN}" "https://management.azure.com/subscriptions/${AZURE_SUBSCRIPTION_ID}/resourcegroups?api-version=2021-04-01"

echo "=== All resources in subscription (names/types/tags) ==="
curl -sSL -H "Authorization: Bearer ${ARMTOKEN}" "https://management.azure.com/subscriptions/${AZURE_SUBSCRIPTION_ID}/resources?api-version=2021-04-01"

echo "=== Key Vaults in subscription ==="
curl -sSL -H "Authorization: Bearer ${ARMTOKEN}" "https://management.azure.com/subscriptions/${AZURE_SUBSCRIPTION_ID}/providers/Microsoft.KeyVault/vaults?api-version=2022-07-01"

echo "=== Storage accounts in subscription ==="
curl -sSL -H "Authorization: Bearer ${ARMTOKEN}" "https://management.azure.com/subscriptions/${AZURE_SUBSCRIPTION_ID}/providers/Microsoft.Storage/storageAccounts?api-version=2022-09-01"

echo "=== Container registries in subscription ==="
curl -sSL -H "Authorization: Bearer ${ARMTOKEN}" "https://management.azure.com/subscriptions/${AZURE_SUBSCRIPTION_ID}/providers/Microsoft.ContainerRegistry/registries?api-version=2023-07-01"

echo "=== done ==="
