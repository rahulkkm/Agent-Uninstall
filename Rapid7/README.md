# Rapid7 Insight Agent - Complete Removal Script

## Overview

`Rapid7_Uninstall.ps1` is a PowerShell script that performs a complete removal of the Rapid7 Insight Agent from Windows systems. It dynamically discovers the installed version and ensures thorough cleanup of all artifacts including services, registry keys, files, and configuration data.

## Features

- **Dynamic Discovery**: Automatically detects installed Rapid7 Insight Agent version and GUID from registry
- **Service Management**: Stops and removes the `ir_agent` Windows service
- **MSI Uninstall**: Executes the official MSI uninstaller with silent parameters
- **Registry Cleanup**: Removes all leftover registry entries including:
  - Uninstall keys (both 32-bit and 64-bit)
  - Installer Products keys
  - Installer Features keys
  - User-specific installer data
- **File Cleanup**: Removes:
  - Installation folder (typically `C:\Program Files\Rapid7\Insight Agent`)
  - ProgramData directories (`C:\ProgramData\rapid7` and `C:\ProgramData\Rapid7`)
- **Verification**: Performs post-removal verification to ensure complete cleanup
- **Logging**: Outputs detailed progress with computer name prefix for easy tracking

## Requirements

- Windows PowerShell 5.1 or later
- Administrator privileges (required for service management and registry modifications)
- Rapid7 Insight Agent must be installed (script exits gracefully if not found)

## Usage

### Basic Execution

```powershell
.\Rapid7_Uninstall.ps1
```

### Execution with SCCM/Intune

The script is designed to work with deployment tools like SCCM or Intune. It includes computer name prefixes in all output for centralized logging.

```powershell
powershell.exe -ExecutionPolicy Bypass -File "Rapid7_Uninstall.ps1"
```

## Script Behavior

### Step-by-Step Process

1. **Registry Mapping**: Maps HKCR if not already available
2. **Version Discovery**: Searches both 32-bit and 64-bit uninstall registry paths for Rapid7 entries
3. **Service Stop**: Stops the `ir_agent` service if running
4. **MSI Uninstall**: Executes `msiexec.exe /X{GUID} /quiet /norestart` with logging to `%TEMP%\r7_uninstall.log`
5. **Service Cleanup**: Force-deletes any leftover service using `sc.exe delete`
6. **Registry Cleanup**: Removes all related registry keys including scrambled GUID entries
7. **File Cleanup**: Takes ownership and removes installation folder and ProgramData directories
8. **Verification**: Checks for remaining artifacts and reports success or warnings

### Exit Codes

- **0**: Success (agent not found or successfully removed)
- **MSI Exit Codes**: The script reports MSI exit codes but continues with cleanup regardless:
  - `0` or `3010`: Success
  - `1612`: Source missing (fallback cleanup handles this)
  - `1605`: Already removed

## Output Format

All output includes the computer name prefix for easy identification in logs:

```
[COMPUTERNAME] Found       : Rapid7 Insight Agent v.x.x.x
[COMPUTERNAME] GUID        : {xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx}
[COMPUTERNAME] InstallPath : C:\Program Files\Rapid7\Insight Agent

[COMPUTERNAME] Stopping service...
[COMPUTERNAME] Stopped : ir_agent

[COMPUTERNAME] Running MSI uninstall...
[COMPUTERNAME] MSI exit code: 0

[COMPUTERNAME] SUCCESS: Rapid7 Insight Agent fully removed!
```

## Troubleshooting

### Agent Not Found

If the script reports "Rapid7 Insight Agent not found - skipping", verify:
- The agent is actually installed
- Check both `HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall` and `HKLM\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall`

### Leftover Files After Execution

If files remain after script execution:
- Check permissions on the installation folder
- Manually take ownership: `takeown /f "C:\Program Files\Rapid7\Insight Agent" /r /d y`
- Grant admin permissions: `icacls "C:\Program Files\Rapid7\Insight Agent" /grant Administrators:F /t`
- Reboot and retry if files are in use

### Service Still Exists

If the service remains after execution:
- Manually stop: `Stop-Service -Name ir_agent -Force`
- Manually delete: `sc.exe delete ir_agent`
- Reboot if service is locked

## Log Files

The MSI uninstaller creates a detailed log at:
```
%TEMP%\r7_uninstall.log
```

Review this file if MSI uninstallation fails.

## Security Considerations

- Script requires administrator privileges
- Modifies system registry and service configuration
- Deletes files from Program Files and ProgramData
- Should be tested in a non-production environment before deployment

## Version Compatibility

- Tested on Windows 10/11
- Compatible with both 32-bit and 64-bit Rapid7 installations
- Handles WOW6432Node registry redirection automatically

## License

This script is provided as-is for system administration purposes.

## Support

For issues related to:
- **Script execution**: Check the troubleshooting section above
- **Rapid7 Agent**: Contact Rapid7 support
- **SCCM/Intune deployment**: Consult your deployment tool documentation
