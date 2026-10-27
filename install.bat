@echo off
rem Installs Super TV on a TV on the same Wi-Fi as this computer: runs install.ps1 from this folder.
if not exist "%~dp0install.ps1" (
  echo Unzip it first: right-click the ZIP file, choose Extract All, then run install.bat from the new folder.
  pause
  exit /b 1
)
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0install.ps1"
pause
