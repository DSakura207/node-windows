@echo off
SETLOCAL ENABLEDELAYEDEXPANSION

REM Extract first parameter, first character of first parameter, and all command line parameters
SET _firstArg=%1
SET _firstChar=%_firstArg:~0,1%
SET _allArg=%*

REM If dash is the first character of first parameter, pass everything to node.
IF /i "%_firstChar%"=="-" GOTO :RUN_NODE

REM If the first parameter is found in path, pass everything cmd.exe.
where.exe /Q $PATH:%1
IF /i "%ERRORLEVEL%"=="0" GOTO :RUN_CMD

REM If the first parameter is not found in path, 
REM But it exists as a file, pass everything to node.
REM Otherwise, pass everything to cmd.exe.
REM If where.exe failed with other error code,
REM Exit with its error level.
IF /i "%ERRORLEVEL%"=="1" (
    IF EXIST "%_firstArg%" (
        GOTO :RUN_NODE
    ) ELSE (
        GOTO :RUN_CMD
    )
) ELSE (
    SET _olderrorlevel=%ERRORLEVEL%
    echo where.exe exited with %_olderrorlevel%
    EXIT /B %_olderrorlevel%
)

:RUN_NODE
node %_allArg%
GOTO :END

:RUN_CMD
cmd.exe /S /C %_allArg%
GOTO :END

:END
EXIT /B %ERRORLEVEL%