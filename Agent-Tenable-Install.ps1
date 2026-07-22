###############################################################################################################
# Nessus Tenable Agent - SCCM Application Deployment Script
#
# USAGE: Update the $Version and $ReleaseDate variables below for each new release.
#        All references (MSI path, application name, content location) update automatically.
###############################################################################################################

#region ─── CONFIGURATION (edit these for each new version) ───────────────────────
$Version      = "11.2.1"
$ReleaseDate  = "7/21/2026"
$Owner        = "AppOwner"
$SupportContact = "Appsupport"
$publisher    = "Tenable"
$MsiFileName  = "NessusAgent-11.2.1-x64.msi"


# SCCM site
$SiteCode            = "SVR"
$ProviderMachineName = "mempr1.contoso.com"

# Paths
$SourceRoot   = "\\mempr1.contoso.com\source$\Tenable"
$FolderPath   = "${SiteCode}:\Application\Tenable"
$MsiPath      = "${SourceRoot}\${Version}\${MsiFileName}"
#endregion ────────────────────────────────────────────────────────────────────────

#region ─── GET MSI PRODUCT CODE ──────────────────────────────────────────────────
$installer = New-Object -ComObject WindowsInstaller.Installer
$database  = $installer.GetType().InvokeMember(
    "OpenDatabase",
    "InvokeMethod",
    $null,
    $installer,
    @($MsiPath, 0)
)

$query  = "SELECT Value FROM Property WHERE Property = 'ProductCode'"
$view   = $database.OpenView($query)
$view.Execute()
$record   = $view.Fetch()
$prodcode = $record.StringData(1)

Write-Host "Product Code: $prodcode"
#endregion ────────────────────────────────────────────────────────────────────────

#region ─── DERIVED VALUES (no edits needed) ──────────────────────────────────────
$icon         = "\\mempr1.contoso.com\source$\Tenable\Icon\Tenable.png"
$AppName      = "Tenable Agent ${Version} (See Comments)" # Localized Application Name
$ScriptPath      = "${SourceRoot}\${Version}"
$Description  = "Use TS to Deploy to Brownfield which removes Rapid7
Use this for Greenfield for new build" #Administrator Comments
$DeploymentTypeName = "Tenable Agent ${Version}"
$InstallCommand     = 'powershell.exe -ExecutionPolicy Bypass -file "Tenable_install.ps1"'
$UninstallCommand   = "msiexec /uninstall $MsiFileName /quiet"
$CollectionName     = "WINTSTSRVs"
$DPGroupName        = "All DPs"

#endregion ────────────────────────────────────────────────────────────────────────


#region ─── CONNECT TO SCCM ───────────────────────────────────────────────────────
$initParams = @{}

if ((Get-Module ConfigurationManager) -eq $null) {
    Import-Module "$($ENV:SMS_ADMIN_UI_PATH)\..\ConfigurationManager.psd1" @initParams
}

if ((Get-PSDrive -Name $SiteCode -PSProvider CMSite -ErrorAction SilentlyContinue) -eq $null) {
    New-PSDrive -Name $SiteCode -PSProvider CMSite -Root $ProviderMachineName @initParams
}

Set-Location "$($SiteCode):\" @initParams
#endregion ────────────────────────────────────────────────────────────────────────

#region ─── CREATE APPLICATION ────────────────────────────────────────────────────
New-CMApplication -Name $AppName `
                  -Description $Description `
                  -Publisher $publisher `
                  -SoftwareVersion $Version `
                  -ReleaseDate $ReleaseDate `
                  -AutoInstall $False `
                  -Owner $Owner `
                  -SupportContact $SupportContact `
                  -LocalizedName $AppName `
                  -IconLocationFile $icon

Move-CMObject -InputObject (Get-CMApplication -Name $AppName) -FolderPath $FolderPath
#endregion ────────────────────────────────────────────────────────────────────────

#region ─── ADD SCRIPT INSTALLER DEPLOYMENT TYPE ───────────────────────────────────────────────
Add-CMScriptDeploymentType -ApplicationName $AppName `
                        -DeploymentTypeName $DeploymentTypeName `
                        -ContentLocation $ScriptPath `
                        -InstallCommand $InstallCommand `
                        -UninstallCommand $UninstallCommand `
                        -InstallationBehaviorType InstallForSystem `
                        -SlowNetworkDeploymentMode Download `
                        -ProductCode $prodcode `
                        -RebootBehavior NoAction `
                        -MaximumRuntimeMins 15 `
                        -AddLanguage "en-US" `
                        -ContentFallback `
                        -LogonRequirementType WhetherOrNotUserLoggedOn
#endregion ─────────────────────────────────────────────────────────────────────────────────────

Write-Host "Application '$AppName' created and configured successfully." -ForegroundColor Green

#region ─── DISTRIBUTE CONTENT ───────────────────────────────────────────────

#Start-CMContentDistribution -ApplicationName "app name" -DistributionPointGroupName "All DPs"
Start-CMContentDistribution -ApplicationName $AppName -DistributionPointGroupName $DPGroupName

#endregion ───────────────────────────────────────────────────────────────────

Write-Host "Application '$AppName' Distributing to all DP's." -ForegroundColor Green

#region ─── DEPLOY CONTENT ───────────────────────────────────────────────
# 1. Safely extract the exact PackageID string using -ExpandProperty
$pkgid = Get-CMApplication -Name $appname | Select-Object -ExpandProperty PackageID

# 2. Loop and wait until content distribution is completely finished
Write-Host "Checking distribution status for $appname..."
while ($true) {
    $pkgprogress = Get-CMDistributionStatus -PackageId $pkgid
    
    # Calculate outstanding Distribution Points
    $wip = $pkgprogress.Targeted - $pkgprogress.NumberSuccess
    
    if ($wip -eq 0) {
        Write-Host "Content successfully distributed to all targeted DPs." -ForegroundColor Green
        break
    }
    
    Write-Host "Waiting on $wip Distribution Points. Sleeping for 60 seconds..." -ForegroundColor Yellow
    Start-Sleep -Seconds 60
}

# 3. Create the Required Deployment once content is verified green
New-CMApplicationDeployment `
    -Name $AppName `
    -CollectionName $CollectionName `
    -DeployAction Install `
    -DeployPurpose Required `
    -UserNotification DisplaySoftwareCenterOnly `
    -AllowRepair $true `
    -OverrideServiceWindow $true `
    -PersistOnWriteFilterDevice $false
    #endregion ───────────────────────────────────────────────────────────────────

Write-Host "Application '$AppName' Created, Distributed and Deployed to GCORE Team Servers." -ForegroundColor Green