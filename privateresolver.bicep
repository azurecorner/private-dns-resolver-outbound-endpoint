param location string
param hubvnetID string
param inboundSubnetID string
param outboundSubnetID string
param inboundPrivateIpAddress string ='10.200.0.70'
resource privateResolver 'Microsoft.Network/dnsResolvers@2022-07-01' = {
  name: 'logcornePrivateResolver'
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
