<#
.SYNOPSIS
    DDU Device Management Module

.DESCRIPTION
    Handles device enumeration and removal using PnP APIs
#>

<#
.SYNOPSIS
    Gets display devices for a specific vendor

.PARAMETER VendorID
    Vendor ID (e.g., VEN_10DE for NVIDIA)

.OUTPUTS
    Array of device objects
#>
function Get-DDUDisplayDevices {
    [CmdletBinding()]
    [OutputType([PSCustomObject[]])]
    param(
        [Parameter(Mandatory=$true)]
        [string]$VendorID
    )

    try {
        Write-DDULog "Enumerating display devices for vendor: $VendorID" -Level Verbose

        # Get PnP devices matching vendor ID
        $devices = Get-PnpDevice -Class 'Display' -Status 'OK','Error','Degraded','Unknown' -ErrorAction SilentlyContinue |
            Where-Object {
                $_.InstanceId -match $VendorID -or
                $_.HardwareID -match $VendorID -or
                $_.CompatibleID -match $VendorID
            }

        # Also get hidden/disconnected devices
        $allDevices = Get-PnpDevice -Class 'Display' -ErrorAction SilentlyContinue |
            Where-Object {
                $_.InstanceId -match $VendorID -or
                $_.HardwareID -match $VendorID -or
                $_.CompatibleID -match $VendorID
            }

        $deviceList = @()

        foreach ($device in $allDevices) {
            $deviceInfo = [PSCustomObject]@{
                FriendlyName = $device.FriendlyName
                InstanceId = $device.InstanceId
                DeviceId = $device.DeviceID
                Class = $device.Class
                Status = $device.Status
                Present = $device.Present
                HardwareIDs = @()
                CompatibleIDs = @()
            }

            # Get additional device properties
            try {
                $props = Get-PnpDeviceProperty -InstanceId $device.InstanceId -ErrorAction SilentlyContinue
                $hwIds = $props | Where-Object { $_.KeyName -eq 'DEVPKEY_Device_HardwareIds' } | Select-Object -ExpandProperty Data
                $compIds = $props | Where-Object { $_.KeyName -eq 'DEVPKEY_Device_CompatibleIds' } | Select-Object -ExpandProperty Data

                if ($hwIds) { $deviceInfo.HardwareIDs = $hwIds }
                if ($compIds) { $deviceInfo.CompatibleIDs = $compIds }
            } catch {
                # Ignore property retrieval errors
            }

            $deviceList += $deviceInfo
        }

        Write-DDULog "Found $($deviceList.Count) display devices" -Level Verbose
        return $deviceList

    } catch {
        Write-DDULog "Failed to enumerate display devices: $_" -Level Error
        return @()
    }
}

<#
.SYNOPSIS
    Gets audio devices for a specific vendor

.PARAMETER VendorID
    Vendor ID

.OUTPUTS
    Array of device objects
#>
function Get-DDUAudioDevices {
    [CmdletBinding()]
    [OutputType([PSCustomObject[]])]
    param(
        [Parameter(Mandatory=$true)]
        [string]$VendorID
    )

    try {
        Write-DDULog "Enumerating audio devices for vendor: $VendorID" -Level Verbose

        $audioClasses = @('Media', 'AudioEndpoint', 'MEDIA')

        $deviceList = @()

        foreach ($className in $audioClasses) {
            $devices = Get-PnpDevice -Class $className -ErrorAction SilentlyContinue |
                Where-Object {
                    ($_.InstanceId -match $VendorID) -or
                    ($_.FriendlyName -match 'NVIDIA|AMD|ATI|Intel') -and ($_.InstanceId -match 'HDAUDIO|USB')
                }

            foreach ($device in $devices) {
                $deviceInfo = [PSCustomObject]@{
                    FriendlyName = $device.FriendlyName
                    InstanceId = $device.InstanceId
                    DeviceId = $device.DeviceID
                    Class = $device.Class
                    Status = $device.Status
                    Present = $device.Present
                }

                $deviceList += $deviceInfo
            }
        }

        Write-DDULog "Found $($deviceList.Count) audio devices" -Level Verbose
        return $deviceList

    } catch {
        Write-DDULog "Failed to enumerate audio devices: $_" -Level Error
        return @()
    }
}

<#
.SYNOPSIS
    Removes a PnP device

.PARAMETER InstanceId
    Device instance ID

.PARAMETER DryRun
    Simulate without removing
#>
function Remove-DDUDevice {
    [CmdletBinding(SupportsShouldProcess=$true)]
    param(
        [Parameter(Mandatory=$true)]
        [string]$InstanceId,

        [Parameter()]
        [switch]$DryRun
    )

    try {
        $device = Get-PnpDevice -InstanceId $InstanceId -ErrorAction Stop

        if ($DryRun) {
            Write-DDULog "Would remove device: $($device.FriendlyName) ($InstanceId)" -Level Verbose
            return $true
        }

        Write-DDULog "Removing device: $($device.FriendlyName) ($InstanceId)" -Level Verbose

        # Use pnputil to remove device
        $pnpResult = & pnputil /remove-device $InstanceId 2>&1

        if ($LASTEXITCODE -eq 0) {
            Write-DDULog "Device removed: $($device.FriendlyName)" -Level Success
            return $true
        } else {
            Write-DDULog "Failed to remove device: $pnpResult" -Level Warning
            return $false
        }

    } catch {
        Write-DDULog "Error removing device ${InstanceId}: $_" -Level Warning
        return $false
    }
}

<#
.SYNOPSIS
    Removes driver packages from the driver store

.PARAMETER VendorID
    Vendor ID to match

.PARAMETER DryRun
    Simulate without removing

.OUTPUTS
    Number of packages removed
#>
function Remove-DDUDriverPackages {
    [CmdletBinding(SupportsShouldProcess=$true)]
    [OutputType([int])]
    param(
        [Parameter(Mandatory=$true)]
        [string]$VendorID,

        [Parameter()]
        [switch]$DryRun
    )

    $removedCount = 0

    try {
        Write-DDULog "Enumerating driver packages for vendor: $VendorID" -Level Verbose

        # Get all OEM driver packages
        $pnpOutput = & pnputil /enum-drivers 2>&1

        if ($LASTEXITCODE -ne 0) {
            Write-DDULog "Failed to enumerate driver packages" -Level Warning
            return 0
        }

        # Parse pnputil output to find matching packages
        $lines = $pnpOutput -split "`r`n"
        $currentPackage = $null
        $packagesToRemove = @()

        foreach ($line in $lines) {
            if ($line -match 'Published Name\s*:\s*(.+\.inf)') {
                $currentPackage = $matches[1].Trim()
            }
            elseif ($line -match 'Provider Name\s*:\s*(.+)' -and $currentPackage) {
                $provider = $matches[1].Trim()

                # Check if provider matches vendor
                if ($provider -match 'NVIDIA|AMD|ATI|Intel|Advanced Micro Devices') {
                    $packagesToRemove += $currentPackage
                }
            }
            elseif ($line -match 'Class Name\s*:\s*(.+)' -and $currentPackage) {
                $className = $matches[1].Trim()

                # Check if class is display-related
                if ($className -match 'Display|3D|Graphics|Video') {
                    # Additional validation with hardware IDs if needed
                    if ($currentPackage -notin $packagesToRemove) {
                        $packagesToRemove += $currentPackage
                    }
                }
            }
        }

        # Remove each package
        foreach ($package in $packagesToRemove) {
            if ($DryRun) {
                Write-DDULog "Would remove driver package: $package" -Level Verbose
                $removedCount++
            } else {
                Write-DDULog "Removing driver package: $package" -Level Verbose

                $result = & pnputil /delete-driver $package /uninstall /force 2>&1

                if ($LASTEXITCODE -eq 0) {
                    Write-DDULog "Driver package removed: $package" -Level Success
                    $removedCount++
                } else {
                    Write-DDULog "Failed to remove driver package ${package}: $result" -Level Warning
                }
            }
        }

        Write-DDULog "Removed $removedCount driver packages" -Level Info

    } catch {
        Write-DDULog "Error removing driver packages: $_" -Level Error
    }

    return $removedCount
}

<#
.SYNOPSIS
    Removes all vendor devices and drivers

.PARAMETER Vendor
    GPU vendor

.PARAMETER RemoveAudio
    Also remove audio devices

.PARAMETER DryRun
    Simulate without removing

.OUTPUTS
    Number of devices removed
#>
function Remove-DDUVendorDevices {
    [CmdletBinding(SupportsShouldProcess=$true)]
    [OutputType([int])]
    param(
        [Parameter(Mandatory=$true)]
        [ValidateSet('NVIDIA', 'AMD', 'Intel')]
        [string]$Vendor,

        [Parameter()]
        [switch]$RemoveAudio,

        [Parameter()]
        [switch]$DryRun
    )

    $removedCount = 0
    $vendorID = Get-DDUVendorID -Vendor $Vendor

    # Remove display devices
    $displayDevices = Get-DDUDisplayDevices -VendorID $vendorID

    foreach ($device in $displayDevices) {
        if (Remove-DDUDevice -InstanceId $device.InstanceId -DryRun:$DryRun) {
            $removedCount++
        }
    }

    # Remove audio devices if requested
    if ($RemoveAudio) {
        $audioDevices = Get-DDUAudioDevices -VendorID $vendorID

        foreach ($device in $audioDevices) {
            if (Remove-DDUDevice -InstanceId $device.InstanceId -DryRun:$DryRun) {
                $removedCount++
            }
        }
    }

    # Remove driver packages from driver store
    $packagesRemoved = Remove-DDUDriverPackages -VendorID $vendorID -DryRun:$DryRun
    $removedCount += $packagesRemoved

    Write-DDULog "Removed $removedCount devices/packages for $Vendor" -Level Info

    return $removedCount
}

# Export module members
Export-ModuleMember -Function @(
    'Get-DDUDisplayDevices',
    'Get-DDUAudioDevices',
    'Remove-DDUDevice',
    'Remove-DDUDriverPackages',
    'Remove-DDUVendorDevices'
)
