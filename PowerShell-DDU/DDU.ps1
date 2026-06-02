<#
.SYNOPSIS
    Display Driver Uninstaller (DDU) - Standalone script entry point.

.DESCRIPTION
    Thin wrapper around Invoke-DDUDriverCleanup for interactive execution.
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
    [switch]$Verbose,

    [Parameter()]
    [switch]$Force,

    [Parameter()]
    [switch]$NoRestartPrompt,

    [Parameter()]
    [switch]$Restart
)

#Requires -Version 5.1
#Requires -RunAsAdministrator

$modulePath = Join-Path $PSScriptRoot 'DDU.Module.psm1'
Import-Module $modulePath -Force -DisableNameChecking

try {
    Write-Host "Display Driver Uninstaller (DDU) - PowerShell Edition" -ForegroundColor Cyan
    Write-Host "======================================================" -ForegroundColor Cyan
    Write-Host ""

    $cleanupParams = @{
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
        Force = $Force
        NoRestartPrompt = $NoRestartPrompt
        Restart = $Restart
    }

    $result = Invoke-DDUDriverCleanup @cleanupParams

    if ($result.Cancelled) {
        Write-Host "Operation cancelled by user" -ForegroundColor Yellow
        exit 0
    }

    Write-Host ""
    Write-Host "Cleanup completed successfully!" -ForegroundColor Green
    Write-Host "Duration: $($result.Duration.ToString('mm\\:ss'))" -ForegroundColor Green

    if (-not $DryRun -and -not $Restart -and -not $NoRestartPrompt) {
        Write-Host ""
        Write-Host "IMPORTANT: A system restart is required to complete the cleanup." -ForegroundColor Yellow
        Write-Host "After restart, you can install new drivers." -ForegroundColor Yellow
    }

} catch {
    Write-Host ""
    Write-Host "FATAL ERROR: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
} finally {
    Write-Host ""
    Write-Host "Log file: $LogPath" -ForegroundColor Cyan
}
