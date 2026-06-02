<#
.SYNOPSIS
    DDU File System Operations Module

.DESCRIPTION
    Handles file and directory cleanup with long path support
#>

Add-Type -TypeDefinition @"
using System;
using System.Runtime.InteropServices;

public class FileNative
{
    [DllImport("kernel32.dll", CharSet = CharSet.Unicode, SetLastError = true)]
    [return: MarshalAs(UnmanagedType.Bool)]
    public static extern bool DeleteFile(string lpFileName);

    [DllImport("kernel32.dll", CharSet = CharSet.Unicode, SetLastError = true)]
    [return: MarshalAs(UnmanagedType.Bool)]
    public static extern bool RemoveDirectory(string lpPathName);

    [DllImport("kernel32.dll", CharSet = CharSet.Unicode, SetLastError = true)]
    [return: MarshalAs(UnmanagedType.Bool)]
    public static extern bool MoveFileEx(
        string lpExistingFileName,
        string lpNewFileName,
        int dwFlags);

    public const int MOVEFILE_DELAY_UNTIL_REBOOT = 0x4;
}
"@

<#
.SYNOPSIS
    Removes a file with long path support

.PARAMETER FilePath
    Path to file to remove

.PARAMETER DryRun
    Simulate without removing

.PARAMETER Force
    Force removal even if read-only
#>
function Remove-DDUFile {
    [CmdletBinding(SupportsShouldProcess=$true)]
    param(
        [Parameter(Mandatory=$true)]
        [string]$FilePath,

        [Parameter()]
        [switch]$DryRun,

        [Parameter()]
        [switch]$Force
    )

    if ($DryRun) {
        if (Test-Path $FilePath) {
            Write-DDULog "Would remove file: $FilePath" -Level Verbose
            return $true
        }
        return $false
    }

    try {
        if (-not (Test-Path $FilePath)) {
            return $false
        }

        # Convert to long path format
        $longPath = ConvertTo-DDULongPath -Path $FilePath

        Write-DDULog "Removing file: $FilePath" -Level Verbose

        # Remove read-only attribute if forcing
        if ($Force) {
            try {
                $file = Get-Item -LiteralPath $FilePath -Force -ErrorAction SilentlyContinue
                if ($file -and $file.IsReadOnly) {
                    $file.IsReadOnly = $false
                }
            } catch {
                # Ignore attribute errors
            }
        }

        # Try standard removal first
        try {
            Remove-Item -LiteralPath $FilePath -Force -ErrorAction Stop
            Write-DDULog "File removed: $FilePath" -Level Success
            return $true
        } catch {
            # Try native API with long path
            if ([FileNative]::DeleteFile($longPath)) {
                Write-DDULog "File removed (long path): $FilePath" -Level Success
                return $true
            }

            # Schedule for deletion on reboot as last resort
            if ([FileNative]::MoveFileEx($longPath, $null, [FileNative]::MOVEFILE_DELAY_UNTIL_REBOOT)) {
                Write-DDULog "File scheduled for deletion on reboot: $FilePath" -Level Warning
                return $true
            }

            throw
        }

    } catch {
        Write-DDULog "Failed to remove file ${FilePath}: $_" -Level Error
        return $false
    }
}

<#
.SYNOPSIS
    Removes a directory with all contents

.PARAMETER DirectoryPath
    Path to directory to remove

.PARAMETER DryRun
    Simulate without removing

.PARAMETER Force
    Force removal of read-only files
#>
function Remove-DDUDirectory {
    [CmdletBinding(SupportsShouldProcess=$true)]
    param(
        [Parameter(Mandatory=$true)]
        [string]$DirectoryPath,

        [Parameter()]
        [switch]$DryRun,

        [Parameter()]
        [switch]$Force
    )

    if ($DryRun) {
        if (Test-Path $DirectoryPath) {
            Write-DDULog "Would remove directory: $DirectoryPath" -Level Verbose
            return $true
        }
        return $false
    }

    try {
        if (-not (Test-Path $DirectoryPath)) {
            return $false
        }

        Write-DDULog "Removing directory: $DirectoryPath" -Level Verbose

        # Convert to long path
        $longPath = ConvertTo-DDULongPath -Path $DirectoryPath

        # Try standard removal first
        try {
            if ($Force) {
                # Remove read-only attributes from all files
                Get-ChildItem -Path $DirectoryPath -Recurse -Force -ErrorAction SilentlyContinue |
                    Where-Object { $_.IsReadOnly } |
                    ForEach-Object { $_.IsReadOnly = $false }
            }

            Remove-Item -LiteralPath $DirectoryPath -Recurse -Force -ErrorAction Stop
            Write-DDULog "Directory removed: $DirectoryPath" -Level Success
            return $true

        } catch {
            # Manually delete files and subdirectories with long path support
            $deleted = $false

            # Delete all files first
            $files = Get-ChildItem -Path $DirectoryPath -File -Recurse -Force -ErrorAction SilentlyContinue
            foreach ($file in $files) {
                Remove-DDUFile -FilePath $file.FullName -Force:$Force | Out-Null
            }

            # Delete subdirectories (deepest first)
            $dirs = Get-ChildItem -Path $DirectoryPath -Directory -Recurse -Force -ErrorAction SilentlyContinue |
                Sort-Object { $_.FullName.Length } -Descending

            foreach ($dir in $dirs) {
                $dirLongPath = ConvertTo-DDULongPath -Path $dir.FullName
                try {
                    [FileNative]::RemoveDirectory($dirLongPath) | Out-Null
                } catch {
                    # Ignore errors for individual subdirectories
                }
            }

            # Remove root directory
            if ([FileNative]::RemoveDirectory($longPath)) {
                Write-DDULog "Directory removed (long path): $DirectoryPath" -Level Success
                $deleted = $true
            }

            return $deleted
        }

    } catch {
        Write-DDULog "Failed to remove directory ${DirectoryPath}: $_" -Level Error
        return $false
    }
}

<#
.SYNOPSIS
    Removes files matching a pattern in a directory

.PARAMETER DirectoryPath
    Directory to search

.PARAMETER Pattern
    File name pattern (wildcards supported)

.PARAMETER Recurse
    Search recursively

.PARAMETER DryRun
    Simulate without removing

.OUTPUTS
    Number of files removed
#>
function Remove-DDUFilesByPattern {
    [CmdletBinding(SupportsShouldProcess=$true)]
    [OutputType([int])]
    param(
        [Parameter(Mandatory=$true)]
        [string]$DirectoryPath,

        [Parameter(Mandatory=$true)]
        [string]$Pattern,

        [Parameter()]
        [switch]$Recurse,

        [Parameter()]
        [switch]$DryRun
    )

    $removedCount = 0

    try {
        if (-not (Test-Path $DirectoryPath)) {
            return 0
        }

        $files = Get-ChildItem -Path $DirectoryPath -Filter $Pattern -File -Force -Recurse:$Recurse -ErrorAction SilentlyContinue

        foreach ($file in $files) {
            if (Remove-DDUFile -FilePath $file.FullName -DryRun:$DryRun -Force) {
                $removedCount++
            }
        }

    } catch {
        Write-DDULog "Error removing files in ${DirectoryPath}: $_" -Level Warning
    }

    return $removedCount
}

<#
.SYNOPSIS
    Removes directories matching a pattern

.PARAMETER BaseDirectory
    Base directory to search

.PARAMETER Pattern
    Directory name pattern

.PARAMETER DryRun
    Simulate without removing

.OUTPUTS
    Number of directories removed
#>
function Remove-DDUDirectoriesByPattern {
    [CmdletBinding(SupportsShouldProcess=$true)]
    [OutputType([int])]
    param(
        [Parameter(Mandatory=$true)]
        [string]$BaseDirectory,

        [Parameter(Mandatory=$true)]
        [string]$Pattern,

        [Parameter()]
        [switch]$DryRun
    )

    $removedCount = 0

    try {
        if (-not (Test-Path $BaseDirectory)) {
            return 0
        }

        $directories = Get-ChildItem -Path $BaseDirectory -Directory -Force -ErrorAction SilentlyContinue |
            Where-Object { $_.Name -like $Pattern }

        foreach ($directory in $directories) {
            if (Remove-DDUDirectory -DirectoryPath $directory.FullName -DryRun:$DryRun -Force) {
                $removedCount++
            }
        }

    } catch {
        Write-DDULog "Error removing directories in ${BaseDirectory}: $_" -Level Warning
    }

    return $removedCount
}

<#
.SYNOPSIS
    Cleans vendor-specific directories

.PARAMETER Vendor
    GPU vendor (NVIDIA, AMD, Intel)

.PARAMETER DryRun
    Simulate without removing

.OUTPUTS
    Number of items removed
#>
function Remove-DDUVendorDirectories {
    [CmdletBinding(SupportsShouldProcess=$true)]
    [OutputType([int])]
    param(
        [Parameter(Mandatory=$true)]
        [ValidateSet('NVIDIA', 'AMD', 'Intel')]
        [string]$Vendor,

        [Parameter()]
        [switch]$DryRun
    )

    $removedCount = 0
    $directories = @()

    switch ($Vendor) {
        'NVIDIA' {
            $directories = @(
                "$env:SystemDrive\NVIDIA",
                "$env:ProgramFiles\NVIDIA Corporation",
                "$env:ProgramFiles\NVIDIA GPU Computing Toolkit",
                "${env:ProgramFiles(x86)}\NVIDIA Corporation",
                "$env:ProgramData\NVIDIA",
                "$env:ProgramData\NVIDIA Corporation"
            )
        }
        'AMD' {
            $directories = @(
                "$env:SystemDrive\AMD",
                "$env:ProgramFiles\AMD",
                "$env:ProgramFiles\ATI",
                "$env:ProgramFiles\ATI Technologies",
                "${env:ProgramFiles(x86)}\AMD",
                "${env:ProgramFiles(x86)}\ATI",
                "${env:ProgramFiles(x86)}\ATI Technologies",
                "$env:ProgramData\AMD",
                "$env:ProgramData\ATI"
            )
        }
        'Intel' {
            $directories = @(
                "$env:ProgramFiles\Intel\Graphics",
                "$env:ProgramFiles\Intel\Media SDK",
                "${env:ProgramFiles(x86)}\Intel\Graphics",
                "${env:ProgramFiles(x86)}\Intel\Media SDK",
                "$env:ProgramData\Intel\Graphics"
            )
        }
    }

    foreach ($directory in $directories) {
        if (Remove-DDUDirectory -DirectoryPath $directory -DryRun:$DryRun -Force) {
            $removedCount++
        }
    }

    Write-DDULog "Removed $removedCount directories for $Vendor" -Level Info

    return $removedCount
}

<#
.SYNOPSIS
    Cleans user profile cache directories

.PARAMETER Vendor
    GPU vendor

.PARAMETER DryRun
    Simulate without removing

.OUTPUTS
    Number of cache directories removed
#>
function Remove-DDUUserCaches {
    [CmdletBinding(SupportsShouldProcess=$true)]
    [OutputType([int])]
    param(
        [Parameter(Mandatory=$true)]
        [ValidateSet('NVIDIA', 'AMD', 'Intel')]
        [string]$Vendor,

        [Parameter()]
        [switch]$DryRun
    )

    $removedCount = 0
    $profiles = Get-DDUUserProfiles

    foreach ($profile in $profiles) {
        $cachePaths = @()

        switch ($Vendor) {
            'NVIDIA' {
                $cachePaths = @(
                    "$profile\AppData\Local\NVIDIA",
                    "$profile\AppData\LocalLow\NVIDIA"
                )
            }
            'AMD' {
                $cachePaths = @(
                    "$profile\AppData\Local\AMD",
                    "$profile\AppData\LocalLow\AMD",
                    "$profile\AppData\LocalLow\ATI"
                )
            }
            'Intel' {
                $cachePaths = @(
                    "$profile\AppData\Local\Intel",
                    "$profile\AppData\LocalLow\Intel"
                )
            }
        }

        foreach ($cachePath in $cachePaths) {
            if (Remove-DDUDirectory -DirectoryPath $cachePath -DryRun:$DryRun -Force) {
                $removedCount++
            }
        }
    }

    return $removedCount
}

# Export module members
Export-ModuleMember -Function @(
    'Remove-DDUFile',
    'Remove-DDUDirectory',
    'Remove-DDUFilesByPattern',
    'Remove-DDUDirectoriesByPattern',
    'Remove-DDUVendorDirectories',
    'Remove-DDUUserCaches'
)
