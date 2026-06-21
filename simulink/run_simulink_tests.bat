@echo off
REM ============================================================
REM  run_tests_cosim.bat - Run Controller + Plant integration tests
REM
REM  Exit code: 0 = all tests pass, non-zero = failure
REM
REM  Usage: run from the simulink directory.
REM  Prerequisite: MATLAB R2025a at E:\MATLAB\R2025a\bin\matlab.exe
REM ============================================================

setlocal

set MATLAB_EXE=E:\MATLAB\R2025a\bin\matlab.exe
set SIMULINK_DIR=%~dp0

if not exist "%MATLAB_EXE%" (
    echo ERROR: MATLAB not found at "%MATLAB_EXE%".
    exit /b 1
)

echo Running co-simulation integration tests ...
pushd "%SIMULINK_DIR%"
"%MATLAB_EXE%" -batch "addpath('tests'); addpath('model'); r=runtests('test_cosim'); disp([num2str(sum([r.Passed])) ' of ' num2str(numel(r)) ' tests passed']); if any([r.Failed]), exit(1); end"
set EXIT=%ERRORLEVEL%
popd

if not "%EXIT%"=="0" (
    echo TESTS FAILED - exit code %EXIT%
    exit /b %EXIT%
)

echo All tests passed.
endlocal
