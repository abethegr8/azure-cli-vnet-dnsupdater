# Azure VNet DNS Update Script

This project uses Azure CLI and Bash to update the DNS server settings for a controlled list of Azure Virtual Networks.

The script is designed with a safety-first approach:

* It uses an approved list of VNets instead of dynamically updating every VNet in the subscription.
* It runs in dry-run mode by default.
* It requires the `--apply` argument before making changes.
* It reports whether each update succeeded or failed.
* It supports post-change verification using Azure CLI.

## Project Overview

The goal of this project was to automate the process of updating DNS server settings across multiple Azure VNets.

Rather than manually updating each VNet through the Azure portal, the script stores approved resource group and VNet pairs in an array and processes them in a loop.

The target DNS servers used in this lab are:

```text
4.2.2.2
8.8.4.4
```

## Files

```text
update-vnet-dns.sh
README.md
```

## Prerequisites

Before running the script, make sure the following requirements are met:

* Azure CLI is installed.
* Bash is available.
* You are authenticated to Azure.
* The correct Azure subscription is selected.
* Your account has permission to update the target VNets.

Authenticate with Azure CLI:

```bash
az login
```

Verify the active subscription:

```bash
az account show --query "{Subscription:name, SubscriptionId:id}" -o table
```

Switch subscriptions when necessary:

```bash
az account set --subscription "<subscription-name-or-id>"
```

## VNet Inventory

Before making changes, use the following Azure CLI query to review the VNet name, resource group, location, and current DNS servers:

```bash
az network vnet list \
  --query '[].{VNet:name, ResourceGroup:resourceGroup, Location:location, DNS:join(`, `, not_null(dhcpOptions.dnsServers, `[]`))}' \
  -o table
```

Example output:

```text
VNet                     ResourceGroup        Location    DNS
-----------------------  -------------------  ----------  -------
az-devlab01-vnet         rg-devlab01-network  eastus      8.8.8.8
azure-terraform-vm-vnet  rg-terraform-lab     eastus
```

A blank DNS field means the VNet is using Azure-provided DNS rather than custom DNS servers.

## Approved Target List

The script does not discover and modify every VNet automatically.

Instead, it uses an approved target list:

```bash
VNETS=(
  "rg-devlab01-network|az-devlab01-vnet"
  "rg-terraform-lab|azure-terraform-vm-vnet"
)
```

Each entry uses this format:

```text
resource-group|vnet-name
```

This approach reduces the blast radius by ensuring that only explicitly approved VNets can be modified.

## Script

```bash
#!/usr/bin/env bash

###############################################################
# Script Name: update-vnet-dns.sh
#
# Description:
# Updates Azure Virtual Network DNS server settings using
# Azure CLI.
#
# Features:
# - Uses an approved list of VNets
# - Dry-run mode by default
# - Optional --apply argument
# - Success/failure reporting
#
# Usage:
#   ./update-vnet-dns.sh
#   ./update-vnet-dns.sh --apply
###############################################################

# Exit if an undefined variable is referenced.
set -u

# ==========================================================
# Script Configuration
# ==========================================================

# Dry-run mode is enabled by default.
DRY_RUN=true

# DNS servers that will be assigned to each approved VNet.
NEW_DNS=("4.2.2.2" "8.8.4.4")

# ==========================================================
# Approved Target List
# ==========================================================
# Format:
# "ResourceGroup|VNetName"
VNETS=(
  "rg-devlab01-network|az-devlab01-vnet"
  "rg-terraform-lab|azure-terraform-vm-vnet"
)

# ==========================================================
# Check Script Arguments
# ==========================================================
# Disable dry-run mode only when --apply is provided.
if [[ "${1:-}" == "--apply" ]]; then
  DRY_RUN=false
fi

# ==========================================================
# Display Target Configuration
# ==========================================================
echo "Target DNS servers: ${NEW_DNS[*]}"
echo

# ==========================================================
# Process Each Approved VNet
# ==========================================================
for entry in "${VNETS[@]}"; do

  # Split the array entry into resource group and VNet name.
  IFS='|' read -r resource_group vnet_name <<< "$entry"

  echo "VNet:           $vnet_name"
  echo "Resource Group: $resource_group"

  # Dry-run mode displays the planned update without changing Azure.
  if $DRY_RUN; then
    echo "Action:         WOULD UPDATE"
    echo "New DNS:        ${NEW_DNS[*]}"

  else
    echo "Action:         UPDATING"

    # Apply the new DNS servers to the target VNet.
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
```

## Usage

Make the script executable:

```bash
chmod +x update-vnet-dns.sh
```

### Dry Run

Run the script without arguments:

```bash
./update-vnet-dns.sh
```

Dry-run mode does not make any Azure changes.

Example output:

```text
Target DNS servers: 4.2.2.2 8.8.4.4

VNet:           az-devlab01-vnet
Resource Group: rg-devlab01-network
Action:         WOULD UPDATE
New DNS:        4.2.2.2 8.8.4.4
----------------------------------------
VNet:           azure-terraform-vm-vnet
Resource Group: rg-terraform-lab
Action:         WOULD UPDATE
New DNS:        4.2.2.2 8.8.4.4
----------------------------------------
```

### Apply Changes

After reviewing the dry-run output, apply the changes:

```bash
./update-vnet-dns.sh --apply
```

Example output:

```text
Target DNS servers: 4.2.2.2 8.8.4.4

VNet:           az-devlab01-vnet
Resource Group: rg-devlab01-network
Action:         UPDATING
Result:         SUCCESS
----------------------------------------
VNet:           azure-terraform-vm-vnet
Resource Group: rg-terraform-lab
Action:         UPDATING
Result:         SUCCESS
----------------------------------------
```

## Verification

After the update, verify the DNS configuration:

```bash
az network vnet list \
  --query '[].{VNet:name, ResourceGroup:resourceGroup, Location:location, DNS:join(`, `, not_null(dhcpOptions.dnsServers, `[]`))}' \
  -o table
```

Expected result:

```text
VNet                     ResourceGroup        Location    DNS
-----------------------  -------------------  ----------  ----------------
az-devlab01-vnet         rg-devlab01-network  eastus      4.2.2.2, 8.8.4.4
azure-terraform-vm-vnet  rg-terraform-lab     eastus      4.2.2.2, 8.8.4.4
```

## Troubleshooting

### `bash\r: No such file or directory`

This usually means the script was created on Windows using CRLF line endings.

Convert the file to Unix LF line endings:

```bash
sed -i 's/\r$//' update-vnet-dns.sh
```

In Visual Studio Code, change the line-ending setting from `CRLF` to `LF` before saving.

### `join()` Received a Null Value

Some VNets may not have custom DNS servers configured. Their DNS property may be null.

The inventory query handles that with:

```text
not_null(dhcpOptions.dnsServers, `[]`)
```

This substitutes an empty array before calling `join()`.

### Azure CLI Requires `--resource-group`

Some Azure CLI versions may incorrectly require a resource group when running:

```bash
az network vnet list
```

When that occurs, either use a different Azure CLI version or query each target resource group separately.

## Safety Considerations

Changing VNet DNS settings can affect name resolution for connected virtual machines and services.

Recommended practices include:

* Use an approved target list.
* Run a dry run before applying changes.
* Verify the active Azure subscription.
* Review resource group and VNet names carefully.
* Validate the DNS configuration after the update.
* Test in a non-production subscription first.
* Plan for VM DNS refresh or restart requirements.

Existing VMs may not immediately begin using the new DNS servers. Depending on the operating system and DHCP lease state, a restart or network configuration refresh may be required.

## Microsoft Copilot Usage

Microsoft Copilot was used to assist with portions of the Bash script, Azure CLI syntax, comments, and troubleshooting.

All generated commands and logic were manually reviewed, tested in an Azure test subscription, executed first in dry-run mode, and validated after deployment.

Copilot was used as an engineering productivity tool, while responsibility for testing, safety, correctness, and final implementation remained with the engineer.

## Skills Demonstrated

This project demonstrates experience with:

* Azure Virtual Networks
* Azure DNS configuration
* Azure CLI
* Bash scripting
* Arrays and loops
* JMESPath queries
* Dry-run implementation
* Controlled change management
* Blast-radius reduction
* Error handling
* Post-change verification
* Microsoft Copilot-assisted development
* Windows and Linux line-ending troubleshooting

## Future Improvements

Potential enhancements include:

* Check the current DNS configuration before updating.
* Skip VNets that are already correctly configured.
* Verify each VNet immediately after the update.
* Add logging to a timestamped file.
* Export results to CSV or JSON.
* Add rollback support.
* Read the approved VNet list from a CSV file.
* Add subscription validation.
* Add command-line parameters for custom DNS servers.
* Integrate the script into an Azure DevOps pipeline.

