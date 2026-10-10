# Boss 1 and 2 approved artwork

Integrated the approved cyan crystal cruiser (`BossShip.png`) and premium red metallic cruiser (`Bosship2.png`). Both were generated with the built-in image generation tool from user-provided spacecraft references, then copied unchanged from the accepted review images. The subsequent cyan background-removal variant was not used.

Original generated images:
- Boss 1: `exec-a3f31796-eea0-4a50-bba0-8aa28b4056f3.png`
- Boss 2: `exec-1d1cbb2a-b199-45df-8a78-b9939b597ecc.png`

Runtime AtlasTexture regions trim the surrounding transparent canvas. Display widths remain approximately 224 and 227 pixels. New aspect ratios are preserved. Collision resources were rebaked using `tools/bake_boss_collisions.gd`; engine plumes and damage sites follow the new hulls. Attack code, shot origins, timing, angles, damage, health and movement values are unchanged.

Validation: `boss_appearance_smoke.gd` and `boss2_pattern_smoke.gd` passed; rendered intact/damaged hulls inspected in `artifacts/review/boss-phases.png`.
