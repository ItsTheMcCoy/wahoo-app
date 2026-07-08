# Patch Plan — Item 3: Enter-name prompt buttons — text too large, no horizontal padding

## Item

In the HOST GAME enter-name screen (the "host prompt" dialog on the home
screen), the text inside the two buttons (Cancel / Create Room) is too large:
"Create Room" currently has no padding on either horizontal side — the text
touches the button edges. Reduce the text size and give it breathing room.

## Root Cause (already diagnosed — verify, then fix)

`godot/scripts/home_screen.gd`:

- In `_apply_theme()` (~lines 485–540) the shared button styleboxes
  (`btn_normal` / `btn_hover` / `btn_pressed` / `btn_disabled`) define borders
  and corner radii but **no `content_margin_left/right`**, so button text can
  run edge-to-edge.
- The same function sets `font_size` 26 on ALL buttons (~line 540), and the
  desktop branch of `_apply_responsive_layout()` (~line 231) re-applies
  `font_size` 26 to the five prompt buttons (`_host_cancel_btn`,
  `_host_create_btn`, `_join_cancel_btn`, `_join_player_btn`,
  `_join_spectator_btn`). At font 26, "Create Room" fills its share of the
  ~320 px prompt row completely.
- Note `_reset_prompt_labels()` also sets `_host_create_btn.text` to
  "Create Room" / "Connecting..." / "Creating room..." during the connect flow
  — the longest string must also fit.

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

Search `documents/**/*.md` (Grep) for keywords like `host prompt`, `Create
Room`, `home screen`, `button`. Likely candidates:

- `documents/MULTIPLAYER_PLAN.md` — describes the host/join entry flow.
- `documents/ASSET_DESIGN_GUIDE.md` — typography/spacing rules; follow any
  button padding or font-scale guidance it defines.

If a document covers this area, treat it as the spec while implementing, and
after the change UPDATE it if it no longer aligns with the current state of the
game. If nothing covers it, note that in your final report.

## Implementation Plan

1. `git switch patch/fixes-and-enhancements`.
2. In `home_screen.gd` `_apply_theme()`, add horizontal (and modest vertical)
   content margins to the shared button stylebox so no button text can touch
   the border:
   ```gdscript
   btn_normal.content_margin_left = 18.0 * ui_scale
   btn_normal.content_margin_right = 18.0 * ui_scale
   btn_normal.content_margin_top = 8.0 * ui_scale
   btn_normal.content_margin_bottom = 8.0 * ui_scale
   ```
   (The hover/pressed/disabled boxes are `duplicate()`d from `btn_normal`, so
   add the margins BEFORE the duplicates are made.)
3. Reduce the prompt-button font size:
   - Desktop branch of `_apply_responsive_layout()` (~line 229–231): change the
     prompt buttons' `font_size` override from 26 to **20**.
   - Mobile branch (~line 218–220) currently uses `22 * ui_scale`; reduce to
     **20 * ui_scale** so both branches match.
   - The base `font_size 26` in `_apply_theme()` (~line 540) applies to the
     main menu buttons too (PLAY SOLO / HOST GAME / JOIN); do NOT change those —
     only ensure the responsive prompt-button overrides (which run after and
     win) use the new size.
4. Verify the prompt buttons still meet the 56 px minimum height and that
   "Create Room", "Creating room...", "Connecting...", "Join", "Watch", and
   "Cancel" all fit with visible padding at:
   - Desktop (~1280×720 window): buttons side-by-side.
   - Compact/mobile portrait (~390×844): buttons stacked vertically
     (`_host_buttons.vertical = true` path).
5. The join prompt shares the same styleboxes and button lists, so it is fixed
   by the same change — verify it too ("Join" / "Watch" / "Cancel").

### Acceptance Criteria

- At every breakpoint, prompt-button label text has ≥ ~16 px of clear space on
  each side and never touches the border.
- No text is clipped or ellipsized during the "Connecting..." states.

### Verification

- Headless smoke tests still pass:
  ```powershell
  & "C:\Users\pc\OneDrive\Documents\Godot4\Godot_v4.6.3-stable_win64_console.exe" --headless --path godot --script scripts/run_smoke.gd
  ```
- Run the game, click HOST GAME, inspect the prompt at desktop and narrow
  window sizes; repeat for JOIN.

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
git add godot/scripts/home_screen.gd godot/build/web <other changed files>
git commit -m "Add padding and reduce font size on enter-name prompt buttons"
git push -u origin patch/fixes-and-enhancements
```
