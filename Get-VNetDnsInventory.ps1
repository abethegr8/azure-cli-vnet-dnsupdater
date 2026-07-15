az network vnet list --query '[].{VNet:name, ResourceGroup:resourceGroup, Location:location, DNS:join(`, `, not_null(dhcpOptions.dnsServers, `[]`))}' -o table
