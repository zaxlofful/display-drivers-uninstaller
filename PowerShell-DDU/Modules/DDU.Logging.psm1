<#
.SYNOPSIS
    DDU Logging Module

.DESCRIPTION
    Provides centralized logging functionality for DDU operations
#>

# Module-level variables
$script:LogPath = $null
$script:VerboseLogging = $false
$script:LogLock = New-Object System.Object

<#
.SYNOPSIS
    Initializes the DDU logging system

.PARAMETER LogPath
    Path to the log file

.PARAMETER Verbose
    Enable verbose logging
#>
function Initialize-DDULogging {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [string]$LogPath,

        [Parameter()]
        [switch]$Verbose
    )

    $script:LogPath = $LogPath
    $script:VerboseLogging = $Verbose

    # Create log file directory if it doesn't exist
    $logDir = Split-Path -Path $LogPath -Parent
    if ($logDir -and -not (Test-Path $logDir)) {
        New-Item -Path $logDir -ItemType Directory -Force | Out-Null
    }

    # Initialize log file with header
    $header = @"
================================================================================
Display Driver Uninstaller (DDU) - PowerShell Edition
Log started: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')
Computer: $env:COMPUTERNAME
User: $env:USERNAME
OS: $(Get-CimInstance Win32_OperatingSystem | Select-Object -ExpandProperty Caption)
PowerShell: $($PSVersionTable.PSVersion.ToString())
================================================================================

"@

    $header | Out-File -FilePath $LogPath -Encoding UTF8 -Force
}

<#
.SYNOPSIS
    Writes a message to the DDU log

.PARAMETER Message
    Message to log

.PARAMETER Level
    Log level: Info, Warning, Error, Success, Verbose

.PARAMETER NoConsole
    Suppress console output
#>
function Write-DDULog {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true, Position=0)]
        [string]$Message,

        [Parameter()]
        [ValidateSet('Info', 'Warning', 'Error', 'Success', 'Verbose')]
        [string]$Level = 'Info',

        [Parameter()]
        [switch]$NoConsole
    )

    if (-not $script:LogPath) {
        Write-Warning "Logging not initialized"
        return
    }

    # Skip verbose messages if verbose logging is disabled
    if ($Level -eq 'Verbose' -and -not $script:VerboseLogging) {
        return
    }

    $timestamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss.fff'
    $logEntry = "[$timestamp] [$Level] $Message"

    # Thread-safe file write
    lock ($script:LogLock) {
        try {
            Add-Content -Path $script:LogPath -Value $logEntry -Encoding UTF8 -ErrorAction SilentlyContinue
        } catch {
            # Silently fail if log write fails to avoid breaking the cleanup process
        }
    }

    # Console output
    if (-not $NoConsole) {
        switch ($Level) {
            'Info'    { Write-Host "  $Message" -ForegroundColor White }
            'Success' { Write-Host "  ✓ $Message" -ForegroundColor Green }
            'Warning' { Write-Host "  ⚠ $Message" -ForegroundColor Yellow }
            'Error'   { Write-Host "  ✗ $Message" -ForegroundColor Red }
            'Verbose' { if ($script:VerboseLogging) { Write-Host "    $Message" -ForegroundColor Gray } }
        }
    }
}

<#
.SYNOPSIS
    Thread-safe lock helper

.PARAMETER InputObject
    Object to lock on

.PARAMETER ScriptBlock
    Script block to execute while locked
#>
function lock {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true, Position=0)]
        [object]$InputObject,

        [Parameter(Mandatory=$true, Position=1)]
        [scriptblock]$ScriptBlock
    )

    try {
        [System.Threading.Monitor]::Enter($InputObject)
        & $ScriptBlock
    } finally {
        [System.Threading.Monitor]::Exit($InputObject)
    }
}

<#
.SYNOPSIS
    Writes a section header to the log

.PARAMETER Title
    Section title
#>
function Write-DDUSectionHeader {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [string]$Title
    )

    $separator = "=" * 80
    Write-DDULog "" -Level Info
    Write-DDULog $separator -Level Info
    Write-DDULog $Title -Level Info
    Write-DDULog $separator -Level Info

    Write-Host ""
    Write-Host $Title -ForegroundColor Cyan
    Write-Host ("-" * $Title.Length) -ForegroundColor Cyan
}

<#
.SYNOPSIS
    Writes an operation result to the log

.PARAMETER Operation
    Description of the operation

.PARAMETER Success
    Whether the operation succeeded

.PARAMETER Details
    Additional details (optional)
#>
function Write-DDUOperationResult {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [string]$Operation,

        [Parameter(Mandatory=$true)]
        [bool]$Success,

        [Parameter()]
        [string]$Details
    )

    if ($Success) {
        $message = $Operation
        if ($Details) {
            $message += " - $Details"
        }
        Write-DDULog $message -Level Success
    } else {
        $message = "Failed: $Operation"
        if ($Details) {
            $message += " - $Details"
        }
        Write-DDULog $message -Level Error
    }
}

# Export module members
Export-ModuleMember -Function @(
    'Initialize-DDULogging',
    'Write-DDULog',
    'Write-DDUSectionHeader',
    'Write-DDUOperationResult'
)
