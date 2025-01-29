@echo off
SETLOCAL ENABLEDELAYEDEXPANSION

:: Set up the APP_HOME directory
PUSHD %~dp0..
IF NOT DEFINED APP_HOME SET "APP_HOME=%CD%"
POPD

:: Default memory and JVM options
set "DEFAULT_LOCATOR_MEMORY=1g"
set "DEFAULT_SERVER_MEMORY=4g"
set "DEFAULT_JVM_OPTS=--J=-Djava.net.preferIPv4Stack=true"
set "LOCATORS=localhost[10334]"


call :AddJarsToClasspath "%APP_HOME%\build\lib
call :AddJarsToClasspath "%APP_HOME%\build\libs


:: Locator configuration
set "COMMON_LOCATOR_ITEMS=--initial-heap=%DEFAULT_LOCATOR_MEMORY%"
set "COMMON_LOCATOR_ITEMS=%COMMON_LOCATOR_ITEMS% --max-heap=%DEFAULT_LOCATOR_MEMORY%"
set "COMMON_LOCATOR_ITEMS=%COMMON_LOCATOR_ITEMS% --locators=%LOCATORS%"
set "COMMON_LOCATOR_ITEMS=%COMMON_LOCATOR_ITEMS% --enable-cluster-configuration=false"
set "COMMON_LOCATOR_ITEMS=%COMMON_LOCATOR_ITEMS% %DEFAULT_JVM_OPTS%"
set "COMMON_LOCATOR_ITEMS=%COMMON_LOCATOR_ITEMS% --classpath=%NEW_CLASSPATH%"

:: Create the locator directory
mkdir "%APP_HOME%\data\locator1"

:: Start locator
start "startingGemFireLocator" /min  cmd /c gfsh -e "start locator --name=locator1 --dir=%APP_HOME%\data\locator1 --port=10334 %COMMON_LOCATOR_ITEMS%"

:: Specify the port to check
set "port=7070"

:: Specify the delay between each check
set "delay=5"

:CHECK_PORT

:: Use netstat to check if the port is listening
:: If you decide to use netstat there seems to be a delay between the port in listening mode and willing to accept  ¯\_(ツ)_/¯
::netstat -an | find ":%port%" | find "LISTENING" >nul 2>&1

:: Use PowerShell to check if the port is open
powershell -Command "if ((Test-NetConnection -ComputerName 'localhost' -Port %port% -WarningAction SilentlyContinue).TcpTestSucceeded) { exit 0 } else { exit 1 }"
if %ERRORLEVEL% equ 0 (
    echo Locator is ready.
    goto END_PORT_CHECK
) else (
    echo Locator running on %port% is not ready. Waiting...
)

:: Wait for the specified delay
 c:\Windows\System32\timeout.exe /T %delay% /NOBREAK >nul

:: Retry the port check
goto CHECK_PORT

:END_PORT_CHECK




:: Server configuration
set "COMMON_SERVER_ITEMS=--J=-Xmx%DEFAULT_SERVER_MEMORY% --J=-Xms%DEFAULT_SERVER_MEMORY%"
set "COMMON_SERVER_ITEMS=%COMMON_SERVER_ITEMS% %DEFAULT_JVM_OPTS%"
set "COMMON_SERVER_ITEMS=%COMMON_SERVER_ITEMS% --server-port=0"
set "COMMON_SERVER_ITEMS=%COMMON_SERVER_ITEMS% --rebalance"
:: Note I am using cache.xml and gemfire properties - just hidden in the jar
set "COMMON_SERVER_ITEMS=%COMMON_SERVER_ITEMS% --use-cluster-configuration=false"
set "COMMON_SERVER_ITEMS=%COMMON_SERVER_ITEMS% --classpath=%NEW_CLASSPATH%"
set "COMMON_SERVER_ITEMS=%COMMON_SERVER_ITEMS% --cache-xml-file=%APP_HOME%/src/main/resources/cache.xml"


call gfsh -e "connect --locator=%LOCATORS%" -e "configure pdx --read-serialized=false --auto-serializable-classes='demo.gemfire.*'"
:: Remove process file if it exists
del /F /Q "%APP_HOME%\data\processfile.txt" 2>nul

:: Start multiple servers
for %%i in (1 2) do (
    set /a port=7070 + %%i * 10
    start "startingGemFireServer%%i" /min cmd /c ^
    "gfsh -e ^"connect --locator=%LOCATORS%^" -e ^"start server --name=server%%i --dir=%APP_HOME%\data\server%%i --start-rest-api=true --http-service-port=!port! %COMMON_SERVER_ITEMS%^" ^& echo server%%i ^>^> %APP_HOME%\data\processfile.txt"
)


:: Monitor server startup
:LOOP
set "allStarted=true"
for %%i in (1 2) do (
    findstr /I /C:"server%%i" "%APP_HOME%\data\processfile.txt" >nul 2>&1
    if ERRORLEVEL 1 (
        set "allStarted=false"
        echo Waiting for startingGemFireServer%%i to complete...
    )
)

:: Check if all servers have completed
if "%allStarted%" equ "false" (
     c:\Windows\System32\timeout.exe /T %delay% /NOBREAK
    goto LOOP
)

:CONTINUE
REM Exit the script
goto :eof

:AddJarsToClasspath
    REM Ensure a parameter is passed
    if "%~1"=="" (
        echo Error: No target directory provided to AddJarsToClasspath.
        goto :eof
    )

    set "DIR_TO_PROCESS=%~1"

    REM Verify that the target directory exists
    if not exist "%DIR_TO_PROCESS%" (
        echo Warning: The directory "%DIR_TO_PROCESS%" does not exist. Skipping.
        goto :eof
    )

    REM Navigate to the target directory
    pushd "%DIR_TO_PROCESS%" || (
        echo Warning: Failed to change directory to "%DIR_TO_PROCESS%". Skipping.
        goto :eof
    )

    for /R %%f in (*.jar) do (
        if "!NEW_CLASSPATH!"=="" (
            set "NEW_CLASSPATH=%%~ff"
        ) else (
            set "NEW_CLASSPATH=!NEW_CLASSPATH!;%%~ff"
        )
        echo Adding %%~ff to CLASSPATH
    )


    REM Return to the original directory
    popd

    REM Exit the function
    goto :eof