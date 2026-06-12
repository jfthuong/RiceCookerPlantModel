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

echo Building RiceCookerPlant.slx and RiceCookerWithPanel.slx ...
pushd "%SIMULINK_DIR%"
"%MATLAB_EXE%" -batch "build_model; build_model_with_panel"
set EXIT=%ERRORLEVEL%
popd

if not "%EXIT%"=="0" (
    echo ERROR: MATLAB exited with code %EXIT%.
    echo.
    pause
    exit /b %EXIT%
)

if not exist "%SIMULINK_DIR%\RiceCookerPlant.slx" (
    echo ERROR: RiceCookerPlant.slx not produced.
    goto Error
)

if not exist "%SIMULINK_DIR%\RiceCookerWithPanel.slx" (
    echo ERROR: RiceCookerWithPanel.slx not produced.
    goto Error
)

goto Success

:Error
echo.
pause
timeout /t 10

:Success
echo.
echo Simulink models build completed successfully.
echo Outputs: Simulink\RiceCookerPlant.slx and Simulink\RiceCookerWithPanel.slx
echo.
endlocal
timeout /t 20
exit /b 0