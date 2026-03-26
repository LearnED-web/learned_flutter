@echo off
setlocal EnableExtensions

if /I "%~1"=="--help" goto :help
if /I "%~1"=="-h" goto :help

set "JDK_PATH_ARG=%~1"

set "KEYSTORE_PATH=android\upload-keystore.jks"
set "KEY_ALIAS=upload"
set "KEY_VALIDITY_DAYS=10000"
set "KEY_PROPERTIES_PATH=android\key.properties"
set "KEY_PROPERTIES_EXAMPLE=android\key.properties.example"

echo Setup Google Play upload signing for this Flutter app
echo.

set "KEYTOOL_CMD="

REM 1) Optional JDK path argument
if defined JDK_PATH_ARG (
  if exist "%JDK_PATH_ARG%\bin\keytool.exe" set "KEYTOOL_CMD=%JDK_PATH_ARG%\bin\keytool.exe"
)

REM 2) JAVA_HOME
if not defined KEYTOOL_CMD (
  if defined JAVA_HOME (
    if exist "%JAVA_HOME%\bin\keytool.exe" set "KEYTOOL_CMD=%JAVA_HOME%\bin\keytool.exe"
  )
)

REM 3) android/local.properties (org.gradle.java.home)
if not defined KEYTOOL_CMD (
  if exist "android\local.properties" (
    for /f "usebackq tokens=1,* delims==" %%A in ("android\local.properties") do (
      if "%%A"=="org.gradle.java.home" set "GRADLE_JAVA_HOME=%%B"
    )
    if defined GRADLE_JAVA_HOME (
      set "GRADLE_JAVA_HOME=%GRADLE_JAVA_HOME:\\=\%"
      if exist "%GRADLE_JAVA_HOME%\bin\keytool.exe" set "KEYTOOL_CMD=%GRADLE_JAVA_HOME%\bin\keytool.exe"
    )
  )
)

REM 4) Common JDK install locations
if not defined KEYTOOL_CMD call :find_in_root "C:\Program Files\Java"
if not defined KEYTOOL_CMD call :find_in_root "C:\Program Files\Eclipse Adoptium"
if not defined KEYTOOL_CMD call :find_in_root "C:\Program Files\Microsoft"

REM 5) PATH
if not defined KEYTOOL_CMD (
  for /f "usebackq delims=" %%I in (`where keytool 2^>nul`) do (
    set "KEYTOOL_CMD=%%I"
    goto :found_keytool
  )
)

:found_keytool

if not defined KEYTOOL_CMD (
  echo [ERROR] keytool could not be found.
  echo You can pass JDK path directly:
  echo   setup-play-signing.bat "C:\Path\To\JDK"
  echo.
  echo Or set JAVA_HOME to your JDK and run again.
  exit /b 1
)

echo [INFO] Using keytool:
echo   %KEYTOOL_CMD%
echo.

if not exist "android" (
  echo [ERROR] android folder not found. Run this from the project root.
  exit /b 1
)

echo This will create an upload keystore at:
echo   %KEYSTORE_PATH%
echo.
if exist "%KEYSTORE_PATH%" (
  set /p OVERWRITE_KEYSTORE=Keystore already exists. Overwrite it? [y/N]: 
  if /I not "%OVERWRITE_KEYSTORE%"=="y" (
    echo Aborted.
    exit /b 1
  )
)

echo.
echo Generating keystore. keytool will prompt you for passwords and owner details.
"%KEYTOOL_CMD%" -genkeypair -v -keystore "%KEYSTORE_PATH%" -alias "%KEY_ALIAS%" -keyalg RSA -keysize 2048 -validity %KEY_VALIDITY_DAYS%
if errorlevel 1 (
  echo [ERROR] Keystore generation failed.
  exit /b 1
)

echo.
echo Enter the same passwords you used in keytool so android/key.properties can be written.
echo NOTE: Input is visible in the terminal.
set /p STORE_PASSWORD=Keystore password: 
set /p KEY_PASSWORD=Key password (usually same as keystore password): 

if "%STORE_PASSWORD%"=="" (
  echo [ERROR] storePassword cannot be empty.
  exit /b 1
)
if "%KEY_PASSWORD%"=="" (
  echo [ERROR] keyPassword cannot be empty.
  exit /b 1
)

echo(%STORE_PASSWORD%| findstr /I /C:"storePassword=" /C:"keyPassword=" /C:"keyAlias=" /C:"storeFile=" >nul
if not errorlevel 1 (
  echo [ERROR] Invalid keystore password input. Paste only the raw password, not key=value text.
  exit /b 1
)

echo(%KEY_PASSWORD%| findstr /I /C:"storePassword=" /C:"keyPassword=" /C:"keyAlias=" /C:"storeFile=" >nul
if not errorlevel 1 (
  echo [ERROR] Invalid key password input. Paste only the raw password, not key=value text.
  exit /b 1
)

if exist "%KEY_PROPERTIES_PATH%" (
  copy /Y "%KEY_PROPERTIES_PATH%" "%KEY_PROPERTIES_PATH%.bak" >nul
)

set "STORE_FILE_FOR_PROPERTIES=../upload-keystore.jks"

call :write_key_properties
if errorlevel 1 (
  echo [ERROR] Failed to write %KEY_PROPERTIES_PATH%.
  exit /b 1
)

powershell -NoProfile -Command "$lines = Get-Content $env:KEY_PROPERTIES_PATH -ErrorAction Stop; if($lines.Count -ne 4){ exit 1 }; if(-not ($lines[0] -like 'storePassword=*')){ exit 1 }; if(-not ($lines[1] -like 'keyPassword=*')){ exit 1 }; if(-not ($lines[2] -like 'keyAlias=*')){ exit 1 }; if(-not ($lines[3] -like 'storeFile=*')){ exit 1 }"
if errorlevel 1 (
  echo [ERROR] key.properties validation failed. Expected 4 lines with storePassword/keyPassword/keyAlias/storeFile.
  exit /b 1
)

if not exist "%KEY_PROPERTIES_PATH%" (
  echo [ERROR] Failed to write %KEY_PROPERTIES_PATH%.
  exit /b 1
)

echo.
echo [OK] Play signing setup complete.
echo Keystore: %KEYSTORE_PATH%
echo Config:   %KEY_PROPERTIES_PATH%
echo.
echo Next step:
echo   build-play-aab.bat
echo.
exit /b 0

:write_key_properties
REM Always write exactly four physical lines in key.properties.
(
  echo storePassword=%STORE_PASSWORD%
  echo keyPassword=%KEY_PASSWORD%
  echo keyAlias=%KEY_ALIAS%
  echo storeFile=%STORE_FILE_FOR_PROPERTIES%
) > "%KEY_PROPERTIES_PATH%"
if errorlevel 1 exit /b 1
exit /b 0

:find_in_root
set "SEARCH_ROOT=%~1"
if not exist "%SEARCH_ROOT%" goto :eof
for /f "delims=" %%D in ('dir /b /ad "%SEARCH_ROOT%" 2^>nul') do (
  if exist "%SEARCH_ROOT%\%%D\bin\keytool.exe" (
    set "KEYTOOL_CMD=%SEARCH_ROOT%\%%D\bin\keytool.exe"
    goto :eof
  )
)
goto :eof

:help
echo Usage:
echo   setup-play-signing.bat
echo   setup-play-signing.bat "C:\Path\To\JDK"
echo.
echo What it does:
echo   1) Creates upload-keystore.jks using keytool
echo   2) Writes android\key.properties for release signing
echo   3) Keeps a backup at android\key.properties.bak if one existed
echo.
echo Keytool resolution order:
echo   1) Optional JDK path argument
echo   2) JAVA_HOME
echo   3) android\local.properties ^(org.gradle.java.home^)
echo   4) Common JDK install locations
echo   5) PATH
echo.
exit /b 0
