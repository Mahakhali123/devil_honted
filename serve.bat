@echo off
REM =====================================================================
REM  Haunted Kingdom: Ghost Hunter  -  local preview server
REM  Double-click this file, then open:  http://localhost:1200/
REM  Close this window to stop the server.
REM =====================================================================
cd /d "%~dp0"
echo.
echo   Haunted Kingdom - Character Studio
echo   Serving: %CD%
echo   Open this in your browser:  http://localhost:1200/
echo.
echo   Press CTRL+C or close this window to stop.
echo.
python -m http.server 1200 --bind 127.0.0.1
pause
