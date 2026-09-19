@echo off
rem Build WhisperApp for Windows - no SDK needed, uses Roslyn from the newest
rem installed Visual Studio / Build Tools, then falls back to legacy locations.
setlocal

set "CSC="
set "VSWHERE=%ProgramFiles(x86)%\Microsoft Visual Studio\Installer\vswhere.exe"
if exist "%VSWHERE%" (
  for /f "usebackq tokens=*" %%I in (`"%VSWHERE%" -latest -products * -requires Microsoft.Component.MSBuild -find MSBuild\Current\Bin\Roslyn\csc.exe`) do set "CSC=%%I"
)

if not defined CSC if exist "C:\Program Files (x86)\Microsoft Visual Studio\2019\BuildTools\MSBuild\Current\Bin\Roslyn\csc.exe" set "CSC=C:\Program Files (x86)\Microsoft Visual Studio\2019\BuildTools\MSBuild\Current\Bin\Roslyn\csc.exe"
if not defined CSC if exist "C:\Program Files (x86)\Microsoft Visual Studio\2019\Community\MSBuild\Current\Bin\Roslyn\csc.exe" set "CSC=C:\Program Files (x86)\Microsoft Visual Studio\2019\Community\MSBuild\Current\Bin\Roslyn\csc.exe"
if not defined CSC set "CSC=C:\Windows\Microsoft.NET\Framework64\v4.0.30319\csc.exe"

set "FW=C:\Windows\Microsoft.NET\Framework64\v4.0.30319"

echo Using C# compiler: %CSC%
"%CSC%" /nologo /noconfig /nostdlib+ /target:winexe /platform:anycpu /optimize+ /langversion:7.3 /codepage:65001 /out:"%~dp0WhisperApp.exe" /r:"%FW%\mscorlib.dll" /r:"%FW%\System.dll" /r:"%FW%\System.Core.dll" /r:"%FW%\System.Drawing.dll" /r:"%FW%\System.Windows.Forms.dll" /r:"%FW%\System.Net.Http.dll" /r:"%FW%\System.Web.Extensions.dll" /r:"%FW%\System.Security.dll" "%~dp0src\*.cs"

if errorlevel 1 (
  echo BUILD FAILED
  exit /b 1
)
echo BUILD OK: %~dp0WhisperApp.exe
