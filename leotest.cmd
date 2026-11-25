@echo off
setlocal
title Leo - test the payroll share
color 1F
echo.
echo  Testing \\GRAPHICSPC\payroll as leoread ...
net use \\GRAPHICSPC\payroll /delete /y >nul 2>&1
net use \\GRAPHICSPC\IPC$ /delete /y >nul 2>&1
echo.
echo  Type the leoread password and press Enter. Nothing shows as you type.
net use \\GRAPHICSPC\payroll /user:GRAPHICSPC\leoread /persistent:no
set "RC=%errorlevel%"
echo.
if "%RC%"=="0" (
  echo  ==========================================
  echo   SUCCESS. The share opens now.
  echo   Check: you can open files, but not delete or add any.
  echo  ==========================================
  start "" explorer \\GRAPHICSPC\payroll
) else (
  echo  ==========================================
  echo   It did not work. Send Bilbo a photo of this window.
  echo  ==========================================
)
echo.
pause
