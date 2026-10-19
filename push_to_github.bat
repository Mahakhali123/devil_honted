@echo off
REM =====================================================================
REM  Haunted Kingdom  -  push this project to GitHub
REM  Double-click this file. It runs in a real console, which is what the
REM  GitHub sign-in window needs (an agent's shell cannot show it).
REM =====================================================================
setlocal
set "PG=%LOCALAPPDATA%\PortableGit"
set "PATH=%PG%\cmd;%PG%\mingw64\bin;%PATH%"
cd /d "%~dp0"

echo.
echo   Repository : https://github.com/Mahakhali123/Hunting-Game.git
echo   Branch     : main
echo.
echo   A "Sign in to GitHub" window should appear.
echo   Sign in once and the push finishes on its own.
echo.
echo   IF IT ASKS FOR A USERNAME / PASSWORD IN THIS WINDOW INSTEAD:
echo     username : Mahakhali123
echo     password : a Personal Access Token - NOT your GitHub password
echo                create one here: https://github.com/settings/tokens
echo                (classic token, tick the "repo" checkbox)
echo.
pause

git push -u origin main

echo.
if errorlevel 1 (
  echo   PUSH FAILED - read the message above.
) else (
  echo   PUSHED OK.
  echo.
  echo   Next: import the repo at https://vercel.com/new
  echo   and set Root Directory to:  build\web
)
echo.
pause
