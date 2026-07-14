# Backup.ps1 - persist and reload the prior-state snapshot used by Revert.

function Save-TGBackup {
    param(
        [Parameter(Mandatory)]$Backup,
        [Parameter(Mandatory)][string]$BackupDir
    )
    if (-not (Test-Path $BackupDir)) { New-Item -ItemType Directory -Path $BackupDir -Force | Out-Null }
    $stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
    $file = Join-Path $BackupDir "backup-$stamp.json"
    $Backup | ConvertTo-Json -Depth 6 | Set-Content -Path $file -Encoding utf8
    return $file
}

function Get-TGLatestBackup {
    param([Parameter(Mandatory)][string]$BackupDir)
    if (-not (Test-Path $BackupDir)) { return $null }
    Get-ChildItem -Path $BackupDir -Filter 'backup-*.json' |
        Sort-Object LastWriteTime -Descending |
        Select-Object -First 1
}

function Read-TGBackup {
    param([Parameter(Mandatory)][string]$Path)
    if (-not (Test-Path $Path)) {
        throw "Backup file not found: $Path"
    }
    Get-Content -Path $Path -Raw | ConvertFrom-Json
}
