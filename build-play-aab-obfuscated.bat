@echo off
setlocal

echo Building LearnED release AAB for Google Play Console (obfuscated)...
echo.

set "FLUTTER_CMD=fvm flutter"
where fvm >nul 2>nul
if errorlevel 1 (
  echo [INFO] FVM not found. Falling back to global Flutter.
  set "FLUTTER_CMD=flutter"
)

if not exist "android\key.properties" (
  echo [ERROR] Missing android\key.properties
  echo Copy android\key.properties.example to android\key.properties and set your upload key values.
  exit /b 1
)

set "SPLIT_DEBUG_DIR=build\app\outputs\symbols\release"
if not exist "%SPLIT_DEBUG_DIR%" mkdir "%SPLIT_DEBUG_DIR%"

echo [1/3] Getting dependencies...
call %FLUTTER_CMD% pub get
if errorlevel 1 (
  echo [ERROR] Failed to fetch dependencies.
  exit /b 1
)

echo [2/3] Building obfuscated app bundle...
call %FLUTTER_CMD% build appbundle --release --obfuscate --split-debug-info=%SPLIT_DEBUG_DIR% ^
  --dart-define=SUPABASE_URL=https://ugphaeiqbfejnzpiqdty.supabase.co ^
  --dart-define=SUPABASE_ANON_KEY=eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InVncGhhZWlxYmZlam56cGlxZHR5Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTQyMTMwNDcsImV4cCI6MjA2OTc4OTA0N30.-OcW0or7v6krUQJUG0Jb8VoPbpbGjbdbjsMKn6KplM8
if errorlevel 1 (
  echo [ERROR] Obfuscated AAB build failed.
  exit /b 1
)

echo [3/3] Build complete.
echo.
echo AAB location:
echo build\app\outputs\bundle\release\app-release.aab
echo.
echo Split debug symbols:
echo %SPLIT_DEBUG_DIR%
echo.
echo IMPORTANT: Keep symbol files safe. They are required for readable crash stack traces.
echo.
pause
endlocal
