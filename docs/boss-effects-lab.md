# Boss effects lab

Double-click `Open-Boss-Effects-Lab.cmd` in the project directory, or open
`scenes/BossEffectsLab.tscn` in Godot and press **F6** (Run Current Scene).
F5 continues to run the normal game.

- Select Boss 1, 2 or 3.
- **Current game effects** (default) previews bright compact cores,
  independently curling orange tongues, and irregular fuel surges at each breach.
  Short-lived upper tongues trail through turns while the cores stay attached.
  Warm soot at the flame tips cools into expanding dark smoke, then fades.
  Tighter amber hull lighting changes brightness and warmth with each surge.
  **Previous fire + smoke** keeps the earlier appearance for comparison.
- **Small blasts below 25% armor** triggers occasional visual hull ruptures only
  below that threshold. The game uses the same effects, capped at three concurrent
  blasts per boss. The lab toggle can disable them in the current effects preview.
- Drag **Damage** from 0% (intact) to 100% (fully damaged).
- Use the armor presets to inspect the 70%, 50%, 30% and 15% health stages.
- **Move ship** starts enabled to show fire attachment and smoke trails. Toggle
  it off to freeze the hull; the fire and smoke keep animating. Adjust
  **Movement speed** from 0.25× to 2× to test drift and direction changes.
- Toggle **Light background** to inspect contrast.
- Press **Test final explosion** to play the game's boss detonation. The ship
  automatically returns after the effects finish; repeat as needed.
- **Restore ship** clears the smoke and restarts the selected damage preview.

The lab uses the production EnemyShip, BossRefinedDamage and VFX scripts and the
same explosion scale as EnemyManager. It does not fire weapons, award score or
advance the campaign. Changing the slider to 100% previews full damage without
automatically destroying the ship; the explosion button controls destruction.
