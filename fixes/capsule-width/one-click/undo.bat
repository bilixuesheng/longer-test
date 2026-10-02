@echo off
rem Event point capsule width fix for Universal-Timer (undo). No git needed.
if exist "%~dp0tools\undo.ps1" goto run
echo The tool files are missing. Please extract the WHOLE folder from the zip first,
echo then double-click undo.bat inside the extracted folder.
pause
exit /b 1
:run
powershell.exe -NoProfile -STA -ExecutionPolicy Bypass -File "%~dp0tools\undo.ps1"
echo.
pause
