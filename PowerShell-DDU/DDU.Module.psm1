<#
.SYNOPSIS
    Display Driver Uninstaller (DDU) module entry point.

.DESCRIPTION
    Exposes an importable PowerShell function for orchestrating complete NVIDIA/AMD/Intel
    display driver cleanup with the same workflow used by the standalone DDU.ps1 script.
#>

function Invoke-DDUDriverCleanup {
    [CmdletBinding(SupportsShouldProcess=$true)]
    [OutputType([PSCustomObject])]
    param(
        [Parameter(Mandatory=$true, Position=0)]
        [ValidateSet('NVIDIA', 'AMD', 'Intel')]
        [string]$Vendor,

        [Parameter()]
        [switch]$DryRun,

        [Parameter()]
        [switch]$RemoveAudio,

        [Parameter()]
        [switch]$RemovePhysX,

        [Parameter()]
        [switch]$Remove3DVision,

        [Parameter()]
        [switch]$RemoveGeForceExperience,

        [Parameter()]
        [switch]$RemoveNVBroadcast,

        [Parameter()]
        [switch]$RemoveArcControl,

        [Parameter()]
        [switch]$RemoveOneAPI,

        [Parameter()]
        [switch]$CleanShaderCache,

        [Parameter()]
        [switch]$SkipDeviceRemoval,

        [Parameter()]
        [switch]$PreventWindowsUpdate,

        [Parameter()]
        [switch]$CreateRestorePoint,

        [Parameter()]
        [string]$LogPath = ".\DDU_Log_$(Get-Date -Format 'yyyyMMdd_HHmmss').txt",

        [Parameter()]
        [switch]$VerboseLogging,

        [Parameter()]
        [switch]$Force,

        [Parameter()]
        [switch]$NoRestartPrompt,

        [Parameter()]
        [switch]$Restart
    )

    Set-StrictMode -Version Latest
    $ErrorActionPreference = 'Stop'

    $scriptRoot = $PSScriptRoot
    $modulesPath = Join-Path $scriptRoot 'Modules'

    $modulesToLoad = @(
        'DDU.Logging.psm1',
        'DDU.Utils.psm1',
        'DDU.Registry.psm1',
        'DDU.FileSystem.psm1',
        'DDU.Services.psm1',
        'DDU.Devices.psm1',
        'DDU.Detection.psm1',
        'DDU.Cleanup.psm1',
        "DDU.Cleanup.$Vendor.psm1"
    )

    foreach ($module in $modulesToLoad) {
        $modulePath = Join-Path $modulesPath $module
        if (-not (Test-Path $modulePath)) {
            throw "Required module not found: $modulePath"
        }

        Import-Module $modulePath -Force -DisableNameChecking
    }

    Initialize-DDULogging -LogPath $LogPath -Verbose:$VerboseLogging
    Write-DDULog "=== Display Driver Uninstaller - PowerShell Edition ===" -Level Info
    Write-DDULog "Started at: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')" -Level Info
    Write-DDULog "Vendor: $Vendor" -Level Info
    Write-DDULog "Dry Run: $DryRun" -Level Info

    $safeMode = $false
    $result = $null
    $startTime = Get-Date

    try {
        if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
            throw "This script requires administrator privileges. Please run as Administrator."
        }

        $osVersion = [System.Environment]::OSVersion.Version
        if ($osVersion.Major -lt 10) {
            throw "This script requires Windows 10 or later. Current version: $($osVersion.ToString())"
        }

        $safeMode = Test-DDUSafeMode
        if ($safeMode) {
            Write-DDULog "Running in Safe Mode" -Level Info
        } else {
            Write-DDULog "Not running in Safe Mode - some operations may fail" -Level Warning
        }

        $config = @{
            Vendor = $Vendor
            DryRun = $DryRun
            RemoveAudio = $RemoveAudio
            RemovePhysX = $RemovePhysX
            Remove3DVision = $Remove3DVision
            RemoveGeForceExperience = $RemoveGeForceExperience
            RemoveNVBroadcast = $RemoveNVBroadcast
            RemoveArcControl = $RemoveArcControl
            RemoveOneAPI = $RemoveOneAPI
            CleanShaderCache = $CleanShaderCache
            SkipDeviceRemoval = $SkipDeviceRemoval
            PreventWindowsUpdate = $PreventWindowsUpdate
            CreateRestorePoint = $CreateRestorePoint
            LogPath = $LogPath
            VerboseLogging = $VerboseLogging
            ScriptRoot = $scriptRoot
            ConfigPath = Join-Path $scriptRoot 'Config'
            SafeMode = $safeMode
        }

        if ($CreateRestorePoint -and -not $DryRun) {
            try {
                Enable-ComputerRestore -Drive "$env:SystemDrive\"
                Checkpoint-Computer -Description "DDU - Before $Vendor driver cleanup" -RestorePointType MODIFY_SETTINGS
                Write-DDULog "System restore point created successfully" -Level Info
            } catch {
                Write-DDULog "Failed to create system restore point: $_" -Level Warning
            }
        }

        if (-not $DryRun -and -not $Force) {
            $confirmation = Read-Host "Proceed with $Vendor driver cleanup? (yes/no)"
            if ($confirmation -ne 'yes') {
                Write-DDULog "Operation cancelled by user" -Level Info
                return [PSCustomObject]@{
                    Success = $false
                    Cancelled = $true
                    Vendor = $Vendor
                    LogPath = $LogPath
                    SafeMode = $safeMode
                    Duration = [TimeSpan]::Zero
                }
            }
        }

        switch ($Vendor) {
            'NVIDIA' { $result = Invoke-DDUCleanupNVIDIA -Config $config }
            'AMD'    { $result = Invoke-DDUCleanupAMD -Config $config }
            'Intel'  { $result = Invoke-DDUCleanupIntel -Config $config }
        }

        $duration = (Get-Date) - $startTime
        Write-DDULog "Cleanup completed in $($duration.TotalSeconds) seconds" -Level Info

        if (-not $DryRun -and $Restart) {
            Write-DDULog "Initiating system restart" -Level Info
            Restart-Computer -Force
        } elseif (-not $DryRun -and -not $NoRestartPrompt) {
            $restartConfirmation = Read-Host "Restart now? (yes/no)"
            if ($restartConfirmation -eq 'yes') {
                Write-DDULog "Initiating system restart" -Level Info
                Restart-Computer -Force
            }
        }

        return [PSCustomObject]@{
            Success = $true
            Cancelled = $false
            Vendor = $Vendor
            SafeMode = $safeMode
            DryRun = [bool]$DryRun
            LogPath = $LogPath
            Duration = $duration
            Cleanup = $result
        }

    } catch {
        Write-DDULog "Cleanup failed: $($_.Exception.Message)" -Level Error
        Write-DDULog "Stack trace: $($_.ScriptStackTrace)" -Level Error
        throw
    } finally {
        Write-DDULog "=== DDU session ended ===" -Level Info
    }
}

Export-ModuleMember -Function Invoke-DDUDriverCleanup
