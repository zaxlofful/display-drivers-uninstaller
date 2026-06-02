<#
.SYNOPSIS
    DDU Detection Module

.DESCRIPTION
    Detects installed GPU vendors and drivers
#>

<#
.SYNOPSIS
    Detects installed GPU vendors

.OUTPUTS
    Array of detected vendor names
#>
function Get-DDUInstalledVendors {
    [CmdletBinding()]
    [OutputType([string[]])]
    param()

    $vendors = @()

    try {
        # Check for NVIDIA
        $nvidiaDevices = Get-PnpDevice -Class 'Display' -Status 'OK','Error','Unknown' -ErrorAction SilentlyContinue |
            Where-Object { $_.InstanceId -match 'VEN_10DE' }

        if ($nvidiaDevices) {
            $vendors += 'NVIDIA'
            Write-DDULog "Detected NVIDIA GPU" -Level Info
        }

        # Check for AMD
        $amdDevices = Get-PnpDevice -Class 'Display' -Status 'OK','Error','Unknown' -ErrorAction SilentlyContinue |
            Where-Object { $_.InstanceId -match 'VEN_1002' }

        if ($amdDevices) {
            $vendors += 'AMD'
            Write-DDULog "Detected AMD GPU" -Level Info
        }

        # Check for Intel
        $intelDevices = Get-PnpDevice -Class 'Display' -Status 'OK','Error','Unknown' -ErrorAction SilentlyContinue |
            Where-Object { $_.InstanceId -match 'VEN_8086' }

        if ($intelDevices) {
            $vendors += 'Intel'
            Write-DDULog "Detected Intel GPU" -Level Info
        }

    } catch {
        Write-DDULog "Error detecting GPU vendors: $_" -Level Warning
    }

    return $vendors
}

<#
.SYNOPSIS
    Gets information about installed GPU

.PARAMETER Vendor
    GPU vendor to query

.OUTPUTS
    GPU information object
#>
function Get-DDUGPUInfo {
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    param(
        [Parameter(Mandatory=$true)]
        [ValidateSet('NVIDIA', 'AMD', 'Intel')]
        [string]$Vendor
    )

    $vendorID = Get-DDUVendorID -Vendor $Vendor

    try {
        $devices = Get-DDUDisplayDevices -VendorID $vendorID

        if ($devices.Count -eq 0) {
            Write-DDULog "No $Vendor GPU found" -Level Info
            return $null
        }

        $gpuInfo = [PSCustomObject]@{
            Vendor = $Vendor
            VendorID = $vendorID
            DeviceCount = $devices.Count
            Devices = $devices
            DriverVersion = $null
            DriverDate = $null
        }

        # Try to get driver version from first device
        if ($devices.Count -gt 0) {
            try {
                $device = Get-PnpDevice -InstanceId $devices[0].InstanceId -ErrorAction SilentlyContinue
                if ($device) {
                    $driver = Get-PnpDeviceProperty -InstanceId $device.InstanceId -KeyName 'DEVPKEY_Device_DriverVersion' -ErrorAction SilentlyContinue
                    if ($driver) {
                        $gpuInfo.DriverVersion = $driver.Data
                    }

                    $driverDate = Get-PnpDeviceProperty -InstanceId $device.InstanceId -KeyName 'DEVPKEY_Device_DriverDate' -ErrorAction SilentlyContinue
                    if ($driverDate) {
                        $gpuInfo.DriverDate = $driverDate.Data
                    }
                }
            } catch {
                # Ignore driver info errors
            }
        }

        Write-DDULog "$Vendor GPU Info: $($devices.Count) device(s), Driver: $($gpuInfo.DriverVersion)" -Level Info

        return $gpuInfo

    } catch {
        Write-DDULog "Error getting $Vendor GPU info: $_" -Level Warning
        return $null
    }
}

<#
.SYNOPSIS
    Checks if vendor software is installed

.PARAMETER Vendor
    GPU vendor

.OUTPUTS
    Boolean indicating if software is installed
#>
function Test-DDUVendorSoftwareInstalled {
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        [Parameter(Mandatory=$true)]
        [ValidateSet('NVIDIA', 'AMD', 'Intel')]
        [string]$Vendor
    )

    $registryPaths = @()
    $installed = $false

    switch ($Vendor) {
        'NVIDIA' {
            $registryPaths = @(
                'HKLM:\Software\NVIDIA',
                'HKLM:\Software\NVIDIA Corporation'
            )
        }
        'AMD' {
            $registryPaths = @(
                'HKLM:\Software\AMD',
                'HKLM:\Software\ATI',
                'HKLM:\Software\ATI Technologies'
            )
        }
        'Intel' {
            $registryPaths = @(
                'HKLM:\Software\Intel\Display',
                'HKLM:\Software\Intel\Graphics'
            )
        }
    }

    foreach ($path in $registryPaths) {
        if (Test-Path $path) {
            $installed = $true
            break
        }
    }

    return $installed
}

# Export module members
Export-ModuleMember -Function @(
    'Get-DDUInstalledVendors',
    'Get-DDUGPUInfo',
    'Test-DDUVendorSoftwareInstalled'
)
