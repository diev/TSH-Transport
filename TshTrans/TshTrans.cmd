@echo off
%windir%\System32\WindowsPowerShell\v1.0\powershell.exe -nologo -noprofile %~dpn0.ps1 -Debug %*
