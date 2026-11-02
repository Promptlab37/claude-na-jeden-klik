@echo off
chcp 65001 >nul
title Instalace Claude
setlocal

set "ADRESA=https://raw.githubusercontent.com/Promptlab37/claude-na-jeden-klik/main/install.ps1"
set "SKRIPT=%~dp0install.ps1"
set "STAZENO="

if exist "%SKRIPT%" goto spustit

echo Pripravuji instalaci...
set "SKRIPT=%TEMP%\claude-na-jeden-klik-%RANDOM%.ps1"
set "STAZENO=1"
powershell -NoProfile -ExecutionPolicy Bypass -Command "[Net.ServicePointManager]::SecurityProtocol='Tls12'; Invoke-WebRequest -UseBasicParsing -Uri $env:ADRESA -OutFile $env:SKRIPT"
if errorlevel 1 (
    echo.
    echo Instalaci se nepodarilo stahnout. Zkontroluj pripojeni k internetu a zkus to znovu.
    goto chyba
)

:spustit
powershell -NoProfile -ExecutionPolicy Bypass -File "%SKRIPT%"
if errorlevel 1 goto chyba
if defined STAZENO del "%SKRIPT%" >nul 2>&1
echo.
echo Toto okno se za chvili samo zavre.
timeout /t 15 >nul
exit /b 0

:chyba
if defined STAZENO del "%SKRIPT%" >nul 2>&1
echo.
pause
exit /b 1
