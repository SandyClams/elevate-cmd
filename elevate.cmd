@echo off
SETLOCAL EnableDelayedExpansion

:[Elevate]
  :: change cmd window title to identify it later by its title
  TITLE Opening Administrator Prompt...
  :: create random name for our temp file to avoid filename clashing
  SET "_ELEVATE TEMP RESTORE NAME_=elevate_restore_%RANDOM%%RANDOM%.cmd"
  SET "_ELEVATE TEMP RESTORE FILE_=%~dp0%_ELEVATE TEMP RESTORE NAME_%"

  :: initialize temp file with echo off
  > "%_ELEVATE TEMP RESTORE FILE_%" ECHO @ECHO off
  :: for each output line of existing variable names and values,
  FOR /f "Tokens=*" %%V IN ('SET') DO (
    :: store the variable display in order to extract substring
    SET "_CURRENT LINE_=%%~V"
    :: if current line isn't one of our temp variables,
    IF NOT "!_CURRENT LINE_:~1,12!"=="ELEVATE TEMP" (
      :: compose new SET command that will redefine the variable
      SET "_RESTORE COMMAND_=SET "%%~V^""
      :: append command to the next line of our restore file
      >> "%_ELEVATE TEMP RESTORE FILE_%" ECHO !_RESTORE COMMAND_!
    )
  )
  :: run Powershell command to launch Administrator cmd, kill old cmd, restore variables, delete temp file
  Powershell.exe -Command "& {Start-Process cmd.exe -Verb RunAs -ArgumentList '/k ^"TASKKILL /f /im cmd.exe /fi \^"WINDOWTITLE eq Opening Administrator Prompt*\^" ^& cd /d %CD% ^& \^"%_ELEVATE TEMP RESTORE FILE_%\^" ^& DEL \^"%_ELEVATE TEMP RESTORE FILE_%\^" ^& cls^"'}"
  :: pause so we never see the old cmd window update
  PAUSE >NUL
