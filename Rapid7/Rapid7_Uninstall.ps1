# =============================================
# Rapid7 Insight Agent - Complete Removal (Dynamic)
# =============================================
 
# Map HKCR if not already mapped
if (-not (Get-PSDrive -Name HKCR -ErrorAction SilentlyContinue)) {
    New-PSDrive -Name HKCR -PSProvider Registry -Root HKEY_CLASSES_ROOT | Out-Null
}
 
$serviceName = "ir_agent"
 
# --- DYNAMICALLY DISCOVER INSTALLED VERSION ---
$uninstallPaths = @(
    "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*",
    "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*"
)
 
$entry = $null
foreach ($path in $uninstallPaths) {
    $found = Get-ItemProperty $path -ErrorAction SilentlyContinue |
        Where-Object { $_.DisplayName -like "*Insight Agent*" -or $_.DisplayName -like "*Rapid7*" }
    if ($found) { $entry = $found; break }
}
 
if (-not $entry) {
    Write-Output "[$env:COMPUTERNAME] Rapid7 Insight Agent not found - skipping"
    exit 0
}
 
$guid = $entry.PSChildName
$installFolder = $entry.InstallLocation -replace '\\$', ''
if (-not $installFolder) { $installFolder = "$env:ProgramFiles\Rapid7\Insight Agent" }
 
Write-Output "[$env:COMPUTERNAME] Found       : $($entry.DisplayName) v$($entry.DisplayVersion)"
Write-Output "[$env:COMPUTERNAME] GUID        : $guid"
Write-Output "[$env:COMPUTERNAME] InstallPath : $installFolder"
 
# --- STEP 1: STOP SERVICE ---
Write-Output "`n[$env:COMPUTERNAME] Stopping service..."
$s = Get-Service -Name $serviceName -ErrorAction SilentlyContinue
if ($s) {
    Stop-Service -Name $serviceName -Force -ErrorAction SilentlyContinue
    Write-Output "[$env:COMPUTERNAME] Stopped : $serviceName"
} else {
    Write-Output "[$env:COMPUTERNAME] Not found: $serviceName"
}
Start-Sleep -Seconds 3
 
# --- STEP 2: RUN OFFICIAL MSI UNINSTALL ---
Write-Output "`n[$env:COMPUTERNAME] Running MSI uninstall..."
$msiArgs = "/X$guid /quiet /norestart /L*v `"$env:TEMP\r7_uninstall.log`""
$proc = Start-Process msiexec.exe -ArgumentList $msiArgs -Wait -PassThru
Write-Output "[$env:COMPUTERNAME] MSI exit code: $($proc.ExitCode)"
# 0 or 3010 = success | 1612 = source missing (fallback below handles it) | 1605 = already removed
 
Start-Sleep -Seconds 5
 
# --- STEP 3: DELETE LEFTOVER SERVICE ---
$s = Get-Service -Name $serviceName -ErrorAction SilentlyContinue
if ($s) {
    Stop-Service -Name $serviceName -Force -ErrorAction SilentlyContinue
    sc.exe delete $serviceName | Out-Null
    Write-Output "[$env:COMPUTERNAME] Force-deleted leftover service: $serviceName"
}
 
# --- STEP 4: REMOVE LEFTOVER REGISTRY KEYS ---
Write-Output "`n[$env:COMPUTERNAME] Checking leftover registry entries..."
$g = $guid -replace '[{}-]', ''
$scrambled = -join ($g[7..0] + $g[11..8] + $g[15..12] + $g[17,16,19,18] + $g[21,20,23,22,25,24,27,26,29,28,31,30])
 
$regKeys = @(
    "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\$guid",
    "HKLM\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\$guid",
    "HKCR\Installer\Products\$scrambled",
    "HKCR\Installer\Features\$scrambled",
    "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Installer\UserData\S-1-5-18\Products\$scrambled"
)
foreach ($key in $regKeys) {
    reg query "$key" >$null 2>&1
    if ($LASTEXITCODE -eq 0) {
        reg delete "$key" /f 2>&1 | Out-Null
        Write-Output "[$env:COMPUTERNAME] Removed leftover key: $key"
    }
}
 
# --- STEP 5: REMOVE LEFTOVER INSTALL FOLDER ---
Write-Output "`n[$env:COMPUTERNAME] Checking install folder..."
if ($installFolder -and (Test-Path $installFolder)) {
    takeown /f "$installFolder" /r /d y 2>&1 | Out-Null
    icacls "$installFolder" /grant Administrators:F /t /c /q 2>&1 | Out-Null
    cmd /c "rd /s /q `"$installFolder`"" 2>&1 | Out-Null
 
    if (Test-Path $installFolder) {
        Write-Output "[$env:COMPUTERNAME] Failed  : $installFolder - still exists"
    } else {
        Write-Output "[$env:COMPUTERNAME] Removed : $installFolder"
    }
} else {
    Write-Output "[$env:COMPUTERNAME] Already clean: $installFolder"
}
 
# --- STEP 6: REMOVE PROGRAMDATA (config/logs) ---
Write-Output "`n[$env:COMPUTERNAME] Checking ProgramData..."
foreach ($pd in @("$env:ProgramData\rapid7", "$env:ProgramData\Rapid7")) {
    if (Test-Path $pd) {
        cmd /c "rd /s /q `"$pd`"" 2>&1 | Out-Null
        if (Test-Path $pd) {
            Write-Output "[$env:COMPUTERNAME] Failed  : $pd - still exists"
        } else {
            Write-Output "[$env:COMPUTERNAME] Removed : $pd"
        }
    } else {
        Write-Output "[$env:COMPUTERNAME] Already clean: $pd"
    }
}
 
# --- VERIFY ---
Write-Output "`n[$env:COMPUTERNAME] Verifying removal..."
$remaining = $false
 
foreach ($key in $regKeys) {
    reg query "$key" >$null 2>&1
    if ($LASTEXITCODE -eq 0) {
        Write-Output "[$env:COMPUTERNAME] WARNING : Still exists - $key"
        $remaining = $true
    } else {
        Write-Output "[$env:COMPUTERNAME] CLEARED : $key"
    }
}
 
if ($installFolder -and (Test-Path $installFolder)) {
    Write-Output "[$env:COMPUTERNAME] WARNING : Still exists - $installFolder"
    $remaining = $true
} else {
    Write-Output "[$env:COMPUTERNAME] CLEARED : $installFolder"
}
 
$s = Get-Service -Name $serviceName -ErrorAction SilentlyContinue
if ($s) {
    Write-Output "[$env:COMPUTERNAME] WARNING : Service still exists - $serviceName"
    $remaining = $true
} else {
    Write-Output "[$env:COMPUTERNAME] CLEARED : Service - $serviceName"
}
 
if (-not $remaining) {
    Write-Output "`n[$env:COMPUTERNAME] SUCCESS: Rapid7 Insight Agent fully removed!"
} else {
    Write-Output "`n[$env:COMPUTERNAME] WARNING: Some items remain - manual check needed"
}