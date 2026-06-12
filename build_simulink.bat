@echo off
REM ============================================================
REM  build_simulink.bat - Generate RiceCookerPlant.slx
REM
REM  Output: Simulink\RiceCookerPlant.slx
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

echo Building RiceCookerPlant.slx ...
pushd "%SIMULINK_DIR%"
"%MATLAB_EXE%" -batch "build_model"
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

echo Done: Simulink\RiceCookerPlant.slx
endlocal
