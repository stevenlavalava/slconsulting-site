# wabridge installer (Windows) - swaps a PAIA's WhatsApp bridge for the 2026-09-15 build
# (whatsmeow v0.0.0-20260914150520) after WhatsApp's 405 "Client outdated" cut-off.
# Run in PowerShell:  irm https://stevenlava.com/upgrades/wabridge/install.ps1 | iex
# Safe to re-run. Keeps the pairing (store\ untouched). Backs up the old exe.
$ErrorActionPreference = "Stop"
$Base = if ($env:WABRIDGE_BASE) { $env:WABRIDGE_BASE } else { "https://stevenlava.com/upgrades/wabridge" }
$Stamp = "20260915"
$ExeSha256 = "1e074d6c6ccf64674e4f09f71b311cba44cd08cfbd81e1718fbfba7eca897224"
function Say($m) { Write-Host $m }
function Die($m) { Write-Host "FAILED: $m"; exit 1 }

# 1. Find the current bridge exe: running process -> scheduled task -> known folders
$Target = $null
$procs = @(Get-Process whatsapp-bridge -ErrorAction SilentlyContinue)
if ($procs.Count -gt 0) { $Target = $procs[0].Path }
$Task = Get-ScheduledTask -ErrorAction SilentlyContinue | Where-Object { $_.TaskName -like "*WhatsApp Bridge*" } | Select-Object -First 1
if (-not $Target -and $Task) {
  $act = ($Task.Actions | ForEach-Object { "$($_.Execute) $($_.Arguments)" }) -join " "
  $m = [regex]::Match($act, '([A-Za-z]:\\[^"]*?whatsapp-bridge\.exe)')
  if ($m.Success) { $Target = $m.Value }
  elseif ($act -match '([A-Za-z]:\\[^"]*?run-bridge\.vbs)') {
    $vbs = Get-Content $Matches[1] -Raw -ErrorAction SilentlyContinue
    $m2 = [regex]::Match($vbs, '([A-Za-z]:\\[^"]*?whatsapp-bridge\.exe)'); if ($m2.Success) { $Target = $m2.Value }
    elseif ($vbs -match '%LOCALAPPDATA%\\([^\\"]+)\\whatsapp-bridge') { $Target = Join-Path $env:LOCALAPPDATA "$($Matches[1])\whatsapp-bridge\whatsapp-bridge.exe" }
  }
}
if (-not $Target -or -not (Test-Path $Target)) {
  $cands = @(Get-ChildItem "$env:LOCALAPPDATA\*\whatsapp-bridge\whatsapp-bridge.exe" -ErrorAction SilentlyContinue) +
           @(Get-ChildItem "$env:USERPROFILE\Desktop\*\modules\whatsapp-bridge\whatsapp-bridge.exe" -ErrorAction SilentlyContinue) +
           @(Get-ChildItem "$env:USERPROFILE\*\modules\whatsapp-bridge\whatsapp-bridge.exe" -ErrorAction SilentlyContinue)
  if ($cands.Count -gt 0) { $Target = $cands[0].FullName }
}
if (-not $Target -or -not (Test-Path $Target)) { Die "could not find whatsapp-bridge.exe. Tell your owner's assistant (Bilbo) where it lives." }
Say "bridge exe: $Target"
$Dir = Split-Path $Target
if ($Task) { Say "scheduled task: $($Task.TaskName)" } else { Say "no scheduled task found - will start the exe directly afterwards" }

# 2. Download the new exe
$Tmp = Join-Path $env:TEMP "whatsapp-bridge-win32-x64.exe"
Say "downloading ..."
Invoke-WebRequest -Uri "$Base/whatsapp-bridge-win32-x64.exe" -OutFile $Tmp -UseBasicParsing
if ((Get-Item $Tmp).Length -lt 10MB) { Die "download looks wrong (too small)" }
$got = (Get-FileHash $Tmp -Algorithm SHA256).Hash.ToLower()
if ($got -ne $ExeSha256) { Die "SHA256 mismatch on the downloaded exe (got $got, expected $ExeSha256) - nothing changed" }
Say "sha256 verified: $got"
Unblock-File $Tmp -ErrorAction SilentlyContinue

# 3. Stop everything, swap, start one
if ($Task) { schtasks /end /tn "$($Task.TaskName)" 2>$null | Out-Null }
Get-Process whatsapp-bridge -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
Start-Sleep 3
if (@(Get-Process whatsapp-bridge -ErrorAction SilentlyContinue).Count -gt 0) { Die "a bridge process is still running; stop it and re-run" }
if (-not (Test-Path "$Target.bak-$Stamp")) { Copy-Item $Target "$Target.bak-$Stamp" -Force } else { Say "backup already exists, keeping it" }
Copy-Item $Tmp $Target -Force
Say "swapped (backup at $Target.bak-$Stamp)"

# 4. Watchdog, if this setup has one next to the bridge folder
$Wd = Join-Path (Split-Path $Dir) "bridge-watchdog.ps1"
if (Test-Path $Wd) {
  $name = if ($Task) { ($Task.TaskName -replace ' WhatsApp Bridge$','') } else { $null }
  if ($name) {
    Copy-Item $Wd "$Wd.bak-$Stamp" -Force
    $new = (Invoke-WebRequest -Uri "$Base/bridge-watchdog.ps1" -UseBasicParsing).Content -replace '<your PAIA name here>', $name
    Set-Content -Path $Wd -Value $new -Encoding UTF8
    Say "watchdog updated (OUTDATED state + socket-error patterns) for task prefix '$name'"
  }
}

# 5. Start and verify
if ($Task) { schtasks /run /tn "$($Task.TaskName)" | Out-Null; Say "task started" }
else { Start-Process -FilePath $Target -WorkingDirectory $Dir -WindowStyle Hidden; Say "exe started directly - set up the logon task afterwards" }
$Log = @(Get-ChildItem $Dir -Filter "*.log" -ErrorAction SilentlyContinue | Sort-Object LastWriteTime -Descending | Select-Object -First 1).FullName
Say "waiting for 'Connected to WhatsApp' ..."
for ($i = 0; $i -lt 45; $i++) {
  Start-Sleep 2
  if ($Log -and (Test-Path $Log)) {
    $tail = Get-Content $Log -Tail 60 -ErrorAction SilentlyContinue
    if (($tail | Select-String "Device logged out")) { Say "swapped, but WhatsApp has unlinked this device - the one case that needs a QR scan. Run 'WhatsApp Setup.bat' on the Desktop."; exit 2 }
    if (($tail | Select-String "Connected to WhatsApp") -and -not ($tail | Select-String "Client outdated")) {
      $n = @(Get-Process whatsapp-bridge -ErrorAction SilentlyContinue).Count
      Say "OK: connected ($n bridge process). Pairing kept. Messages missed while down will backfill on their own."; Say "wabridge $Stamp installed"; exit 0
    }
  }
}
$n = @(Get-Process whatsapp-bridge -ErrorAction SilentlyContinue).Count
$port = try { Test-NetConnection 127.0.0.1 -Port 8080 -WarningAction SilentlyContinue -InformationLevel Quiet } catch { $false }
Say "swapped and started (processes=$n, port8080=$port) but no 'Connected to WhatsApp' seen in $Log yet. Check the log in a minute; if it shows 405 again, tell Bilbo."; exit 3
