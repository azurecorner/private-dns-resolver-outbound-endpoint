param location string
param hubvnetID string
param inboundSubnetID string
param inboundPrivateIpAddress string ='10.200.0.70'
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
        privateIpAddress: inboundPrivateIpAddress
        privateIpAllocationMethod: 'Static'
        subnet: {
          id: inboundSubnetID
        }
      }
    ]
  }
}


