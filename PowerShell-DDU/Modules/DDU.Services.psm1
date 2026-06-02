<#
.SYNOPSIS
    DDU Services Management Module

.DESCRIPTION
    Handles Windows service removal and management
#>

<#
.SYNOPSIS
    Stops and removes a Windows service

.PARAMETER ServiceName
    Name of the service to remove

.PARAMETER DryRun
    Simulate without removing
#>
function Remove-DDUService {
    [CmdletBinding(SupportsShouldProcess=$true)]
    param(
        [Parameter(Mandatory=$true)]
        [string]$ServiceName,

        [Parameter()]
        [switch]$DryRun
    )

    try {
        $service = Get-Service -Name $ServiceName -ErrorAction SilentlyContinue

        if (-not $service) {
            Write-DDULog "Service not found: $ServiceName" -Level Verbose
            return $false
        }

        if ($DryRun) {
            Write-DDULog "Would remove service: $ServiceName (Status: $($service.Status))" -Level Verbose
            return $true
        }

        Write-DDULog "Removing service: $ServiceName (Status: $($service.Status))" -Level Verbose

        # Stop service if running
        if ($service.Status -eq 'Running') {
            try {
                Stop-Service -Name $ServiceName -Force -ErrorAction Stop
                Write-DDULog "Service stopped: $ServiceName" -Level Verbose
            } catch {
                Write-DDULog "Failed to stop service ${ServiceName}: $_" -Level Warning
            }
        }

        # Remove service using sc.exe
        $result = & sc.exe delete $ServiceName 2>&1
        if ($LASTEXITCODE -eq 0) {
            Write-DDULog "Service removed: $ServiceName" -Level Success
            return $true
        } else {
            Write-DDULog "Failed to remove service ${ServiceName}: $result" -Level Warning
            return $false
        }

    } catch {
        Write-DDULog "Error removing service ${ServiceName}: $_" -Level Warning
        return $false
    }
}

<#
.SYNOPSIS
    Removes services matching a pattern

.PARAMETER Pattern
    Service name pattern (wildcards supported)

.PARAMETER DryRun
    Simulate without removing

.OUTPUTS
    Number of services removed
#>
function Remove-DDUServicesByPattern {
    [CmdletBinding(SupportsShouldProcess=$true)]
    [OutputType([int])]
    param(
        [Parameter(Mandatory=$true)]
        [string]$Pattern,

        [Parameter()]
        [switch]$DryRun
    )

    $removedCount = 0

    try {
        $services = Get-Service | Where-Object { $_.Name -like $Pattern }

        foreach ($service in $services) {
            if (Remove-DDUService -ServiceName $service.Name -DryRun:$DryRun) {
                $removedCount++
            }
        }

    } catch {
        Write-DDULog "Error removing services matching pattern ${Pattern}: $_" -Level Warning
    }

    return $removedCount
}

<#
.SYNOPSIS
    Removes services from a configuration file

.PARAMETER ConfigFile
    Path to configuration file containing service names

.PARAMETER DryRun
    Simulate without removing

.OUTPUTS
    Number of services removed
#>
function Remove-DDUServicesFromConfig {
    [CmdletBinding(SupportsShouldProcess=$true)]
    [OutputType([int])]
    param(
        [Parameter(Mandatory=$true)]
        [string]$ConfigFile,

        [Parameter()]
        [switch]$DryRun
    )

    $removedCount = 0

    $serviceNames = Get-DDUConfigFile -FilePath $ConfigFile -IgnoreComments

    foreach ($serviceName in $serviceNames) {
        if (Remove-DDUService -ServiceName $serviceName -DryRun:$DryRun) {
            $removedCount++
        }
    }

    Write-DDULog "Removed $removedCount services from config: $ConfigFile" -Level Info

    return $removedCount
}

<#
.SYNOPSIS
    Removes scheduled tasks matching a pattern

.PARAMETER Pattern
    Task name pattern (wildcards supported)

.PARAMETER DryRun
    Simulate without removing

.OUTPUTS
    Number of tasks removed
#>
function Remove-DDUScheduledTasksByPattern {
    [CmdletBinding(SupportsShouldProcess=$true)]
    [OutputType([int])]
    param(
        [Parameter(Mandatory=$true)]
        [string]$Pattern,

        [Parameter()]
        [switch]$DryRun
    )

    $removedCount = 0

    try {
        $tasks = Get-ScheduledTask -ErrorAction SilentlyContinue |
            Where-Object { $_.TaskName -like $Pattern }

        foreach ($task in $tasks) {
            try {
                if ($DryRun) {
                    Write-DDULog "Would remove scheduled task: $($task.TaskName)" -Level Verbose
                    $removedCount++
                } else {
                    Unregister-ScheduledTask -TaskName $task.TaskName -Confirm:$false -ErrorAction Stop
                    Write-DDULog "Removed scheduled task: $($task.TaskName)" -Level Success
                    $removedCount++
                }
            } catch {
                Write-DDULog "Failed to remove scheduled task $($task.TaskName): $_" -Level Warning
            }
        }

    } catch {
        Write-DDULog "Error removing scheduled tasks matching pattern ${Pattern}: $_" -Level Warning
    }

    return $removedCount
}

<#
.SYNOPSIS
    Removes vendor-specific services

.PARAMETER Vendor
    GPU vendor (NVIDIA, AMD, Intel)

.PARAMETER ConfigPath
    Path to configuration directory

.PARAMETER DryRun
    Simulate without removing

.OUTPUTS
    Number of services removed
#>
function Remove-DDUVendorServices {
    [CmdletBinding(SupportsShouldProcess=$true)]
    [OutputType([int])]
    param(
        [Parameter(Mandatory=$true)]
        [ValidateSet('NVIDIA', 'AMD', 'Intel')]
        [string]$Vendor,

        [Parameter(Mandatory=$true)]
        [string]$ConfigPath,

        [Parameter()]
        [switch]$DryRun
    )

    $removedCount = 0

    # Load service list from config
    $vendorConfigPath = Join-Path $ConfigPath $Vendor
    $servicesConfigFile = Join-Path $vendorConfigPath 'services.cfg'

    if (Test-Path $servicesConfigFile) {
        $removed = Remove-DDUServicesFromConfig -ConfigFile $servicesConfigFile -DryRun:$DryRun
        $removedCount += $removed
    }

    # Remove audio services if config exists
    $audioServicesConfigFile = Join-Path $vendorConfigPath 'servicesaudio.cfg'
    if (Test-Path $audioServicesConfigFile) {
        $removed = Remove-DDUServicesFromConfig -ConfigFile $audioServicesConfigFile -DryRun:$DryRun
        $removedCount += $removed
    }

    # Remove vendor-specific scheduled tasks
    $taskPatterns = @()

    switch ($Vendor) {
        'NVIDIA' {
            $taskPatterns = @('*NVIDIA*', '*GeForce*', '*NvTm*')
        }
        'AMD' {
            $taskPatterns = @('*AMD*', '*ATI*', '*Radeon*')
        }
        'Intel' {
            $taskPatterns = @('*Intel*Graphics*', '*Arc*')
        }
    }

    foreach ($pattern in $taskPatterns) {
        $removed = Remove-DDUScheduledTasksByPattern -Pattern $pattern -DryRun:$DryRun
        $removedCount += $removed
    }

    Write-DDULog "Removed $removedCount services/tasks for $Vendor" -Level Info

    return $removedCount
}

# Export module members
Export-ModuleMember -Function @(
    'Remove-DDUService',
    'Remove-DDUServicesByPattern',
    'Remove-DDUServicesFromConfig',
    'Remove-DDUScheduledTasksByPattern',
    'Remove-DDUVendorServices'
)
