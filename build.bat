@echo off
REM =============================================================================
REM V8 MSVC Build Script
REM Must be run from a Visual Studio Developer Command Prompt, or this script
REM will set up the environment automatically.
REM =============================================================================

setlocal EnableDelayedExpansion

REM Check if cl.exe is available
where cl.exe >nul 2>&1
if %ERRORLEVEL% NEQ 0 (
    echo Setting up MSVC environment...
    for /f "usebackq tokens=*" %%i in (`"%ProgramFiles(x86)%\Microsoft Visual Studio\Installer\vswhere.exe" -latest -property installationPath`) do set VS_PATH=%%i
    if not defined VS_PATH (
        echo ERROR: Visual Studio not found. Please install Visual Studio with C++ workload.
        exit /b 1
    )
    call "!VS_PATH!\VC\Auxiliary\Build\vcvars64.bat" >nul 2>&1
)

REM Parse arguments
set BUILD_TYPE=Release
set BUILD_DIR=build

:parse_args
if "%~1"=="" goto :done_args
if /i "%~1"=="debug" set BUILD_TYPE=Debug
if /i "%~1"=="release" set BUILD_TYPE=Release
if /i "%~1"=="--build-dir" (
    set BUILD_DIR=%~2
    shift
)
shift
goto :parse_args
:done_args

echo.
echo === V8 MSVC Build ===
echo Build type: %BUILD_TYPE%
echo Build dir:  %BUILD_DIR%
echo.

REM Fetch dependencies if needed
if not exist "v8-src\src" (
    echo Fetching V8 source and dependencies...
    python fetch_deps.py
    if %ERRORLEVEL% NEQ 0 (
        echo ERROR: Failed to fetch dependencies.
        exit /b 1
    )
)

REM Configure
echo Configuring with CMake...
cmake -B %BUILD_DIR% -G Ninja -DCMAKE_BUILD_TYPE=%BUILD_TYPE% -DCMAKE_C_COMPILER=cl -DCMAKE_CXX_COMPILER=cl
if %ERRORLEVEL% NEQ 0 (
    echo ERROR: CMake configure failed.
    exit /b 1
)

REM Build
echo Building...
cmake --build %BUILD_DIR% --parallel
if %ERRORLEVEL% NEQ 0 (
    echo ERROR: Build failed.
    exit /b 1
)

echo.
echo === Build complete ===
echo Output in: %BUILD_DIR%
