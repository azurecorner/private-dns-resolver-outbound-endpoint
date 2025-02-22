## 1. Overview

Azure DNS Private Resolver allow you to create your own provate dns server and/or to query Azure DNS private zones from an on-premises environment and vice versa without deploying VM based DNS servers.

for more informations about private dns resolver you can follow the official doumentation here : <https://learn.microsoft.com/en-us/azure/dns/dns-private-resolver-overview>

In this tutorial, I will demonstrate how to create a custom DNS server using Azure DNS Private Resolver

- **inbound endpoints:** Inbound endpoints require a subnet delegated to Microsoft.Network/dnsResolvers. In a virtual network, you must configure a custom DNS server using the private IP of the inbound endpoint.

When a client within the virtual network issues a DNS query, the query is forwarded to the specified IP address, which is the private IP of the inbound endpoint of the Azure DNS Private Resolver.

DNS queries received by the inbound endpoint are processed and routed into Azure.

- **outbound endpoints:**
Outbound endpoints require a dedicated subnet delegated to Microsoft.Network/dnsResolvers within the virtual network where they are provisioned. They can be used to forward DNS queries to external DNS servers using DNS forwarding rulesets.

DNS queries sent to the outbound endpoint will exit Azure.

In this tutorial, I will configure only the inbound endpoint. The outbound endpoint will be set up in the next tutorial.

## 2. Infrastructure

To configure the infrastructure, deploy the DNS Private Resolver within a virtual network.
Set up the Private DNS Resolver inbound endpoint using a private IP address from the virtual network.
Delegate the inbound and outbound subnets to Microsoft.Network/dnsResolvers.
In the spoke virtual network, configure the custom DNS server to use the private IP address of the DNS resolver inbound endpoint (e.g., 10.200.0.70).

To setup  DNS Private Resolver inbound endpoint, you need the following infrastructure:

- **A Hub virtual network with two subnets:**
  - Inbound subnet delegated to Microsoft.Network/dnsResolvers
  - Outbound subnet delegated to Microsoft.Network/dnsResolvers

- **A Spoke  virtual network:**
  - The spoke Vnet is used to set up our demo and should be configured to use a custom DNS server with the private IP of the Private Resolver inbound endpoint.

- **A storage account** with public network access disabled.

- **A private endpoint** within the virtual network, configured with the **file** sub-resource on the storage account.

- **A private DNS zone** (`privatelink.file.core.windows.net`) linked to the hub and spoke virtual network.

- **A Private Resolver**  is configured in the hub virtual network with an inbound endpoint.

- **An Azure virtual machine** in the spoke virtual network for the demo.
- **An Azure Bastion** in the hub virtual network, used to connect to the VM.

### 2.1 Hub Virtual Network

/*------------------------------------------ Hub Virtual Network ------------------------------------------*/

```bicep
resource hubvnet 'Microsoft.Network/virtualNetworks@2023-09-01' = {
  name: 'Hub'
  location: location
  properties: {
    addressSpace: {
      addressPrefixes: [
        vnetAddressPrefixes
      ]
    }
    subnets: [
      {
        name: 'AzureBastionSubnet'
        properties: {
          addressPrefix: bastionSubnetAddressPrefixes
        }
      }
      {
        name: 'Inbound'
        properties: {
          addressPrefix: inboundSubnetAddressPrefixes
          delegations: [
            {
              name: 'Microsoft.Network.dnsResolvers'
              properties: {
                serviceName: 'Microsoft.Network/dnsResolvers'
              }
            }
          ]
        }
      }
      {
        name: 'Outbound'
        properties: {
          addressPrefix: outboundSubnetAddressPrefixes
          delegations: [
            {
              name: 'Microsoft.Network.dnsResolvers'
              properties: {
                serviceName: 'Microsoft.Network/dnsResolvers'
              }
            }
          ]
        }
      }
    ]
  }
}

```

### 2.2 Spoke Virtual Network

/*------------------------------------------ Spoke Virtual Network ------------------------------------------*/

```bicep
resource spokevnet 'Microsoft.Network/virtualNetworks@2023-09-01' = {
  name: 'Spoke'
  location: location
  properties: {
    addressSpace: {
      addressPrefixes: [
        '10.201.0.0/24'
      ]
    }
    subnets: [
      {
        name: 'default'
        properties: {
          addressPrefix: '10.201.0.0/26'
        }
      }
    ]
    dhcpOptions: Stage == 'EndStage' ? {
      dnsServers: [
        '10.200.0.70'
      ]
    } : null
  }
}

```

### 2.3 Storage Account

/*------------------------------------------ Storage Account -----------------------------------------------*/

```bicep
resource storageAccount 'Microsoft.Storage/storageAccounts@2023-01-01' = {
  name: storageAccountName
  location: location
  sku: {
    name: 'Standard_LRS'
  }
  kind: 'StorageV2'
  properties: {
    publicNetworkAccess: 'Disabled'
    accessTier: 'Cool'
  }
}

resource fileService 'Microsoft.Storage/storageAccounts/fileServices@2023-01-01' = {
  name: 'default'
  parent: storageAccount
}

resource share 'Microsoft.Storage/storageAccounts/fileServices/shares@2023-01-01' = {
  name: 'share'
  parent: fileService
  properties: {
    accessTier: 'Cool'
  }
}
```

### 2.4 Storage Account  Private Endpoint

/*---------------------------------------  Storage Account  Private Endpoint ----------------------------------*/

```bicep
resource privateEndpoint 'Microsoft.Network/privateEndpoints@2023-09-01' = {
  name: 'private'
  location: location
  properties: {
    subnet: {
      id: spokeSubnetID
    }
    privateLinkServiceConnections: [
      {
        name: 'private'
        properties: {
          privateLinkServiceId: storageAccount.id
          groupIds: [
            'file'
          ]
        }
      } 
    ]
  }
}

resource privateDNSZone 'Microsoft.Network/privateDnsZones@2020-06-01' = {
  name: 'privatelink.file.${environment().suffixes.storage}'
  location: 'global'
}

resource privateDNSZoneLinkToHub 'Microsoft.Network/privateDnsZones/virtualNetworkLinks@2020-06-01' = {
  name: 'privatelink.file.${environment().suffixes.storage}-linkToHub'
  parent: privateDNSZone
  location: 'global'
  properties: {
    registrationEnabled: false
    virtualNetwork: {
      id: hubVnetID
    }
  }
}

```

### 2.5 Private Resolver

/*------------------------------------------ Private Resolver -------------------------------------------------*/

```bicep
resource privateResolver 'Microsoft.Network/dnsResolvers@2022-07-01' = {
  name: 'privateResolver'
  location: location
  properties: {
    virtualNetwork: {
      id: hubvnetID
    }
  }
}

resource inboundEndpoint 'Microsoft.Network/dnsResolvers/inboundEndpoints@2022-07-01' = {
  name: 'inboundEndpoint'
  location: location
  parent: privateResolver
  properties: {
    ipConfigurations: [
      {
        privateIpAddress: outboundPrivateIpAddress
        privateIpAllocationMethod: 'Static'
        subnet: {
          id: inboundSubnetID
        }
      }
    ]
  }
}

```

### Deployment Commands  

**Test deployement using Default Azure DNS**

```powershell
Connect-AzAccount -Tenant 'xxxx-xxxx-xxxx-xxxx' -SubscriptionId 'yyyy-yyyy-yyyy-yyyy'

$subscriptionId= (Get-AzContext).Subscription.id
az account set --subscription $subscriptionId
$resourceGroupName="rg-dns-private-resolver"
New-AzResourceGroup -Name $resourceGroupName -Location "westeurope"
New-AzResourceGroupDeployment -Name "NoPrivateResolver" -ResourceGroupName $resourceGroupName -TemplateFile main.bicep -UsePrivateResolver $false
```
run the following command :

```powershell
nslookup logcornerstprivdnsrev.file.core.windows.net

```

returns the following

```powershell
Server:  UnKnown
Address:  168.63.129.16

Non-authoritative answer:
Name:    logcornerstprivdnsrev.privatelink.file.core.windows.net
Address:  10.201.0.5
Aliases:  logcornerstprivdnsrev.file.core.windows.net

```

The query resolved the domain to the private IP address 10.201.0.5, indicating that Azure's default DNS service is functioning as expected, resolving the logcornerstprivdnsrev.file.core.windows.net domain to its corresponding private endpoint.

**Test deployement using Azure Private DNS Resolver**

```powershell
Connect-AzAccount -Tenant 'xxxx-xxxx-xxxx-xxxx' -SubscriptionId 'yyyy-yyyy-yyyy-yyyy'

$subscriptionId= (Get-AzContext).Subscription.id
az account set --subscription $subscriptionId
$resourceGroupName="rg-dns-private-resolver"
New-AzResourceGroup -Name $resourceGroupName -Location "westeurope"
New-AzResourceGroupDeployment -Name "UsePrivateResolver" -ResourceGroupName $resourceGroupName -TemplateFile main.bicep -UsePrivateResolver $true
```

Restart the vm and run the following command :

```powershell
nslookup logcornerstprivdnsrev.file.core.windows.net
```

returns the following

```powershell
Server:  UnKnown
Address:  10.200.0.70

Non-authoritative answer:
Name:    logcornerstprivdnsrev.privatelink.file.core.windows.net
Address:  10.201.0.5
Aliases:  logcornerstprivdnsrev.file.core.windows.net
```

The query resolved the domain to the private IP address 10.201.0.5, indicating that the custom DNS server at 10.200.0.70 is functioning as expected, resolving the logcornerstprivdnsrev.file.core.windows.net domain to its corresponding private endpoint.

### Github Repository

[<[https://github.com/azurecorner/deployment-script-privately-over-a-private-endpoint-custum-dns-02](https://github.com/azurecorner/private-dns-resolver-inbound-endpoint)>](https://github.com/azurecorner/private-dns-resolver-inbound-endpoint)
