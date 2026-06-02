<#
.SYNOPSIS
    DDU Intel-Specific Cleanup Module

.DESCRIPTION
    Handles Intel-specific cleanup operations
#>

<#
.SYNOPSIS
    Main Intel cleanup function

.PARAMETER Config
    Configuration hashtable
#>
function Invoke-DDUCleanupIntel {
    [CmdletBinding(SupportsShouldProcess=$true)]
    param(
        [Parameter(Mandatory=$true)]
        [hashtable]$Config
    )

    Write-DDUSectionHeader "Intel Driver Cleanup"

    # Execute base cleanup
    $result = Invoke-DDUCleanup -Config $Config

    # Intel-specific additional cleanup
    Write-DDUSectionHeader "Intel-Specific Cleanup"

    # Remove Arc Control if requested
    if ($Config.RemoveArcControl) {
        Remove-IntelArcControl -DryRun:$Config.DryRun
    }

    # Remove One API if requested
    if ($Config.RemoveOneAPI) {
        Remove-IntelOneAPI -DryRun:$Config.DryRun
    }

    # Intel-specific registry cleanup
    Remove-IntelRegistryExtras -DryRun:$Config.DryRun

    # Intel-specific file cleanup
    Remove-IntelFileExtras -DryRun:$Config.DryRun

    # Remove Intel graphics software
    Remove-IntelGraphicsSoftware -DryRun:$Config.DryRun

    Write-DDULog "Intel cleanup completed" -Level Success
}

<#
.SYNOPSIS
    Removes Intel Arc Control

.PARAMETER DryRun
    Simulate without removing
#>
function Remove-IntelArcControl {
    [CmdletBinding(SupportsShouldProcess=$true)]
    param(
        [Parameter()]
        [switch]$DryRun
    )

    Write-DDULog "Removing Intel Arc Control..." -Level Info

    # Stop Arc Control processes
    $arcProcesses = @(
        'ArcControl', 'ArcControlAssist', 'ArcControlLauncher',
        'ArcControlPostProcessing'
    )

    Stop-DDUProcess -ProcessNames $arcProcesses -DryRun:$DryRun

    # Remove Arc Control registry keys
    $arcKeys = @(
        'HKLM:\Software\Intel\ArcControl',
        'HKCU:\Software\Intel\ArcControl'
    )

    foreach ($key in $arcKeys) {
        Remove-DDURegistryKey -KeyPath $key -DryRun:$DryRun -Force | Out-Null
    }

    # Remove Arc Control directories
    $arcDirs = @(
        "$env:ProgramFiles\Intel\Arc Control",
        "${env:ProgramFiles(x86)}\Intel\Arc Control",
        "$env:ProgramData\Intel\ArcControl"
    )

    foreach ($dir in $arcDirs) {
        Remove-DDUDirectory -DirectoryPath $dir -DryRun:$DryRun -Force | Out-Null
    }

    # Remove user profile Arc Control data
    $profiles = Get-DDUUserProfiles

    foreach ($profile in $profiles) {
        $arcUserDirs = @(
            "$profile\AppData\Local\Intel\ArcControl",
            "$profile\AppData\Roaming\Intel\ArcControl"
        )

        foreach ($dir in $arcUserDirs) {
            Remove-DDUDirectory -DirectoryPath $dir -DryRun:$DryRun -Force | Out-Null
        }
    }

    Write-DDULog "Intel Arc Control removal completed" -Level Success
}

<#
.SYNOPSIS
    Removes Intel One API

.PARAMETER DryRun
    Simulate without removing
#>
function Remove-IntelOneAPI {
    [CmdletBinding(SupportsShouldProcess=$true)]
    param(
        [Parameter()]
        [switch]$DryRun
    )

    Write-DDULog "Removing Intel One API..." -Level Info

    # Remove One API directories
    $oneAPIDirs = @(
        "$env:ProgramFiles\Intel\oneAPI",
        "${env:ProgramFiles(x86)}\Intel\oneAPI",
        "$env:ProgramData\Intel\oneAPI"
    )

    foreach ($dir in $oneAPIDirs) {
        Remove-DDUDirectory -DirectoryPath $dir -DryRun:$DryRun -Force | Out-Null
    }

    # Remove One API registry keys
    $oneAPIKeys = @(
        'HKLM:\Software\Intel\oneAPI',
        'HKLM:\Software\Wow6432Node\Intel\oneAPI'
    )

    foreach ($key in $oneAPIKeys) {
        Remove-DDURegistryKey -KeyPath $key -DryRun:$DryRun -Force | Out-Null
    }

    Write-DDULog "Intel One API removal completed" -Level Success
}

<#
.SYNOPSIS
    Removes additional Intel registry entries

.PARAMETER DryRun
    Simulate without removing
#>
function Remove-IntelRegistryExtras {
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
                    $_.Name -match 'igfx|Intel.*Graphics|Arc'
                } | ForEach-Object {
                    Remove-DDURegistryValue -KeyPath $runKey -ValueName $_.Name -DryRun:$DryRun | Out-Null
                }
            }
        }
    }

    # Remove OpenCL entries
    $openclPath = 'HKLM:\Software\Khronos\OpenCL\Vendors'
    if (Test-Path $openclPath) {
        $values = Get-ItemProperty -Path $openclPath -ErrorAction SilentlyContinue
        if ($values) {
            $values.PSObject.Properties | Where-Object {
                $_.Name -match 'intelopencl|intel_opencl'
            } | ForEach-Object {
                Remove-DDURegistryValue -KeyPath $openclPath -ValueName $_.Name -DryRun:$DryRun | Out-Null
            }
        }
    }

    # Remove Vulkan entries
    $vulkanPath = 'HKLM:\Software\Khronos\Vulkan\Drivers'
    if (Test-Path $vulkanPath) {
        $values = Get-ItemProperty -Path $vulkanPath -ErrorAction SilentlyContinue
        if ($values) {
            $values.PSObject.Properties | Where-Object {
                $_.Name -match 'intel.*vulkan'
            } | ForEach-Object {
                Remove-DDURegistryValue -KeyPath $vulkanPath -ValueName $_.Name -DryRun:$DryRun | Out-Null
            }
        }
    }

    # Remove Intel-specific registry paths
    $intelKeys = @(
        'HKLM:\Software\Intel\IGX',
        'HKLM:\Software\Intel\IntelDTT',
        'HKCU:\Software\Intel\IGX'
    )

    foreach ($key in $intelKeys) {
        Remove-DDURegistryKey -KeyPath $key -DryRun:$DryRun -Force | Out-Null
    }
}

<#
.SYNOPSIS
    Removes additional Intel files

.PARAMETER DryRun
    Simulate without removing
#>
function Remove-IntelFileExtras {
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
        Remove-DDUFilesByPattern -DirectoryPath $desktopPath -Pattern '*Intel*Graphics*.lnk' -DryRun:$DryRun | Out-Null
        Remove-DDUFilesByPattern -DirectoryPath $desktopPath -Pattern '*Arc*.lnk' -DryRun:$DryRun | Out-Null
    }

    # Remove Start Menu shortcuts
    $startMenuPaths = @(
        "$env:ProgramData\Microsoft\Windows\Start Menu\Programs",
        "$env:APPDATA\Microsoft\Windows\Start Menu\Programs"
    )

    foreach ($startMenuPath in $startMenuPaths) {
        Remove-DDUDirectoriesByPattern -BaseDirectory $startMenuPath -Pattern '*Intel*Graphics*' -DryRun:$DryRun | Out-Null
        Remove-DDUDirectoriesByPattern -BaseDirectory $startMenuPath -Pattern '*Arc*' -DryRun:$DryRun | Out-Null
    }

    # Remove system driver files
    $systemDrivers = "$env:SystemRoot\System32\drivers"
    $intelDriverPatterns = @('igfx*.sys', 'igfx*.dll', 'ig*.sys')

    foreach ($pattern in $intelDriverPatterns) {
        Remove-DDUFilesByPattern -DirectoryPath $systemDrivers -Pattern $pattern -DryRun:$DryRun | Out-Null
    }

    # Remove System32 Intel graphics files
    $system32 = "$env:SystemRoot\System32"
    $intelFilePatterns = @('igfx*.exe', 'igfx*.dll', 'ig*.dll')

    foreach ($pattern in $intelFilePatterns) {
        Remove-DDUFilesByPattern -DirectoryPath $system32 -Pattern $pattern -DryRun:$DryRun | Out-Null
    }

    # Remove user profile Intel graphics profiles
    $profiles = Get-DDUUserProfiles

    foreach ($profile in $profiles) {
        $profileFile = "$profile\IntelGraphicsProfiles"
        if (Test-Path $profileFile) {
            Remove-DDUDirectory -DirectoryPath $profileFile -DryRun:$DryRun -Force | Out-Null
        }
    }
}

<#
.SYNOPSIS
    Removes Intel Graphics Software

.PARAMETER DryRun
    Simulate without removing
#>
function Remove-IntelGraphicsSoftware {
    [CmdletBinding(SupportsShouldProcess=$true)]
    param(
        [Parameter()]
        [switch]$DryRun
    )

    Write-DDULog "Removing Intel Graphics Software..." -Level Info

    # Stop Intel graphics processes
    $intelProcesses = @(
        'IntelGraphicsSoftware', 'igfxEM', 'igfxHK', 'igfxTray',
        'igfxCUIService', 'GfxUIEx'
    )

    Stop-DDUProcess -ProcessNames $intelProcesses -DryRun:$DryRun

    # Remove Intel Graphics Software directories
    $graphicsDirs = @(
        "$env:ProgramFiles\Intel\Graphics",
        "${env:ProgramFiles(x86)}\Intel\Graphics",
        "$env:ProgramData\Intel\Graphics"
    )

    foreach ($dir in $graphicsDirs) {
        Remove-DDUDirectory -DirectoryPath $dir -DryRun:$DryRun -Force | Out-Null
    }

    # Remove Media SDK directories
    $mediaDirs = @(
        "$env:ProgramFiles\Intel\Media SDK",
        "${env:ProgramFiles(x86)}\Intel\Media SDK"
    )

    foreach ($dir in $mediaDirs) {
        Remove-DDUDirectory -DirectoryPath $dir -DryRun:$DryRun -Force | Out-Null
    }

    Write-DDULog "Intel Graphics Software removal completed" -Level Success
}

# Export module members
Export-ModuleMember -Function @(
    'Invoke-DDUCleanupIntel'
)
