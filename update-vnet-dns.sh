#!/usr/bin/env bash

set -u

DRY_RUN=true
NEW_DNS=("4.2.2.2" "8.8.4.4")

# Format:
# "resource-group|vnet-name"
VNETS=(
  "rg-devlab01-network|az-devlab01-vnet"
  "rg-terraform-lab|azure-terraform-vm-vnet"
)

if [[ "${1:-}" == "--apply" ]]; then
  DRY_RUN=false
fi

echo "Target DNS servers: ${NEW_DNS[*]}"
echo

for entry in "${VNETS[@]}"; do
  IFS='|' read -r resource_group vnet_name <<< "$entry"

  echo "VNet:           $vnet_name"
  echo "Resource Group: $resource_group"

  if $DRY_RUN; then
    echo "Action:         WOULD UPDATE"
    echo "New DNS:        ${NEW_DNS[*]}"
  else
    echo "Action:         UPDATING"

    if az network vnet update \
      --resource-group "$resource_group" \
      --name "$vnet_name" \
      --dns-servers "${NEW_DNS[@]}" \
      --only-show-errors \
      --output none; then

      echo "Result:         SUCCESS"
    else
      echo "Result:         FAILED"
    fi
  fi

  echo "----------------------------------------"
done