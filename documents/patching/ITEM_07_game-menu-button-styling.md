# Patch Plan — Item 7: In-game Menu button — move closer to the wordmark and style as a real button

## Item

Inside an active game, the "Menu" control in the sidebar (a) needs to sit
closer to the WAHULO wordmark above it, and (b) currently looks like plain
floating text — it must look like an interactive element (bordered/filled
button consistent with the rest of the UI).

## Current Implementation (read before changing)

- `godot/scenes/Main.tscn`: `Root/SidePanel` (VBoxContainer,
  `separation = 10`) children in order: `GameTitle` (TextureRect, wordmark PNG,
  `custom_minimum_size = (326, 138)`, `stretch_mode = 5` keep-aspect-centered)
  → `GameMenuButton` (**MenuButton**, min height 52, `text = "Menu"`,
  font 26) → `Spacer` → `Status` → `DieFrame` → …
- **Why it looks like floating text:** `MenuButton` inherits from Button but
  ships with a FLAT default theme (no background stylebox), and `main.gd` never
  applies the game's brown/bordered button styleboxes to it — only the popup's
  font colors are themed (`main.gd` ~lines 378–382). Every other sidebar button
  (Roll, End Turn) gets the full stylebox treatment.
- **Why the gap:** the wordmark texture aspect is 1400:520 (≈2.69). At 326 px
  wide the drawn image is only ≈121 px tall, but `GameTitle` reserves 138 px,
  so keep-aspect-centered letterboxes ≈8 px of dead space above AND below the
  image, plus the VBox `separation = 10` — the menu button ends up ~18 px
  below the visible wordmark. Responsive code also resizes these nodes
  (`main.gd` ~lines 655–666), so fix sizing there too, not just in the .tscn.

## Implementation Plan

1. `git switch patch/fixes-and-enhancements`.
2. **Close the gap:**
   - In `Main.tscn`, set `GameTitle.custom_minimum_size` height to match the
     wordmark aspect at its width (326 / (1400/520) ≈ 121), eliminating the
     letterboxing.
   - In `main.gd`'s responsive layout (~lines 655–666 region), find where
     `GameTitle` / `_game_title` sizing is computed (search `GameTitle` and
     `_game_title` in the file) and derive the height from the width using the
     same 1400:520 ratio (mirror `home_screen.gd`'s
     `WORDMARK_ASPECT_RATIO` approach) so no letterbox gap appears at any
     breakpoint.
   - Keep the VBox `separation` (10) as the intentional visual gap.
3. **Make it look interactive:**
   - In `main.gd`'s theme setup (where `die_style` and the Roll/End Turn
     button styleboxes are built, ~lines 288–380), apply the SAME
     normal/hover/pressed/disabled styleboxes and font colors used for the
     Roll/End Turn buttons to `_game_menu_button`. `MenuButton` accepts the
     same `add_theme_stylebox_override("normal"/"hover"/"pressed"/"disabled")`
     overrides as Button. Reuse the existing stylebox construction — extract a
     helper like lobby.gd's `_apply_button_theme()` if main.gd builds them
     inline, rather than duplicating stylebox code.
   - Add a dropdown affordance so it reads as a menu: set
     `text = "Menu ▾"` ONLY if the `▾` glyph renders in the web build
     (beware the tofu-box issue from Item 2 — U+25BE may not be in the font).
     Safer: draw/reuse a small chevron SVG icon
     (`godot/assets/textures/back_chevron.svg` exists; a down-chevron variant
     `menu_chevron_down.svg` can be created the same way, paths only) and set
     `_game_menu_button.icon` with `icon_alignment = HORIZONTAL_ALIGNMENT_RIGHT`.
   - Confirm hover/pressed feedback is visible when interacting.
4. Check the compact/mobile layout branch (`_compact_layout` paths in
   `main.gd`, e.g. ~line 657) so the restyled button and tightened wordmark
   spacing hold up in portrait phone layout — the side panel is rearranged
   there; verify the menu button stays adjacent to the wordmark (or, if the
   compact layout intentionally relocates it, keep that layout but with the
   new interactive styling).

### Acceptance Criteria

- The menu control visually matches the game's button language (brown fill,
  tan border, rounded corners, hover/pressed states) — clearly clickable.
- Vertical dead space between the visible wordmark image and the menu button
  is just the panel separation (~10 px), at desktop, short-landscape, and
  mobile-portrait breakpoints.
- The popup menu still opens with all items (How to Play, Save/Load, Restart,
  Exit To Setup / Leave Match, Quit App) and multiplayer-mode item filtering
  still works (`_setup_game_menu`, ~line 1210).

### Verification

- Headless smoke tests still pass:
  ```powershell
  & "C:\Users\pc\OneDrive\Documents\Godot4\Godot_v4.6.3-stable_win64_console.exe" --headless --path godot --script scripts/run_smoke.gd
  ```
- Start a solo game; exercise every menu item (Save, Load, Restart, Exit To
  Setup, How to Play) and confirm behavior is unchanged. Resize the window
  through desktop → narrow portrait and confirm layout.

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

Search `documents/**/*.md` (Grep) for `menu`, `sidebar`, `side panel`,
`button`. Likely candidates:

- `documents/ASSET_DESIGN_GUIDE.md` — button styling rules; follow them, and
  UPDATE the guide if the menu button treatment adds anything new (e.g., the
  chevron icon asset).
- `documents/GRAPHICS_UPGRADE_PLAN.md` — sidebar/UI polish roadmap.

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
git add godot/scenes/Main.tscn godot/scripts/main.gd godot/assets/textures <godot/build/web and other changed files>
git commit -m "Style in-game menu as a real button and tighten spacing under wordmark"
git push -u origin patch/fixes-and-enhancements
```
