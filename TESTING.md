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

## Mobile (Android/iOS)

- Hold a finger anywhere to fire (multi-touch safe; releases missed while
  paused are re-anchored so firing can't stick); drag anywhere to steer (touch
  coordinates are converted through the canvas stretch, so drags track on
  phones). Covered by `res://tests/mobile_smoke.gd` via `force_touch`.
- Armor/score/sound/boss HUDs and the capture overlay render 1.5x
  (`force_mobile` in tests); the pause menu itself is unchanged.
- A subtle MENU button (same styling as the other HUDs) sits at the projected
  bottom-left corner and opens the pause menu (ESC on desktop); it hides on
  the end-of-run screens. The pause dialog is 1.25x, centered, and drops the
  ESC/S/R key hints on mobile. Game-over/victory/boss-warning popups also
  center in the real viewport instead of fixed design coords.

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

## Sector terrain and visual presentation

Aircraft retain the shared metal/paint grade, softer ground contrast, and cyan
player accents. Hostile shots retain their original glow, sparks, trails and
rendering order; the outlined cores from the initial pass were reverted.

Sector 1 uses the original canyon. Sector 2 uses industrial_riverworks.png with
spillways, refineries and loading yards. Sector 3 uses command_fortress.png with
armored bridges, cliff defenses and command installations. Both new textures
share the original normalized map coordinates, retaining bridge routes and
structure yards. Outer vehicle routes shift inward to follow the new service
roads. Scenery damage and wreck state persist during the five-second advancing
terrain blend; checkpoint retries initialize the correct map immediately.
Both terrain textures have repaired cyclical artwork at their boundaries. The
shader uses repeat filtering and periodic water motion without mirrored blending.

Run tests with rendering enabled (screenshot checkpoints cannot run headless):
- res://tests/visual_pass_smoke.gd
- res://tests/campaign_smoke.gd
- res://tests/ground_combat_smoke.gd

Visual captures: artifacts/visual-sector-1.png through visual-sector-3.png,
and sector-transition-2.png / sector-transition-3.png. Checks cover terrain
selection, transition progress, checkpoint initialization, wrap continuity,
original hostile rendering order/sparks, unchanged projectile collision radius,
and the retained player accent. Campaign and ground tests cover progression,
bosses, real projectile collisions, vehicle firing and persistent destruction.

Source assets and generation prompts: assets/background/SECTOR_ART.md.
APK and web distributions require a new export.

## Terrain seam verification

Run `res://tests/terrain_seam_smoke.gd` with rendering enabled. It captures
both maps at three scroll positions with the boundary in the middle of the screen.
Inspect `artifacts/seams/sector-2-wrap-1.png` and `sector-3-wrap-1.png`.
Raw joins and triple-stack previews are also in `artifacts/seams/`.
The offline assembly asserts that rows 160 through height-161 are unchanged.


## Boss damage appearance

Run `Godot_v4.7-stable_win64_console.exe --path . --script tests/boss_appearance_smoke.gd` with a rendering display. Verifies all three bosses, alternating final-boss wing charge cues, and smoke/fire reset on reuse as an interceptor. Smoke and fire use an accelerated continuous health curve: 60% health matches the previous 35% appearance, with smoothly increasing density, size and coverage; the original hull artwork remains unchanged. Saves `artifacts/review/boss-phases.png` for visual inspection. Combat values and projectile artwork are unchanged.


## Debug destination menu

Project Settings > Application > Run > Main Run Args is configured to `-- --debug-menu` (enable Advanced Settings if hidden). The first `--` separates Godot options from game arguments. Clear this field to disable the menu. F2 opens/closes it during play; Escape resumes. Select Level 1–3 or Boss Ship 1–3. Each selection starts a fresh run in that sector; bosses retain their normal warning and entrance. Restarts repeat the selected destination while this debug mode is enabled. Legacy `--debug-final-boss` still works when the menu is disabled.

Run `Godot_v4.7-stable_win64_console.exe --path . --script tests/debug_menu_smoke.gd -- --debug-menu` to verify all six destinations, checkpoints, pause/resume, boss effects, and the bunker's matching wreck and reuse. Screenshot: `artifacts/review/debug-menu.png`.


## Crater and progressive damage refinement

Run `Godot_v4.7-stable_win64_console.exe --path . --script tests/damage_refinement_smoke.gd` to check the original crater behind the aligned bunker wreck, monotonic smoke/fire strength, and eased heavy-hit transitions. Saves `artifacts/review/crater-progressive-damage.png`. The bunker uses the existing crater and destroyed-building textures as two game layers; other building craters keep their original size.


## Building wreck variants

Run `Godot_v4.7-stable_win64_console.exe --path . --script tests/building_wrecks_smoke.gd` with rendering enabled. Verifies every gameplay building has a matching transparent wreck, source canvas and footprint sizes agree, crater and wreck layers align, destruction awards score once, and reset restores the building. Extra crop padding preserves bent metal beyond the intact silhouette. Saves `artifacts/review/building-wrecks.png`.

`damage_refinement_smoke.gd` also checks that both smoke and fire at 60% health match the prior 35% targets.


## Sector crater tints

Run `Godot_v4.7-stable_win64_console.exe --path . --script tests/crater_tint_smoke.gd` to render the three crater palettes and verify persistent remains blend to the next sector over five seconds. Saves `artifacts/review/crater-sector-tints.png`. Level 1 retains the original sand tint; Level 2 uses desaturated concrete dust; Level 3 uses cooler slate rubble. Both vehicle and building remains use the shared shader, preserving texture detail and alpha.


## Building destruction variety

Each lethal building hit rolls once: 50% leaves its matching wreck and crater, 50% leaves only a crater with a 30% larger explosion. Vehicle destruction is unchanged. Run `Godot_v4.7-stable_win64_console.exe --headless --path . --script tests/destruction_variety_smoke.gd` to exercise both outcomes on all five buildings, verify explosion scaling, one-time score/roll, and reuse. Wreck-art preview tests seed their outcome to remain deterministic.
