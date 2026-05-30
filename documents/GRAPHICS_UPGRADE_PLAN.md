# Graphics Upgrade Plan

This document defines the practical path to move Wahoo from a clean prototype look to a more realistic tabletop presentation while keeping gameplay code unchanged.

## Best Upgrade Path

1. Board Surface Pass (highest impact)
- Add a layered board surface style (base tone, grain lines, vignette, inner panel, stronger border).
- Keep all existing board coordinates and hit-testing unchanged.
- Goal: remove flat-color look immediately.

2. Piece Rendering Pass
- Upgrade marbles from flat circles to layered shading with shadow, specular highlight, and subtle rim lighting.
- Preserve current marble animation timing and interaction behavior.
- Goal: marbles read as physical objects instead of icons.

3. Track and Cell Depth Pass
- Add ring/cavity depth cues to track cells and home/base spots.
- Add two-tone lane strokes for visual depth and readability.
- Goal: board geometry feels machined/printed rather than flat.

4. UI Skin Pass
- Add matching panel/button styling on the right info panel (warm board-matching palette, stronger contrast).
- Keep layout and game flow unchanged.
- Goal: visual consistency between board and HUD.

5. Optional Asset Upgrade Pass
- Replace procedural layers with hand-painted textures or photo-derived textures once style is approved.
- Use compressed atlases suitable for HTML5/mobile export.

## Concrete Technical Change

1. Rendering system changes in `godot/scripts/wahoo_board_view.gd`
- Replace single flat board rectangle with layered board draw helpers.
- Add procedural wood-grain-like line overlays and vignette for depth.
- Upgrade `_draw_track_path`, `_draw_grid_spot`, `_draw_center`, and `MarbleToken._draw` to multi-layer shading.
- Keep `WahooLayout` mapping and all move-selection geometry unchanged.

2. UI theme changes in `godot/scripts/main.gd`
- Add a runtime UI skin function that applies panel/button colors and mild outline/shadow to key labels.
- Target existing scene nodes only; no scene hierarchy change required.

3. Scene compatibility
- No changes required to rules logic in `godot/scripts/wahoo_rules.gd` or state in `godot/scripts/wahoo_state.gd`.
- No protocol or save/load schema change required.

4. Performance constraints (Web/mobile)
- Prefer simple layered draw calls over expensive fragment shaders for first pass.
- Keep line counts and circle detail moderate to avoid frame drops on HTML5 export.

## Recommended Visual Style

Style Name: Warm Tabletop Realism

1. Board
- Warm walnut / oak-inspired base colors.
- Subtle grain, darker edge framing, soft center illumination.

2. Pieces
- Glossy painted marbles with visible highlight and shadow.
- Slightly darker lower hemisphere to suggest volume.

3. Track and Slots
- Printed lane look with soft cavity rings.
- Home and base areas tinted per player with muted saturation.

4. UI
- Parchment/wood-adjacent panel tones to match board.
- Strong text contrast and restrained accent colors.

5. Motion
- Keep current cinematic move timing.
- Preserve impact pulse and improve perceived weight via shading.

## First-Pass Scope (implemented)

1. Layered board surface rendering.
2. Enhanced track/cell depth cues.
3. Upgraded marble shading.
4. Right-side panel color/theme polish.

## Second-Pass Scope (implemented)

1. External texture asset pipeline added via SVG board/marble materials in `godot/assets/textures/`.
2. Richer board material details: fine grain overlays, edge tone, and broad wood streak variation.
3. Ambient depth pass in board renderer (track/home/base/center AO-style shading).
4. Stronger lane depth via shadow underlay beneath the path polyline.
5. Typography/readability pass for side panel labels and die/status text.

## Out of Scope After Second Pass

1. Full lighting/shader graph system.
2. Particle systems or advanced post-processing.
3. Hand-painted or photo-derived final production texture set.
