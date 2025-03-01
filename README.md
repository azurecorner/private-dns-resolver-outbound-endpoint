## 1. Overview

Azure DNS Private Resolver allow you to create your own provate dns server and/or to query Azure DNS private zones from an on-premises environment and vice versa without deploying VM based DNS servers.

for more informations about private dns resolver you can follow the official doumentation here : <https://learn.microsoft.com/en-us/azure/dns/dns-private-resolver-overview>

In this tutorial, I will demonstrate how to configure the outbound endpoint of Azure DNS Private Resolver.
The inbound endpoint is configured in the previous tutorial : https://logcorner.com/azure-private-dns-resolver-using-inbound-endpoint/

- **inbound endpoints:** Inbound endpoints require a subnet delegated to Microsoft.Network/dnsResolvers. In a virtual network, you must configure a custom DNS server using the private IP of the inbound endpoint.

When a client within the virtual network issues a DNS query, the query is forwarded to the specified IP address, which is the private IP of the inbound endpoint of the Azure DNS Private Resolver.

DNS queries received by the inbound endpoint are processed and routed into Azure.

- **outbound endpoints:**
Outbound endpoints require a dedicated subnet delegated to Microsoft.Network/dnsResolvers within the virtual network where they are provisioned. They can be used to forward DNS queries to external DNS servers using DNS forwarding rulesets.

DNS queries sent to the outbound endpoint will exit Azure.



## 2. Infrastructure

To configure the infrastructure, deploy the DNS Private Resolver within a virtual network.
Set up the Private DNS Resolver inbound endpoint using a private IP address from the virtual network.
Delegate the inbound and outbound subnets to Microsoft.Network/dnsResolvers.
In the spoke virtual network, configure the custom DNS server to use the private IP address of the DNS resolver inbound endpoint (e.g., 10.200.0.70).

To setup  DNS Private Resolver , you need the following infrastructure:

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

# Bicep Subnet Definition: `Outbound`


The following Bicep code defines a subnet named **Outbound** with specific properties.



#### 2.1.1. **Subnet Name**
   - The subnet is named **Outbound**.

#### 2.1.2. **Address Prefix**
   - The `addressPrefix` property is assigned the value of `outboundSubnetAddressPrefixes`.
   - This variable contains the CIDR range for the subnet.

#### 2.1.3. **Delegations**
   - The subnet is **delegated** to  `Microsoft.Network.dnsResolvers`service and allows the subnet to be used for **Azure DNS Private Resolvers**.


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


### 2.2 Private Resolver Outbound Endpoint

This Bicep code sets up a **DNS forwarding configuration** in Azure using an **Azure DNS Private Resolver**. It allows Azure resources to resolve **on-premises domain names** by forwarding DNS queries to an **on-premises DNS server**.

#### 2.2.1. Creating an Outbound Endpoint
- An **outbound endpoint** is created within a specified subnet.
- This endpoint enables **Azure DNS Private Resolver** to send DNS queries outside of Azure.

#### 2.2.2. Defining a DNS Forwarding Ruleset
- A **DNS forwarding ruleset** is created and linked to the outbound endpoint.
- This ruleset determines how DNS queries should be handled and forwarded.

#### 2.2.3. Configuring a DNS Forwarding Rule
- A **forwarding rule** is added to the ruleset.
- Any DNS query for the domain **`logcorner.onpremise.`** will be forwarded to the on-premises DNS server at **10.100.0.5** on port **53**.

#### 2.2.4. How It Works Together
1. Azure resources send DNS queries.
2. If the query matches **`logcorner.onpremise.`**, it is forwarded via the **outbound endpoint**.
3. The query reaches the **on-premises DNS server** at **10.100.0.5** for resolution.


/*------------------------------------------ Private Resolver Outbound Endpoint ------------------------------------------*/

```bicep
      resource outboundEndpoint 'Microsoft.Network/dnsResolvers/outboundEndpoints@2022-07-01' = {
  name: 'outboundEndpoint'
  location: location
  parent: privateResolver
  properties: {
    subnet: {
      id: outboundSubnetID
    }
  }
}

resource labzoneRuleset 'Microsoft.Network/dnsForwardingRulesets@2022-07-01' = {
  name: 'labzoneRuleset'
  location: location
  properties: {
    dnsResolverOutboundEndpoints: [
      {
        id: outboundEndpoint.id
      }
    ]
  }
}

resource labzoneForwarding 'Microsoft.Network/dnsForwardingRulesets/forwardingRules@2022-07-01' = {
  name: 'labzoneForwarding'
  parent: labzoneRuleset
  properties: {
    domainName: 'logcorner.onpremise.'
    targetDnsServers: [
       {
        ipAddress: '10.100.0.5'
        port: 53
       }
    ]
  }
}

```

### Deployment Commands  

```powershell
Connect-AzAccount -Tenant 'xxxx-xxxx-xxxx-xxxx' -SubscriptionId 'yyyy-yyyy-yyyy-yyyy'

$subscriptionId= (Get-AzContext).Subscription.id
az account set --subscription $subscriptionId
$resourceGroupName="rg-dns-private-resolver"
New-AzResourceGroup -Name $resourceGroupName -Location "westeurope"
New-AzResourceGroupDeployment -Name "PrivateResolver" -ResourceGroupName $resourceGroupName -TemplateFile main.bicep 
```

### Github Repository

https://github.com/azurecorner/private-dns-resolver-outbound-endpoint
