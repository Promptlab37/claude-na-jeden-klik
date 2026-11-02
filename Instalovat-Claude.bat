@echo off
title Instalace Claude
setlocal

rem Nespolehame na PATH: na nekterych pocitacich v ni systemove slozky chybi.
if not defined SystemRoot set "SystemRoot=C:\Windows"
set "PATH=%SystemRoot%\System32;%SystemRoot%;%SystemRoot%\System32\Wbem;%SystemRoot%\System32\WindowsPowerShell\v1.0;%PATH%"
if not defined TEMP set "TEMP=%USERPROFILE%"

rem Pri spusteni z 32bitove aplikace by System32 vedla na 32bitovy PowerShell.
set "PS=%SystemRoot%\System32\WindowsPowerShell\v1.0\powershell.exe"
if exist "%SystemRoot%\Sysnative\WindowsPowerShell\v1.0\powershell.exe" set "PS=%SystemRoot%\Sysnative\WindowsPowerShell\v1.0\powershell.exe"

"%SystemRoot%\System32\chcp.com" 65001 >nul

if exist "%PS%" goto pripravit
echo V tomto pocitaci se nepodarilo najit Windows PowerShell.
goto chyba

:pripravit
set "ADRESA=https://raw.githubusercontent.com/Promptlab37/claude-na-jeden-klik/main/install.ps1"
set "SKRIPT=%TEMP%\claude-na-jeden-klik-%RANDOM%.ps1"

echo Pripravuji instalaci...
"%PS%" -NoProfile -ExecutionPolicy Bypass -Command "[Net.ServicePointManager]::SecurityProtocol='Tls12'; Invoke-WebRequest -UseBasicParsing -Uri $env:ADRESA -OutFile $env:SKRIPT"
if errorlevel 1 (
    echo.
    echo Instalaci se nepodarilo stahnout. Zkontroluj pripojeni k internetu a zkus to znovu.
    goto chyba
)

"%PS%" -NoProfile -ExecutionPolicy Bypass -File "%SKRIPT%"
if errorlevel 1 goto chyba
del "%SKRIPT%" >nul 2>&1
echo.
echo Toto okno se za chvili samo zavre.
"%SystemRoot%\System32\timeout.exe" /t 15 >nul 2>&1
exit /b 0

:chyba
del "%SKRIPT%" >nul 2>&1
echo.
pause
exit /b 1
