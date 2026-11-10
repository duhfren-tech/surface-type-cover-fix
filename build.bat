@echo off
rem Builds TypeCoverFix.exe - needs only the .NET Framework 4.x compiler that ships with Windows.
setlocal
set CSC=%WINDIR%\Microsoft.NET\Framework\v4.0.30319\csc.exe
if not exist build mkdir build
"%CSC%" /nologo /target:exe /optimize+ /out:build\TypeCoverFix.exe ^
  /reference:System.Windows.Forms.dll ^
  /resource:TypeCoverFix.ps1,TypeCoverFix.ps1 ^
  Program.cs
if errorlevel 1 goto :fail
echo Built build\TypeCoverFix.exe
exit /b 0
:fail
echo Build failed
exit /b 1
