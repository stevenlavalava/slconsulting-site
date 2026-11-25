# Leo bridge setup: OpenSSH server, Leo's key only, no passwords, tailnet-only.
$ErrorActionPreference = 'Stop'
$key = 'ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIJcPfQ9fCyfwZSEM3OeN7bkSwaZm5Ubi2YFpHW+lRif8 rico-laptop'
function Say($t){ Write-Host "  $t" -ForegroundColor White }
try {
  Say 'STEP 1 of 4: install the SSH server (can take a few minutes)...'
  $cap = Get-WindowsCapability -Online | Where-Object Name -like 'OpenSSH.Server*'
  if ($cap.State -ne 'Installed') { Add-WindowsCapability -Online -Name $cap.Name | Out-Null }
  Set-Service sshd -StartupType Automatic
  Start-Service sshd
  Say 'OK'

  Say 'STEP 2 of 4: trust Leo''s key only'
  $adm = "$env:ProgramData\ssh\administrators_authorized_keys"
  Set-Content -Path $adm -Value $key -Encoding ascii
  icacls $adm /inheritance:r /grant 'Administrators:F' /grant 'SYSTEM:F' | Out-Null
  $udir = Join-Path $env:USERPROFILE '.ssh'
  New-Item -ItemType Directory -Force -Path $udir | Out-Null
  Set-Content -Path (Join-Path $udir 'authorized_keys') -Value $key -Encoding ascii
  Say 'OK'

  Say 'STEP 3 of 4: no password logins'
  $cfg = "$env:ProgramData\ssh\sshd_config"
  $c = Get-Content $cfg | Where-Object { $_ -notmatch '^\s*#?\s*(PasswordAuthentication|PubkeyAuthentication)\b' }
  $c = @('PubkeyAuthentication yes','PasswordAuthentication no') + $c
  Set-Content -Path $cfg -Value $c -Encoding ascii
  Restart-Service sshd
  Say 'OK'

  Say 'STEP 4 of 4: allow SSH from Rico''s tailnet only'
  Get-NetFirewallRule -ErrorAction SilentlyContinue | Where-Object { $_.Name -like 'OpenSSH*' -or $_.DisplayName -like 'OpenSSH*' } | Remove-NetFirewallRule
  New-NetFirewallRule -Name 'Leo-SSH-Tailnet' -DisplayName 'Leo SSH (tailnet only)' -Direction Inbound -Protocol TCP -LocalPort 22 -RemoteAddress 100.64.0.0/10 -Action Allow | Out-Null
  Say 'OK'

  $ts = & "$env:ProgramFiles\Tailscale\tailscale.exe" ip -4 2>$null
  Write-Host ''
  Write-Host '  ==========================================' -ForegroundColor Yellow
  Write-Host '   DONE. Send Bilbo these:' -ForegroundColor Yellow
  Write-Host ''
  Write-Host "   Windows user:  $env:USERNAME"
  Write-Host "   PC name:       $env:COMPUTERNAME"
  Write-Host "   Tailscale IP:  $ts"
  Write-Host '  ==========================================' -ForegroundColor Yellow
} catch {
  Write-Host ''
  Write-Host "  It stopped: $($_.Exception.Message)" -ForegroundColor Red
  Write-Host '  Send Bilbo a photo of this window.' -ForegroundColor Red
}
Write-Host ''
Read-Host '  Press Enter to close'
