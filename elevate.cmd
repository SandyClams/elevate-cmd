@echo off

:[Initialize]
  :: change cmd window title to identify it later by its title
  TITLE Opening Administrator Prompt...
  :: create random name for our temp file to avoid filename clashing
  SET "_RESTORE NAME_=elevate_restore_%RANDOM%%RANDOM%.cmd"
  SET "_RESTORE FILE_=%~dp0%_RESTORE NAME_%"
  :: initialize temp file with echo off
  > "%_RESTORE FILE_%" ECHO @ECHO off
  :: for keeping track of POPD iterations
  SET "_PREVIOUS DIRECTORY_=%CD%"
  SET "_COUNT_=0"

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
  >> "%_RESTORE FILE_%" ECHO %_CREATE STACK COMMAND_%
  :: append a command to quit restore file early, we will use this on window cancel
  >> "%_RESTORE FILE_%" ECHO IF "%%~1"=="earlyquit" EXIT /b

:[ProcessVariables]
  :: first we need these suckers gone
  SET "_RESTORE NAME_="
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
    :: if the current line isn't our own local variable,
    IF NOT "!_CURRENT LINE_:~1,12!"=="RESTORE FILE" (
      :: compose new SET command that will redefine the variable
      SET "_RESTORE VARIABLE COMMAND_=SET "%%~V^""
      :: append command to the next line of our restore file
      >> "%_RESTORE FILE_%" ECHO !_RESTORE VARIABLE COMMAND_!
    )
  )
  ENDLOCAL

:[LaunchAdministratorWindow]
  :: run Powershell command to launch Administrator cmd, kill old cmd, restore state, delete temp file
  Powershell.exe -Command "& {Start-Process cmd.exe -Verb RunAs -ArgumentList '/k ^"TASKKILL /f /im cmd.exe /fi \^"WINDOWTITLE eq Opening Administrator Prompt*\^" ^& \^"%_RESTORE FILE_%\^" ^& DEL \^"%_RESTORE FILE_%\^" ^& cls^"'} 2>NUL"
  :: silently pause for one second after command completes, giving original window time to close
  TIMEOUT /t 1 /nobreak >NUL

:[OnWindowCancel]
  :: else recreate original stack from our restore file and clean up
  "%_RESTORE FILE_%" earlyquit & DEL "%_RESTORE FILE_%" & SET "_RESTORE FILE_="

