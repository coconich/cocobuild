::=====================================================================================================================
::
::  @author Cory Simonich 
::  @brief  This is a c/c++ build system that is ever evolving
::          I use it for tiny-medium sized projects
::          todo list:
::              optional incremental compilation
::              optional pre compiled headers
::              optional unity build 
::
::          long term todos:
::              port to python/other interpreted language with cross platform support
::                  python
::                  ???
::              port to a compiled language
::                  something that will provide native support for a gui win32, linux, and macos
::                  ironically, zig or jai are leading the race rn
::                      i want this to be simple shape rendering  
::                          I solemnly swear to write exactly 0 lines of renderer code
::                          DrawTexture good
::                          BindBuffer  bad
::                      i want it to be easy to write the features and extend them  
::                  i don't plan on doing the gui until this is a fully featured 
::              create a build recipe/config file that allows you to save things
::                  there is only one of these per build per platform per whatever (if you want)
::                  think, win32_debug_d3d11, linux_release_vulkan, linux_debug_opengl
::                  the recipe would be self contained
::                      meaning only one gets ran
::                      no other files are involved (other than this script, and any gui you might be using
::              gui
::                  blueprint style interface for writing build recipes
::                  you can see all your projects in a big 2d world
::                  click into a project and camera focuses there
::                  use root nodes and trees like a behavior tree/blueprint editor to assign build recipes
::                      include dirs
::                      directories to copy
::                      libs/dlls to link with
::                      external deps to have precompiled possibly
::                      platform specific recipes within a project (see recipes above)
::=====================================================================================================================

:: this allows the script to be ran from within an existing environment and open itself in a new console
:: i use this as a workaround for focus editor project build commands
:: i dont like it when an IDE opens my script it their terminal, id rather a freestanding one
@echo off
if "%~1"=="-open_self_in_new_console" goto :main
start "" cmd /k "%~f0" -open_self_in_new_console
exit

::=====================================================================================================================
:: User Config and script initialization
:: These variables are set to defaults and some of them are editable throught the script interface 
::=====================================================================================================================

:: i've been building this script for a while and changing it for better or worse often 
:: it is actually like the version num + 100th iteration of this file
:main
set COCOBUILD_VERSION_STRING=v1.0.0
echo [cocobuild %COCOBUILD_VERSION_STRING%]
echo .
echo .
echo .

:: Environment setup :: 
setlocal enabledelayedexpansion

:: find vcvarsall in a known folder
:: if you want a specific one, just set this explicitly 
set VCVARSALL_BAT=
for %%d in (
    "C:\Program Files\Microsoft Visual Studio\2022\Community\VC\Auxiliary\Build\vcvarsall.bat"
    "C:\Program Files\Microsoft Visual Studio\2022\Professional\VC\Auxiliary\Build\vcvarsall.bat"
    "C:\Program Files\Microsoft Visual Studio\2022\Enterprise\VC\Auxiliary\Build\vcvarsall.bat"
    "C:\Program Files (x86)\Microsoft Visual Studio\2022\BuildTools\VC\Auxiliary\Build\vcvarsall.bat"
) do if not defined VCVARSALL_BAT if exist "%%~d" set "VCVARSALL_BAT=%%~d"
    
:: we didnt find it 
:: use vswhere to find it
:: if you have visual studio installed, vswhere should be on your path
:: we are asking for the installationPath for the latest installed version
:: vswhere fails silently, so VCVARSALL_BAT still wont be defined if it fails
if not defined VCVARSALL_BAT (
    set "VSWHERE_CMD=vswhere -latest -products * -requires Microsoft.VisualStudio.Component.VC.Tools.x86.x64 -property installationPath"
    for /f "usebackq tokens=*" %%i in (`!VSWHERE_CMD! 2^>nul`) do (
        if exist "%%i\VC\Auxiliary\Build\vcvarsall.bat" set "VCVARSALL_BAT=%%i\VC\Auxiliary\Build\vcvarsall.bat"
    )
)

:: we couldnt setup the windows x64 environment
:: shutting down
if not defined VCVARSALL_BAT (
    echo Unable to initialize x64 environment
    echo Couldn't find vcvarsall.bat
    echo .
    echo .
    echo .
    echo Looked for it in these directories:
    echo     "C:\Program Files\Microsoft Visual Studio\2022\Community\VC\Auxiliary\Build\vcvarsall.bat"
    echo     "C:\Program Files\Microsoft Visual Studio\2022\Professional\VC\Auxiliary\Build\vcvarsall.bat"
    echo     "C:\Program Files\Microsoft Visual Studio\2022\Enterprise\VC\Auxiliary\Build\vcvarsall.bat"
    echo     "C:\Program Files (x86)\Microsoft Visual Studio\2022\BuildTools\VC\Auxiliary\Build\vcvarsall.bat"
    echo .
    echo .
    echo .
    echo Also tried using vswhere to locate it automatically.
    echo .
    echo .
    echo .
    echo Do you have Visual Studio Installed?
    goto shutdown
)

set VCVARSALL_BAT="!VCVARSALL_BAT!"
call !VCVARSALL_BAT! x64 > nul

:: Project Setup ::
set EXE_NAME=rat
set CONFIG_DEFAULT=debug
set RUN_ARGS_DEFAULT=-r opengl -s 1.0
set SOURCE_DIR=src
set COPY_DIRS=shaders\compiled assets

set EXTERNAL_INCLUDE_DIRS=^
-I"%~dp0external\sdl\include" ^
-I"%~dp0external\sdl_ttf\include" ^
-I"%~dp0external\stb"

:: @todo:: make a separate set of libs for each config (i dont need that rn tbh)
set LIBS_DIR=libs
set DLLS_DIR=libs
set COMMON_LIBS=
set COMMON_DLLS=

:: collect libs and dlls from the /libs directory
:: @todo:: this will need custom support for other platforms
for /r "%LIBS_DIR%" %%f in (*.lib) do (
    set "COMMON_LIBS=!COMMON_LIBS!^"%%f^" "
)
for /r "%LIBS_DIR%" %%f in (*.dll) do (
    set "COMMON_DLLS=!COMMON_DLLS!^"%%f^" "
)

set DEBUG_LIBS=%COMMON_LIBS%
set RELEASE_LIBS=%COMMON_LIBS% 

:: Compiler setup :: 
set CPP_STANDARD=c++17
set COMPILER=clang
set LINKER=clang
set ALL_FLAGS=-D_CRT_SECURE_NO_WARNINGS
set DEBUG_FLAGS=-g -O0 -DDEBUG -D_DEBUG -Xclang --dependent-lib=libcmtd
set RELEASE_W_DEBUG_FLAGS=-g -O2 -DNDEBUG 
set RELEASE_FLAGS=-O2 -DNDEBUG 
set SHIPPING_FLAGS=-O2 -w -DNDEBUG 

:: Configuration
set CONFIG=%CONFIG_DEFAULT%
set OUTPUT_ROOT=build
set RUN_ARGS=%RUN_ARGS_DEFAULT%
set SOURCE_DIR=%~dp0%SOURCE_DIR%
set OUTPUT_ROOT=%~dp0%OUTPUT_ROOT%
set OUTPUT_PATH=%OUTPUT_ROOT%\%CONFIG%\%EXE_NAME%.exe
set DEBUG_FLAGS=%ALL_FLAGS% %DEBUG_FLAGS%
set RELEASE_W_DEBUG_FLAGS=%ALL_FLAGS% %RELEASE_W_DEBUG_FLAGS%
set RELEASE_FLAGS=%ALL_FLAGS% %RELEASE_FLAGS%
set SHIPPING_FLAGS=%ALL_FLAGS% %SHIPPING_FLAGS%
set DEEP_CLEAN=uninitialized
set OUTPUT_VERBOSITY=uninitialized

:: /subsystem:console /entry:%ENTRY_POINT% 
::set ENTRY_POINT=main
set DEBUG_LINK_FLAGS=-g -Xlinker /DEBUG -o "%OUTPUT_PATH%" -Xlinker /NODEFAULTLIB:libcmt.lib  %DEBUG_LIBS%
set RELEASE_W_DEBUG_LINK_FLAGS=-g -Xlinker /DEBUG -o "%OUTPUT_PATH%" %RELEASE_LIBS%
set RELEASE_LINK_FLAGS=-o "%OUTPUT_PATH%" %RELEASE_LIBS%
set SHIPPING_LINK_FLAGS=-o "%OUTPUT_PATH%" %RELEASE_LIBS%

:: set these to defaults
set BASE_FLAGS=%DEBUG_FLAGS%"
set LINK_FLAGS=%DEBUG_LINK_FLAGS%"

:: define a preprocessor macro for config based ifdefs
set "CONFIG_DEFINE=%EXE_NAME%_%CONFIG%"
for %%A in (A B C D E F G H I J K L M N O P Q R S T U V W X Y Z) do (
    set "CONFIG_DEFINE=!CONFIG_DEFINE:%%A=%%A!"
)
:: echo %CONFIG_DEFINE%
goto run_loop

::=====================================================================================================================
:: Interactive Menu
::=====================================================================================================================

:run_loop

if "%OUTPUT_VERBOSITY%" == "verbose" (
    echo project:           %EXE_NAME% %CONFIG%
    echo run arguments:     %RUN_ARGS%
    echo compiler:          %COMPILER% %CPP_STANDARD%
    echo linker:            %LINKER%
    echo compiler flags:    %BASE_FLAGS%
    echo linker flags:      %LINK_FLAGS% 
    echo include dirs:      %EXTERNAL_INCLUDE_DIRS%
) else (
    echo current project: %EXE_NAME% %RUN_ARGS% ^(%CONFIG%^)
)
echo    ^(Y^) Run
echo    ^(R^) Full Rebuild
echo    ^(C^) Clean Menu
echo    ^(A^) Asset Copying
echo    ^(B^) Change Build Config
echo    ^(P^) Change Program Args
echo    ^(V^) Show verbose build information
echo    ^(Q^) Quit
powershell -command "exit ([array]::IndexOf(@('y','q','r','a','c','p','b','v'), [Console]::ReadKey($true).KeyChar.ToString().ToLower()) + 1)"
if errorlevel 8 goto change_output_verbosity_stage
if errorlevel 7 goto change_build_config_stage
if errorlevel 6 goto update_run_args_stage
if errorlevel 5 goto clean_stage
if errorlevel 4 goto copy_stage
if errorlevel 3 goto compile_stage
if errorlevel 2 goto shutdown
if errorlevel 1 (
    echo Running !OUTPUT_PATH! !RUN_ARGS!
    "!OUTPUT_PATH!" !RUN_ARGS!
)
goto run_loop


::=====================================================================================================================
:: Compile/Link/Asset packaging
:: This is one big section section, even though there are 3 explicit stages currently
:: @todo:: optional incremental builds 
:: @todo:: asset refreshing using file timestamps
:: @todo:: any pre build or post build steps like asset packing/embedding, code generation for enums/tables/etc
::=====================================================================================================================

:compile_stage
echo Compiling source files...
echo .
echo .
echo .

:: Create output directory
if not exist "%OUTPUT_ROOT%\%CONFIG%\" mkdir "%OUTPUT_ROOT%\%CONFIG%\"
if not exist "temp\" mkdir "temp\"

:: Set active flags
if "%CONFIG%" == "debug" (
    set "BASE_FLAGS=%DEBUG_FLAGS%"
    set "LINK_FLAGS=%DEBUG_LINK_FLAGS%"
) else if "%CONFIG%" == "release_with_debug" (
    set "BASE_FLAGS=%RELEASE_W_DEBUG_FLAGS%"
    set "LINK_FLAGS=%RELEASE_W_DEBUG_LINK_FLAGS%"
) else if "%CONFIG%" == "release" (
    set "BASE_FLAGS=%RELEASE_FLAGS%"
    set "LINK_FLAGS=%RELEASE_LINK_FLAGS%"
) else if "%CONFIG%" == "shipping" (
    set "BASE_FLAGS=%SHIPPING_FLAGS%"
    set "LINK_FLAGS=%SHIPPING_LINK_FLAGS%"
) else (
    echo Unknown Configuration: %CONFIG%
    echo Valid configurations: debug, release_with_debug, release, shipping
    exit /b 1
)

for /r "%SOURCE_DIR%" %%f in (*.c *.cpp *.cxx *.cc *.c++) do (
    
    echo %%~f 
    set "src_file=%%~nxf"
    set "src_full=%%~f"
    
    :: Get just filename without extension for naming .o files
    set "obj_file=!OUTPUT_ROOT!\!CONFIG!\%%~nf.o"
    
    :: Check if this is a C or C++ file by extension
    set "src_ext=%%~xf"

    if /i "!src_ext!" == ".c" (
        %COMPILER% "-D%CONFIG_DEFINE%" -x c %BASE_FLAGS% %EXTERNAL_INCLUDE_DIRS% -I"%SOURCE_DIR%" -c "%%~f" -o "!obj_file!" 
    ) else (
        %COMPILER% "-D%CONFIG_DEFINE%" -x c++ %BASE_FLAGS% %EXTERNAL_INCLUDE_DIRS% -I"%SOURCE_DIR%" "-std=%CPP_STANDARD%" -c "%%~f" -o "!obj_file!" 
    )
    
    if errorlevel 1 (
        echo Compilation failed for %%~f
        goto run_loop
    )
)

echo .
echo .
echo .

:: Link everything
:link_stage
echo Linking executable...
%LINKER% %LINK_FLAGS% "%OUTPUT_ROOT%\%CONFIG%\*.o"

if errorlevel 1 (
    echo Linking failed!
    echo .
    echo .
    echo .
    echo Running %LINKER% -v to see invocation
    %LINKER% -v
    goto run_loop
)
echo .
echo .
echo .

:copy_stage
echo Copying assets and resources...
set "dirs_to_copy=%COPY_DIRS%"
set "output_config_dir=%OUTPUT_ROOT%\%CONFIG%"

for %%d in (%dirs_to_copy%) do (
    set "dir_name=%%d"
    set "dir_name=!dir_name: =!"
    
    if not "!dir_name!"=="" (
        if exist "!dir_name!\" (
            echo Copying "!dir_name!\" to "%output_config_dir%\!dir_name!\"
            xcopy "!dir_name!\" "%output_config_dir%\!dir_name!\" /E /I /Y /Q
            if errorlevel 1 (
                echo Warning: Failed to copy !dir_name!
            ) else (
                echo Successfully copied !dir_name!
            )
        ) else (
            echo Warning: Directory "!dir_name!" does not exist, skipping...
        )
    )
)

for /r "%LIBS_DIR%" %%f in (*.lib *.dll) do (
    echo Copying "%%f" to "%output_config_dir%\"
    copy /Y "%%f" "%output_config_dir%\" >nul
    if errorlevel 1 (
        echo Warning: Failed to copy %%~nxf to output directory
    )
)

echo .
echo .
echo .
echo Build succeeded: %OUTPUT_PATH%

goto run_loop


::=====================================================================================================================
:: Change Program Startup Arguments
::=====================================================================================================================

:change_output_verbosity_stage
echo .
echo .
echo .
if "%OUTPUT_VERBOSITY%" == "verbose" (
    set OUTPUT_VERBOSITY=light
) else (
    set OUTPUT_VERBOSITY=verbose
)
echo updated output verbosity: %OUTPUT_VERBOSITY%
echo .
echo .
echo .
goto run_loop

::=====================================================================================================================
:: Change Program Startup Arguments
::=====================================================================================================================

:update_run_args_stage
echo .
echo .
echo .
echo default startup arguments are defined within: 
echo    %~f0
if defined RUN_ARGS (
    echo    current startup arguments: %RUN_ARGS%
) else (
    echo    current startup arguments: ^<none^>
)

echo .
echo .
echo .
echo Enter new startup arguments
echo    ^<none^>      == no arguments
echo    ^<default^>   == default arguments
echo    leave blank == nothing happens
echo .
echo .
echo .
set /p RUN_ARGS=

if "%RUN_ARGS%"=="none" set RUN_ARGS=
if "%RUN_ARGS%"=="<none>" set RUN_ARGS=
if "%RUN_ARGS%"=="default" set RUN_ARGS=%RUN_ARGS_DEFAULT%
if "%RUN_ARGS%"=="<default>" set RUN_ARGS=%RUN_ARGS_DEFAULT%
if "%RUN_ARGS%"=="" (
    echo program args updated to: ^<none^>
) else (
    echo program args updated to: %RUN_ARGS%
)

echo .
echo .
echo .


goto run_loop

::=====================================================================================================================
:: Change Build Config
::=====================================================================================================================

:change_build_config_stage
echo .
echo .
echo .
echo current configuration: %CONFIG%
echo .
echo .
echo .
echo Choose new configuration:
echo     ^(1^) Debug
echo     ^(2^) Release With Debug
echo     ^(3^) Release
echo     ^(4^) Shipping 
powershell -command "exit ([array]::IndexOf(@('1','2','3','4'), [Console]::ReadKey($true).KeyChar.ToString().ToLower()) + 1)"
if errorlevel 4 (
    set CONFIG=shipping
) else if errorlevel 3 ( 
    set CONFIG=release
) else if errorlevel 2 (
    set CONFIG=release_with_debug
) else if errorlevel 1 (
    set CONFIG=debug
)
echo .
echo .
echo .
echo updated configuration: %CONFIG%
echo .
echo .
echo .
goto run_loop

::=====================================================================================================================
:: File Cleaning by Config
:: Cleaning a single config is done via procedure call, so you need to goto :eof to get back to the clean_stage
::=====================================================================================================================

:clean_stage
set DEEP_CLEAN=false

:clean_stage_2

echo .
echo .
echo .
echo Clean Options:
echo    ^(C^) Clean current config (%CONFIG%)
echo    ^(D^) Enable Deep Clean (%DEEP_CLEAN%)
echo    ^(A^) Clean ALL configs
echo    ^(1^) Clean Debug config
echo    ^(2^) Clean Release_w_Debug config  
echo    ^(3^) Clean Release config
echo    ^(4^) Clean Shipping config
echo    ^(0^) Cancel
echo .
choice /c CA1234D0 /n /m "Select clean option (deep clean will delete everything from the current config):"

if errorlevel 8 (
    echo Clean cancelled.
    echo .
    goto run_loop
) else if errorlevel 7 (
    if %DEEP_CLEAN% ==false (
        set DEEP_CLEAN=true
    ) else (
        set DEEP_CLEAN=false
    )
    goto :clean_stage_2;
) else if errorlevel 6 (
    call :clean_single_config "Shipping" "%OUTPUT_ROOT%"
) else if errorlevel 5 (
    call :clean_single_config "Release" "%OUTPUT_ROOT%"
) else if errorlevel 4 (
    call :clean_single_config "Release_w_Debug" "%OUTPUT_ROOT%"
) else if errorlevel 3 (
    call :clean_single_config "Debug" "%OUTPUT_ROOT%"
) else if errorlevel 2 (
    call :clean_all_configs
) else if errorlevel 1 (
    call :clean_single_config "%CONFIG%" "%OUTPUT_ROOT%"
)
echo .
echo .
echo .
goto run_loop

:clean_single_config
setlocal enabledelayedexpansion
set CONFIG_TO_CLEAN=%~1
set CLEAN_ROOT=%~2
set CLEAN_PATH=%CLEAN_ROOT%\%CONFIG_TO_CLEAN%
set DELETED_COUNT=0

if %DEEP_CLEAN%==false (
    :: clean only build artifacts, do not delete assets/shaders/dlls/libs/etc
    echo Cleaning %CONFIG_TO_CLEAN% build (deleting *.o *.pdb *.ilk *.exe files)
    for /r "%CLEAN_PATH%" %%F in (*.o *.pdb *.ilk *.exe) do (
        if exist "%%F" (
            del /q "%%F" 2>nul
            if not exist "%%F" set /a DELETED_COUNT+=1
        )
    )
) else (
    :: rm rf my guy
    echo Cleaning %CONFIG_TO_CLEAN% build, (deleting everyting)
    for /r "%CLEAN_PATH%" %%F in (*) do (
        if exist "%%F" (
            del /q "%%F" 2>nul
            if not exist "%%F" set /a DELETED_COUNT+=1
        )
    )
)
echo Deleted !DELETED_COUNT! file(s) in %CLEAN_PATH%
endlocal
goto :eof

:clean_all_configs
echo Cleaning ALL configs...
call :clean_single_config "Debug"           "%OUTPUT_ROOT%"
call :clean_single_config "Release_w_Debug" "%OUTPUT_ROOT%"
call :clean_single_config "Release"         "%OUTPUT_ROOT%"
call :clean_single_config "Shipping"        "%OUTPUT_ROOT%"
goto :eof

:shutdown
echo .
echo .
echo .
echo [cocobuild %COCOBUILD_VERSION_STRING%]
pause
exit

:: MIT License

:: Copyright (c) 2025-2026 Cory Simonich

:: Permission is hereby granted, free of charge, to any person obtaining a copy
:: of this software and associated documentation files (the "Software"), to deal
:: in the Software without restriction, including without limitation the rights
:: to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
:: copies of the Software, and to permit persons to whom the Software is
:: furnished to do so, subject to the following conditions:

:: The above copyright notice and this permission notice shall be included in all
:: copies or substantial portions of the Software.

:: THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
:: IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
:: FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
:: AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
:: LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
:: OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
:: SOFTWARE.