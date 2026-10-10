# Boss 1 and 2 approved artwork

Integrated the approved cyan crystal cruiser (`BossShip.png`) and compact burgundy/titanium assault ship (`Bosship2.png`). Both were generated with the built-in image generation tool from user-provided spacecraft references, then copied unchanged from the accepted review images. The subsequent cyan background-removal variant was not used.

Original generated images:
- Boss 1: `exec-a3f31796-eea0-4a50-bba0-8aa28b4056f3.png`
- Boss 2: `exec-c63738f8-112f-4531-9db1-70348d03dc8f.png`

Runtime AtlasTexture regions trim the surrounding transparent canvas. Boss 1 is 224 pixels wide; boss 2 is 320 pixels wide and approximately 319 pixels tall, preserving its compact aspect ratio and placing the bow at the existing shot origin. Boss 2's collision resource was rebaked from its new silhouette using the logic in `tools/bake_boss_collisions.gd`; its twin rear exhausts follow the new nozzles. Attack code, shot origins, timing, angles, damage, health and movement values are unchanged.

Validation: `boss_appearance_smoke.gd` and `boss2_pattern_smoke.gd` passed; rendered intact/damaged hulls inspected in `artifacts/review/boss-phases.png`.
