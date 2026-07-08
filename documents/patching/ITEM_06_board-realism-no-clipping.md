# Patch Plan — Item 6: More realistic board; no elements may clip the marble-track circles

## Item

Make the board look more realistic, and specifically ensure that no drawn
elements visually clip/overlap the circles of the marble track (the 56 track
spots, plus home-row, base, and center spots).

## Current Implementation (read before changing)

All board rendering is immediate-mode drawing in
`godot/scripts/wahoo_board_view.gd`. Draw order in `_draw()` (~line 271):

```
_draw_board_surface()          # wood bg, texture, grain lines, inner rect, bevel, edge, vignette bands
_draw_ambient_occlusion()      # soft dark circles under every spot
_draw_player_areas()           # base cluster spots
_draw_current_player_focus()   # colored rings around current player's base spots
_draw_home_rows()              # home spots
_draw_track_cells()            # the 56 track spots
_draw_center()                 # center hole
_draw_impact_pulse()           # capture pulse ring
_draw_legal_destinations()     # move highlights
_draw_seat_labels()            # player name labels (drawn LAST, on top)
```

Elements that can visually intersect the spot circles (audit each):

1. **Vignette bands** (`_draw_board_surface`, ~lines 313–321): four filled
   rects inset `_cell_size * 0.82` from the board edge. They are drawn under
   the spots, but their hard rectangular edges can cross the outer ring of
   track circles — a straight edge cutting across a circle's ambient-occlusion
   halo reads as "clipping".
2. **Inner background rect + bevel** (~lines 302–311): `inner` is inset
   `_cell_size * 0.48`, and the bevel outline at `inner.grow(_cell_size*0.08)`
   is a stroked rectangle whose line may pass through/beside outer spots.
3. **Wood grain lines** (~lines 292–300): drawn across the full board; under
   the spots but over nothing else — verify they don't render over any spot
   (they shouldn't, given draw order, but the translucent AO halos let them
   show right at circle edges).
4. **Seat labels** (`_draw_seat_labels`, ~line 501): drawn last, on top of
   everything — check they never overlap base/track circles at any window size.
5. **Impact pulse & legal-destination rings**: transient overlays; expanding
   ring may be fine to cross spots (it's feedback, not board furniture) — leave
   unless it looks wrong.

`BOARD_EDGE_PADDING_UNITS` and `_compute_cell_size` (~lines 376–388) control
how much margin exists between the outermost spots and the board edge.

## Implementation Plan

1. `git switch patch/fixes-and-enhancements`.
2. **Capture a baseline screenshot** first (run the game, F12/print-screen or
   use `get_viewport().get_texture().get_image().save_png()` from a debug
   hook) so before/after can be compared.
3. **Eliminate clipping geometrically** (deterministic, not eyeballed):
   - Write a helper that computes the minimum clearance between the outermost
     spot circles (including their AO halo radius, `_position_spot_radius() *
     1.20 * 1.24` worst case) and each static rectangle edge (vignette inset,
     inner rect, bevel outline).
   - Adjust the offending insets so every edge keeps a clearance of at least
     `0.25 * _cell_size` from every circle: either pull the vignette inset
     outward (reduce `vignette_inset` toward the true edge), increase
     `BOARD_EDGE_PADDING_UNITS` so the ring of spots sits further from the
     edge, or both. Prefer increasing padding slightly + shrinking the
     vignette, so the felt/wood border reads as a real board frame.
   - Move seat labels into the reserved margin space (between board edge and
     outermost circles, or outside the inner rect), and verify at multiple
     aspect ratios: labels must never touch a circle.
4. **Realism upgrades** (do all that fit the budget of this item, guided by
   `documents/ASSET_DESIGN_GUIDE.md` and `documents/GRAPHICS_UPGRADE_PLAN.md`):
   - Replace the hard-edged vignette rects with a softly graded vignette:
     several concentric `draw_rect` outlines with decreasing alpha, or a
     radial-ish falloff via layered translucent rects — no visible hard edge.
   - Make the track spots read as drilled holes: keep the existing
     cavity + fill + highlight trio in `_draw_grid_spot`, but add an inner
     rim shadow (thin darker arc at the top-inside of each hole) so holes
     look recessed into the wood.
   - Soften the bevel: two offset strokes (light top-left, dark bottom-right)
     instead of a single uniform outline, simulating routed wood.
   - Keep the wood grain, but clamp grain line endpoints to the region outside
     spot halos OR reduce grain alpha under the play area so it never argues
     with the circles.
5. Keep ALL colors within the existing palette constants (`BOARD_BG`,
   `BOARD_BG_INNER`, `TRACK_CELL`, etc.) or derive from them — do not invent a
   new palette. Do not change any gameplay geometry (`WahooLayout` grid
   coords), hit-testing, or `wahoo_rules`/`wahoo_state` code.

### Acceptance Criteria

- No straight edge, band, grain line, or label intersects any track/home/base/
  center circle (including its occlusion halo) at 16:9 desktop, ~4:3, and
  mobile portrait sizes.
- The board reads as a wooden game board with recessed holes; before/after
  screenshots show a clear improvement.
- Marble rendering, move highlighting, capture pulse, and input hit areas are
  unchanged and functional.

### Verification

- Board-view smoke tests still pass (this file exists:
  `godot/scripts/wahoo_board_view_smoke.gd`):
  ```powershell
  & "C:\Users\pc\OneDrive\Documents\Godot4\Godot_v4.6.3-stable_win64_console.exe" --headless --path godot --script scripts/run_smoke.gd
  ```
- Play a full solo game vs AI: select marbles, capture, enter center, enter
  home — all interactions render correctly at three window sizes.

## Branch — Work Here, Not on Main

All changes for this item MUST be implemented on the branch:

```
patch/fixes-and-enhancements
```

Before starting work:

```
git switch patch/fixes-and-enhancements
git pull   # if the branch has an upstream; otherwise skip
```

Do NOT commit to `main`. This branch collects a group of fixes and enhancements
for testing together before anything is merged to `main`.

## Step 0 — Check Existing Documentation First

Search `documents/**/*.md` (Grep) for `board`, `wood`, `vignette`, `grain`,
`realism`, `clip`. Likely candidates:

- `documents/GRAPHICS_UPGRADE_PLAN.md` — the board's visual roadmap; if it
  specifies board-surface treatments, follow it, and UPDATE it afterward to
  reflect what was actually implemented.
- `documents/ASSET_DESIGN_GUIDE.md` — authoritative palette/design system;
  UPDATE its board-rendering section after the change so it matches the new
  drawing pipeline.

If a document covers this area, treat it as the spec while implementing, and
after the change UPDATE it if it no longer aligns with the current state of
the game. If nothing covers it, note that in your final report.

## Godot Executable Location

The Godot .exe lives in:

```
C:\Users\pc\OneDrive\Documents\Godot4
```

- `Godot_v4.6.3-stable_win64.exe` — editor/GUI
- `Godot_v4.6.3-stable_win64_console.exe` — use for headless/CLI work

## Re-Exporting the HTML (Web Build)

This item changes files under `godot/`, so a re-export IS required.

**You must re-export BEFORE committing and pushing** so the committed
`godot/build/web/` output matches the committed source. From the repo root:

```powershell
& "C:\Users\pc\OneDrive\Documents\Godot4\Godot_v4.6.3-stable_win64_console.exe" --headless --path godot --export-release "Web" "build/web/index.html"
```

Notes:

- The export preset is named `Web` and already points at `build/web/index.html`
  with the branded custom shell. Do not rename the preset or change its path.
- `godot/build/web/` contains hand-placed branded assets that must remain —
  never delete the folder before exporting.

## Commit and Push

After verification passes and the re-export is done:

```
git add godot/scripts/wahoo_board_view.gd godot/build/web <other changed files>
git commit -m "Improve board realism; keep all surface elements clear of track circles"
git push -u origin patch/fixes-and-enhancements
```
