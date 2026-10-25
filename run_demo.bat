@echo off
setlocal
echo ===================================================
echo     Starting Running Biomechanics Analyzer Demo
echo ===================================================
echo Input Video: demo\run.mp4
echo.

set "PYTHON_CMD=C:\Users\Tanishka\.cache\codex-runtimes\codex-primary-runtime\dependencies\python\python.exe"
if exist "%PYTHON_CMD%" (
    "%PYTHON_CMD%" main.py demo/run.mp4 --play --show
) else (
    python main.py demo/run.mp4 --play --show
)

if %ERRORLEVEL% NEQ 0 (
    echo.
    echo Demo finished or encountered an issue.
)
pause
