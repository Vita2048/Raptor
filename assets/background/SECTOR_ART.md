# Sector terrain assets

## Final riverbank and pipe correction

Built-in image_gen localized edit, assembled by `tools/repair_industrial_pipes.gd`. Final asset: `assets/background/industrial_riverworks.png`. Only the two shoreline/pipe zones are inserted; accepted rails, clarifier and silos are verified pixel-identical. Fortress is unchanged. Latest preview: `artifacts/seams/industrial-final-join.png` and `industrial-river-pipe-detail.png`. This supersedes the previous assertion that all central river columns remain unchanged.

Prompt:
Localized production game texture repair. Preserve this exact image composition, scale, colors, lighting and all structures except TWO small defective junctions at the middle. Coordinates refer to input 887x512: LEFT shoreline near x=285..390,y=235..285 has a sharp horizontal step/kink: replace with a gently continuous natural sloping riverbank and continuous white shoreline foam, flowing smoothly from above to below. RIGHT riverbank/pipes near x=520..650,y=225..310: reconnect every copper and steel pipeline across the horizontal join into continuous physically plausible pipes of consistent diameter with proper elbows/couplings; remove abrupt staggered cutoffs, doubled or mismatched segments. Smooth the right shoreline too. Keep corrected circular basin, silos and rails entirely unchanged. Keep bridge and all terrain outside these small areas unchanged. Same aspect ratio 887:512, no reframing, zoom, crop, added objects, blur or text. This is surgical correction of shoreline tangency and pipe topology, not regeneration of the map.

## Industrial geometry revision

The first seam repair left malformed rails, clarifier rims and silo roofs. A second built-in image_gen edit reconstructs those as complete objects. `tools/revise_industrial_seam.gd` applies the corrected outer sides only; columns 265 through 694 are verified pixel-identical to the preceding version. This revision can affect the outermost 231 rows at each end on those sides, superseding the earlier 159-row limit for the industrial texture. The fortress texture is unchanged by this revision.

Final asset: `assets/background/industrial_riverworks.png`. Close-up previews: `artifacts/seams/industrial-left-detail.png` and `industrial-right-detail.png`; complete join: `industrial-revision-after.png`.

Prompt:
Precise architectural correction of this top-down industrial game map strip. Preserve river, roads, bridge, coastline, lighting, color and exact layout. Fix malformed industrial objects around the horizontal middle: LEFT at x=145..225 y=185..295 the blue clarifier/centrifuge must be ONE geometrically perfect round tank with ONE continuous circular rim and ONE straight diagonal rotating arm through its center, no overlapping circles, no doubled lower rim or duplicate arm. Far LEFT clipped silos x=0..65 y=145..330: replace intersecting mismatched halves with TWO clearly separated complete circular tank roofs, consistent circular rims and cylindrical walls; no half circles glued together. Far RIGHT x=815..887 y=180..340: same coherent nonintersecting silo geometry. Rails at x=100 and x=780 through central y=160..340 must remain TWO continuous smoothly curving parallel rails with evenly spaced sleepers, not disconnected tracks or kinks, no branching or doubled ghost structures. You may simplify/remove surplus pipes next to these objects to make their geometry physically coherent. Keep top 90 and bottom 90 rows unchanged, same 887:512 aspect ratio, no crop, no shift, no zoom, no blur. Correct the actual shapes, not just the seam. Output detailed consistent game art.


## Cyclical seam repair

Both textures were repaired with the built-in image_gen tool using a 512-row reference strip made from the final 256 rows followed by the first 256 rows. The generated continuous scene was inserted across the wrap; only the outer 159 rows at each end can change, with a feathered transition into the original art. The central 1,454 rows remain pixel-identical. Dimensions and map coordinates are unchanged.

Final assets: `assets/background/industrial_riverworks.png` and `assets/background/command_fortress.png`.
Offline preparation and assembly: `tools/prepare_seams.gd`, `tools/apply_seams.gd`. Working strips, generated patches, originals and triple-stack previews are under `artifacts/seams/` (local verification artifacts). The runtime needs only the two final textures.

The shader now uses repeat filtering instead of mirrored edge blending. Vertical ripple and glint frequencies use whole cycles, so water animation is periodic too.

### Industrial repair prompt

Edit this game terrain seam strip. This image joins the bottom of a vertically looping industrial map (upper half) to its top (lower half). Repair ONLY the horizontal discontinuity at the exact middle y=256: connect all pipes, roads, tanks, retaining walls and river banks smoothly with natural coherent geometry. Repaint the central band y=145..365 to make one continuous overhead landscape. Preserve the outer top 100 rows and bottom 100 rows and all x positions as precisely as possible: these must rejoin the unedited map. Do not redesign, shift, zoom, crop or add landmarks. Match original texture detail, colors, lighting and orthographic perspective. No blur strip, no mirrored geometry, no crossfade ghosting. Same landscape aspect ratio and composition as input. This is a localized production texture repair, not a new scene.

### Fortress repair prompt

Edit this game terrain seam strip. Upper half is bottom of vertically looping fortress map, lower half is top. Repair ONLY horizontal discontinuity at middle y=256: connect fortress walls, service roads, cliff shapes and riverbanks as continuous natural structures. Repaint central band y=145..365. Preserve outer top 100 rows and bottom 100 rows and all x positions precisely so patch rejoins existing art. Preserve same landscape aspect, original composition, scale, sharpness, top-down orthographic perspective, lighting and color. No redesign, zoom, crop, text, new landmarks, mirrored terrain or blurry crossfade. Make the middle a single coherent overhead scene with no visible horizontal stitching line.


Created with the built-in image_gen tool using dessert_bridges.png as the edit
reference. Outputs: industrial_riverworks.png and command_fortress.png.
Both delivered assets are 887 x 1774, sampled in normalized UV coordinates over
the original 1024 x 2048 map footprint. No external asset dependency is required.

## Industrial prompt

Create a production game terrain texture, a new INDUSTRIAL RIVERWORKS sector variant of the reference top-down vertically scrolling shooter map. Output portrait 1024x2048. Strict orthographic directly overhead, realistic painted detailed game terrain, no aircraft, HUD, text or vehicles. Preserve exactly the reference river shoreline topology, bridges at y=252 and y=772 in 1024x2048 coordinates, roads along both sides, and top/bottom edge terrain for seamless wrapping. Transform the banks into a weathered industrial valley: concrete retaining walls along water, pipe networks, pumping stations, cooling basins, rail sidings, rusted industrial machinery and refinery tanks on the far outer banks. Prominent industrial spillway landmark integrated into first bridge, crane loading yard along outer left bank. Muted ochre concrete, steel and blue-green water, coherent upper-left lighting. Keep these ground-object spawn rectangles EMPTY flat concrete yards free of buildings: (166,94,124,254), (729,153,111,197), (208,636,103,218), (726,683,110,163), (160,1132,129,228), (722,1178,110,204), (209,1784,115,96), (702,1832,111,93). Preserve roads near x=910 y=35..380 and x=140 y=1120..1430. Keep all major architecture out of these reserved yards. Fill canvas edge to edge; no border.

## Fortress prompt

Create a production game terrain texture: FORTIFIED COMMAND BASE sector of this reference top-down scrolling shooter map. Portrait 1024x2048, strictly directly overhead orthographic, detailed realistic painted game art, no HUD, text, aircraft or vehicles. Preserve exact river shoreline topology, bridge road centerlines y=252 and y=772 in reference coordinates, side roads and top/bottom boundary continuity. Convert banks into a monumental militarized canyon fortress: reinforced dark concrete embankments, blast walls along far outer edges, recessed bunkers carved in cliffs, cable conduits, landing aprons and a distinctive large hexagonal command citadel on far left margin centered near x=75,y=1550; radar installation on far right margin near x=945,y=1600. Existing bridges become armored security bridges. Cool slate stone, dusty concrete, blue water, restrained amber facility lighting, upper-left sunlight consistent with reference. Keep eight spawn yards EMPTY and level with ground: rectangles (166,94,124,254), (729,153,111,197), (208,636,103,218), (726,683,110,163), (160,1132,129,228), (722,1178,110,204), (209,1784,115,96), (702,1832,111,93). Keep roads clear near x=910 y=35..380 and x=140 y=1120..1430. Major fortress landmarks must remain outside these reserved yards. Preserve water, road and bridge locations accurately. Edge to edge texture, no border.
