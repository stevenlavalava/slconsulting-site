$ErrorActionPreference = 'Stop'
$key = 'ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIJxY9X2T0pUgVW1y/TqRV3pG7wKgG9hET1H2gkMnhAii gyeskep@WIN-7HMI2FL21M6'
try {
  $adm = "$env:ProgramData\ssh\administrators_authorized_keys"
  if (-not (Test-Path $adm)) { throw 'The bridge setup has not finished yet (no key file). Run leobridge.cmd first.' }
  $lines = @(Get-Content $adm | Where-Object { $_.Trim() -ne '' })
  if ($lines -notcontains $key) { $lines += $key }
  Set-Content -Path $adm -Value $lines -Encoding ascii
  icacls $adm /inheritance:r /grant 'Administrators:F' /grant 'SYSTEM:F' | Out-Null
  $n = (Get-Content $adm | Where-Object { $_ -match 'rico-laptop|gyeskep@' }).Count
  $svc = (Get-Service sshd).Status
  $ts = & "$env:ProgramFiles\Tailscale\tailscale.exe" ip -4 2>$null
  Write-Host ''
  Write-Host '  ==========================================' -ForegroundColor Yellow
  Write-Host "   DONE. Keys trusted: $n (Leo + Gyeskep)" -ForegroundColor Yellow
  Write-Host ''
  Write-Host "   Windows user:  $env:USERNAME"
  Write-Host "   PC name:       $env:COMPUTERNAME"
  Write-Host "   Tailscale IP:  $ts"
  Write-Host "   SSH server:    $svc"
  Write-Host '  ==========================================' -ForegroundColor Yellow
  Write-Host '   Send Bilbo a photo of this.'
} catch {
  Write-Host "  It stopped: $($_.Exception.Message)" -ForegroundColor Red
  Write-Host '  Send Bilbo a photo of this window.' -ForegroundColor Red
}
Write-Host ''
Read-Host '  Press Enter to close'
