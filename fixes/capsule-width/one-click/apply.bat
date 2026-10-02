@echo off
rem Event point capsule width fix for Universal-Timer (apply). No git needed.
if exist "%~dp0tools\apply.ps1" goto run
echo The tool files are missing. Please extract the WHOLE folder from the zip first,
echo then double-click apply.bat inside the extracted folder.
pause
exit /b 1
:run
if "%~1"=="" goto noarg
powershell.exe -NoProfile -STA -ExecutionPolicy Bypass -File "%~dp0tools\apply.ps1" -ProjectDir "%~1"
goto done
:noarg
powershell.exe -NoProfile -STA -ExecutionPolicy Bypass -File "%~dp0tools\apply.ps1"
:done
echo.
pause
