# Final boss testing

Desktop command (arguments after the double dash belong to the game):

```powershell
& 'C:\Temp\Godot\Godot_v4.7-stable_win64_console.exe' --path 'C:\Temp\Raptor' -- --debug-final-boss
```

For the exported browser game, append `?debug=final-boss` to its URL (or
`&debug=final-boss` if there is already a query string). This works in release
exports as well, including GitHub Pages. It requires exporting this updated code.

The shortcut starts Sector 3 with full player armor and the normal final-boss
warning/entrance. It does not award skipped score or kills. Fly Again repeats the
test encounter while the parameter is present. Remove the parameter for a normal run.

The final boss has 10,800 armor, wider lateral movement, alternating aimed spreads
and fan volleys, and 8 armor damage per central projectile. Below 55% armor it adds
wing cannons; below 25% it fires faster again. The charge cue remains before each volley.

Automated checks:

```powershell
& 'C:\Temp\Godot\Godot_v4.7-stable_win64_console.exe' --path . --script res://tests/final_boss_smoke.gd -- --debug-final-boss
& 'C:\Temp\Godot\Godot_v4.7-stable_win64_console.exe' --path . --script res://tests/campaign_smoke.gd
& 'C:\Temp\Godot\Godot_v4.7-stable_win64_console.exe' --path . --script res://tests/capture_smoke.gd
```

# Desktop capture (S / R)

Desktop builds only (disabled on Web/mobile and headless):

- `S` saves a PNG screenshot at native viewport resolution to
  `user://screenshots/screenshot_<timestamp>.png`. The on-screen indicator is
  hidden for the captured frame. Note `S` still steers the ship down while held;
  the screenshot fires once per press.
- `R` starts/stops 30fps recording at native resolution: a JPG sequence
  `user://recordings/REC_<timestamp>/frame_<n>.jpg` plus `manifest.txt` with
  size/frame counts and an ffmpeg command. If `ffmpeg` is on PATH, an MP4 is
  encoded in the background on stop. A red `● REC` timer shows while recording.
  Recording pauses with the game and auto-stops after 3 minutes (5400 frames).
- Performance: the game thread only does the viewport readback; JPEG encoding
  runs on a worker thread, so gameplay stays fluent and is only affected while
  recording is active (plus a one-frame hitch per screenshot). If the worker
  falls behind, frames are counted as dropped in the manifest instead of
  slowing the game. `RECORD_SCALE` in `scripts/CaptureManager.gd` stays `1.0`
  for full resolution; set it to `0.5` for half-resolution recording.

On Windows, `user://` maps to `%APPDATA%\Godot\app_userdata\Raptor Shadow Run\`.

The MP4 is only produced when `ffmpeg` is on PATH (the toast and the manifest
say so when it is missing). Install it, then stop a recording again or rerun
the manifest's ffmpeg command inside the session folder:

```powershell
winget install Gyan.FFmpeg
ffmpeg -version
```

Quitting mid-recording still writes the manifest and attempts the MP4.

## Running the game

`F5` in the editor runs a debug session (debugger hooks, editor overhead). For
full-speed play and recording, close the editor and run the game binary:

```powershell
& 'C:\Temp\Godot\Godot_v4.7-stable_win64.exe' --path 'C:\Temp\Raptor'
```

## Resolution (pause menu)

`ESC` offers 1920×1080, 1600×900, and 1280×720 (windowed, saved across runs).
Lower resolutions render fewer pixels, which speeds up both the game and the
30fps recording; the HUD re-anchors to the projected playfield automatically.
Desktop only: on Web the canvas is owned by the browser and on mobile the
window is the device screen, so the menu shows "FIXED BY DEVICE / BROWSER"
and the saved setting is ignored there.

## Effect warm-up (Web first-explosion freeze)

`Main` calls `VFX.warm_up()` once per process: one quiet small + large
explosion, muzzle flash, and impact spark at startup (no sound/shake). This
forces WebGL shader compiles and particle-texture uploads before combat so
the first mid-game explosion doesn't freeze. Extend it when adding new
effect kinds. Checked by `res://tests/warmup_smoke.gd`.
