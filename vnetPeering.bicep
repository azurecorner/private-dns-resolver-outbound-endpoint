param HubID string
param SpokeID string

var HubIDAsArray = split(HubID,'/')
var HubName = last(HubIDAsArray)

var Spoke1AsArray = split(SpokeID,'/')
var Spoke1Name = last(Spoke1AsArray)


resource HubToSpoke1Peer 'Microsoft.Network/virtualNetworks/virtualNetworkPeerings@2020-07-01' = {
  name: '${HubName}/peer-${Spoke1Name}'
  properties: {
    allowVirtualNetworkAccess: true
    allowForwardedTraffic: true
    allowGatewayTransit: true
    useRemoteGateways: false
    remoteVirtualNetwork: {
      id: SpokeID
    }
  }
}

resource Spoke1ToHubPeer 'Microsoft.Network/virtualNetworks/virtualNetworkPeerings@2020-07-01' = {
  name: '${Spoke1Name}/peer-${HubName}'
  properties: {
    allowVirtualNetworkAccess: true
    allowForwardedTraffic: true
    allowGatewayTransit: true
    useRemoteGateways: false
    remoteVirtualNetwork: {
      id: HubID
    }
  }
}


