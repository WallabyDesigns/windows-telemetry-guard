# Operations.ps1 - apply / read / restore primitives for registry, services, and tasks.
# Every mutating function returns a backup record describing the prior state.

# ---------- Registry ----------

function Get-TGRegistryCurrent {
    param([Parameter(Mandatory)]$Setting)
    try {
        $item = Get-ItemProperty -Path $Setting.Path -Name $Setting.Name -ErrorAction Stop
        return @{ Exists = $true; Value = $item.($Setting.Name); Denied = $false }
    } catch [System.Security.SecurityException] {
        # Some keys (e.g. WMI Autologger) are unreadable without an elevated
        # token. This is NOT the same as "not set" - report it distinctly so
        # a non-elevated status check doesn't show a false negative.
        return @{ Exists = $false; Value = $null; Denied = $true }
    } catch [System.UnauthorizedAccessException] {
        return @{ Exists = $false; Value = $null; Denied = $true }
    } catch {
        return @{ Exists = $false; Value = $null; Denied = $false }
    }
}

function Set-TGRegistryValue {
    param([Parameter(Mandatory)]$Setting)

    $current = Get-TGRegistryCurrent -Setting $Setting
    if (-not (Test-Path $Setting.Path)) {
        New-Item -Path $Setting.Path -Force | Out-Null
        $keyCreated = $true
    } else {
        $keyCreated = $false
    }
    New-ItemProperty -Path $Setting.Path -Name $Setting.Name -Value $Setting.Value `
        -PropertyType DWord -Force | Out-Null

    return [pscustomobject]@{
        Kind          = 'Registry'
        Path          = $Setting.Path
        Name          = $Setting.Name
        Existed       = $current.Exists
        PreviousValue = $current.Value
        KeyCreated    = $keyCreated
    }
}

function Restore-TGRegistryValue {
    param([Parameter(Mandatory)]$Record)

    if ($Record.Existed) {
        if (-not (Test-Path $Record.Path)) { New-Item -Path $Record.Path -Force | Out-Null }
        New-ItemProperty -Path $Record.Path -Name $Record.Name -Value $Record.PreviousValue `
            -PropertyType DWord -Force | Out-Null
    } elseif (Test-Path $Record.Path) {
        Remove-ItemProperty -Path $Record.Path -Name $Record.Name -ErrorAction SilentlyContinue
    }
}

# ---------- Services ----------

function Get-TGServiceCurrent {
    param([Parameter(Mandatory)][string]$Name)
    $svc = Get-Service -Name $Name -ErrorAction SilentlyContinue
    if (-not $svc) { return $null }
    return @{ StartType = [string]$svc.StartType; Status = [string]$svc.Status }
}

function Disable-TGService {
    param([Parameter(Mandatory)][string]$Name)

    $current = Get-TGServiceCurrent -Name $Name
    if (-not $current) { return $null }  # service not present on this machine

    Set-Service -Name $Name -StartupType Disabled
    if ($current.Status -eq 'Running') {
        Stop-Service -Name $Name -Force -ErrorAction SilentlyContinue
    }

    return [pscustomobject]@{
        Kind              = 'Service'
        Name              = $Name
        PreviousStartType = $current.StartType
        WasRunning        = ($current.Status -eq 'Running')
    }
}

function Restore-TGService {
    param([Parameter(Mandatory)]$Record)

    if (-not (Get-Service -Name $Record.Name -ErrorAction SilentlyContinue)) { return }
    Set-Service -Name $Record.Name -StartupType $Record.PreviousStartType
    if ($Record.WasRunning) {
        Start-Service -Name $Record.Name -ErrorAction SilentlyContinue
    }
}

# ---------- Scheduled tasks ----------

function Get-TGTaskCurrent {
    param([Parameter(Mandatory)]$TaskDef)
    $task = Get-ScheduledTask -TaskPath $TaskDef.TaskPath -TaskName $TaskDef.TaskName -ErrorAction SilentlyContinue
    if (-not $task) { return $null }
    return @{ State = [string]$task.State }
}

function Disable-TGTask {
    param([Parameter(Mandatory)]$TaskDef)

    $current = Get-TGTaskCurrent -TaskDef $TaskDef
    if (-not $current) { return $null }  # task not present on this build

    Disable-ScheduledTask -TaskPath $TaskDef.TaskPath -TaskName $TaskDef.TaskName | Out-Null

    return [pscustomobject]@{
        Kind       = 'Task'
        TaskPath   = $TaskDef.TaskPath
        TaskName   = $TaskDef.TaskName
        WasEnabled = ($current.State -ne 'Disabled')
    }
}

function Restore-TGTask {
    param([Parameter(Mandatory)]$Record)

    if (-not (Get-ScheduledTask -TaskPath $Record.TaskPath -TaskName $Record.TaskName -ErrorAction SilentlyContinue)) { return }
    if ($Record.WasEnabled) {
        Enable-ScheduledTask -TaskPath $Record.TaskPath -TaskName $Record.TaskName | Out-Null
    }
}
