# Quick Start Guide - PowerShell DDU

Get started with PowerShell Display Driver Uninstaller in under 5 minutes.

## Prerequisites Check

✅ **Windows 10 or 11** - Check: Press `Win + R`, type `winver`, press Enter
✅ **PowerShell 5.1+** - Check: Open PowerShell, type `$PSVersionTable.PSVersion`
✅ **Administrator Rights** - Required for all operations

## Installation (30 seconds)

1. Download or clone this repository
2. Extract to any location (e.g., `C:\DDU-PowerShell`)
3. Done! No compilation or dependencies needed.

## Usage (3 steps)

### Step 1: Open PowerShell as Administrator

Right-click on PowerShell and select "Run as Administrator"

### Step 2: Navigate to DDU Directory

```powershell
cd C:\DDU-PowerShell\PowerShell-DDU
```

### Step 3: Run DDU

**For NVIDIA:**
```powershell
.\DDU.ps1 -Vendor NVIDIA
```

**For AMD:**
```powershell
.\DDU.ps1 -Vendor AMD
```

**For Intel:**
```powershell
.\DDU.ps1 -Vendor Intel
```

That's it! The tool will guide you through the cleanup process.

## Recommended First Use

**Test with dry-run mode first:**

```powershell
.\DDU.ps1 -Vendor NVIDIA -DryRun -Verbose
```

This shows what WOULD be done without making any changes.

## Common Commands

### Safe Testing
```powershell
.\DDU.ps1 -Vendor NVIDIA -DryRun -Verbose
```

### Basic Cleanup
```powershell
.\DDU.ps1 -Vendor NVIDIA
```

### Complete Cleanup (Recommended)
```powershell
.\DDU.ps1 -Vendor NVIDIA -RemoveAudio -CleanShaderCache -CreateRestorePoint
```

### Maximum Cleanup
```powershell
.\DDU.ps1 -Vendor NVIDIA `
    -RemoveAudio `
    -RemovePhysX `
    -RemoveGeForceExperience `
    -CleanShaderCache `
    -PreventWindowsUpdate `
    -CreateRestorePoint `
    -Verbose
```

## Safe Mode Usage (Best Results)

For the most thorough cleanup, use Safe Mode:

1. **Enter Safe Mode:**
   - Press `Win + R`
   - Type `msconfig`, press Enter
   - Go to "Boot" tab
   - Check "Safe boot" → "Minimal"
   - Click OK and restart

2. **Run DDU in Safe Mode:**
   ```powershell
   cd C:\DDU-PowerShell\PowerShell-DDU
   .\DDU.ps1 -Vendor NVIDIA
   ```

3. **Exit Safe Mode:**
   - Run `msconfig` again
   - Uncheck "Safe boot"
   - Restart

## What to Expect

1. **Pre-Flight Checks**
   - Administrator verification
   - Windows version check
   - Safe Mode detection

2. **Confirmation Prompt**
   - Review your settings
   - Type `yes` to proceed
   - Or `no` to cancel

3. **Cleanup Process**
   - Phase 1: Stop processes
   - Phase 2: Remove services
   - Phase 3: Remove devices
   - Phase 4: Clean registry
   - Phase 5: Clean file system
   - Phase 6: Clean caches (if enabled)
   - Phase 7: Prevent Windows Update (if enabled)

4. **Completion**
   - Summary of items removed
   - Log file location
   - Restart prompt

5. **After Restart**
   - Display will use basic adapter
   - Install new drivers
   - Done!

## Important Notes

⚠️ **Before You Start:**
- Back up important data
- Have new drivers ready to install
- Close all applications
- Consider creating a System Restore point

✅ **After Cleanup:**
- System restart is required
- Display will be in basic mode
- Install new drivers
- Everything returns to normal

## Troubleshooting

**"Execution policy" error?**
```powershell
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
```

**"Access denied" errors?**
- Run in Safe Mode for maximum privileges
- The tool automatically attempts to fix ACLs

**Files still remaining?**
- Run in Safe Mode
- Some files scheduled for deletion on next reboot

## Getting Help

**View all parameters:**
```powershell
Get-Help .\DDU.ps1 -Detailed
```

**View examples:**
```powershell
Get-Help .\DDU.ps1 -Examples
```

**View full help:**
```powershell
Get-Help .\DDU.ps1 -Full
```

## Log Files

Every run creates a timestamped log file:
- Location: Same directory as DDU.ps1
- Format: `DDU_Log_YYYYMMDD_HHmmss.txt`
- Contains: All operations, successes, failures, errors

Check the log file if you need to verify what was done.

## Quick Parameter Reference

| What You Want | Command |
|--------------|---------|
| Test without changes | Add `-DryRun` |
| See detailed output | Add `-Verbose` |
| Remove audio too | Add `-RemoveAudio` |
| Clean shader caches | Add `-CleanShaderCache` |
| Create restore point | Add `-CreateRestorePoint` |
| Block Windows Update | Add `-PreventWindowsUpdate` |
| Remove GeForce Experience | Add `-RemoveGeForceExperience` (NVIDIA) |
| Remove Arc Control | Add `-RemoveArcControl` (Intel) |

## Examples by Scenario

**Switching from NVIDIA to AMD:**
```powershell
.\DDU.ps1 -Vendor NVIDIA -RemoveAudio -RemoveGeForceExperience -CleanShaderCache -PreventWindowsUpdate -CreateRestorePoint
# Restart, then install AMD drivers
```

**Clean driver reinstall (same vendor):**
```powershell
.\DDU.ps1 -Vendor NVIDIA -CleanShaderCache -CreateRestorePoint
# Restart, then install latest NVIDIA drivers
```

**Troubleshooting driver issues:**
```powershell
.\DDU.ps1 -Vendor AMD -DryRun -Verbose
# Review log to see what will be removed
.\DDU.ps1 -Vendor AMD -CreateRestorePoint
# Restart and reinstall drivers
```

## Need More Info?

📖 **Full Documentation:** See `README.md`
📊 **Technical Details:** See `IMPLEMENTATION_SUMMARY.md`
💬 **Issues:** Check the log file first, then report issues with the log file attached

---

**You're ready to go!** Start with a dry-run test, then proceed with confidence.

**Estimated Time:**
- Testing (dry-run): 1-2 minutes
- Actual cleanup: 3-5 minutes
- Total with restart: 10-15 minutes

**Remember:** Always create a System Restore point before major system changes!

```powershell
# Your first command should be:
.\DDU.ps1 -Vendor [YOUR-VENDOR] -DryRun -Verbose
```

Happy cleaning! 🧹
