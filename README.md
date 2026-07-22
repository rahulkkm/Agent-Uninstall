# Agent-Tenable-Install.ps1

## Overview

This PowerShell script automates the deployment of the Tenable Nessus Agent via Microsoft System Center Configuration Manager (SCCM). It creates a new SCCM application, configures deployment types, distributes content to distribution points, and deploys the application to target collections.

## Purpose

The script is designed to streamline the SCCM application deployment process for Tenable Agent updates. It handles:
- Application creation in SCCM
- MSI product code extraction
- Script-based deployment type configuration
- Content distribution to distribution points
- Automated deployment to server collections

## Prerequisites

- **SCCM Administrator Rights**: Must have permissions to create applications and deploy content
- **SCCM Console Installed**: Configuration Manager PowerShell module must be available
- **Network Access**: Access to the SCCM provider server and source file shares
- **PowerShell 5.1+**: Required for SCCM module interaction

## Configuration

Before running the script, update the following variables in the `CONFIGURATION` section:

```powershell
$Version      = "11.2.1"           # Tenable Agent version
$ReleaseDate  = "7/21/2026"         # Release date
$Owner        = "AppOwner"          # Application owner
$SupportContact = "Appsupport"      # Support contact
$MsiFileName  = "NessusAgent-11.2.1-x64.msi"  # MSI filename
```

### SCCM Configuration

```powershell
$SiteCode            = "SVR"                  # SCCM site code
$ProviderMachineName = "mempr1.contoso.com"   # SCCM provider server
```

### Path Configuration

```powershell
$SourceRoot   = "\\mempr1.contoso.com\source$\Tenable"  # Source files location
$FolderPath   = "${SiteCode}:\Application\Tenable"       # SCCM application folder
$MsiPath      = "${SourceRoot}\${Version}\${MsiFileName}" # Full MSI path
```

### Deployment Configuration

The following derived values are automatically calculated but can be modified if needed:

```powershell
$AppName              = "Tenable Agent ${Version} (See Comments)"
$DeploymentTypeName   = "Tenable Agent ${Version}"
$InstallCommand       = 'powershell.exe -ExecutionPolicy Bypass -file "Tenable_install.ps1"'
$UninstallCommand     = "msiexec /uninstall $MsiFileName /quiet"
$CollectionName       = "WINTSTSRVs"           # Target collection
$DPGroupName          = "All DPs"             # Distribution point group
```

## Usage

1. **Prepare the Source Files**
   - Place the Tenable Agent MSI file in: `\\mempr1.contoso.com\source$\Tenable\[Version]\`
   - Ensure the installation script `Tenable_install.ps1` exists in the same directory

2. **Update Configuration**
   - Edit the `CONFIGURATION` section with the new version details
   - Update `$Version`, `$ReleaseDate`, and `$MsiFileName` for each release

3. **Run the Script**
   ```powershell
   .\Agent-Tenable-Install.ps1
   ```

4. **Monitor Execution**
   - The script will display progress messages
   - It waits for content distribution to complete before creating the deployment
   - Check for green success messages indicating each stage completed

## Script Execution Flow

1. **Extract MSI Product Code**
   - Uses Windows Installer COM object to read the ProductCode from the MSI
   - Required for SCCM detection methods

2. **Connect to SCCM**
   - Imports ConfigurationManager module
   - Creates PSDrive to the SCCM site

3. **Create Application**
   - Creates new CMApplication with specified metadata
   - Moves application to the Tenable folder in SCCM

4. **Add Deployment Type**
   - Configures script-based installer deployment
   - Sets install/uninstall commands
   - Configures behavior (system install, no reboot, 15 min runtime)

5. **Distribute Content**
   - Distributes application content to all distribution points
   - Waits for distribution to complete (checks every 60 seconds)

6. **Deploy Application**
   - Creates required deployment to target collection
   - Configured for Software Center display only
   - Allows repair and overrides service windows

## Deployment Notes

- **Brownfield Deployments**: The script description indicates this version removes Rapid7 agents during installation
- **Greenfield Deployments**: Use for new builds without existing Rapid7 installations
- **Collection Targeting**: Currently targets `WINTSTSRVs` collection
- **Distribution Points**: Content is distributed to `All DPs` group

## Troubleshooting

### Module Import Failures
Ensure the SCCM console is installed and the path `$ENV:SMS_ADMIN_UI_PATH` is available.

### MSI Product Code Errors
Verify the MSI file exists at the specified path and is accessible.

### Distribution Timeout
The script waits indefinitely for content distribution. If stuck, check:
- Distribution point status in SCCM
- Network connectivity to DPs
- Sufficient disk space on distribution points

### Permission Errors
Ensure your account has:
- Application creation rights in SCCM
- Write access to source file shares
- Distribution point group membership

## Version History

| Version | Release Date | Notes |
|---------|-------------|-------|
| 11.2.1 | 7/21/2026 | Initial version |

## Support

For issues or questions:
- **Owner**: AppOwner
- **Support**: Appsupport
- **Publisher**: Tenable

## Related Files

- `Tenable_install.ps1` - Installation script referenced by the deployment type
- `NessusAgent-[Version]-x64.msi` - Tenable Agent installer package
- `Tenable.png` - Application icon file
