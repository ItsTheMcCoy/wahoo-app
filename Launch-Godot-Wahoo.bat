@echo off
setlocal

set "REPO_ROOT=%~dp0"
set "GODOT_DIR=%REPO_ROOT%godot"
set "WEB_DIR=%GODOT_DIR%\build\web"
set "GODOT_EXE=Godot_v4.6.3-stable_win64_console.exe"
set "GODOT_FALLBACK=C:\Users\macwe\OneDrive\Documents\Gdot4\Godot_v4.6.3-stable_win64_console.exe"
set "MODE=%~1"
set "PORT=%~2"

if "%MODE%"=="" set "MODE=game"
if "%PORT%"=="" set "PORT=8000"

where "%GODOT_EXE%" >nul 2>nul
if errorlevel 1 (
    if exist "%GODOT_FALLBACK%" (
        set "GODOT_EXE=%GODOT_FALLBACK%"
    ) else (
        echo Godot 4.6.3 was not found.
        echo Add the Godot 4.6.3 folder to PATH, or edit GODOT_FALLBACK in this file.
        exit /b 1
    )
)

if not exist "%GODOT_DIR%\project.godot" (
    echo Godot project file not found:
    echo %GODOT_DIR%\project.godot
    exit /b 1
)

if /I "%MODE%"=="editor" goto editor
if /I "%MODE%"=="smoke" goto smoke_only
if /I "%MODE%"=="export" goto export_only
if /I "%MODE%"=="web" goto web
if /I "%MODE%"=="game" goto game

echo Unknown mode: %MODE%
echo.
echo Usage:
echo   Launch-Godot-Wahoo.bat
echo   Launch-Godot-Wahoo.bat game
echo   Launch-Godot-Wahoo.bat editor
echo   Launch-Godot-Wahoo.bat smoke
echo   Launch-Godot-Wahoo.bat export
echo   Launch-Godot-Wahoo.bat web [port]
exit /b 1

:run_smoke
echo.
echo ==^> Running Godot smoke tests from %GODOT_DIR%
pushd "%GODOT_DIR%"
"%GODOT_EXE%" --headless --script res://scripts/run_smoke.gd
set "RESULT=%ERRORLEVEL%"
popd
if not "%RESULT%"=="0" exit /b %RESULT%
exit /b 0

:run_export
echo.
echo ==^> Exporting Web build from %GODOT_DIR%
pushd "%GODOT_DIR%"
"%GODOT_EXE%" --headless --path . --export-release Web build/web/index.html
set "RESULT=%ERRORLEVEL%"
popd
if not "%RESULT%"=="0" exit /b %RESULT%
echo Export written to %WEB_DIR%\index.html
exit /b 0

:smoke_only
call :run_smoke
exit /b %ERRORLEVEL%

:export_only
call :run_smoke
if errorlevel 1 exit /b %ERRORLEVEL%
call :run_export
exit /b %ERRORLEVEL%

:web
call :run_smoke
if errorlevel 1 exit /b %ERRORLEVEL%
call :run_export
if errorlevel 1 exit /b %ERRORLEVEL%
echo.
echo ==^> Serving Web build from %WEB_DIR%
echo Open http://localhost:%PORT% in your browser.
pushd "%WEB_DIR%"
python -m http.server %PORT%
set "RESULT=%ERRORLEVEL%"
popd
exit /b %RESULT%

:editor
echo.
echo ==^> Opening Godot editor from %GODOT_DIR%
pushd "%GODOT_DIR%"
"%GODOT_EXE%" --path . --editor
set "RESULT=%ERRORLEVEL%"
popd
exit /b %RESULT%

:game
call :run_smoke
if errorlevel 1 exit /b %ERRORLEVEL%
echo.
echo ==^> Launching Godot game from %GODOT_DIR%
pushd "%GODOT_DIR%"
"%GODOT_EXE%" --path .
set "RESULT=%ERRORLEVEL%"
popd
exit /b %RESULT%
