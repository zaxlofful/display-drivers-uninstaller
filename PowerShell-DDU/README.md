# Display Driver Uninstaller (DDU) - PowerShell Edition

**Pure PowerShell reimplementation of Display Driver Uninstaller for thorough removal of NVIDIA, AMD, and Intel display drivers on Windows 10/11.**

## Overview

This is a complete PowerShell reimplementation of the Display Driver Uninstaller (DDU) tool, providing behavioral parity with the original VB.NET application while using only native PowerShell and Windows APIs.

The implementation performs comprehensive cleanup of:
- Display driver packages and device instances
- Windows services and scheduled tasks
- Registry entries and device configurations
- Application files and directories
- Shader caches and temporary files
- Windows Update driver store entries
- Vendor-specific software components

## Features

✅ **Complete Driver Removal**
- Removes all driver packages from the Windows driver store
- Uninstalls PnP devices using native Windows APIs
- Cleans hidden/phantom devices
- Removes OEM INF files

✅ **Comprehensive Registry Cleanup**
- Removes vendor registry keys with ACL handling
- Cleans device enumeration entries
- Removes installer metadata
- Cleans shell extensions and COM objects

✅ **File System Cleanup**
- Long path support (>260 characters) using UNC prefixes
- Removes vendor directories from Program Files, ProgramData
- Cleans user profile caches and application data
- Removes system driver files
- Force-removes read-only and locked files

✅ **Service Management**
- Stops and removes vendor services
- Removes scheduled tasks
- Terminates vendor processes

✅ **Safe Mode Support**
- Detects Safe Mode automatically
- Optimized cleanup in Safe Mode

✅ **Windows Update Control**
- Prevents automatic driver reinstallation
- Configures device installation policies

✅ **Vendor-Specific Features**

**NVIDIA:**
- Optional PhysX removal
- Optional 3D Vision removal
- Optional GeForce Experience removal
- Optional NVIDIA Broadcast removal
- UpdatusUser account cleanup

**AMD:**
- Catalyst Control Center removal
- Radeon Software removal
- AMD installer remnant cleanup
- AUEP cleanup

**Intel:**
- Optional Arc Control removal
- Optional One API SDK removal
- Intel Graphics Software removal
- Media SDK cleanup

✅ **Safety Features**
- Dry-run mode for testing
- Comprehensive logging
- System restore point creation
- Administrator privilege validation
- Detailed error handling

## Requirements

- **Operating System:** Windows 10 or Windows 11
- **PowerShell:** Version 5.1 or later
- **Privileges:** Administrator rights required
- **Recommended:** Safe Mode for complete cleanup

## Installation

1. Clone or download this repository
2. Extract to a directory (e.g., `C:\DDU-PowerShell`)
3. No additional dependencies required - uses only native Windows components

## Usage

### Basic Usage

Open PowerShell as Administrator and navigate to the DDU directory:

```powershell
# Remove NVIDIA drivers
.\DDU.ps1 -Vendor NVIDIA

# Remove AMD drivers
.\DDU.ps1 -Vendor AMD

# Remove Intel drivers
.\DDU.ps1 -Vendor Intel
```

### Module Usage (for integration in larger scripts/packages)

Import the module and call the cleanup function directly:

```powershell
Import-Module .\DDU.Module.psm1 -Force

$result = Invoke-DDUDriverCleanup `
    -Vendor NVIDIA `
    -RemoveAudio `
    -CleanShaderCache `
    -CreateRestorePoint `
    -Force `
    -NoRestartPrompt

if (-not $result.Success) {
    throw "DDU cleanup did not complete successfully."
}
```

### Dry Run Mode (Testing)

Test without making any changes:

```powershell
.\DDU.ps1 -Vendor NVIDIA -DryRun
```

### Common Scenarios

**Complete NVIDIA cleanup with all components:**
```powershell
.\DDU.ps1 -Vendor NVIDIA -RemoveAudio -RemovePhysX -RemoveGeForceExperience -CleanShaderCache -CreateRestorePoint
```

**AMD cleanup with shader cache:**
```powershell
.\DDU.ps1 -Vendor AMD -RemoveAudio -CleanShaderCache -PreventWindowsUpdate
```

**Intel cleanup with Arc Control:**
```powershell
.\DDU.ps1 -Vendor Intel -RemoveArcControl -CleanShaderCache
```

### Parameters

| Parameter | Type | Description |
|-----------|------|-------------|
| `-Vendor` | String | **Required.** GPU vendor: `NVIDIA`, `AMD`, or `Intel` |
| `-DryRun` | Switch | Simulate cleanup without making changes |
| `-RemoveAudio` | Switch | Also remove audio drivers |
| `-RemovePhysX` | Switch | Remove NVIDIA PhysX (NVIDIA only) |
| `-Remove3DVision` | Switch | Remove NVIDIA 3D Vision (NVIDIA only) |
| `-RemoveGeForceExperience` | Switch | Remove GeForce Experience (NVIDIA only) |
| `-RemoveNVBroadcast` | Switch | Remove NVIDIA Broadcast (NVIDIA only) |
| `-RemoveArcControl` | Switch | Remove Intel Arc Control (Intel only) |
| `-RemoveOneAPI` | Switch | Remove Intel One API SDK (Intel only) |
| `-CleanShaderCache` | Switch | Remove DirectX/OpenGL/Vulkan shader caches |
| `-SkipDeviceRemoval` | Switch | Skip physical device removal (registry/files only) |
| `-PreventWindowsUpdate` | Switch | Prevent Windows Update driver reinstallation |
| `-CreateRestorePoint` | Switch | Create System Restore point before cleanup |
| `-LogPath` | String | Custom log file path (default: auto-generated) |
| `-Verbose` | Switch | Enable detailed logging output |
| `-Force` | Switch | Run without interactive confirmation prompt |
| `-NoRestartPrompt` | Switch | Suppress restart prompt for non-interactive orchestration |
| `-Restart` | Switch | Restart immediately after successful cleanup |

## Architecture

### Module Structure

```
PowerShell-DDU/
├── DDU.ps1                              # Main entry point
├── Modules/
│   ├── DDU.Logging.psm1                 # Logging and output
│   ├── DDU.Utils.psm1                   # Utility functions
│   ├── DDU.Registry.psm1                # Registry operations with ACL
│   ├── DDU.FileSystem.psm1              # File/directory operations
│   ├── DDU.Services.psm1                # Service management
│   ├── DDU.Devices.psm1                 # Device enumeration/removal
│   ├── DDU.Detection.psm1               # GPU detection
│   ├── DDU.Cleanup.psm1                 # Main cleanup orchestration
│   ├── DDU.Cleanup.NVIDIA.psm1          # NVIDIA-specific cleanup
│   ├── DDU.Cleanup.AMD.psm1             # AMD-specific cleanup
│   └── DDU.Cleanup.Intel.psm1           # Intel-specific cleanup
└── Config/
    ├── NVIDIA/
    │   └── services.cfg                 # NVIDIA service list
    ├── AMD/
    │   └── services.cfg                 # AMD service list
    └── Intel/
        └── services.cfg                 # Intel service list
```

### Cleanup Workflow

1. **Phase 1: Process Termination**
   - Stop vendor-specific processes

2. **Phase 2: Service Removal**
   - Remove Windows services
   - Remove scheduled tasks

3. **Phase 3: Device Removal** (unless skipped)
   - Enumerate PnP devices by vendor ID
   - Remove devices using pnputil
   - Remove driver packages from driver store

4. **Phase 4: Registry Cleanup**
   - Remove vendor registry keys
   - Clean device enumeration
   - Remove uninstall entries
   - Remove startup entries

5. **Phase 5: File System Cleanup**
   - Remove vendor directories
   - Clean user profile caches
   - Remove system driver files
   - Clean desktop/start menu shortcuts

6. **Phase 6: Shader Cache Cleanup** (optional)
   - Remove DirectX shader cache
   - Remove Vulkan cache
   - Remove OpenGL cache

7. **Phase 7: Windows Update Prevention** (optional)
   - Configure driver installation policies

## Technical Details

### Native Windows APIs Used

- **Get-PnpDevice / pnputil**: Device enumeration and removal
- **SetupAPI** (via P/Invoke): Advanced device operations
- **Registry API** (via P/Invoke): Registry operations with ACL handling
- **File API** (via P/Invoke): Long path support for file operations
- **sc.exe**: Service management
- **schtasks / Get-ScheduledTask**: Task scheduling
- **CIM/WMI**: System information queries

### Long Path Support

All file operations use UNC prefixes (`\\?\`) to support paths longer than 260 characters, ensuring complete cleanup even in deeply nested directories.

### Permission Handling

The implementation automatically:
- Takes ownership of protected registry keys
- Grants full control permissions before deletion
- Retries operations after ACL fixes
- Handles access denied errors gracefully

### Thread Safety

Registry operations use synchronization locks to prevent concurrent access issues when running cleanup operations.

## Safe Mode Usage

For the most complete cleanup, run DDU in Safe Mode:

1. **Enter Safe Mode:**
   - Press `Win + R`
   - Type `msconfig` and press Enter
   - Go to "Boot" tab
   - Check "Safe boot" → "Minimal"
   - Click OK and restart

2. **Run DDU in Safe Mode:**
   ```powershell
   .\DDU.ps1 -Vendor NVIDIA
   ```

3. **Exit Safe Mode:**
   - Run `msconfig` again
   - Uncheck "Safe boot"
   - Restart

The tool automatically detects Safe Mode and logs it for your reference.

## Logging

Every operation is logged to a timestamped log file:
- Default location: `.\DDU_Log_YYYYMMDD_HHmmss.txt`
- Custom location: Use `-LogPath` parameter
- Verbose logging: Use `-Verbose` parameter

Log entries include:
- Timestamp for each operation
- Operation details (registry keys, files, services)
- Success/failure status
- Error messages and stack traces
- System information

## Troubleshooting

### "Access Denied" Errors

Some operations may fail with access denied even as Administrator:
- **Solution:** Run in Safe Mode for maximum privileges
- The tool automatically attempts to fix ACLs and retry

### Files Still Remaining

Some files may be locked by running processes:
- **Solution:** Run in Safe Mode or manually terminate processes
- Some files are scheduled for deletion on next reboot

### Display Not Working After Cleanup

This is expected - display drivers have been removed:
- **Solution:** Install new drivers or restore from System Restore point
- Windows will use basic display adapter until drivers are installed

### Windows Update Reinstalls Drivers

Use the `-PreventWindowsUpdate` parameter to configure policies that prevent automatic driver installation.

## Differences from Original DDU

### Implementation Differences

- **No compiled binaries**: Pure PowerShell, no DLLs
- **Native PowerShell cmdlets**: Uses Get-PnpDevice, pnputil instead of custom SetupAPI wrappers
- **Simplified UI**: Command-line interface instead of GUI
- **Modern PowerShell**: Uses PowerShell 5.1+ features

### Behavioral Parity

The implementation maintains behavioral parity with the original DDU for:
- Cleanup scope and thoroughness
- Registry paths and patterns
- File system locations
- Service identification
- Device removal logic
- Windows Update handling

### Limitations

- No GUI (command-line only)
- No automatic reboot into Safe Mode
- No real-time progress bar (uses console output)
- Configuration files are simplified (services only, not full file lists)

## Security Considerations

**This tool makes significant system changes:**
- ⚠️ Removes device drivers and system files
- ⚠️ Modifies system registry
- ⚠️ Stops Windows services
- ⚠️ May cause system instability if used incorrectly

**Best Practices:**
- ✅ Create a System Restore point (`-CreateRestorePoint`)
- ✅ Test with `-DryRun` first
- ✅ Back up important data
- ✅ Have new drivers ready to install
- ✅ Run in Safe Mode when possible

## Contributing

This is a forked implementation based on the original Display Driver Uninstaller by Wagnardsoft.

### Adding Configuration

To add more services or cleanup targets:

1. Edit configuration files in `Config/[Vendor]/`
2. Add service names to `services.cfg` (one per line)
3. Test changes with `-DryRun`

### Extending Functionality

Each module is self-contained and can be enhanced independently:
- Add new cleanup targets to vendor-specific modules
- Enhance detection logic in `DDU.Detection.psm1`
- Add new device classes to `DDU.Devices.psm1`

## Credits

- **Original DDU**: Wagnardsoft - https://github.com/Wagnard/display-driver-uninstaller
- **PowerShell Implementation**: Based on the authoritative DDU VB.NET codebase

## License

This project inherits the license from the original Display Driver Uninstaller repository.

See the LICENSE file for details.

## Disclaimer

**USE AT YOUR OWN RISK**

This software is provided "as is" without warranty of any kind. The authors are not responsible for any damage or data loss resulting from the use of this tool.

Always create backups and System Restore points before using driver cleanup tools.

---

## Quick Reference

### Minimal Command
```powershell
.\DDU.ps1 -Vendor NVIDIA
```

### Recommended Command
```powershell
.\DDU.ps1 -Vendor NVIDIA -RemoveAudio -CleanShaderCache -CreateRestorePoint -Verbose
```

### Safe Testing
```powershell
.\DDU.ps1 -Vendor NVIDIA -DryRun -Verbose
```

### Maximum Cleanup (NVIDIA)
```powershell
.\DDU.ps1 -Vendor NVIDIA `
    -RemoveAudio `
    -RemovePhysX `
    -Remove3DVision `
    -RemoveGeForceExperience `
    -RemoveNVBroadcast `
    -CleanShaderCache `
    -PreventWindowsUpdate `
    -CreateRestorePoint
```

---

**Version:** 1.0.0
**Last Updated:** 2026-06-02
**PowerShell Version:** 5.1+
**Windows Version:** 10/11
