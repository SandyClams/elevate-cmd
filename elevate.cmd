@ECHO off

:[Initialize]
  :: create random id for our temp files to avoid filename clashing
  SET "_ELEVATE ID_=%RANDOM%%RANDOM%"
  SET "_TEMP RESTORE FILE_=%~dp0elevate_restore_%_ELEVATE ID_%.cmd"
  SET "_TEMP PID FILE_=%~dp0elevate_pid_%_ELEVATE ID_%.txt"
  :: initialize restore file with echo off
  > "%_TEMP RESTORE FILE_%" ECHO @ECHO off
  :: for keeping track of POPD iterations
  SET "_PREVIOUS DIRECTORY_=%CD%"
  SET "_COUNT_=0"

:[ProcessWindowTitle]
  SETLOCAL EnableDelayedExpansion
  :: we have to call into WMIC outside our FOR loop to return an accurate process ID
  WMIC PROCESS WHERE NAME^="WMIC.EXE" GET PARENTPROCESSID /value > "%_TEMP PID FILE_%"
  :: then loop a single time over the temp file output to isolate our cmd window PID
  FOR /f "Tokens=2 Delims==" %%R IN ('FIND "ParentProcess" "%_TEMP PID FILE_%"') DO (
    DEL "%_TEMP PID FILE_%"
    SET "_THIS PROCESS ID_=%%R"
    :: loop again over the verbose printed attributes of the task having our matching PID
    FOR /f "Tokens=*" %%L IN ('TASKLIST /fi "PID eq !_THIS PROCESS ID_!" /fo LIST /v') DO (
      SET "_CURRENT ATTRIBUTE_=%%L"
      :: if we have a window title attribute,
      if "!_CURRENT ATTRIBUTE_:~0,12!"=="Window Title" (
        :: finally store the title of our cmd window
        SET "_TEMP RESTORE TITLE_=!_CURRENT ATTRIBUTE_:~14!"
      )
    )
  )
  :: get the title to the global scope
  ENDLOCAL & SET "_TEMP RESTORE TITLE_=%_TEMP RESTORE TITLE_%"
  :: now change cmd window title, not to identify it later, but to provide user feedback
  TITLE Opening Administrator Prompt...

:[PopCurrentStackItem]
  POPD
  SET "_CURRENT DIRECTORY_=%CD%"

  IF "%_CURRENT DIRECTORY_%"=="%_PREVIOUS DIRECTORY_%" (
    :: update the number of times we've seen a duplicate item, but copy nothing
    SET /a "_COUNT_+=1"

  ) ELSE (
    :: if we just found a new stack item after one or more duplicates,
    IF %_COUNT_% GTR 0 (
      :: then those duplicates were valid stack items, so we go and copy them over
      GOTO [RegisterStackDuplicates]
    )
    :: if this is a new stack item after zero duplicate items, copy it over normally
    SET "_RECREATED STACK_= ^& PUSHD ^"%_PREVIOUS DIRECTORY_%^"%_RECREATED STACK_%"
    SET "_PREVIOUS DIRECTORY_=%_CURRENT DIRECTORY_%"
  )
  :: if we have five or fewer duplicate items, keep counting, else finish
  IF %_COUNT_% LEQ 5 (GOTO [PopCurrentStackItem]) ELSE GOTO [ProcessStackData]

:[RegisterStackDuplicates]
  :: copy over our last duplicate item
  SET "_RECREATED STACK_= ^& PUSHD ^"%_PREVIOUS DIRECTORY_%^"%_RECREATED STACK_%"
  :: update the number of remaining duplicates
  SET /a "_COUNT_-=1"
  :: if we still have duplicates, keep counting
  IF %_COUNT_% GTR 0 (GOTO [RegisterStackDuplicates])
  :: otherwise go back to popping the stack
  SET "_PREVIOUS DIRECTORY_=%_CURRENT DIRECTORY_%"
  GOTO [PopCurrentStackItem]

:[ProcessStackData]
  :: compose command to start at first item on stack and push each subsequent item
  SET "_CREATE STACK COMMAND_=CD /d ^"%_CURRENT DIRECTORY_%^"%_RECREATED STACK_%"
  :: append command to the next line of our restore file
  >> "%_TEMP RESTORE FILE_%" ECHO %_CREATE STACK COMMAND_%
  :: append a command to quit restore file early, we will use this on window cancel
  >> "%_TEMP RESTORE FILE_%" ECHO IF "%%~1"=="earlyquit" EXIT /b

:[ProcessVariables]
  :: first we need these suckers gone
  SET "_ELEVATE ID_="
  SET "_TEMP PID FILE_="
  SET "_PREVIOUS DIRECTORY_="
  SET "_COUNT_="
  SET "_CURRENT DIRECTORY_="
  SET "_RECREATED STACK_="
  SET "_CREATE STACK COMMAND_="

  SETLOCAL EnableDelayedExpansion
  :: for each output line of existing variable names and values,
  FOR /f "Tokens=*" %%V IN ('SET') DO (
    :: store the variable display in order to extract substring
    SET "_CURRENT LINE_=%%~V"
    :: if the current line isn't one of our own local variables,
    IF NOT "!_CURRENT LINE_:~1,12!"=="TEMP RESTORE" (
      :: compose new SET command that will redefine the variable
      SET "_RESTORE VARIABLE COMMAND_=SET "%%~V^""
      :: append command to the next line of our restore file
      >> "%_TEMP RESTORE FILE_%" ECHO !_RESTORE VARIABLE COMMAND_!
    )
  )
  ENDLOCAL

:[LaunchAdministratorWindow]
  :: run Powershell command to launch Administrator cmd, kill old cmd, restore state, delete temp file
  Powershell.exe -Command "& {Start-Process cmd.exe -Verb RunAs -ArgumentList '/k ^"TASKKILL /f /im cmd.exe /fi \^"WINDOWTITLE eq Opening Administrator Prompt*\^" ^& \^"%_TEMP RESTORE FILE_%\^" ^& DEL \^"%_TEMP RESTORE FILE_%\^" ^& cls^"'} 2>NUL"
  :: silently pause for one second after command executes, giving original window time to close
  TIMEOUT /t 1 /nobreak >NUL

:[OnWindowCancel]
  :: else recreate original stack from our restore file
  "%_TEMP RESTORE FILE_%" earlyquit & (
    :: and clean up
    TITLE %_TEMP RESTORE TITLE_%
    DEL "%_TEMP RESTORE FILE_%"
    SET "_TEMP RESTORE TITLE_="
    SET "_TEMP RESTORE FILE_="
  )

