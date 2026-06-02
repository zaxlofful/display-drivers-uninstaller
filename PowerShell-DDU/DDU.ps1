<#
.SYNOPSIS
    Display Driver Uninstaller (DDU) - Pure PowerShell Implementation

.DESCRIPTION
    Complete PowerShell reimplementation of Display Driver Uninstaller (DDU) for thorough removal
    of NVIDIA, AMD, and Intel display drivers from Windows 10/11 systems.

    This implementation provides behavioral parity with the original VB.NET DDU application,
    including comprehensive cleanup of:
    - Display driver packages and files
    - Registry entries and device configurations
    - Services, scheduled tasks, and startup items
    - Vendor applications and utilities
    - Shader caches and temporary files
    - Windows Update driver store entries

.PARAMETER Vendor
    GPU vendor to clean: NVIDIA, AMD, or Intel

.PARAMETER DryRun
    Simulates cleanup without making actual changes (logs actions)

.PARAMETER RemoveAudio
    Also removes audio drivers associated with the GPU vendor

.PARAMETER RemovePhysX
    Also removes NVIDIA PhysX SDK (NVIDIA only)

.PARAMETER Remove3DVision
    Also removes NVIDIA 3D Vision components (NVIDIA only)

.PARAMETER RemoveGeForceExperience
    Also removes NVIDIA GeForce Experience (NVIDIA only)

.PARAMETER RemoveNVBroadcast
    Also removes NVIDIA Broadcast app (NVIDIA only)

.PARAMETER RemoveArcControl
    Also removes Intel Arc Control (Intel only)

.PARAMETER RemoveOneAPI
    Also removes Intel One API SDK (Intel only)

.PARAMETER CleanShaderCache
    Removes DirectX/OpenGL/Vulkan shader caches

.PARAMETER SkipDeviceRemoval
    Skips physical device removal (registry and file cleanup only)

.PARAMETER PreventWindowsUpdate
    Prevents Windows Update from reinstalling drivers

.PARAMETER CreateRestorePoint
    Creates a System Restore point before cleanup

.PARAMETER LogPath
    Custom path for log file (default: .\DDU_Log.txt)

.PARAMETER Verbose
    Enables detailed logging output

.EXAMPLE
    .\DDU.ps1 -Vendor NVIDIA -DryRun
    Simulates NVIDIA driver cleanup without making changes

.EXAMPLE
    .\DDU.ps1 -Vendor AMD -RemoveAudio -CleanShaderCache -CreateRestorePoint
    Removes AMD drivers, audio components, and shader caches with restore point

.EXAMPLE
    .\DDU.ps1 -Vendor Intel -RemoveArcControl -PreventWindowsUpdate
    Removes Intel drivers and Arc Control, prevents Windows Update driver installation

.NOTES
    Version:        1.0.0
    Author:         PowerShell DDU Project
    Creation Date:  2026-06-02

    Requirements:
    - Windows 10/11
    - PowerShell 5.1 or later
    - Administrator privileges
    - Safe Mode recommended for complete cleanup

    Based on Display Driver Uninstaller by Wagnardsoft
    https://github.com/Wagnard/display-driver-uninstaller
#>

[CmdletBinding(SupportsShouldProcess=$true)]
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
    [switch]$Verbose
)

#Requires -Version 5.1
#Requires -RunAsAdministrator

# Set strict mode for better error detection
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# Script root directory
$script:ScriptRoot = $PSScriptRoot

# Import required modules
$ModulesPath = Join-Path $ScriptRoot 'Modules'

try {
    Write-Host "Display Driver Uninstaller (DDU) - PowerShell Edition" -ForegroundColor Cyan
    Write-Host "======================================================" -ForegroundColor Cyan
    Write-Host ""

    # Load all required modules
    Write-Host "Loading modules..." -ForegroundColor Yellow

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
        $modulePath = Join-Path $ModulesPath $module
        if (Test-Path $modulePath) {
            Import-Module $modulePath -Force -DisableNameChecking
            Write-Verbose "Loaded module: $module"
        } else {
            Write-Warning "Module not found: $module"
        }
    }

    # Initialize logging
    Initialize-DDULogging -LogPath $LogPath -Verbose:$Verbose
    Write-DDULog "=== Display Driver Uninstaller - PowerShell Edition ===" -Level Info
    Write-DDULog "Started at: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')" -Level Info
    Write-DDULog "Vendor: $Vendor" -Level Info
    Write-DDULog "Dry Run: $DryRun" -Level Info

    # Check prerequisites
    Write-Host "Checking prerequisites..." -ForegroundColor Yellow

    # Verify administrator privileges
    if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
        throw "This script requires administrator privileges. Please run as Administrator."
    }
    Write-DDULog "Administrator privileges verified" -Level Info

    # Check Windows version
    $osVersion = [System.Environment]::OSVersion.Version
    if ($osVersion.Major -lt 10) {
        throw "This script requires Windows 10 or later. Current version: $($osVersion.ToString())"
    }
    Write-DDULog "Windows version: $($osVersion.ToString())" -Level Info

    # Detect Safe Mode
    $safeMode = Test-DDUSafeMode
    if ($safeMode) {
        Write-Host "Safe Mode detected - optimal for driver cleanup" -ForegroundColor Green
        Write-DDULog "Running in Safe Mode" -Level Info
    } else {
        Write-Host "WARNING: Not running in Safe Mode. Some cleanup operations may be incomplete." -ForegroundColor Yellow
        Write-DDULog "Not running in Safe Mode - some operations may fail" -Level Warning
    }

    # Build configuration object
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
        VerboseLogging = $Verbose
        ScriptRoot = $ScriptRoot
        ConfigPath = Join-Path $ScriptRoot 'Config'
        SafeMode = $safeMode
    }

    # Create system restore point if requested
    if ($CreateRestorePoint -and -not $DryRun) {
        Write-Host "Creating system restore point..." -ForegroundColor Yellow
        try {
            Enable-ComputerRestore -Drive "$env:SystemDrive\"
            Checkpoint-Computer -Description "DDU - Before $Vendor driver cleanup" -RestorePointType MODIFY_SETTINGS
            Write-DDULog "System restore point created successfully" -Level Info
            Write-Host "System restore point created" -ForegroundColor Green
        } catch {
            Write-DDULog "Failed to create system restore point: $_" -Level Warning
            Write-Host "Warning: Could not create system restore point" -ForegroundColor Yellow
        }
    }

    # Display configuration summary
    Write-Host ""
    Write-Host "Configuration Summary:" -ForegroundColor Cyan
    Write-Host "=====================" -ForegroundColor Cyan
    Write-Host "Vendor:                    $Vendor"
    Write-Host "Dry Run Mode:              $DryRun"
    Write-Host "Remove Audio:              $RemoveAudio"
    Write-Host "Clean Shader Cache:        $CleanShaderCache"
    Write-Host "Skip Device Removal:       $SkipDeviceRemoval"
    Write-Host "Prevent Windows Update:    $PreventWindowsUpdate"
    Write-Host "Safe Mode:                 $safeMode"
    if ($Vendor -eq 'NVIDIA') {
        Write-Host "Remove PhysX:              $RemovePhysX"
        Write-Host "Remove 3D Vision:          $Remove3DVision"
        Write-Host "Remove GeForce Experience: $RemoveGeForceExperience"
        Write-Host "Remove NV Broadcast:       $RemoveNVBroadcast"
    } elseif ($Vendor -eq 'Intel') {
        Write-Host "Remove Arc Control:        $RemoveArcControl"
        Write-Host "Remove One API:            $RemoveOneAPI"
    }
    Write-Host ""

    if ($DryRun) {
        Write-Host "DRY RUN MODE - No changes will be made" -ForegroundColor Yellow
        Write-Host ""
    }

    # Confirm before proceeding
    if (-not $DryRun) {
        $confirmation = Read-Host "Proceed with $Vendor driver cleanup? (yes/no)"
        if ($confirmation -ne 'yes') {
            Write-Host "Operation cancelled by user" -ForegroundColor Yellow
            Write-DDULog "Operation cancelled by user" -Level Info
            exit 0
        }
    }

    Write-Host ""
    Write-Host "Starting cleanup process..." -ForegroundColor Cyan
    Write-Host ""

    # Execute cleanup
    $startTime = Get-Date

    try {
        # Call vendor-specific cleanup function
        switch ($Vendor) {
            'NVIDIA' {
                Invoke-DDUCleanupNVIDIA -Config $config
            }
            'AMD' {
                Invoke-DDUCleanupAMD -Config $config
            }
            'Intel' {
                Invoke-DDUCleanupIntel -Config $config
            }
        }

        $endTime = Get-Date
        $duration = $endTime - $startTime

        Write-Host ""
        Write-Host "Cleanup completed successfully!" -ForegroundColor Green
        Write-Host "Duration: $($duration.ToString('mm\:ss'))" -ForegroundColor Green
        Write-DDULog "Cleanup completed in $($duration.TotalSeconds) seconds" -Level Info

        if (-not $DryRun) {
            Write-Host ""
            Write-Host "IMPORTANT: A system restart is required to complete the cleanup." -ForegroundColor Yellow
            Write-Host "After restart, you can install new drivers." -ForegroundColor Yellow
            Write-Host ""

            $restart = Read-Host "Restart now? (yes/no)"
            if ($restart -eq 'yes') {
                Write-DDULog "Initiating system restart" -Level Info
                Restart-Computer -Force
            }
        }

    } catch {
        Write-Host ""
        Write-Host "ERROR: Cleanup failed" -ForegroundColor Red
        Write-Host $_.Exception.Message -ForegroundColor Red
        Write-DDULog "Cleanup failed: $($_.Exception.Message)" -Level Error
        Write-DDULog "Stack trace: $($_.ScriptStackTrace)" -Level Error
        throw
    }

} catch {
    Write-Host ""
    Write-Host "FATAL ERROR: $($_.Exception.Message)" -ForegroundColor Red
    Write-DDULog "Fatal error: $($_.Exception.Message)" -Level Error
    exit 1
} finally {
    Write-Host ""
    Write-Host "Log file: $LogPath" -ForegroundColor Cyan
    Write-DDULog "=== DDU session ended ===" -Level Info
}
