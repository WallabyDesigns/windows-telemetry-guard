<#
.SYNOPSIS
    TelemetryGuard - inspect, disable, and revert Windows telemetry / tracking.

.DESCRIPTION
    Status (default) : read-only report of every managed setting vs. its hardened value.
    Apply            : harden all settings. Saves a timestamped backup of prior state first.
    Revert           : restore prior state from the most recent backup (or -BackupFile).

    -Strict adds: web search fully removed from Start menu, plus a hosts-file block
    of Microsoft telemetry endpoints (never Windows Update / Defender / Store hosts).

.EXAMPLE
    .\TelemetryGuard.ps1                    # status report (no admin needed)
    .\TelemetryGuard.ps1 -Mode Apply        # harden (run as Administrator)
    .\TelemetryGuard.ps1 -Mode Apply -Strict
    .\TelemetryGuard.ps1 -Mode Revert       # undo, from latest backup
    .\TelemetryGuard.ps1 -Json              # status report as JSON (used by the GUI)
#>
[CmdletBinding()]
param(
    [ValidateSet('Status', 'Apply', 'Revert')]
    [string]$Mode = 'Status',

    [switch]$Strict,

    [string]$BackupFile,

    [switch]$Json
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$script:Root = Split-Path -Parent $MyInvocation.MyCommand.Path
$script:BackupDir = Join-Path $script:Root 'backups'

. (Join-Path $script:Root 'lib\Catalog.ps1')
. (Join-Path $script:Root 'lib\Operations.ps1')
. (Join-Path $script:Root 'lib\Hosts.ps1')
. (Join-Path $script:Root 'lib\Backup.ps1')

function Get-TGProp {
    param($InputObject, [string]$Name, $Default = $null)
    if ($InputObject.PSObject.Properties.Name -contains $Name) { $InputObject.$Name } else { $Default }
}

function Test-TGAdmin {
    $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($identity)
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

function Get-TGActiveRegistrySettings {
    Get-TGRegistrySettings | Where-Object { $_.Level -eq 'Balanced' -or $Strict }
}

# ---------------- Status ----------------

function Invoke-TGStatus {
    $rows = New-Object System.Collections.Generic.List[object]

    foreach ($setting in Get-TGActiveRegistrySettings) {
        $current = Get-TGRegistryCurrent -Setting $setting
        $currentText = if ($current.Denied) { '(unknown - requires admin to verify)' }
                       elseif ($current.Exists) { "$($current.Value)" }
                       else { '(not set)' }
        $rows.Add([pscustomobject]@{
            Category = $setting.Category
            Item     = "$($setting.Name)"
            Current  = $currentText
            Hardened = "$($setting.Value)"
            Note     = "$($setting.Note)"
            Capped   = [bool](Get-TGProp $setting 'Capped' $false)
            Verified = (-not $current.Denied)
            OK       = ($current.Exists -and "$($current.Value)" -eq "$($setting.Value)")
        })
    }

    foreach ($svcDef in Get-TGServices) {
        $current = Get-TGServiceCurrent -Name $svcDef.Name
        $currentText = if ($current) { "$($current.StartType)/$($current.Status)" } else { '(not present)' }
        $rows.Add([pscustomobject]@{
            Category = 'Service'
            Item     = $svcDef.Name
            Current  = $currentText
            Hardened = 'Disabled/Stopped'
            Note     = "$($svcDef.Note)"
            Capped   = $false
            Verified = $true
            OK       = (-not $current) -or ($current.StartType -eq 'Disabled' -and $current.Status -ne 'Running')
        })
    }

    foreach ($taskDef in Get-TGScheduledTasks) {
        $current = Get-TGTaskCurrent -TaskDef $taskDef
        $currentText = if ($current) { $current.State } else { '(not present)' }
        $rows.Add([pscustomobject]@{
            Category = 'Scheduled task'
            Item     = "$($taskDef.TaskPath)$($taskDef.TaskName)"
            Current  = $currentText
            Hardened = 'Disabled'
            Note     = "$($taskDef.Note)"
            Capped   = $false
            Verified = $true
            OK       = (-not $current) -or ($current.State -eq 'Disabled')
        })
    }

    if ($Strict) {
        $rows.Add([pscustomobject]@{
            Category = 'Hosts file'
            Item     = 'Telemetry endpoint block'
            Current  = if (Test-TGHostsBlockApplied) { 'applied' } else { 'not applied' }
            Hardened = 'applied'
            Note     = 'STRICT: blocks ~26 Microsoft telemetry hostnames (vortex/watson/events) via marked hosts-file entries. Never touches Windows Update, Defender, Store, or activation hosts.'
            Capped   = $false
            Verified = $true
            OK       = (Test-TGHostsBlockApplied)
        })
    }

    if ($Json) {
        $done = @($rows | Where-Object OK).Count
        $unverified = @($rows | Where-Object { -not $_.Verified }).Count
        [pscustomobject]@{
            Rows        = $rows
            Done        = $done
            Total       = $rows.Count
            Unverified  = $unverified
            IsAdmin     = (Test-TGAdmin)
            Strict      = [bool]$Strict
        } | ConvertTo-Json -Depth 6
        return
    }

    $rows | Format-Table -AutoSize -Wrap
    $done = @($rows | Where-Object OK).Count
    $unverified = @($rows | Where-Object { -not $_.Verified }).Count
    Write-Host ("{0} of {1} settings are in the hardened state." -f $done, $rows.Count) -ForegroundColor Cyan
    if ($unverified -gt 0) {
        Write-Host ("{0} setting(s) could not be verified without an elevated prompt (shown as unknown, not counted as hardened or not)." -f $unverified) -ForegroundColor Yellow
    }
    if (-not (Test-TGAdmin)) {
        Write-Host 'Note: run from an elevated (Administrator) prompt to Apply or Revert.' -ForegroundColor Yellow
    }
}

# ---------------- Apply ----------------

function Invoke-TGApply {
    if (-not (Test-TGAdmin)) {
        throw 'Apply requires an elevated prompt. Right-click PowerShell -> Run as administrator.'
    }

    $backup = [ordered]@{
        Timestamp = (Get-Date).ToString('o')
        Strict    = [bool]$Strict
        Registry  = @()
        Services  = @()
        Tasks     = @()
        HostsBlockAddedByUs = $false
    }
    $failures = New-Object System.Collections.Generic.List[string]

    foreach ($setting in Get-TGActiveRegistrySettings) {
        try {
            $backup.Registry += Set-TGRegistryValue -Setting $setting
            Write-Host "[reg]  $($setting.Path)\$($setting.Name) = $($setting.Value)" -ForegroundColor Green
        } catch {
            $failures.Add("Registry $($setting.Path)\$($setting.Name): $($_.Exception.Message)")
        }
    }

    foreach ($svcDef in Get-TGServices) {
        try {
            $record = Disable-TGService -Name $svcDef.Name
            if ($record) {
                $backup.Services += $record
                Write-Host "[svc]  $($svcDef.Name) disabled and stopped" -ForegroundColor Green
            } else {
                Write-Host "[svc]  $($svcDef.Name) not present - skipped" -ForegroundColor DarkGray
            }
        } catch {
            $failures.Add("Service $($svcDef.Name): $($_.Exception.Message)")
        }
    }

    foreach ($taskDef in Get-TGScheduledTasks) {
        try {
            $record = Disable-TGTask -TaskDef $taskDef
            if ($record) {
                $backup.Tasks += $record
                Write-Host "[task] $($taskDef.TaskPath)$($taskDef.TaskName) disabled" -ForegroundColor Green
            } else {
                Write-Host "[task] $($taskDef.TaskPath)$($taskDef.TaskName) not present - skipped" -ForegroundColor DarkGray
            }
        } catch {
            $failures.Add("Task $($taskDef.TaskPath)$($taskDef.TaskName): $($_.Exception.Message)")
        }
    }

    if ($Strict) {
        try {
            $backup.HostsBlockAddedByUs = Add-TGHostsBlock -Hostnames (Get-TGBlockedHosts)
            if ($backup.HostsBlockAddedByUs) {
                Write-Host '[hosts] Telemetry endpoint block added to hosts file' -ForegroundColor Green
            } else {
                Write-Host '[hosts] Block already present - left as-is' -ForegroundColor DarkGray
            }
        } catch {
            $failures.Add("Hosts file: $($_.Exception.Message)")
        }
    }

    $backupPath = Save-TGBackup -Backup $backup -BackupDir $script:BackupDir
    Write-Host ""
    Write-Host "Backup of prior state saved to: $backupPath" -ForegroundColor Cyan
    Write-Host 'Sign out and back in (or reboot) for every setting to take full effect.' -ForegroundColor Cyan

    if ($failures.Count -gt 0) {
        Write-Host ""
        Write-Warning ("{0} item(s) failed:" -f $failures.Count)
        $failures | ForEach-Object { Write-Warning "  $_" }
        exit 1
    }
}

# ---------------- Revert ----------------

function Invoke-TGRevert {
    if (-not (Test-TGAdmin)) {
        throw 'Revert requires an elevated prompt. Right-click PowerShell -> Run as administrator.'
    }

    if ($BackupFile) {
        $backupPath = $BackupFile
    } else {
        $latest = Get-TGLatestBackup -BackupDir $script:BackupDir
        if (-not $latest) { throw "No backups found in $script:BackupDir - nothing to revert." }
        $backupPath = $latest.FullName
    }

    $backup = Read-TGBackup -Path $backupPath
    Write-Host "Reverting from backup: $backupPath (taken $($backup.Timestamp))" -ForegroundColor Cyan
    $failures = New-Object System.Collections.Generic.List[string]

    foreach ($record in @($backup.Registry)) {
        try {
            Restore-TGRegistryValue -Record $record
            $desc = if ($record.Existed) { "restored to $($record.PreviousValue)" } else { 'removed (did not exist before)' }
            Write-Host "[reg]  $($record.Path)\$($record.Name) $desc" -ForegroundColor Green
        } catch {
            $failures.Add("Registry $($record.Path)\$($record.Name): $($_.Exception.Message)")
        }
    }

    foreach ($record in @($backup.Services)) {
        try {
            Restore-TGService -Record $record
            Write-Host "[svc]  $($record.Name) restored to $($record.PreviousStartType)" -ForegroundColor Green
        } catch {
            $failures.Add("Service $($record.Name): $($_.Exception.Message)")
        }
    }

    foreach ($record in @($backup.Tasks)) {
        try {
            Restore-TGTask -Record $record
            if ($record.WasEnabled) {
                Write-Host "[task] $($record.TaskPath)$($record.TaskName) re-enabled" -ForegroundColor Green
            }
        } catch {
            $failures.Add("Task $($record.TaskPath)$($record.TaskName): $($_.Exception.Message)")
        }
    }

    if ($backup.HostsBlockAddedByUs) {
        try {
            if (Remove-TGHostsBlock) {
                Write-Host '[hosts] Telemetry endpoint block removed from hosts file' -ForegroundColor Green
            }
        } catch {
            $failures.Add("Hosts file: $($_.Exception.Message)")
        }
    }

    Write-Host ""
    Write-Host 'Revert complete. Sign out and back in (or reboot) to finish.' -ForegroundColor Cyan

    if ($failures.Count -gt 0) {
        Write-Host ""
        Write-Warning ("{0} item(s) failed:" -f $failures.Count)
        $failures | ForEach-Object { Write-Warning "  $_" }
        exit 1
    }
}

# ---------------- Dispatch ----------------

switch ($Mode) {
    'Status' { Invoke-TGStatus }
    'Apply'  { Invoke-TGApply }
    'Revert' { Invoke-TGRevert }
}
