param location string
param vnetAddressPrefixes string ='10.200.0.0/24'
param bastionSubnetAddressPrefixes string ='10.200.0.0/26'
param inboundSubnetAddressPrefixes string ='10.200.0.64/26'
param outboundSubnetAddressPrefixes string ='10.200.0.128/26'

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

output vnetID string = hubvnet.id
output bastionSubnetID string = hubvnet.properties.subnets[0].id
output inboundSubnetID string = hubvnet.properties.subnets[1].id
output outboundSubnetID string = hubvnet.properties.subnets[2].id
