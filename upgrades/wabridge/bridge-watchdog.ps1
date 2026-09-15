# <your PAIA name here> WhatsApp bridge watchdog - runs every 5 min from the scheduled task. Version 2026-09-15.
# States: OK / RESTARTED (no process, >1 process, keepalive or socket errors after last connect)
#         NEEDS-QR (WhatsApp unlinked the device - only a phone scan fixes it; no restart loop)
#         OUTDATED (WhatsApp retired this bridge version - only a new bridge exe fixes it; no restart loop, no QR)
#         STALE? (store untouched >4h in 07-22 - may just be quiet, worth a look)
# Writes bridge-status.txt that <your PAIA name here> reads at session start.
$dir = Join-Path $PSScriptRoot "whatsapp-bridge"; $log = Join-Path $dir "bridge.log"; $status = Join-Path $PSScriptRoot "bridge-status.txt"
$task = "<your PAIA name here> WhatsApp Bridge"; $now = Get-Date; $state = "OK"; $note = ""
$procs = @(Get-Process whatsapp-bridge -ErrorAction SilentlyContinue)
$tail = if (Test-Path $log) { Get-Content $log -Tail 400 } else { @() }
$lastAuth  = ($tail | Select-String "Successfully authenticated|Successfully connected|Connected to WhatsApp" | Select-Object -Last 1).LineNumber
$lastBad   = ($tail | Select-String "Keepalive timed out|Error reconnecting|Failed to establish stable connection|Error reading from websocket|stream error" | Select-Object -Last 1).LineNumber
$outdated  = ($tail | Select-String "Client outdated" | Select-Object -Last 1).LineNumber
$loggedOut = ($tail | Select-String "Device logged out|logged out from another device" | Select-Object -Last 1).LineNumber
if ($outdated -and (-not $lastAuth -or $outdated -gt $lastAuth)) { $state = "OUTDATED"; $note = "WhatsApp retired this bridge version (405) - a restart or QR scan will not help; install the newer whatsapp-bridge.exe from the wabridge upgrade, then run the task again" }
elseif ($loggedOut -and (-not $lastAuth -or $loggedOut -gt $lastAuth)) { $state = "NEEDS-QR"; $note = "WhatsApp unlinked this device - run 'WhatsApp Setup.bat' on the Desktop and scan again" }
elseif ($procs.Count -eq 0) { $state = "RESTARTED"; $note = "no bridge process"; schtasks /run /tn "$task" | Out-Null }
elseif ($procs.Count -gt 1) { $state = "RESTARTED"; $note = "$($procs.Count) bridge processes"; $procs | Stop-Process -Force; Start-Sleep 2; schtasks /run /tn "$task" | Out-Null }
elseif ($lastBad -and (-not $lastAuth -or $lastBad -gt $lastAuth)) { $state = "RESTARTED"; $note = "connection errors after last connect"; $procs | Stop-Process -Force; Start-Sleep 2; schtasks /run /tn "$task" | Out-Null }
else {
  $db = Get-ChildItem (Join-Path $dir "store") -Filter "messages.db*" -ErrorAction SilentlyContinue | Sort-Object LastWriteTime | Select-Object -Last 1
  if ($db -and $now.Hour -ge 7 -and $now.Hour -le 22 -and ($now - $db.LastWriteTime).TotalHours -gt 4) { $state = "STALE?"; $note = "store untouched since $($db.LastWriteTime)" }
}
$port = try { (Test-NetConnection 127.0.0.1 -Port 8080 -WarningAction SilentlyContinue -InformationLevel Quiet) } catch { $false }
"$($now.ToString('yyyy-MM-dd HH:mm')) | $state | port8080=$port | procs=$($procs.Count) | $note" | Set-Content $status -Encoding UTF8
