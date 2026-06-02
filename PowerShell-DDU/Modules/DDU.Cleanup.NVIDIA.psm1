<#
.SYNOPSIS
    DDU NVIDIA-Specific Cleanup Module

.DESCRIPTION
    Handles NVIDIA-specific cleanup operations
#>

<#
.SYNOPSIS
    Main NVIDIA cleanup function

.PARAMETER Config
    Configuration hashtable
#>
function Invoke-DDUCleanupNVIDIA {
    [CmdletBinding(SupportsShouldProcess=$true)]
    param(
        [Parameter(Mandatory=$true)]
        [hashtable]$Config
    )

    Write-DDUSectionHeader "NVIDIA Driver Cleanup"

    # Execute base cleanup
    $result = Invoke-DDUCleanup -Config $Config

    # NVIDIA-specific additional cleanup
    Write-DDUSectionHeader "NVIDIA-Specific Cleanup"

    # Remove PhysX if requested
    if ($Config.RemovePhysX) {
        Remove-NVIDIAPhysX -DryRun:$Config.DryRun
    }

    # Remove 3D Vision if requested
    if ($Config.Remove3DVision) {
        Remove-NVIDIA3DVision -DryRun:$Config.DryRun
    }

    # Remove GeForce Experience if requested
    if ($Config.RemoveGeForceExperience) {
        Remove-NVIDIAGeForceExperience -DryRun:$Config.DryRun
    }

    # Remove NVIDIA Broadcast if requested
    if ($Config.RemoveNVBroadcast) {
        Remove-NVIDIABroadcast -DryRun:$Config.DryRun
    }

    # NVIDIA-specific registry cleanup
    Remove-NVIDIARegistryExtras -DryRun:$Config.DryRun

    # NVIDIA-specific file cleanup
    Remove-NVIDIAFileExtras -DryRun:$Config.DryRun

    # Remove NVIDIA user account (UpdatusUser)
    Remove-NVIDIAUpdatusUser -DryRun:$Config.DryRun

    Write-DDULog "NVIDIA cleanup completed" -Level Success
}

<#
.SYNOPSIS
    Removes NVIDIA PhysX

.PARAMETER DryRun
    Simulate without removing
#>
function Remove-NVIDIAPhysX {
    [CmdletBinding(SupportsShouldProcess=$true)]
    param(
        [Parameter()]
        [switch]$DryRun
    )

    Write-DDULog "Removing NVIDIA PhysX..." -Level Info

    # Remove PhysX registry keys
    $physxKeys = @(
        'HKLM:\Software\NVIDIA Corporation\PhysX',
        'HKLM:\Software\Wow6432Node\NVIDIA Corporation\PhysX'
    )

    foreach ($key in $physxKeys) {
        Remove-DDURegistryKey -KeyPath $key -DryRun:$DryRun -Force | Out-Null
    }

    # Remove PhysX directories
    $physxDirs = @(
        "$env:ProgramFiles\NVIDIA Corporation\PhysX",
        "${env:ProgramFiles(x86)}\NVIDIA Corporation\PhysX",
        "$env:ProgramData\NVIDIA Corporation\PhysX"
    )

    foreach ($dir in $physxDirs) {
        Remove-DDUDirectory -DirectoryPath $dir -DryRun:$DryRun -Force | Out-Null
    }

    Write-DDULog "PhysX removal completed" -Level Success
}

<#
.SYNOPSIS
    Removes NVIDIA 3D Vision

.PARAMETER DryRun
    Simulate without removing
#>
function Remove-NVIDIA3DVision {
    [CmdletBinding(SupportsShouldProcess=$true)]
    param(
        [Parameter()]
        [switch]$DryRun
    )

    Write-DDULog "Removing NVIDIA 3D Vision..." -Level Info

    # Remove 3D Vision registry keys
    $visionKeys = @(
        'HKLM:\Software\NVIDIA Corporation\3D Vision',
        'HKLM:\Software\Wow6432Node\NVIDIA Corporation\3D Vision'
    )

    foreach ($key in $visionKeys) {
        Remove-DDURegistryKey -KeyPath $key -DryRun:$DryRun -Force | Out-Null
    }

    # Remove 3D Vision directories
    $visionDirs = @(
        "$env:ProgramFiles\NVIDIA Corporation\3D Vision",
        "${env:ProgramFiles(x86)}\NVIDIA Corporation\3D Vision",
        "$env:ProgramData\NVIDIA Corporation\3D Vision"
    )

    foreach ($dir in $visionDirs) {
        Remove-DDUDirectory -DirectoryPath $dir -DryRun:$DryRun -Force | Out-Null
    }

    Write-DDULog "3D Vision removal completed" -Level Success
}

<#
.SYNOPSIS
    Removes NVIDIA GeForce Experience

.PARAMETER DryRun
    Simulate without removing
#>
function Remove-NVIDIAGeForceExperience {
    [CmdletBinding(SupportsShouldProcess=$true)]
    param(
        [Parameter()]
        [switch]$DryRun
    )

    Write-DDULog "Removing NVIDIA GeForce Experience..." -Level Info

    # Stop GFE processes
    $gfeProcesses = @(
        'GFExperience', 'NVIDIA GeForce Experience',
        'NvContainer', 'NvXDSync', 'NVIDIA Share'
    )

    Stop-DDUProcess -ProcessNames $gfeProcesses -DryRun:$DryRun

    # Remove GFE services
    $gfeServices = @(
        'GfExperienceService', 'NvContainerLocalSystem',
        'NvContainerNetworkService', 'NVDisplay.ContainerLocalSystem'
    )

    foreach ($service in $gfeServices) {
        Remove-DDUService -ServiceName $service -DryRun:$DryRun | Out-Null
    }

    # Remove GFE registry keys
    $gfeKeys = @(
        'HKLM:\Software\NVIDIA Corporation\NvContainer',
        'HKLM:\Software\NVIDIA Corporation\Global\GFExperience'
    )

    foreach ($key in $gfeKeys) {
        Remove-DDURegistryKey -KeyPath $key -DryRun:$DryRun -Force | Out-Null
    }

    # Remove GFE directories
    $gfeDirs = @(
        "$env:ProgramFiles\NVIDIA Corporation\NvContainer",
        "$env:ProgramFiles\NVIDIA Corporation\NvStreamSrv",
        "$env:ProgramFiles\NVIDIA Corporation\NVIDIA GeForce Experience",
        "$env:ProgramData\NVIDIA Corporation\GeForce Experience"
    )

    foreach ($dir in $gfeDirs) {
        Remove-DDUDirectory -DirectoryPath $dir -DryRun:$DryRun -Force | Out-Null
    }

    Write-DDULog "GeForce Experience removal completed" -Level Success
}

<#
.SYNOPSIS
    Removes NVIDIA Broadcast

.PARAMETER DryRun
    Simulate without removing
#>
function Remove-NVIDIABroadcast {
    [CmdletBinding(SupportsShouldProcess=$true)]
    param(
        [Parameter()]
        [switch]$DryRun
    )

    Write-DDULog "Removing NVIDIA Broadcast..." -Level Info

    # Stop Broadcast process
    Stop-DDUProcess -ProcessNames @('NVIDIA Broadcast') -DryRun:$DryRun

    # Remove Broadcast directories
    $broadcastDirs = @(
        "$env:ProgramFiles\NVIDIA Corporation\NVIDIA Broadcast",
        "$env:ProgramData\NVIDIA Corporation\NVIDIA Broadcast"
    )

    foreach ($dir in $broadcastDirs) {
        Remove-DDUDirectory -DirectoryPath $dir -DryRun:$DryRun -Force | Out-Null
    }

    Write-DDULog "NVIDIA Broadcast removal completed" -Level Success
}

<#
.SYNOPSIS
    Removes additional NVIDIA registry entries

.PARAMETER DryRun
    Simulate without removing
#>
function Remove-NVIDIARegistryExtras {
    [CmdletBinding(SupportsShouldProcess=$true)]
    param(
        [Parameter()]
        [switch]$DryRun
    )

    # Remove from run keys
    $runKeys = @(
        'HKLM:\Software\Microsoft\Windows\CurrentVersion\Run',
        'HKLM:\Software\Wow6432Node\Microsoft\Windows\CurrentVersion\Run',
        'HKCU:\Software\Microsoft\Windows\CurrentVersion\Run'
    )

    foreach ($runKey in $runKeys) {
        if (Test-Path $runKey) {
            $values = Get-ItemProperty -Path $runKey -ErrorAction SilentlyContinue
            if ($values) {
                $values.PSObject.Properties | Where-Object {
                    $_.Name -match 'NVIDIA|NvBackend|ShadowPlay'
                } | ForEach-Object {
                    Remove-DDURegistryValue -KeyPath $runKey -ValueName $_.Name -DryRun:$DryRun | Out-Null
                }
            }
        }
    }

    # Remove OpenCL/Vulkan entries
    $khronosPath = 'HKLM:\Software\Khronos\OpenCL\Vendors'
    if (Test-Path $khronosPath) {
        $values = Get-ItemProperty -Path $khronosPath -ErrorAction SilentlyContinue
        if ($values) {
            $values.PSObject.Properties | Where-Object {
                $_.Name -match 'nvopencl'
            } | ForEach-Object {
                Remove-DDURegistryValue -KeyPath $khronosPath -ValueName $_.Name -DryRun:$DryRun | Out-Null
            }
        }
    }

    $vulkanPath = 'HKLM:\Software\Khronos\Vulkan\Drivers'
    if (Test-Path $vulkanPath) {
        $values = Get-ItemProperty -Path $vulkanPath -ErrorAction SilentlyContinue
        if ($values) {
            $values.PSObject.Properties | Where-Object {
                $_.Name -match 'nv.*vulkan'
            } | ForEach-Object {
                Remove-DDURegistryValue -KeyPath $vulkanPath -ValueName $_.Name -DryRun:$DryRun | Out-Null
            }
        }
    }
}

<#
.SYNOPSIS
    Removes additional NVIDIA files

.PARAMETER DryRun
    Simulate without removing
#>
function Remove-NVIDIAFileExtras {
    [CmdletBinding(SupportsShouldProcess=$true)]
    param(
        [Parameter()]
        [switch]$DryRun
    )

    # Remove desktop shortcuts
    $desktopPaths = @(
        "$env:Public\Desktop",
        "$env:USERPROFILE\Desktop"
    )

    foreach ($desktopPath in $desktopPaths) {
        Remove-DDUFilesByPattern -DirectoryPath $desktopPath -Pattern '*NVIDIA*.lnk' -DryRun:$DryRun | Out-Null
    }

    # Remove Start Menu shortcuts
    $startMenuPaths = @(
        "$env:ProgramData\Microsoft\Windows\Start Menu\Programs",
        "$env:APPDATA\Microsoft\Windows\Start Menu\Programs"
    )

    foreach ($startMenuPath in $startMenuPaths) {
        Remove-DDUDirectoriesByPattern -BaseDirectory $startMenuPath -Pattern '*NVIDIA*' -DryRun:$DryRun | Out-Null
    }

    # Remove system driver files
    $systemDrivers = "$env:SystemRoot\System32\drivers"
    $nvidiaDriverPatterns = @('nv*.sys', 'nv*.dll')

    foreach ($pattern in $nvidiaDriverPatterns) {
        Remove-DDUFilesByPattern -DirectoryPath $systemDrivers -Pattern $pattern -DryRun:$DryRun | Out-Null
    }
}

<#
.SYNOPSIS
    Removes NVIDIA UpdatusUser account

.PARAMETER DryRun
    Simulate without removing
#>
function Remove-NVIDIAUpdatusUser {
    [CmdletBinding(SupportsShouldProcess=$true)]
    param(
        [Parameter()]
        [switch]$DryRun
    )

    try {
        $user = Get-LocalUser -Name 'UpdatusUser' -ErrorAction SilentlyContinue

        if ($user) {
            if ($DryRun) {
                Write-DDULog "Would remove user account: UpdatusUser" -Level Verbose
            } else {
                Remove-LocalUser -Name 'UpdatusUser' -ErrorAction Stop
                Write-DDULog "Removed user account: UpdatusUser" -Level Success
            }
        }
    } catch {
        Write-DDULog "Error removing UpdatusUser account: $_" -Level Warning
    }
}

# Export module members
Export-ModuleMember -Function @(
    'Invoke-DDUCleanupNVIDIA'
)
