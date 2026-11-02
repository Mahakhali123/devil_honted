@echo off
REM =====================================================================
REM  The Haveli of Kamla  -  jump straight into the playable palace slice.
REM =====================================================================
set GODOT="%LOCALAPPDATA%\Microsoft\WinGet\Packages\GodotEngine.GodotEngine_Microsoft.Winget.Source_8wekyb3d8bbwe\Godot_v4.7.2-stable_windows_arm64.exe"

if not exist %GODOT% (
  echo Could not find Godot at:
  echo   %GODOT%
  echo.
  echo Open the project manually from the Godot Project Manager instead.
  pause
  exit /b 1
)

start "" %GODOT% --path "%~dp0" res://tests/step1_duplex_palace.tscn -- --live
exit /b 0
