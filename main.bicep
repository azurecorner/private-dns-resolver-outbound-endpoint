targetScope = 'resourceGroup'

param location string = 'westeurope'
param localAdminUsername string = 'logcorner'
@secure()
param localAdminPassword string   
param storageAccountName string = 'logcornerstprivdnsrev'
@allowed([
  true
 false
])
@description('Use Private DNS Resolver for DNS resolution')
param UsePrivateResolver bool = false

module hubvnet './hubvnet.bicep' = {
  name: 'hubvnet'
  params: {
    location: location
  }
}

module spokevnet './spokevnet.bicep' = {
  name: 'spokevnet'
  params: {
    location: location
    UsePrivateResolver: UsePrivateResolver
  }
}



module VMs './VMs.bicep' = {
  name: 'VMs'
  params: {
    location: location
    localAdminUsername: localAdminUsername
    localAdminPassword: localAdminPassword
    spokesubnetID: spokevnet.outputs.spokesubnetID
  }
}

 module vnetpeering './vnetPeering.bicep' = {
  name: 'vnetpeering'
  params: {
    HubID: hubvnet.outputs.vnetID
    SpokeID: spokevnet.outputs.vnetID
   
  }
}  

module bastion 'bastion.bicep' = {
  name: 'bastion'
  params: {
    HubSubnetID: hubvnet.outputs.bastionSubnetID
    location: location
  }
}

module storage 'storage.bicep' = {
  name: 'storage'
  params: {
    location: location
    hubVnetID: hubvnet.outputs.vnetID
    spokeVnetID: spokevnet.outputs.vnetID
    spokeSubnetID: spokevnet.outputs.spokesubnetID
    storageAccountName: storageAccountName
  }
}

module privateresolver 'privateresolver.bicep' = if (UsePrivateResolver == true) {
  name: 'privateresolver'
  params: {
    location: location
    hubvnetID: hubvnet.outputs.vnetID
    inboundSubnetID: hubvnet.outputs.inboundSubnetID
   
  }
}


