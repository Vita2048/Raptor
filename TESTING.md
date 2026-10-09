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
```
