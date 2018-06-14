Import-Module -Name AzureRM
#region variables
$subscr="MSDN Platforms"                           #verify on the Azure Portal
$rgName="rg_scb_test4"                             #for foundation resources creating
$locName="southeastasia"
      
$FwVNetName="FwVNET"
$FwVNETCIDR="10.0.0.0/16"

$FwMgmtSubnetName="mgmt_net"
$FwMgmtSubnetMark="10.0.10.0/24"

$FwUntrustSubnetName="untrust_net"
$FwUntrustSubnetMark="10.0.20.0/24"

$FwTrustSubnetName="trust_net"
$FwTrustSubnetMark="10.0.30.0/24"

$FwNSGName="Fw_NSG_Any"
##------App----------
$AppVNetName="AppVNET"
$AppVNetCIDR="50.0.0.0/16"

$AppPRODSubnetName="App_PROD_Net"
$AppPRODSubnetMark="50.0.10.0/24"
$AppNSGName="App_NSG_RDP_HTTP_s"
#endregion

#region get_credential_ARMSubscription

Login-AzureRMAccount
#Get-AzureRMSubscription | Sort Name | Select Name

Get-AzureRmSubscription -SubscriptionName $subscr | Select-AzureRmSubscription

#endregion

#region Fw_resources_foundation
New-AzureRMResourceGroup -Name $rgName -Location $locName

$locName=(Get-AzureRmResourceGroup -Name $rgName).Location

##Create Firewall virtual network 
$FwVNETObj = New-AzureRmVirtualNetwork `
  -ResourceGroupName $rgName `
  -Location $locName `
  -Name $FwVNetName `
  -AddressPrefix $FwVNETCIDR

## creating NSG
$FwNSGRule=New-AzureRMNetworkSecurityRuleConfig -Name "AnyTraffic" -Description "Allow all traffic to make evaluation" -Access Allow -Protocol * -Direction Inbound -Priority 100 -SourceAddressPrefix * -SourcePortRange * -DestinationAddressPrefix * -DestinationPortRange *
New-AzureRMNetworkSecurityGroup -Name $FwNSGName -ResourceGroupName $rgName -Location $locName -SecurityRules $FwNSGRule
#$vnet=Get-AzureRMVirtualNetwork -ResourceGroupName $rgName -Name $FwVNetName
$FwNSGObj=Get-AzureRMNetworkSecurityGroup -Name $FwNSGName -ResourceGroupName $rgName


##Azure resources are deployed to a subnet within a virtual network, so you need to create The MGMT subnet.
$subnetConfig = Add-AzureRmVirtualNetworkSubnetConfig `
  -Name $FwMgmtSubnetName `
  -AddressPrefix $FwMgmtSubnetMark `
  -VirtualNetwork $FwVNETObj `
  -NetworkSecurityGroup $FwNSGObj
##create Untrust subnet.
$subnetConfig = Add-AzureRmVirtualNetworkSubnetConfig `
  -Name $FwUntrustSubnetName `
  -AddressPrefix $FwUntrustSubnetMark `
  -VirtualNetwork $FwVNETObj `
  -NetworkSecurityGroup $FwNSGObj
##create Trust subnet.
$subnetConfig = Add-AzureRmVirtualNetworkSubnetConfig `
  -Name $FwTrustSubnetName `
  -AddressPrefix $FwTrustSubnetMark `
  -VirtualNetwork $FwVNETObj `
  -NetworkSecurityGroup $FwNSGObj
##Write the subnet configuration to the virtual network 
$FwVNETObj | Set-AzureRmVirtualNetwork

#endregion

#region App_Resources_Fundamental

##Create App virtual network 
$AppVNETObj = New-AzureRmVirtualNetwork `
  -ResourceGroupName $rgName `
  -Location $locName `
  -Name $AppVNetName `
  -AddressPrefix $AppVNetCIDR

## creating App NSG
## by default the NSG must creating with 1 configuration and cannot go with multiple configuration also.
$AppNSGRule1=New-AzureRMNetworkSecurityRuleConfig -Name "RDP_Traffic" -Description "Allow RDP to all VMs on the subnet" -Access Allow -Protocol Tcp -Direction Inbound -Priority 100 -SourceAddressPrefix * -SourcePortRange * -DestinationAddressPrefix * -DestinationPortRange 3389
New-AzureRMNetworkSecurityGroup -Name $AppNSGName -ResourceGroupName $rgName -Location $locName -SecurityRules $AppNSGRule1

$AppNSGObj=Get-AzureRMNetworkSecurityGroup -Name $AppNSGName -ResourceGroupName $rgName
##Adding another rules
Add-AzureRmNetworkSecurityRuleConfig -NetworkSecurityGroup $AppNSGObj -Name "HTTP_Traffic" -Description "Allow HTTP to all VMs on the subnet" -Access Allow -Protocol Tcp -Direction Inbound -Priority 101 -SourceAddressPrefix * -SourcePortRange * -DestinationAddressPrefix * -DestinationPortRange 80
Add-AzureRmNetworkSecurityRuleConfig -NetworkSecurityGroup $AppNSGObj -Name "HTTPS_Traffic" -Description "Allow HTTPS to all VMs on the subnet" -Access Allow -Protocol Tcp -Direction Inbound -Priority 102 -SourceAddressPrefix * -SourcePortRange * -DestinationAddressPrefix * -DestinationPortRange 443

##Apply the change to the NSG Object
$AppNSGObj | Set-AzureRmNetworkSecurityGroup

##Azure resources are deployed to a subnet within a virtual network, so you need to create The MGMT subnet.
$subnetConfig = Add-AzureRmVirtualNetworkSubnetConfig `
  -Name $AppPRODSubnetName `
  -AddressPrefix $AppPRODSubnetMark `
  -VirtualNetwork $AppVNETObj `
  -NetworkSecurityGroup $AppNSGObj

##Write the subnet configuration to the virtual network 
$AppVNETObj | Set-AzureRmVirtualNetwork
#endregion