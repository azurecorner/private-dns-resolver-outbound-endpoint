param location string
param vnetAddressPrefixes string ='10.201.0.0/24'
param defaultSubnetAddressPrefixes string ='10.201.0.0/26'
param inboundPrivateIpAddress string = '10.200.0.70'



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
    dhcpOptions: {
      dnsServers: [
        inboundPrivateIpAddress
      ]
    } 
  }
}

output vnetID string = spokevnet.id
output spokesubnetID string = spokevnet.properties.subnets[0].id
