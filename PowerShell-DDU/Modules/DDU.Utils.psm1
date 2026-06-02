<#
.SYNOPSIS
    DDU Utilities Module

.DESCRIPTION
    Common utility functions for DDU operations
#>

<#
.SYNOPSIS
    Tests if the system is running in Safe Mode

.OUTPUTS
    Boolean - True if in Safe Mode
#>
function Test-DDUSafeMode {
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    try {
        $bootMode = (Get-CimInstance -ClassName Win32_ComputerSystem).BootupState
        return ($bootMode -match 'safe')
    } catch {
        Write-DDULog "Failed to detect Safe Mode: $_" -Level Warning
        return $false
    }
}

<#
.SYNOPSIS
    Terminates processes matching specified names

.PARAMETER ProcessNames
    Array of process names to terminate

.PARAMETER DryRun
    Simulate without actually terminating
#>
function Stop-DDUProcess {
    [CmdletBinding(SupportsShouldProcess=$true)]
    param(
        [Parameter(Mandatory=$true)]
        [string[]]$ProcessNames,

        [Parameter()]
        [switch]$DryRun
    )

    foreach ($processName in $ProcessNames) {
        try {
            $processes = Get-Process -Name $processName -ErrorAction SilentlyContinue
            if ($processes) {
                foreach ($process in $processes) {
                    if ($DryRun) {
                        Write-DDULog "Would terminate process: $($process.ProcessName) (PID: $($process.Id))" -Level Verbose
                    } else {
                        Write-DDULog "Terminating process: $($process.ProcessName) (PID: $($process.Id))" -Level Verbose
                        $process.Kill()
                        $process.WaitForExit(5000) | Out-Null
                        Write-DDULog "Process terminated: $($process.ProcessName)" -Level Success
                    }
                }
            }
        } catch {
            Write-DDULog "Failed to terminate process $processName : $_" -Level Warning
        }
    }
}

<#
.SYNOPSIS
    Tests if a string contains any of the specified substrings

.PARAMETER String
    String to test

.PARAMETER Substrings
    Array of substrings to search for

.PARAMETER CaseSensitive
    Perform case-sensitive comparison

.OUTPUTS
    Boolean
#>
function Test-DDUStringContains {
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        [Parameter(Mandatory=$true)]
        [string]$String,

        [Parameter(Mandatory=$true)]
        [string[]]$Substrings,

        [Parameter()]
        [switch]$CaseSensitive
    )

    if ([string]::IsNullOrWhiteSpace($String)) {
        return $false
    }

    $compareType = if ($CaseSensitive) {
        [System.StringComparison]::Ordinal
    } else {
        [System.StringComparison]::OrdinalIgnoreCase
    }

    foreach ($substring in $Substrings) {
        if ($String.IndexOf($substring, $compareType) -ge 0) {
            return $true
        }
    }

    return $false
}

<#
.SYNOPSIS
    Tests if a string matches any of the specified patterns

.PARAMETER String
    String to test

.PARAMETER Patterns
    Array of wildcard patterns

.PARAMETER CaseSensitive
    Perform case-sensitive comparison

.OUTPUTS
    Boolean
#>
function Test-DDUStringMatch {
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        [Parameter(Mandatory=$true)]
        [string]$String,

        [Parameter(Mandatory=$true)]
        [string[]]$Patterns,

        [Parameter()]
        [switch]$CaseSensitive
    )

    if ([string]::IsNullOrWhiteSpace($String)) {
        return $false
    }

    foreach ($pattern in $Patterns) {
        if ($CaseSensitive) {
            if ($String -clike $pattern) {
                return $true
            }
        } else {
            if ($String -like $pattern) {
                return $true
            }
        }
    }

    return $false
}

<#
.SYNOPSIS
    Converts a path to UNC format for long path support

.PARAMETER Path
    Path to convert

.OUTPUTS
    String - UNC formatted path
#>
function ConvertTo-DDULongPath {
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory=$true)]
        [string]$Path
    )

    if ([string]::IsNullOrWhiteSpace($Path)) {
        return $Path
    }

    # Already UNC path
    if ($Path.StartsWith('\\?\')) {
        return $Path
    }

    # Convert to absolute path if needed
    if (-not [System.IO.Path]::IsPathRooted($Path)) {
        $Path = [System.IO.Path]::GetFullPath($Path)
    }

    # Add UNC prefix
    if ($Path.StartsWith('\\')) {
        # Network path
        return '\\?\UNC\' + $Path.Substring(2)
    } else {
        # Local path
        return '\\?\' + $Path
    }
}

<#
.SYNOPSIS
    Loads configuration from a text file

.PARAMETER FilePath
    Path to configuration file

.PARAMETER IgnoreComments
    Ignore lines starting with # or ;

.OUTPUTS
    Array of strings (non-empty lines)
#>
function Get-DDUConfigFile {
    [CmdletBinding()]
    [OutputType([string[]])]
    param(
        [Parameter(Mandatory=$true)]
        [string]$FilePath,

        [Parameter()]
        [switch]$IgnoreComments
    )

    if (-not (Test-Path $FilePath)) {
        Write-DDULog "Config file not found: $FilePath" -Level Warning
        return @()
    }

    try {
        $lines = Get-Content -Path $FilePath -ErrorAction Stop
        $result = @()

        foreach ($line in $lines) {
            # Trim whitespace
            $line = $line.Trim()

            # Skip empty lines
            if ([string]::IsNullOrWhiteSpace($line)) {
                continue
            }

            # Skip comments if requested
            if ($IgnoreComments -and ($line.StartsWith('#') -or $line.StartsWith(';'))) {
                continue
            }

            $result += $line
        }

        Write-DDULog "Loaded $($result.Count) entries from: $FilePath" -Level Verbose
        return $result

    } catch {
        Write-DDULog "Failed to read config file ${FilePath}: $_" -Level Error
        return @()
    }
}

<#
.SYNOPSIS
    Gets all user profile directories

.OUTPUTS
    Array of directory paths
#>
function Get-DDUUserProfiles {
    [CmdletBinding()]
    [OutputType([string[]])]
    param()

    try {
        $profilesPath = "$env:SystemDrive\Users"
        $profiles = Get-ChildItem -Path $profilesPath -Directory -ErrorAction SilentlyContinue |
            Where-Object { $_.Name -notin @('Public', 'Default', 'Default User', 'All Users') } |
            Select-Object -ExpandProperty FullName

        return $profiles
    } catch {
        Write-DDULog "Failed to enumerate user profiles: $_" -Level Warning
        return @()
    }
}

<#
.SYNOPSIS
    Checks if running with administrator privileges

.OUTPUTS
    Boolean
#>
function Test-DDUAdministrator {
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    $currentPrincipal = [Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()
    return $currentPrincipal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

<#
.SYNOPSIS
    Retries an operation with exponential backoff

.PARAMETER ScriptBlock
    Script block to execute

.PARAMETER MaxAttempts
    Maximum number of retry attempts

.PARAMETER InitialDelay
    Initial delay in seconds

.OUTPUTS
    Result of the script block
#>
function Invoke-DDURetry {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [scriptblock]$ScriptBlock,

        [Parameter()]
        [int]$MaxAttempts = 3,

        [Parameter()]
        [int]$InitialDelay = 1
    )

    $attempt = 1
    $delay = $InitialDelay

    while ($attempt -le $MaxAttempts) {
        try {
            return & $ScriptBlock
        } catch {
            if ($attempt -eq $MaxAttempts) {
                throw
            }

            Write-DDULog "Attempt $attempt failed, retrying in $delay seconds: $_" -Level Verbose
            Start-Sleep -Seconds $delay
            $delay *= 2
            $attempt++
        }
    }
}

<#
.SYNOPSIS
    Gets the vendor ID from a vendor name

.PARAMETER Vendor
    Vendor name (NVIDIA, AMD, Intel)

.OUTPUTS
    String - Vendor ID (VEN_XXXX format)
#>
function Get-DDUVendorID {
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory=$true)]
        [ValidateSet('NVIDIA', 'AMD', 'Intel')]
        [string]$Vendor
    )

    switch ($Vendor) {
        'NVIDIA' { return 'VEN_10DE' }
        'AMD'    { return 'VEN_1002' }
        'Intel'  { return 'VEN_8086' }
    }
}

<#
.SYNOPSIS
    Waits for pending file operations to complete

.PARAMETER Seconds
    Seconds to wait
#>
function Wait-DDUPendingOperations {
    [CmdletBinding()]
    param(
        [Parameter()]
        [int]$Seconds = 2
    )

    Write-DDULog "Waiting $Seconds seconds for pending operations..." -Level Verbose
    Start-Sleep -Seconds $Seconds
    [System.GC]::Collect()
    [System.GC]::WaitForPendingFinalizers()
}

# Export module members
Export-ModuleMember -Function @(
    'Test-DDUSafeMode',
    'Stop-DDUProcess',
    'Test-DDUStringContains',
    'Test-DDUStringMatch',
    'ConvertTo-DDULongPath',
    'Get-DDUConfigFile',
    'Get-DDUUserProfiles',
    'Test-DDUAdministrator',
    'Invoke-DDURetry',
    'Get-DDUVendorID',
    'Wait-DDUPendingOperations'
)
