<#
.SYNOPSIS
    DDU AMD-Specific Cleanup Module

.DESCRIPTION
    Handles AMD-specific cleanup operations
#>

<#
.SYNOPSIS
    Main AMD cleanup function

.PARAMETER Config
    Configuration hashtable
#>
function Invoke-DDUCleanupAMD {
    [CmdletBinding(SupportsShouldProcess=$true)]
    param(
        [Parameter(Mandatory=$true)]
        [hashtable]$Config
    )

    Write-DDUSectionHeader "AMD Driver Cleanup"

    # Execute base cleanup
    $result = Invoke-DDUCleanup -Config $Config

    # AMD-specific additional cleanup
    Write-DDUSectionHeader "AMD-Specific Cleanup"

    # Remove AMD/ATI registry extras
    Remove-AMDRegistryExtras -DryRun:$Config.DryRun

    # Remove AMD file extras
    Remove-AMDFileExtras -DryRun:$Config.DryRun

    # Remove AMD Catalyst/Radeon Software
    Remove-AMDCatalystSoftware -DryRun:$Config.DryRun

    # Clean AMD installer remnants
    Remove-AMDInstallerRemnants -DryRun:$Config.DryRun

    Write-DDULog "AMD cleanup completed" -Level Success
}

<#
.SYNOPSIS
    Removes additional AMD registry entries

.PARAMETER DryRun
    Simulate without removing
#>
function Remove-AMDRegistryExtras {
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
                    $_.Name -match 'AMD|ATI|Radeon|StartCN|StartCCC'
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
                $_.Name -match 'amdocl|atiocl'
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
                $_.Name -match 'amd.*vulkan|ati.*vulkan'
            } | ForEach-Object {
                Remove-DDURegistryValue -KeyPath $vulkanPath -ValueName $_.Name -DryRun:$DryRun | Out-Null
            }
        }
    }

    # Remove AMD-specific registry paths
    $amdKeys = @(
        'HKLM:\Software\AMD\CN',
        'HKLM:\Software\AMD\Install',
        'HKCU:\Software\AMD\DVR',
        'HKCU:\Software\ATI\ACE'
    )

    foreach ($key in $amdKeys) {
        Remove-DDURegistryKey -KeyPath $key -DryRun:$DryRun -Force | Out-Null
    }
}

<#
.SYNOPSIS
    Removes additional AMD files

.PARAMETER DryRun
    Simulate without removing
#>
function Remove-AMDFileExtras {
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
        Remove-DDUFilesByPattern -DirectoryPath $desktopPath -Pattern '*AMD*.lnk' -DryRun:$DryRun | Out-Null
        Remove-DDUFilesByPattern -DirectoryPath $desktopPath -Pattern '*ATI*.lnk' -DryRun:$DryRun | Out-Null
        Remove-DDUFilesByPattern -DirectoryPath $desktopPath -Pattern '*Radeon*.lnk' -DryRun:$DryRun | Out-Null
    }

    # Remove Start Menu shortcuts
    $startMenuPaths = @(
        "$env:ProgramData\Microsoft\Windows\Start Menu\Programs",
        "$env:APPDATA\Microsoft\Windows\Start Menu\Programs"
    )

    foreach ($startMenuPath in $startMenuPaths) {
        Remove-DDUDirectoriesByPattern -BaseDirectory $startMenuPath -Pattern '*AMD*' -DryRun:$DryRun | Out-Null
        Remove-DDUDirectoriesByPattern -BaseDirectory $startMenuPath -Pattern '*ATI*' -DryRun:$DryRun | Out-Null
        Remove-DDUDirectoriesByPattern -BaseDirectory $startMenuPath -Pattern '*Radeon*' -DryRun:$DryRun | Out-Null
    }

    # Remove system driver files
    $systemDrivers = "$env:SystemRoot\System32\drivers"
    $amdDriverPatterns = @('amd*.sys', 'ati*.sys', 'amd*.dll', 'ati*.dll')

    foreach ($pattern in $amdDriverPatterns) {
        Remove-DDUFilesByPattern -DirectoryPath $systemDrivers -Pattern $pattern -DryRun:$DryRun | Out-Null
    }

    # Remove Windows root files
    $windowsRoot = $env:SystemRoot
    $amdRootFiles = @('ati*.ace', 'ati*.bin', 'atiogl.xml')

    foreach ($file in $amdRootFiles) {
        Remove-DDUFilesByPattern -DirectoryPath $windowsRoot -Pattern $file -DryRun:$DryRun | Out-Null
    }

    # Remove AMD folders in System32
    $system32AMD = "$env:SystemRoot\System32\AMD"
    if (Test-Path $system32AMD) {
        Remove-DDUDirectory -DirectoryPath $system32AMD -DryRun:$DryRun -Force | Out-Null
    }
}

<#
.SYNOPSIS
    Removes AMD Catalyst/Radeon Software

.PARAMETER DryRun
    Simulate without removing
#>
function Remove-AMDCatalystSoftware {
    [CmdletBinding(SupportsShouldProcess=$true)]
    param(
        [Parameter()]
        [switch]$DryRun
    )

    Write-DDULog "Removing AMD Catalyst/Radeon Software..." -Level Info

    # Stop AMD processes
    $amdProcesses = @(
        'RadeonSoftware', 'AMDRSServ', 'cncmd', 'AUEPMaster',
        'CN', 'CCC', 'MOM', 'CLI', 'atiesrxx', 'atieclxx'
    )

    Stop-DDUProcess -ProcessNames $amdProcesses -DryRun:$DryRun

    # Remove Radeon Software directories
    $radeonDirs = @(
        "$env:ProgramFiles\AMD\CNext",
        "$env:ProgramFiles\AMD\CIM",
        "${env:ProgramFiles(x86)}\AMD\CNext",
        "${env:ProgramFiles(x86)}\AMD\CIM",
        "$env:ProgramData\AMD\PPC"
    )

    foreach ($dir in $radeonDirs) {
        Remove-DDUDirectory -DirectoryPath $dir -DryRun:$DryRun -Force | Out-Null
    }

    # Remove Catalyst Control Center directories
    $cccDirs = @(
        "$env:ProgramFiles\ATI Technologies\ATI.ACE",
        "${env:ProgramFiles(x86)}\ATI Technologies\ATI.ACE",
        "$env:ProgramData\ATI\ACE"
    )

    foreach ($dir in $cccDirs) {
        Remove-DDUDirectory -DirectoryPath $dir -DryRun:$DryRun -Force | Out-Null
    }

    Write-DDULog "AMD Catalyst/Radeon Software removal completed" -Level Success
}

<#
.SYNOPSIS
    Removes AMD installer remnants

.PARAMETER DryRun
    Simulate without removing
#>
function Remove-AMDInstallerRemnants {
    [CmdletBinding(SupportsShouldProcess=$true)]
    param(
        [Parameter()]
        [switch]$DryRun
    )

    # Remove AMD installer directories
    $installerDirs = @(
        "$env:SystemDrive\AMD",
        "$env:ProgramData\Package Cache\AMD",
        "$env:ProgramData\AMD\PPC"
    )

    foreach ($dir in $installerDirs) {
        Remove-DDUDirectory -DirectoryPath $dir -DryRun:$DryRun -Force | Out-Null
    }

    # Remove installer temp files
    $profiles = Get-DDUUserProfiles

    foreach ($profile in $profiles) {
        $tempDirs = @(
            "$profile\AppData\Local\Temp\AMD",
            "$profile\AppData\Local\AMD\CN"
        )

        foreach ($dir in $tempDirs) {
            Remove-DDUDirectory -DirectoryPath $dir -DryRun:$DryRun -Force | Out-Null
        }
    }
}

# Export module members
Export-ModuleMember -Function @(
    'Invoke-DDUCleanupAMD'
)
