<#
.SYNOPSIS
    DDU Registry Operations Module

.DESCRIPTION
    Handles registry cleanup operations with ACL handling
#>

Add-Type -TypeDefinition @"
using System;
using System.Runtime.InteropServices;
using System.Security.AccessControl;
using System.Security.Principal;

public class RegistryNative
{
    [DllImport("advapi32.dll", SetLastError = true)]
    public static extern int RegOpenKeyEx(
        UIntPtr hKey,
        string lpSubKey,
        int ulOptions,
        int samDesired,
        out UIntPtr phkResult);

    [DllImport("advapi32.dll", SetLastError = true)]
    public static extern int RegCloseKey(UIntPtr hKey);

    [DllImport("advapi32.dll", SetLastError = true, CharSet = CharSet.Unicode)]
    public static extern int RegDeleteTree(
        UIntPtr hKey,
        string lpSubKey);

    [DllImport("advapi32.dll", SetLastError = true)]
    public static extern int RegDeleteKeyEx(
        UIntPtr hKey,
        string lpSubKey,
        int samDesired,
        int Reserved);

    public static readonly UIntPtr HKEY_CLASSES_ROOT = (UIntPtr)0x80000000;
    public static readonly UIntPtr HKEY_CURRENT_USER = (UIntPtr)0x80000001;
    public static readonly UIntPtr HKEY_LOCAL_MACHINE = (UIntPtr)0x80000002;
    public static readonly UIntPtr HKEY_USERS = (UIntPtr)0x80000003;

    public const int KEY_READ = 0x20019;
    public const int KEY_WRITE = 0x20006;
    public const int KEY_WOW64_64KEY = 0x0100;
    public const int KEY_WOW64_32KEY = 0x0200;
}
"@

# Module-level lock for thread-safe registry operations
$script:RegistryLock = New-Object System.Object

<#
.SYNOPSIS
    Takes ownership and grants full control permissions on a registry key

.PARAMETER KeyPath
    Registry key path (e.g., "HKLM:\Software\NVIDIA")

.PARAMETER DryRun
    Simulate without making changes
#>
function Grant-DDURegistryPermission {
    [CmdletBinding(SupportsShouldProcess=$true)]
    param(
        [Parameter(Mandatory=$true)]
        [string]$KeyPath,

        [Parameter()]
        [switch]$DryRun
    )

    if ($DryRun) {
        Write-DDULog "Would grant permissions on: $KeyPath" -Level Verbose
        return $true
    }

    try {
        # Check if key exists
        if (-not (Test-Path $KeyPath)) {
            return $true
        }

        Write-DDULog "Granting permissions on: $KeyPath" -Level Verbose

        # Get the registry key
        $key = Get-Item -Path $KeyPath -ErrorAction Stop

        # Get current ACL
        $acl = $key.GetAccessControl([System.Security.AccessControl.AccessControlSections]::All)

        # Get current user and system identities
        $currentUser = [System.Security.Principal.WindowsIdentity]::GetCurrent().User
        $administrators = New-Object System.Security.Principal.SecurityIdentifier([System.Security.Principal.WellKnownSidType]::BuiltinAdministratorsSid, $null)

        # Set owner to Administrators group
        $acl.SetOwner($administrators)

        # Grant full control to Administrators
        $rule = New-Object System.Security.AccessControl.RegistryAccessRule(
            $administrators,
            [System.Security.AccessControl.RegistryRights]::FullControl,
            [System.Security.AccessControl.InheritanceFlags]::ContainerInherit -bor [System.Security.AccessControl.InheritanceFlags]::ObjectInherit,
            [System.Security.AccessControl.PropagationFlags]::None,
            [System.Security.AccessControl.AccessControlType]::Allow
        )

        $acl.AddAccessRule($rule)

        # Apply the ACL
        $key.SetAccessControl($acl)

        Write-DDULog "Permissions granted successfully" -Level Verbose
        return $true

    } catch {
        Write-DDULog "Failed to grant permissions on ${KeyPath}: $_" -Level Warning
        return $false
    }
}

<#
.SYNOPSIS
    Removes a registry key with all subkeys

.PARAMETER KeyPath
    Registry key path to remove

.PARAMETER DryRun
    Simulate without making changes

.PARAMETER Force
    Attempt to take ownership if access denied
#>
function Remove-DDURegistryKey {
    [CmdletBinding(SupportsShouldProcess=$true)]
    param(
        [Parameter(Mandatory=$true)]
        [string]$KeyPath,

        [Parameter()]
        [switch]$DryRun,

        [Parameter()]
        [switch]$Force
    )

    if ($DryRun) {
        if (Test-Path $KeyPath) {
            Write-DDULog "Would remove registry key: $KeyPath" -Level Verbose
            return $true
        }
        return $false
    }

    # Thread-safe registry operations
    lock ($script:RegistryLock) {
        try {
            if (-not (Test-Path $KeyPath)) {
                return $false
            }

            Write-DDULog "Removing registry key: $KeyPath" -Level Verbose

            try {
                # Attempt direct removal
                Remove-Item -Path $KeyPath -Recurse -Force -ErrorAction Stop
                Write-DDULog "Registry key removed: $KeyPath" -Level Success
                return $true

            } catch [System.UnauthorizedAccessException], [System.Security.SecurityException] {
                if ($Force) {
                    Write-DDULog "Access denied, attempting to take ownership: $KeyPath" -Level Verbose

                    # Grant permissions and retry
                    if (Grant-DDURegistryPermission -KeyPath $KeyPath) {
                        Start-Sleep -Milliseconds 500
                        Remove-Item -Path $KeyPath -Recurse -Force -ErrorAction Stop
                        Write-DDULog "Registry key removed after permission fix: $KeyPath" -Level Success
                        return $true
                    }
                }
                throw
            }

        } catch {
            Write-DDULog "Failed to remove registry key ${KeyPath}: $_" -Level Error
            return $false
        }
    }
}

<#
.SYNOPSIS
    Removes a registry value

.PARAMETER KeyPath
    Registry key path

.PARAMETER ValueName
    Name of the value to remove

.PARAMETER DryRun
    Simulate without making changes
#>
function Remove-DDURegistryValue {
    [CmdletBinding(SupportsShouldProcess=$true)]
    param(
        [Parameter(Mandatory=$true)]
        [string]$KeyPath,

        [Parameter(Mandatory=$true)]
        [string]$ValueName,

        [Parameter()]
        [switch]$DryRun
    )

    if ($DryRun) {
        if (Test-Path $KeyPath) {
            $value = Get-ItemProperty -Path $KeyPath -Name $ValueName -ErrorAction SilentlyContinue
            if ($value) {
                Write-DDULog "Would remove registry value: $KeyPath\$ValueName" -Level Verbose
                return $true
            }
        }
        return $false
    }

    lock ($script:RegistryLock) {
        try {
            if (-not (Test-Path $KeyPath)) {
                return $false
            }

            $value = Get-ItemProperty -Path $KeyPath -Name $ValueName -ErrorAction SilentlyContinue
            if (-not $value) {
                return $false
            }

            Remove-ItemProperty -Path $KeyPath -Name $ValueName -Force -ErrorAction Stop
            Write-DDULog "Removed registry value: $KeyPath\$ValueName" -Level Verbose
            return $true

        } catch {
            Write-DDULog "Failed to remove registry value ${KeyPath}\${ValueName}: $_" -Level Warning
            return $false
        }
    }
}

<#
.SYNOPSIS
    Finds and removes registry keys matching a pattern

.PARAMETER BaseKey
    Base registry path to search

.PARAMETER Pattern
    Wildcard pattern to match

.PARAMETER DryRun
    Simulate without making changes

.PARAMETER Recursive
    Search recursively

.OUTPUTS
    Number of keys removed
#>
function Remove-DDURegistryKeysByPattern {
    [CmdletBinding(SupportsShouldProcess=$true)]
    [OutputType([int])]
    param(
        [Parameter(Mandatory=$true)]
        [string]$BaseKey,

        [Parameter(Mandatory=$true)]
        [string]$Pattern,

        [Parameter()]
        [switch]$DryRun,

        [Parameter()]
        [switch]$Recursive
    )

    $removedCount = 0

    try {
        if (-not (Test-Path $BaseKey)) {
            return 0
        }

        # Get all child keys
        $childKeys = Get-ChildItem -Path $BaseKey -ErrorAction SilentlyContinue

        foreach ($childKey in $childKeys) {
            $keyName = Split-Path -Path $childKey.PSPath -Leaf

            # Check if matches pattern
            if ($keyName -like $Pattern) {
                if (Remove-DDURegistryKey -KeyPath $childKey.PSPath -DryRun:$DryRun -Force) {
                    $removedCount++
                }
            }

            # Recurse if requested
            if ($Recursive) {
                $removedCount += Remove-DDURegistryKeysByPattern -BaseKey $childKey.PSPath -Pattern $Pattern -DryRun:$DryRun -Recursive
            }
        }

    } catch {
        Write-DDULog "Error searching registry keys in ${BaseKey}: $_" -Level Warning
    }

    return $removedCount
}

<#
.SYNOPSIS
    Removes registry keys from a list

.PARAMETER KeyPaths
    Array of registry key paths

.PARAMETER DryRun
    Simulate without making changes

.OUTPUTS
    Number of keys removed
#>
function Remove-DDURegistryKeys {
    [CmdletBinding(SupportsShouldProcess=$true)]
    [OutputType([int])]
    param(
        [Parameter(Mandatory=$true)]
        [string[]]$KeyPaths,

        [Parameter()]
        [switch]$DryRun
    )

    $removedCount = 0

    foreach ($keyPath in $KeyPaths) {
        if (Remove-DDURegistryKey -KeyPath $keyPath -DryRun:$DryRun -Force) {
            $removedCount++
        }
    }

    return $removedCount
}

<#
.SYNOPSIS
    Cleans vendor-specific registry entries

.PARAMETER Vendor
    GPU vendor (NVIDIA, AMD, Intel)

.PARAMETER DryRun
    Simulate without making changes

.OUTPUTS
    Number of keys removed
#>
function Remove-DDUVendorRegistry {
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

    # Define vendor-specific registry paths
    $registryPaths = @()

    switch ($Vendor) {
        'NVIDIA' {
            $registryPaths = @(
                'HKLM:\Software\NVIDIA',
                'HKLM:\Software\NVIDIA Corporation',
                'HKLM:\Software\NVIDIA CORPORATION',
                'HKLM:\Software\Wow6432Node\NVIDIA',
                'HKLM:\Software\Wow6432Node\NVIDIA Corporation',
                'HKLM:\Software\Wow6432Node\NVIDIA CORPORATION',
                'HKCU:\Software\NVIDIA',
                'HKCU:\Software\NVIDIA Corporation',
                'HKLM:\System\CurrentControlSet\Services\nvlddmkm',
                'HKLM:\System\CurrentControlSet\Services\NVDisplay.ContainerLocalSystem'
            )
        }
        'AMD' {
            $registryPaths = @(
                'HKLM:\Software\ATI',
                'HKLM:\Software\ATI Technologies',
                'HKLM:\Software\AMD',
                'HKLM:\Software\AUEP',
                'HKLM:\Software\AMDDVR',
                'HKLM:\Software\Wow6432Node\ATI',
                'HKLM:\Software\Wow6432Node\ATI Technologies',
                'HKLM:\Software\Wow6432Node\AMD',
                'HKCU:\Software\ATI',
                'HKCU:\Software\AMD',
                'HKLM:\System\CurrentControlSet\Services\amdkmdap',
                'HKLM:\System\CurrentControlSet\Services\amdkmdag'
            )
        }
        'Intel' {
            $registryPaths = @(
                'HKLM:\Software\Intel\Display',
                'HKLM:\Software\Intel\Graphics',
                'HKLM:\Software\Wow6432Node\Intel\Display',
                'HKLM:\Software\Wow6432Node\Intel\Graphics',
                'HKCU:\Software\Intel\Display',
                'HKCU:\Software\Intel\Graphics'
            )
        }
    }

    # Remove each registry path
    foreach ($path in $registryPaths) {
        if (Remove-DDURegistryKey -KeyPath $path -DryRun:$DryRun -Force) {
            $removedCount++
        }
    }

    # Remove from uninstall registry
    $uninstallPaths = @(
        'HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall',
        'HKLM:\Software\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall'
    )

    foreach ($uninstallPath in $uninstallPaths) {
        $removed = Remove-DDURegistryKeysByPattern -BaseKey $uninstallPath -Pattern "*$Vendor*" -DryRun:$DryRun
        $removedCount += $removed
    }

    Write-DDULog "Removed $removedCount registry keys for $Vendor" -Level Info

    return $removedCount
}

<#
.SYNOPSIS
    Locks for thread-safe operations
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

# Export module members
Export-ModuleMember -Function @(
    'Grant-DDURegistryPermission',
    'Remove-DDURegistryKey',
    'Remove-DDURegistryValue',
    'Remove-DDURegistryKeysByPattern',
    'Remove-DDURegistryKeys',
    'Remove-DDUVendorRegistry'
)
