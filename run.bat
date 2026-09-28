@echo off
:: EN: Set UTF-8 encoding immediately for all code branches
:: CA: Establiment immediat de la codificació UTF-8 per a totes les branques
chcp 65001 > nul

:: ==============================================================================
:: EN: Check for Administrator privileges
:: CA: Comprovació de permisos d'administrador
:: ==============================================================================
net session >nul 2>&1
if %errorLevel% == 0 (
    goto :admin
) else (
    goto :uac
)

:uac
:: ==============================================================================
:: EN: Request Administrator privileges without losing working directory
:: CA: Sol·licitud de permisos d'administrador sense perdre la carpeta de treball
:: ==============================================================================
echo Demanant permisos d'administrador...
powershell -c "Start-Process -FilePath '%comspec%' -ArgumentList '/c \"\"%~f0\"\"' -WorkingDirectory '%~dp0' -Verb RunAs"
exit /b 

:admin
:: ==============================================================================
:: EN: Force working directory back to script folder (prevents C:\Windows\System32 reset)
:: CA: Força el canvi a la carpeta de l'script (evita el canvi a C:\Windows\System32)
:: ==============================================================================
cd /d "%~dp0"

:loop
cls
:: EN: Extract drive letter and parent folder name to build a trimmed path format (e.g. C:/.../FolderName)
:: CA: Extreu la lletra de la unitat i el nom de la carpeta pare per crear un format de camí retallat
set "DRIVE=%~d0"
for %%I in ("%~dp0.") do set "FOLDER=%%~nxI"
:: %%~nxI (Name + Extension); %~dp0. "." evade backslash 

echo     S'està executant com a Administrador a %DRIVE%/.../%FOLDER%

:: ==============================================================================
:: EN: Execute PowerShell script with Bypass execution policy
:: CA: Execució de l'script de PowerShell amb la política d'execució bypass
:: ==============================================================================
powershell -nop -ex Bypass -Command "[Console]::InputEncoding = [System.Text.Encoding]::UTF8; Get-Content -Raw -Encoding UTF8 '%~dp0pstnst.ps1' | Invoke-Expression"

echo.
echo     Presiona qualsevol tecla per reiniciar l'script...
pause > nul
goto loop
