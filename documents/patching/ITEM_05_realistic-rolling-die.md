# Patch Plan — Item 5: Display the roll as a realistic rolling die instead of a number

## Item

The die roll currently displays as a plain number that flickers through random
values and does a scale "pop". Replace it with a realistic-looking die: a
rounded-square die face with pips (dots) that visibly tumbles while rolling and
settles on the final face.

## Current Implementation (read before changing)

- `godot/scenes/Main.tscn`: `DieFrame` (PanelContainer, 152×152) containing
  `DieLabel` (Label, font size 96, text "–").
- `godot/scripts/main.gd`:
  - `_die_face(value)` (~line 1341) — returns `str(value)`.
  - `_play_roll_visual(final_roll)` (~line 1344) — 14 iterations of random
    number text at 0.04 s, then a scale-pop tween. `await`ed from
    `_on_roll_pressed` flow (~line 907), the AI turn coroutine (~line 1001),
    and (check) the multiplayer roll-result handler — find ALL call sites and
    `_die_label` references (`~lines 44, 124, 374–376, 664–666, 865–877`).
  - Die frame styling: `die_style` stylebox (~lines 288–297).
  - Responsive sizing (~lines 664–666) sets `DieFrame`/`DieLabel` minimum size
    and font per breakpoint.

## Design (recommended approach: custom-drawn 2D die, no 3D)

A physically simulated 3D die (SubViewport + RigidBody) is overkill for a
152 px side-panel widget and heavy for the web build. Instead build a polished
2D die that reads as a real die:

1. **New script `godot/scripts/die_view.gd`** (`extends Control`), drawing in
   `_draw()`:
   - Rounded-square body (`draw_style_box` with a StyleBoxFlat, or
     `draw_rect` + corner logic) in ivory/bone white (`#f2ead8`-ish, per the
     game's warm palette) with a subtle darker lower-edge shade and a soft
     drop shadow, echoing the marble rendering conventions in
     `wahoo_board_view.gd` (`_draw_grid_spot`, marble gloss circles).
   - Pips for faces 1–6 drawn with `draw_circle` in the standard die layout
     (a small `PIP_LAYOUTS` dict of normalized offsets per face). Dark
     brown/near-black pips with a tiny highlight circle each.
   - Exported/state vars: `face: int`, plus a `tilt` (rotation degrees) and
     `squash` used during animation.
2. **Rolling animation** (public coroutine `func play_roll(final_face: int)`):
   - ~0.7–0.9 s total, keeping the game's current pacing.
   - Phase 1 "tumble": every 0.05–0.07 s swap to a random face while tweening
     `rotation` through a few ±15–25° wobbles and `scale` 0.92–1.08 (gives the
     thrown-die feel). Slow the face-swap interval toward the end
     (ease-out) so the die visibly "settles".
   - Phase 2 "land": snap rotation to 0 with `Tween.TRANS_BACK`/`EASE_OUT`
     overshoot and a final scale pop like the existing tween.
   - Keep it deterministic in outcome: the visual must ALWAYS end on
     `final_face`. The roll value itself is still produced by the existing
     RNG/server — this is presentation only.
3. **Integration in `main.gd` / `Main.tscn`:**
   - Replace `DieLabel` with a `DieView` control inside `DieFrame` (keep
     `DieFrame` and its stylebox as the recessed "tray" the die sits in, or
     restyle it as a felt tray).
   - Rewrite `_play_roll_visual(final_roll)` to `await _die_view.play_roll(final_roll)`
     so every existing call site keeps working unchanged (solo human, AI turns,
     multiplayer). Do not change its signature.
   - Replace the idle placeholder (`_die_label.text = "–"` at ~lines 124/875)
     with an idle die state (e.g., dimmed die showing the last face, or an
     empty tray).
   - Port the responsive sizing (~lines 664–666): size the DieView square to
     the current `DieFrame` minimum sizes; drawing scales with the control
     size, so no font sizing is needed.
4. Sound is out of scope unless a dice-roll SFX asset already exists in the
   repo (search `godot/assets` for audio; if none, skip).

### Acceptance Criteria

- Rolling shows a die with pips tumbling (rotation + face cycling) and
  settling on the rolled value; no numerals anywhere in the die area.
- Total animation duration stays within ~1 s so turn pacing is unchanged.
- Works identically for human rolls, AI rolls, and multiplayer rolls (all
  paths flow through `_play_roll_visual`).
- Scales cleanly at compact/mobile (112 px) and desktop (126–152 px) sizes.

### Verification

- Headless smoke tests still pass:
  ```powershell
  & "C:\Users\pc\OneDrive\Documents\Godot4\Godot_v4.6.3-stable_win64_console.exe" --headless --path godot --script scripts/run_smoke.gd
  ```
- Play a solo game against AI: human roll, AI rolls, a full game reaching a
  "no legal moves" turn and a 6-reroll — die always matches the number reported
  in the status log line ("X rolled N").
- If feasible, start a multiplayer game and confirm the server-driven roll
  animates too.

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

Search `documents/**/*.md` (Grep) for `die`, `dice`, `roll`, `animation`.
Likely candidates:

- `documents/GRAPHICS_UPGRADE_PLAN.md` — may already plan a die visual; if so,
  follow/extend its spec rather than inventing a new one.
- `documents/ASSET_DESIGN_GUIDE.md` — palette and rendering conventions the
  die must match; UPDATE it afterward to document the new die widget.
- `documents/HOW_TO_PLAY.md` — if it references "the number shown", update
  wording after the change.

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
git add godot/scripts/die_view.gd godot/scripts/main.gd godot/scenes/Main.tscn godot/build/web <other changed files>
git commit -m "Replace numeric die readout with animated pip-face rolling die"
git push -u origin patch/fixes-and-enhancements
```
