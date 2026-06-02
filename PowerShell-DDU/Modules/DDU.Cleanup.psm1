<#
.SYNOPSIS
    DDU Main Cleanup Module

.DESCRIPTION
    Orchestrates the complete cleanup process
#>

<#
.SYNOPSIS
    Executes the complete cleanup workflow

.PARAMETER Config
    Configuration hashtable

.OUTPUTS
    Cleanup result object
#>
function Invoke-DDUCleanup {
    [CmdletBinding(SupportsShouldProcess=$true)]
    [OutputType([PSCustomObject])]
    param(
        [Parameter(Mandatory=$true)]
        [hashtable]$Config
    )

    $result = [PSCustomObject]@{
        Success = $false
        Vendor = $Config.Vendor
        DevicesRemoved = 0
        ServicesRemoved = 0
        RegistryKeysRemoved = 0
        FilesRemoved = 0
        DirectoriesRemoved = 0
        Errors = @()
    }

    try {
        # Phase 1: Stop processes
        Write-DDUSectionHeader "Phase 1: Stopping Vendor Processes"
        Invoke-DDUStopVendorProcesses -Config $Config

        # Phase 2: Remove services
        Write-DDUSectionHeader "Phase 2: Removing Services and Scheduled Tasks"
        $servicesRemoved = Invoke-DDURemoveServices -Config $Config
        $result.ServicesRemoved = $servicesRemoved

        # Phase 3: Remove devices (unless skipped)
        if (-not $Config.SkipDeviceRemoval) {
            Write-DDUSectionHeader "Phase 3: Removing Devices and Drivers"
            $devicesRemoved = Invoke-DDURemoveDevices -Config $Config
            $result.DevicesRemoved = $devicesRemoved
        } else {
            Write-DDULog "Device removal skipped (SkipDeviceRemoval = true)" -Level Info
        }

        # Phase 4: Clean registry
        Write-DDUSectionHeader "Phase 4: Cleaning Registry"
        $registryKeysRemoved = Invoke-DDUCleanRegistry -Config $Config
        $result.RegistryKeysRemoved = $registryKeysRemoved

        # Phase 5: Clean file system
        Write-DDUSectionHeader "Phase 5: Cleaning File System"
        $filesAndDirs = Invoke-DDUCleanFileSystem -Config $Config
        $result.FilesRemoved = $filesAndDirs.Files
        $result.DirectoriesRemoved = $filesAndDirs.Directories

        # Phase 6: Clean shader caches (if requested)
        if ($Config.CleanShaderCache) {
            Write-DDUSectionHeader "Phase 6: Cleaning Shader Caches"
            Invoke-DDUCleanShaderCaches -Config $Config
        }

        # Phase 7: Prevent Windows Update (if requested)
        if ($Config.PreventWindowsUpdate) {
            Write-DDUSectionHeader "Phase 7: Preventing Windows Update Driver Installation"
            Invoke-DDUPreventWindowsUpdate -Config $Config
        }

        $result.Success = $true

    } catch {
        $result.Errors += $_.Exception.Message
        Write-DDULog "Cleanup failed: $_" -Level Error
        throw
    }

    return $result
}

<#
.SYNOPSIS
    Stops vendor-specific processes

.PARAMETER Config
    Configuration hashtable
#>
function Invoke-DDUStopVendorProcesses {
    [CmdletBinding(SupportsShouldProcess=$true)]
    param(
        [Parameter(Mandatory=$true)]
        [hashtable]$Config
    )

    $processesToStop = @()

    switch ($Config.Vendor) {
        'NVIDIA' {
            $processesToStop = @(
                'nvcontainer', 'NVIDIA Web Helper', 'NVIDIA Share',
                'NVDisplay.Container', 'nvxdsync', 'nvwmi', 'nvsphelper64',
                'NVIDIA Broadcast', 'NvNodeLauncher', 'nvprofileupdater',
                'GFExperience', 'NVIDIA GeForce Experience'
            )
        }
        'AMD' {
            $processesToStop = @(
                'RadeonSoftware', 'AMDRSServ', 'AMDrsServ', 'cncmd',
                'AUEPMaster', 'amdow', 'atiesrxx', 'atieclxx'
            )
        }
        'Intel' {
            $processesToStop = @(
                'ArcControl', 'ArcControlAssist', 'ArcControlLauncher',
                'ArcControlPostProcessing', 'IntelGraphicsSoftware',
                'EnduranceGamingProcess', 'igfxEM', 'igfxHK', 'igfxTray'
            )
        }
    }

    if ($processesToStop.Count -gt 0) {
        Stop-DDUProcess -ProcessNames $processesToStop -DryRun:$Config.DryRun
    }
}

<#
.SYNOPSIS
    Removes vendor services

.PARAMETER Config
    Configuration hashtable

.OUTPUTS
    Number of services removed
#>
function Invoke-DDURemoveServices {
    [CmdletBinding(SupportsShouldProcess=$true)]
    [OutputType([int])]
    param(
        [Parameter(Mandatory=$true)]
        [hashtable]$Config
    )

    return Remove-DDUVendorServices -Vendor $Config.Vendor -ConfigPath $Config.ConfigPath -DryRun:$Config.DryRun
}

<#
.SYNOPSIS
    Removes vendor devices

.PARAMETER Config
    Configuration hashtable

.OUTPUTS
    Number of devices removed
#>
function Invoke-DDURemoveDevices {
    [CmdletBinding(SupportsShouldProcess=$true)]
    [OutputType([int])]
    param(
        [Parameter(Mandatory=$true)]
        [hashtable]$Config
    )

    return Remove-DDUVendorDevices -Vendor $Config.Vendor -RemoveAudio:$Config.RemoveAudio -DryRun:$Config.DryRun
}

<#
.SYNOPSIS
    Cleans vendor registry entries

.PARAMETER Config
    Configuration hashtable

.OUTPUTS
    Number of registry keys removed
#>
function Invoke-DDUCleanRegistry {
    [CmdletBinding(SupportsShouldProcess=$true)]
    [OutputType([int])]
    param(
        [Parameter(Mandatory=$true)]
        [hashtable]$Config
    )

    return Remove-DDUVendorRegistry -Vendor $Config.Vendor -DryRun:$Config.DryRun
}

<#
.SYNOPSIS
    Cleans vendor file system entries

.PARAMETER Config
    Configuration hashtable

.OUTPUTS
    Hashtable with Files and Directories counts
#>
function Invoke-DDUCleanFileSystem {
    [CmdletBinding(SupportsShouldProcess=$true)]
    [OutputType([hashtable])]
    param(
        [Parameter(Mandatory=$true)]
        [hashtable]$Config
    )

    $result = @{
        Files = 0
        Directories = 0
    }

    # Remove vendor directories
    $dirsRemoved = Remove-DDUVendorDirectories -Vendor $Config.Vendor -DryRun:$Config.DryRun
    $result.Directories += $dirsRemoved

    # Remove user caches
    $cachesRemoved = Remove-DDUUserCaches -Vendor $Config.Vendor -DryRun:$Config.DryRun
    $result.Directories += $cachesRemoved

    return $result
}

<#
.SYNOPSIS
    Cleans shader caches

.PARAMETER Config
    Configuration hashtable
#>
function Invoke-DDUCleanShaderCaches {
    [CmdletBinding(SupportsShouldProcess=$true)]
    param(
        [Parameter(Mandatory=$true)]
        [hashtable]$Config
    )

    $profiles = Get-DDUUserProfiles

    foreach ($profile in $profiles) {
        # DirectX shader cache
        $dxCache = "$profile\AppData\Local\D3DSCache"
        if (Test-Path $dxCache) {
            Remove-DDUDirectory -DirectoryPath $dxCache -DryRun:$Config.DryRun -Force | Out-Null
        }

        # Vendor-specific caches
        $cacheDirs = @(
            "$profile\AppData\LocalLow\*\dxcache",
            "$profile\AppData\LocalLow\*\vkcache",
            "$profile\AppData\LocalLow\*\glcache",
            "$profile\AppData\LocalLow\*\dxccache",
            "$profile\AppData\LocalLow\*\OglpCache"
        )

        foreach ($cachePattern in $cacheDirs) {
            $dirs = Get-Item -Path $cachePattern -ErrorAction SilentlyContinue
            foreach ($dir in $dirs) {
                Remove-DDUDirectory -DirectoryPath $dir.FullName -DryRun:$Config.DryRun -Force | Out-Null
            }
        }
    }

    # System profile caches
    $systemCache = "$env:SystemDrive\Windows\System32\config\systemprofile\AppData\Local\D3DSCache"
    if (Test-Path $systemCache) {
        Remove-DDUDirectory -DirectoryPath $systemCache -DryRun:$Config.DryRun -Force | Out-Null
    }
}

<#
.SYNOPSIS
    Prevents Windows Update from installing drivers

.PARAMETER Config
    Configuration hashtable
#>
function Invoke-DDUPreventWindowsUpdate {
    [CmdletBinding(SupportsShouldProcess=$true)]
    param(
        [Parameter(Mandatory=$true)]
        [hashtable]$Config
    )

    if ($Config.DryRun) {
        Write-DDULog "Would configure Windows Update driver policy" -Level Verbose
        return
    }

    try {
        # Set policy to never install driver updates
        $policyPath = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate'

        if (-not (Test-Path $policyPath)) {
            New-Item -Path $policyPath -Force | Out-Null
        }

        Set-ItemProperty -Path $policyPath -Name 'ExcludeWUDriversInQualityUpdate' -Value 1 -Type DWord -Force
        Write-DDULog "Windows Update driver installation policy configured" -Level Success

        # Additional device installation restrictions
        $deviceInstallPath = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Device Installer'
        if (-not (Test-Path $deviceInstallPath)) {
            New-Item -Path $deviceInstallPath -Force | Out-Null
        }

        Set-ItemProperty -Path $deviceInstallPath -Name 'DisableCoInstallers' -Value 1 -Type DWord -Force
        Write-DDULog "Device co-installer policy configured" -Level Success

    } catch {
        Write-DDULog "Failed to configure Windows Update policy: $_" -Level Warning
    }
}

# Export module members
Export-ModuleMember -Function @(
    'Invoke-DDUCleanup',
    'Invoke-DDUStopVendorProcesses',
    'Invoke-DDURemoveServices',
    'Invoke-DDURemoveDevices',
    'Invoke-DDUCleanRegistry',
    'Invoke-DDUCleanFileSystem',
    'Invoke-DDUCleanShaderCaches',
    'Invoke-DDUPreventWindowsUpdate'
)
