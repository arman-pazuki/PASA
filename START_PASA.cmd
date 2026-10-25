@echo off
setlocal
cd /d "%~dp0"
rem Translate the common Unix UTF-8 locale when inherited on Windows.
if /i "%LC_ALL%"=="C.UTF-8" set "LC_ALL=.UTF-8"
if /i "%LANG%"=="C.UTF-8" set "LANG=.UTF-8"
if /i "%LC_CTYPE%"=="C.UTF-8" set "LC_CTYPE=.UTF-8"
set "PASA_RSCRIPT="
if defined R_HOME if exist "%R_HOME%\bin\Rscript.exe" set "PASA_RSCRIPT=%R_HOME%\bin\Rscript.exe"
if not defined PASA_RSCRIPT if exist "%ProgramFiles%\R\R-4.6.0\bin\Rscript.exe" set "PASA_RSCRIPT=%ProgramFiles%\R\R-4.6.0\bin\Rscript.exe"
if not defined PASA_RSCRIPT for /f "delims=" %%R in ('where Rscript.exe 2^>nul') do if not defined PASA_RSCRIPT set "PASA_RSCRIPT=%%R"
if not defined PASA_RSCRIPT goto missing_r
"%PASA_RSCRIPT%" --vanilla "%~dp0START_PASA.R"
set "PASA_EXIT=%ERRORLEVEL%"
if not "%PASA_EXIT%"=="0" (
  echo.
  echo PASA could not start or stopped with an error. Read the message above.
  pause
)
exit /b %PASA_EXIT%
:missing_r
echo PASA requires 64-bit R 4.6.0. Install R, then open this file again.
echo If R is installed elsewhere, set R_HOME or add Rscript.exe to PATH.
pause
exit /b 1
