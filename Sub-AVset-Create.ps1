Import-Module -Name AzureRM

#region variables
$subscr="MSDN Platforms"                           #verify on the Azure Portal
$rgName="rg_scb_test4"                             #for foundation resources creating
$locName="southeastasia"
$FwAvailabilitySetName = "PaloAVSet"               #for test, it will re-definded in 'Sub-SA-n-2VM3nics.ps1' again beware!!
#endregion

#region get_credential_ARMSubscription

Login-AzureRMAccount

Get-AzureRmSubscription -SubscriptionName $subscr | Select-AzureRmSubscription -ErrorAction Stop

#endregion

#region Create/validate Availability Set
    if ($FwAvailabilitySetName) {
        Write-Output "Creating/verifying Availability Set '$FwAvailabilitySetName'"
        try {
            $AvailabilitySetObj = Get-AzureRmAvailabilitySet -ResourceGroupName $rgName -Name $FwAvailabilitySetName `
            -Sku aligned `
            -PlatformFaultDomainCount 2 `
            -PlatformUpdateDomainCount 2 `
            -ErrorAction Stop
            Write-Output "Availability Set '$FwAvailabilitySetName' already exists"
            Write-Output ($AvailabilitySetObj | Out-String)
        } catch {
            try {
                $AvailabilitySetObj = New-AzureRmAvailabilitySet -ResourceGroupName $rgName -Name $FwAvailabilitySetName `
                                      -Location $locName `
                                      -Sku aligned `
                                      -PlatformFaultDomainCount 2 `
                                      -PlatformUpdateDomainCount 2 `
                                      -ErrorAction Stop
                Write-Output "Created Availability Set '$FwAvailabilitySetName'"
            } catch {
                throw "Failed to create Availability Set '$FwAvailabilitySetName'"
            }
        }
        if ($AvailabilitySetObj.Location -ne $locName) {
            throw "Unable to proceed, Availability set must be in the same location '$($AvailabilitySetObj.Location)' as the desired VM location '$locName'"
        }
    }
#endregion