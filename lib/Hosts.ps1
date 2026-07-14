# Hosts.ps1 - optional (Strict) hosts-file blocking of telemetry endpoints.
# All entries live between clearly-marked BEGIN/END lines so revert is exact.

$script:TGHostsFile   = Join-Path $env:SystemRoot 'System32\drivers\etc\hosts'
$script:TGBeginMarker = '# === TelemetryGuard BEGIN (do not edit inside this block) ==='
$script:TGEndMarker   = '# === TelemetryGuard END ==='

function Test-TGHostsBlockApplied {
    if (-not (Test-Path $script:TGHostsFile)) { return $false }
    return (Select-String -Path $script:TGHostsFile -Pattern ([regex]::Escape($script:TGBeginMarker)) -Quiet)
}

function Add-TGHostsBlock {
    param([Parameter(Mandatory)][string[]]$Hostnames)

    if (Test-TGHostsBlockApplied) { return $false }  # already applied; nothing to do

    $block = @($script:TGBeginMarker)
    foreach ($h in $Hostnames) {
        $block += "0.0.0.0 $h"
    }
    $block += $script:TGEndMarker

    $existing = Get-Content -Path $script:TGHostsFile -ErrorAction Stop
    Set-Content -Path $script:TGHostsFile -Value ($existing + '' + $block) -Encoding ascii
    return $true
}

function Remove-TGHostsBlock {
    if (-not (Test-TGHostsBlockApplied)) { return $false }

    $lines = Get-Content -Path $script:TGHostsFile
    $kept = New-Object System.Collections.Generic.List[string]
    $inBlock = $false
    foreach ($line in $lines) {
        if ($line -eq $script:TGBeginMarker) { $inBlock = $true; continue }
        if ($line -eq $script:TGEndMarker)   { $inBlock = $false; continue }
        if (-not $inBlock) { $kept.Add($line) }
    }
    Set-Content -Path $script:TGHostsFile -Value $kept -Encoding ascii
    return $true
}
