# Patch Plan — Item 1: Lobby (HOST GAME setup screen) wordmark is missing the "WAHULO" text

## Item

In the HOST GAME setup screen (the multiplayer lobby, `godot/scenes/Lobby.tscn`),
the brand wordmark shows the marbles and the curved underline but NOT the
"WAHULO" text.

## Root Cause (already diagnosed — verify, then fix)

`godot/scripts/lobby.gd` line 5 preloads the **SVG** wordmark:

```gdscript
const WORDMARK_TEXTURE = preload("res://assets/textures/wahulo_wordmark.svg")
```

`godot/assets/textures/wahulo_wordmark.svg` renders its "WAHULO" lettering with
SVG `<text>` elements (see lines ~71–77 of the SVG). Godot's SVG importer
(ThorVG) does **not** render `<text>` elements — it only rasterizes vector
shapes. So in-engine the marbles and curved line (paths/circles) appear but the
text does not. Browsers render the same SVG fine, which is why the HTML loading
screen looks correct.

The home screen already does this right: `godot/scripts/home_screen.gd` line 3
preloads `res://assets/textures/wahulo_wordmark.png` (the 1400×520 PNG version),
and `godot/scenes/Main.tscn` also uses the PNG. Only the lobby uses the SVG.

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

Search the `documents/` folder for existing coverage of this item before
implementing. Most likely candidates:

- `documents/ASSET_DESIGN_GUIDE.md` — the visual design system; check what it
  says about wordmark usage (SVG vs PNG) inside Godot scenes.
- `documents/MULTIPLAYER_PLAN.md` — describes the lobby screen.
- `documents/GRAPHICS_UPGRADE_PLAN.md`

Use Grep across `documents/**/*.md` for keywords like `wordmark`, `SVG`,
`lobby`, `brand`. If a document covers this area, treat it as the spec while
implementing. After your change, if the document no longer matches the actual
behavior of the game, UPDATE it to align with the current state (e.g., add a
note that in-engine scenes must use `wahulo_wordmark.png` because Godot cannot
rasterize SVG `<text>`). If no document covers it, note that in your final
report.

## Implementation Plan

1. `git switch patch/fixes-and-enhancements`.
2. In `godot/scripts/lobby.gd`, change line 5:
   ```gdscript
   const WORDMARK_TEXTURE = preload("res://assets/textures/wahulo_wordmark.png")
   ```
3. Sweep for other in-engine users of the SVG so this bug cannot recur:
   run Grep for `wahulo_wordmark.svg` across `godot/scenes/**` and
   `godot/scripts/**`. Replace any scene/script texture reference with the PNG.
   Do NOT touch `godot/build/web/wahulo_wordmark.svg` or
   `godot/custom_html_shell.html` / `godot/build/web/index.html` — the HTML
   loading screen renders the SVG in the browser, where `<text>` works, and it
   must keep using the SVG.
4. The lobby sizes the wordmark via `_brand_title.custom_minimum_size`
   (`lobby.gd`, `_apply_responsive_layout`, height 150/195) with
   `STRETCH_KEEP_ASPECT_CENTERED`, so the PNG (aspect 1400:520) will letterbox
   the same way the SVG did — no layout change should be needed. Confirm
   visually that the wordmark is not distorted or cropped at both compact and
   desktop widths.

### Verification

- Run the Godot parity smoke tests headless (should be unaffected, quick
  regression check):
  ```powershell
  & "C:\Users\pc\OneDrive\Documents\Godot4\Godot_v4.6.3-stable_win64_console.exe" --headless --path godot --script scripts/run_smoke.gd
  ```
- Launch the game locally (run the editor exe with `--path godot`, or serve the
  re-exported web build), click HOST GAME, enter a name, create a room, and
  confirm the lobby wordmark now shows marbles, curved line, AND the "WAHULO"
  text. Check both a wide desktop window and a narrow (~400 px) window.
- Python tests are unaffected by this change; if you run
  `python -m pytest tests/`, note the pre-existing baseline of ~20 failures
  caused by `wahoo/profiles_manager.json` (managed profile names) — do not
  chase those; only ensure no NEW failures.

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
  with the branded custom shell (`godot/custom_html_shell.html`). Do not rename
  the preset or change its path.
- `godot/build/web/` also contains hand-placed branded assets (`og_preview.png`,
  `wahulo_wordmark.svg`, `background_felt_tile_512.svg`, `index.png`, favicons).
  The export overwrites engine files but these extras must remain — never
  delete the folder before exporting.

## Commit and Push

After verification passes and the re-export is done:

```
git add godot/scripts/lobby.gd godot/build/web <any other changed files>
git commit -m "Use PNG wordmark in lobby so WAHULO text renders in-engine"
git push -u origin patch/fixes-and-enhancements
```
