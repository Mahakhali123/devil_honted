@echo off
REM =====================================================================
REM  Haunted Kingdom: Ghost Hunter  -  build the BROWSER version
REM  Double-click this to rebuild build\web\ . That folder is the whole
REM  website: upload it to Vercel and the game runs in a browser tab.
REM =====================================================================
setlocal
set GODOT="%LOCALAPPDATA%\Microsoft\WinGet\Packages\GodotEngine.GodotEngine_Microsoft.Winget.Source_8wekyb3d8bbwe\Godot_v4.7.2-stable_win64_console.exe"
set OUT=%~dp0build\web

if not exist %GODOT% (
  echo Could not find Godot at:
  echo   %GODOT%
  echo.
  echo Open this project in the Godot editor and use Project -^> Export instead.
  pause
  exit /b 1
)

echo.
echo   [1/3] Importing assets...
%GODOT% --headless --path "%~dp0" --import
if errorlevel 1 goto failed

echo.
echo   [2/3] Exporting Web build...
if not exist "%OUT%" mkdir "%OUT%"
%GODOT% --headless --path "%~dp0" --export-release "Web" "%OUT%\index.html"
if errorlevel 1 goto failed

echo.
echo   [3/3] Copying Vercel config...
copy /Y "%~dp0deploy\vercel.json" "%OUT%\vercel.json" >nul

echo.
echo   Done. The website is in:
echo     %OUT%
echo.
echo   Test it locally:   python -m http.server 8000  (run it inside that folder)
echo   Publish it:        npx vercel --prod            (run it inside that folder)
echo.
pause
exit /b 0

:failed
echo.
echo   BUILD FAILED - read the messages above.
echo   The most common cause is missing export templates:
echo     Editor -^> Manage Export Templates -^> Download and Install
pause
exit /b 1
