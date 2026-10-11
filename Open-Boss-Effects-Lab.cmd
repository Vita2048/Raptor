@echo off
setlocal
set "RAPTOR_GODOT=C:\Temp\Godot\Godot_v4.7-stable_win64_console.exe"
if not exist "%RAPTOR_GODOT%" (
  echo Godot was not found at %RAPTOR_GODOT%.
  echo Open scenes/BossEffectsLab.tscn in the Godot editor and press F6.
  pause
  exit /b 1
)
"%RAPTOR_GODOT%" --path "%~dp0." --windowed --resolution 1440x810 res://scenes/BossEffectsLab.tscn
