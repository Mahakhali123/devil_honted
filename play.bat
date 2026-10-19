@echo off
REM =====================================================================
REM  Haunted Kingdom: Ghost Hunter  -  play the game
REM  Double-click this file to launch the Godot 4 project.
REM =====================================================================
set GODOT="%LOCALAPPDATA%\Microsoft\WinGet\Packages\GodotEngine.GodotEngine_Microsoft.Winget.Source_8wekyb3d8bbwe\Godot_v4.7.2-stable_win64.exe"

if not exist %GODOT% (
  echo Could not find Godot at:
  echo   %GODOT%
  echo.
  echo Open this project manually from the Godot Project Manager instead.
  pause
  exit /b 1
)

start "" %GODOT% --path "%~dp0"
exit /b 0
