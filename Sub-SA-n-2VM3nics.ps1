Import-Module -Name AzureRM

#region variables
$subscr="MSDN Platforms"                           #verify on the Azure Portal
$rgName="rg_scb_test4"                             #for foundation resources creating
$locName="southeastasia"
$FwVNetName="FwVNET"
$StorageAccountPrefix = "scb"

$FwAvailabilitySetName = "PaloAVSet"
$FwUntrustSubnetName="untrust_net"
$FwTrustSubnetName="trust_net"
## VMSeries information
$TimeZone = "SE Asia Standard Time"                #refer to 'http://jackstromberg.com/2017/01/list-of-time-zones-consumed-by-azure/'
$FwVMSize="Standard_DS3_v2"
$FwVM01Name="vmseries01"
$FwVM01_TrustNicName="FwVM1_nic0_trust_data" 
$FwVM01_UnTrustNicName="FwVM1_nic1_untrust_data"
$FwVM01_MgmtNicName="FwVM1_nic2_trust_mgmt"  
$FwVM02Name="vmseries02"
$FwVM02_TrustNicName="FwVM2_trust_data"
$FwVM02_UnTrustNicName="FwVM2_untrust_data"
$FwVM02_MgmtNicName="FwVM2_trust_mgmt"
#endregion

#region get_credential_ARMSubscription

Login-AzureRMAccount

Get-AzureRmSubscription -SubscriptionName $subscr | Select-AzureRmSubscription -ErrorAction Stop

#endregion

#region Create Storage Account if it does not exist in this Resource Group
    $StorageAccountName = "stor$($StorageAccountPrefix.ToLower())$((get-date -Format yyyyMMddhhmm).ToString())"
    if ($StorageAccountName.Length -gt 20) { 
        Write-Output "Storage account name '$StorageAccountName' is too long, using first 20 characters only.."
        $StorageAccountName = $StorageAccountName.Substring(0,19) 
    }  
    Write-output "Creating Storage Account '$StorageAccountName'"
    try {
        $StorageAccount = Get-AzureRmStorageAccount -Name $StorageAccountName -ResourceGroupName $rgName -ErrorAction Stop
        Write-Output "Using existing storage account '$StorageAccountName'"
    } catch {
        $i=0
        $DesiredStorageAccountName = $StorageAccountName
        while (!(Get-AzureRmStorageAccountNameAvailability $StorageAccountName).NameAvailable) {
            $i++
            $StorageAccountName = "$StorageAccountName$i"
        }
        if ($DesiredStorageAccountName -ne $StorageAccountName ) {
            Write-Output "Storage account '$DesiredStorageAccountName' is taken, using '$StorageAccountName' instead (available)"
        }
        try {
            $Splatt = @{
                ResourceGroupName = $rgName
                Name              = $StorageAccountName 
                SkuName           = 'Standard_LRS' 
                Kind              = 'Storage' 
                Location          = $locName 
                ErrorAction       = 'Stop'
            }
            $StorageAccountObj = New-AzureRmStorageAccount @Splatt
            Write-Output "Created storage account $StorageAccountName"
        } catch {
            throw "Failed to create storage account $StorageAccountName"
        }
    }
#endregion 

#region FW_VM_Nics
##Get FwVNET Object
$FwVNETObj = get-AzureRmVirtualNetwork -ResourceGroupName $rgName -Name $FwVNetName

##below are the way I getting the NIC.id that combinded with subnet 
$TrustSubnetObj = $FwVNETObj.Subnets|?{$_.Name -eq $FwTrustSubnetName}
$Fw1Nic1 = New-AzureRmNetworkInterface -ResourceGroupName $rgName `
    -Name $FwVM01_TrustNicName `
    -Location $locName `
    -SubnetId $TrustSubnetObj.Id

$UnTrustSubnetObj = $FwVNETObj.Subnets|?{$_.Name -eq $FwUntrustSubnetName}
$Fw1Nic2 = New-AzureRmNetworkInterface -ResourceGroupName $rgName `
    -Name $FwVM01_UnTrustNicName `
    -Location $locName `
    -SubnetId $UnTrustSubnetObj.Id

$MgmtSubnetObj = $FwVNETObj.Subnets|?{$_.Name -eq $FwMgmtSubnetName}
$Fw1Nic3 = New-AzureRmNetworkInterface -ResourceGroupName $rgName `
    -Name $FwVM01_MgmtNicName `
    -Location $locName `
    -SubnetId $MgmtSubnetObj.Id

##-------for vm No.2
##below are the way I getting the NIC.id that combinded with subnet 

$Fw2Nic1 = New-AzureRmNetworkInterface -ResourceGroupName $rgName `
    -Name $FwVM02_TrustNicName `
    -Location $locName `
    -SubnetId $TrustSubnetObj.Id


$Fw2Nic2 = New-AzureRmNetworkInterface -ResourceGroupName $rgName `
    -Name $FwVM02_UnTrustNicName `
    -Location $locName `
    -SubnetId $UnTrustSubnetObj.Id


$Fw2Nic3 = New-AzureRmNetworkInterface -ResourceGroupName $rgName `
    -Name $FwVM02_MgmtNicName `
    -Location $locName `
    -SubnetId $MgmtSubnetObj.Id

#endregion

#region VM_creation

## VMSeries VM admin credential
$FwVMCred = Get-Credential
$FwAvailabilitySetObj = Get-AzureRmAvailabilitySet -ResourceGroupName $rgName -Name $FwAvailabilitySetName

## VMseries No.1 information
$FwVMConfig_1 = New-AzureRmVMConfig -VMName $FwVM01Name -VMSize $FwVMSize -AvailabilitySetID $FwAvailabilitySetObj.Id

## VMSeries No.1 configuration
$FwVMConfig_1 = Set-AzureRmVMOperatingSystem -VM $FwVMConfig_1 `
    -Windows `
    -ComputerName $FwVM01Name `
    -Credential $FwVMCred `
    -ProvisionVMAgent `
    -EnableAutoUpdate `
    -TimeZone $TimeZone `
    
    
$FwVMConfig_1 = Set-AzureRmVMSourceImage -VM $FwVMConfig_1 `
    -PublisherName "MicrosoftWindowsServer" `
    -Offer "WindowsServer" `
    -Skus "2016-Datacenter" `
    -Version "latest"

##Attaching NIC to the VM
$FwVMConfig_1 = Add-AzureRmVMNetworkInterface -VM $FwVMConfig_1 -Id $Fw1Nic1.Id
$FwVMConfig_1 = Add-AzureRmVMNetworkInterface -VM $FwVMConfig_1 -Id $Fw1Nic2.Id
$FwVMConfig_1 = Add-AzureRmVMNetworkInterface -VM $FwVMConfig_1 -Id $Fw1Nic3.Id -Primary

##Creating the VM with defined configuration
New-AzureRmVM -VM $FwVMConfig_1 -ResourceGroupName $rgName -Location $locName -ErrorAction Stop
#endregion

#$vm = New-AzureRmVMConfig
# Disk setup
#$diskName = ”jason-disk”
#$storageaccount = "jasontest321"
#$STA = Get-AzureRmStorageAccount -ResourceGroupName $rgName -Name $storageAccount
#$OSDiskUri = $STA.PrimaryEndpoints.Blob.ToString() + "vhds/" + $diskName? + ".vhd"
#$vm = Set-AzureRmVMOSDisk -VM $vm -Name $diskName -VhdUri $OSDiskUri -CreateOption fromImage 
