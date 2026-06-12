@echo off
REM ============================================================
REM  run_cosim.bat - Build model (if needed) then run demo_cosim
REM
REM  Output: Interactive MATLAB plot of 2-hour cooking simulation
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

echo Running Controller + Plant co-simulation demo ...
pushd "%SIMULINK_DIR%"
"%MATLAB_EXE%" -r "demo_cosim; input('Press Enter to exit...');exit"
set EXIT=%ERRORLEVEL%
popd

if not "%EXIT%"=="0" (
    echo ERROR: MATLAB exited with code %EXIT%.
    exit /b %EXIT%
)

echo Done.
endlocal
