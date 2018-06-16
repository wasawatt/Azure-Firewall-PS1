Import-Module -Name AzureRM
#region variables
$subscr="MSDN Platforms"                           #verify on the Azure Portal
$rgName="rg_scb_test5"                             #for foundation resources creating
$locName="southeastasia"
$iNLBName="FwTrustedNLB-Outbound3"
$iNLBskuType="Standard"                            # Basic , Standard
$FwTrustSubnetName="trust_net"

$FwVM01_TrustNicName="FwVM1_nic0_trust_data" 
$FwVM02_TrustNicName="FwVM2_nic0_trust_data"
#endregion

#region get_credential_ARMSubscription

Login-AzureRMAccount
#Get-AzureRMSubscription | Sort Name | Select Name

Get-AzureRmSubscription -SubscriptionName $subscr | Select-AzureRmSubscription

#endregion

#region creating a NLB


##get vNet
$FwVNETObj = Get-AzureRmVirtualNetwork -ResourceGroupName $rgName -Name $FwVNetName
$TrustSubnetObj = $FwVNETObj.Subnets|?{$_.Name -eq $FwTrustSubnetName}

## creat the frontend ip address(Dynamic) of NLB
$iNLBfrontendIP1 = New-AzureRmLoadBalancerFrontendIpConfig -Name iNLB-Frontend-IP -SubnetId $TrustSubnetObj.id

$iNLBBackendPool1 = New-AzureRmLoadBalancerBackendAddressPoolConfig -Name FwAVSet

$healthProbe = New-AzureRmLoadBalancerProbeConfig -Name FwTCPProbe -Protocol TCP -Port 80 -IntervalInSeconds 10 -ProbeCount 2

$iNLB80Rule = New-AzureRmLoadBalancerRuleConfig -Name HTTP `
             -FrontendIpConfiguration $iNLBfrontendIP1 `
             -BackendAddressPool $iNLBBackendPool1 `
             -Probe $healthprobe `
             -Protocol Tcp `
             -FrontendPort 80 `
             -BackendPort 80 `
             -IdleTimeoutInMinutes 5 `
             -LoadDistribution SourceIPProtocol

$iNLB443Rule = New-AzureRmLoadBalancerRuleConfig -Name HTTPs `
             -FrontendIpConfiguration $iNLBfrontendIP1 `
             -BackendAddressPool $iNLBBackendPool1 `
             -Probe $healthprobe `
             -Protocol Tcp `
             -FrontendPort 443 `
             -BackendPort 443 `
             -IdleTimeoutInMinutes 5 `
             -LoadDistribution SourceIPProtocol

## create NLB with #primary rule
$iNLBObj = New-AzureRmLoadBalancer -ResourceGroupName $rgName `
           -Name $iNLBName `
           -Location $locName `
           -FrontendIpConfiguration $iNLBfrontendIP1 `
           -BackendAddressPool $iNLBBackendPool1 `
           -Sku $iNLBskuType `
           -Probe $healthProbe

## add secondary rule(HTTPs) to NLB

$iNLBObj.LoadBalancingRules.Add($iNLB80Rule)
$iNLBObj.LoadBalancingRules.Add($iNLB443Rule)
$iNLBSetObj=Set-AzureRmLoadBalancer -LoadBalancer $iNLBObj

## add VMSeries NICs to backendpool
$Fw1TrustedNIC = Get-AzureRmNetworkInterface -Name $FwVM01_TrustNicName -ResourceGroupName $rgName
$Fw2TrustedNIC = Get-AzureRmNetworkInterface -Name $FwVM02_TrustNicName -ResourceGroupName $rgName

##Add FW1,2 Trusted NICs to $iNLBObj's backendpool
$Fw1TrustedNIC.IpConfigurations[0].LoadBalancerBackendAddressPools.Add($iNLBObj.BackendAddressPools[0]);
$Fw2TrustedNIC.IpConfigurations[0].LoadBalancerBackendAddressPools.Add($iNLBObj.BackendAddressPools[0]);


$iNLBObj = $iNLBObj | Set-AzureRmLoadBalancer

$Fw1TrustedNIC | Set-AzureRmNetworkInterface
$Fw2TrustedNIC | Set-AzureRmNetworkInterface


#endregion