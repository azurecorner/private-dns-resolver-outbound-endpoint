param location string
param vnetAddressPrefixes string ='10.201.0.0/24'
param defaultSubnetAddressPrefixes string ='10.201.0.0/26'
param inboundPrivateIpAddress string = '10.200.0.70'

@description('Use Private DNS Resolver for DNS resolution')
param UsePrivateResolver bool = false

resource spokevnet 'Microsoft.Network/virtualNetworks@2023-09-01' = {
  name: 'Spoke'
  location: location
  properties: {
    addressSpace: {
      addressPrefixes: [
        vnetAddressPrefixes
      ]
    }
    subnets: [
      {
        name: 'default'
        properties: {
          addressPrefix: defaultSubnetAddressPrefixes 
        }
      }
    ]
    dhcpOptions: UsePrivateResolver == true ? {
      dnsServers: [
        inboundPrivateIpAddress
      ]
    } : null
  }
}

output vnetID string = spokevnet.id
output spokesubnetID string = spokevnet.properties.subnets[0].id
