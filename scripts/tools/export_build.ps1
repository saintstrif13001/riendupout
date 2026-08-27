# Regénère l'exécutable Windows autonome (build/windows/RienDuPoutOnline.exe)
# Usage : depuis PowerShell, à la racine du projet : .\scripts\tools\export_build.ps1
$ErrorActionPreference = "Stop"
$exe = "C:\Users\jarch\Documents\Godot_v4.7.1-stable_win64.exe\Godot_v4.7.1-stable_win64_console.exe"
$proj = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
& $exe --headless --rendering-driver opengl3 --path $proj --export-release "Windows Desktop" "build/windows/RienDuPoutOnline.exe"
Write-Output "Export terminé : $proj\build\windows\RienDuPoutOnline.exe"
