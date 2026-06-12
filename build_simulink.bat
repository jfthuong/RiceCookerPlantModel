@echo off
REM ============================================================
REM  build_simulink.bat - Generate RiceCookerPlant.slx
REM                       and RiceCookerWithPanels.slx
REM
REM  Output: Simulink\RiceCookerPlant.slx
REM          Simulink\RiceCookerWithPanels.slx
REM
REM  Usage: run from the repository root.
REM  Prerequisite: MATLAB R2025a at E:\MATLAB\R2025a\bin\matlab.exe
REM ============================================================

setlocal

set MATLAB_EXE=E:\MATLAB\R2025a\bin\matlab.exe
set SIMULINK_DIR=%~dp0Simulink

if not exist "%MATLAB_EXE%" (
    echo ERROR: MATLAB not found at "%MATLAB_EXE%".
    exit /b 1
)

echo Building RiceCookerPlant.slx and RiceCookerWithPanels.slx ...
pushd "%SIMULINK_DIR%"
"%MATLAB_EXE%" -batch "build_model; build_model_with_panels"
set EXIT=%ERRORLEVEL%
popd

if not "%EXIT%"=="0" (
    echo ERROR: MATLAB exited with code %EXIT%.
    exit /b %EXIT%
)

if not exist "%SIMULINK_DIR%\RiceCookerPlant.slx" (
    echo ERROR: RiceCookerPlant.slx not produced.
    exit /b 1
)

if not exist "%SIMULINK_DIR%\RiceCookerWithPanels.slx" (
    echo ERROR: RiceCookerWithPanels.slx not produced.
    exit /b 1
)

echo Done: Simulink\RiceCookerPlant.slx and Simulink\RiceCookerWithPanels.slx
endlocal
