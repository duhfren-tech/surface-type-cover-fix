# TypeCoverFix - disables USB power management for the Surface Type Cover
# and the USB hubs it is attached through, and turns off USB selective suspend.
# Must run as Administrator (the launcher handles elevation).

$ErrorActionPreference = 'Continue'
$stamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
$lines = New-Object System.Collections.Generic.List[string]
function Say($m) { $script:lines.Add($m); Write-Host $m }

Say "TypeCoverFix 1.0.0  ($stamp)"
$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
Say "administrator: $isAdmin"
if (-not $isAdmin) { Say "ERROR: run as administrator"; exit 1 }

# --- 1. find the Type Cover -------------------------------------------------
$coverIds = @()
foreach ($root in @('HKLM:\SYSTEM\CurrentControlSet\Enum\USB\VID_045E&PID_07E8')) {
    if (Test-Path $root) { $coverIds += (Get-ChildItem $root -ErrorAction SilentlyContinue | ForEach-Object { $_.PSChildName }) }
}
if ($coverIds.Count -eq 0) {
    Say "Type Cover not found - attach the keyboard cover and run again."
} else {
    Say "Type Cover instances: $($coverIds -join ', ')"
}

# hubs the cover may sit behind (Genesys / root hubs) + the cover itself
$targets = @()
foreach ($prefix in @('VID_045E&PID_07E8', 'VID_05E3&PID_0610', 'VID_05E3&PID_0626')) {
    $p = "HKLM:\SYSTEM\CurrentControlSet\Enum\USB\$prefix"
    if (Test-Path $p) { $targets += $p }
}
foreach ($p in (Get-ChildItem 'HKLM:\SYSTEM\CurrentControlSet\Enum\USB' -ErrorAction SilentlyContinue)) {
    if ($p.PSChildName -like 'ROOT_HUB*') { $targets += $p.PSPath }
}

$changed = 0
foreach ($t in $targets) {
    $insts = Get-ChildItem $t -ErrorAction SilentlyContinue
    foreach ($i in $insts) {
        $dp = Join-Path $i.PSPath 'Device Parameters'
        if (-not (Test-Path $dp)) { New-Item -Path $dp -Force | Out-Null }
        $before = @{}
        foreach ($n in @('SelectiveSuspendEnabled', 'EnhancedPowerManagementEnabled', 'AllowIdleIrpInD3')) {
            $v = (Get-ItemProperty -Path $dp -Name $n -ErrorAction SilentlyContinue).$n
            $before[$n] = $v
            try { New-ItemProperty -Path $dp -Name $n -Value 0 -PropertyType DWord -Force -ErrorAction Stop | Out-Null; $changed++ }
            catch { Say "  ! $($i.PSChildName) $n : $($_.Exception.Message)" }
        }
        Say ("  {0,-22} {1}  (was suspend={2} powerMgmt={3} idleIrp={4})" -f $i.PSChildName, (Split-Path $t -Leaf), $before['SelectiveSuspendEnabled'], $before['EnhancedPowerManagementEnabled'], $before['AllowIdleIrpInD3'])
    }
}
Say "values written: $changed"

# --- 2. USB selective suspend off in the active power scheme ----------------
$sub = '2a737441-1930-4402-8d77-b2bebba308a3'
$set = '48e6b7a6-50f5-4782-a5d4-53bb8f07e226'
& powercfg /setacvalueindex SCHEME_CURRENT $sub $set 0 | Out-Null
& powercfg /setdcvalueindex SCHEME_CURRENT $sub $set 0 | Out-Null
& powercfg /setactive SCHEME_CURRENT | Out-Null
$q = (& powercfg /query SCHEME_CURRENT $sub $set | Select-String -Pattern '0x0000' | Out-String).Trim()
Say "USB selective suspend (AC/DC):"
($q -split "`r?`n") | ForEach-Object { if ($_.Trim()) { Say ("  " + $_.Trim()) } }

# --- 3. restart the cover so it picks up the settings -----------------------
if ($coverIds.Count -gt 0) {
    $inst = "USB\VID_045E&PID_07E8\$($coverIds[0])"
    $r = (& pnputil /restart-device $inst 2>&1 | Out-String).Trim()
    Say "restart-device: $r"
    Start-Sleep -Seconds 3
    $present = Get-CimInstance Win32_PnPEntity -ErrorAction SilentlyContinue |
        Where-Object { $_.DeviceID -like '*PID_07E8*' -and $_.Name }
    Say "Type Cover child devices present: $(@($present).Count)"
    $present | ForEach-Object { Say ("  " + $_.Name + " | " + $_.Status + " | err=" + $_.ConfigManagerErrorCode) }
}

Say ""
Say "Done."
