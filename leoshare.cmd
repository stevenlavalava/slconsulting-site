@echo off
setlocal
rem Leo payroll share setup (Windows 8.1+). Shares one folder read-only to local user leoread.
net session >nul 2>&1 || (powershell -NoProfile -Command "Start-Process -FilePath '%~f0' -Verb RunAs" & exit /b)
title Leo - payroll share setup
color 1F
echo.
echo  STEP 1 of 4: pick the PAYROLL folder in the window that opens.
for /f "usebackq delims=" %%F in (`powershell -NoProfile -STA -Command "Add-Type -AssemblyName System.Windows.Forms; $d=New-Object System.Windows.Forms.FolderBrowserDialog; $d.Description='Pick the PAYROLL folder to share with Leo (read-only)'; if($d.ShowDialog() -eq 'OK'){$d.SelectedPath}"`) do set "FOLDER=%%F"
if not defined FOLDER (echo  No folder picked. Nothing was changed. & pause & exit /b 1)
echo  Folder: %FOLDER%
echo.
echo  STEP 2 of 4: reader account "leoread"
net user leoread >nul 2>&1 && (echo  leoread already exists, keeping it.) || (echo  Type the leoread password twice. Nothing shows as you type. & net user leoread * /add)
net user leoread >nul 2>&1 || (echo  The account was not created. & pause & exit /b 1)
wmic useraccount where name='leoread' set PasswordExpires=false >nul 2>&1
reg add "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon\SpecialAccounts\UserList" /v leoread /t REG_DWORD /d 0 /f >nul
echo  OK (hidden from the sign-in screen, password never expires)
echo.
echo  STEP 3 of 4: share "payroll", read-only, leoread only
net share payroll /delete /y >nul 2>&1
net share payroll="%FOLDER%" /grant:leoread,READ >nul || (echo  Sharing failed. & pause & exit /b 1)
icacls "%FOLDER%" /grant leoread:(OI)(CI)RX >nul
echo  OK
echo.
echo  STEP 4 of 4: turn on file sharing for this network
powershell -NoProfile -Command "Get-NetConnectionProfile | Where-Object {$_.NetworkCategory -eq 'Public'} | Set-NetConnectionProfile -NetworkCategory Private" >nul 2>&1
netsh advfirewall firewall set rule group="File and Printer Sharing" new enable=Yes >nul
echo  OK
echo.
echo  ==========================================
echo   DONE. Send Bilbo these:
echo.
echo   PC name:  %COMPUTERNAME%
for /f "tokens=2 delims=:" %%I in ('ipconfig ^| findstr /c:"IPv4"') do echo   Address: %%I
echo  ==========================================
echo.
pause
