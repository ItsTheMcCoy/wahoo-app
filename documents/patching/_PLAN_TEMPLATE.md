# Patch Plan: <ITEM TITLE>

> Template for all plan files in `documents/patching/`. Every item plan must contain
> every section below. Replace `<...>` placeholders; keep the standing sections
> (branch, doc check, Godot location, re-export) verbatim unless the item requires
> deviating, and say so explicitly if it does.

## Item

<One-paragraph description of the fix or enhancement this plan addresses.>

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

Before implementing, search the `documents/` folder to see whether this item is
already covered by an existing document (for example `RULES.md`,
`DEVELOPMENT_PLAN.md`, `ASSET_DESIGN_GUIDE.md`, `AI_Strategy_Spec.md`, or any
plan/spec file). Use content search (e.g. Grep) across `documents/**/*.md` for
keywords related to this item.

- If an existing document covers this item, read it and treat it as the
  authoritative spec while implementing (`documents/RULES.md` always wins over
  code on rules questions).
- After your changes are complete, if that document no longer matches the actual
  behavior of the game, UPDATE the document so it aligns with the current state
  of the game post-change.
- If no document covers the item, no doc update is required (but note that in
  your final report).

## Implementation Plan

<Numbered, step-by-step instructions detailed enough for another AI agent to
execute without additional context. Reference exact files and functions. Include
acceptance criteria.>

1. <step>
2. <step>
3. <step>

### Verification

- Run the Python test suite where relevant: `python -m pytest tests/`
  - Known pre-existing baseline (July 2026): ~20 failures caused by the committed
    `wahoo/profiles_manager.json` replacing builtin profile names. Do not chase
    those; only ensure your change introduces no NEW failures.
- For Godot changes, run the parity smoke tests headless:
  `& "C:\Users\pc\OneDrive\Documents\Godot4\Godot_v4.6.3-stable_win64_console.exe" --headless --path godot --script scripts/run_smoke.gd`

## Godot Executable Location

The Godot .exe lives in:

```
C:\Users\pc\OneDrive\Documents\Godot4
```

Specifically:

- `C:\Users\pc\OneDrive\Documents\Godot4\Godot_v4.6.3-stable_win64.exe` — editor/GUI
- `C:\Users\pc\OneDrive\Documents\Godot4\Godot_v4.6.3-stable_win64_console.exe` — use this one for headless/CLI work (prints output to the console)

## Re-Exporting the HTML (Web Build)

**When:** Re-export whenever this item changes anything that affects the web
build — anything under `godot/` (scenes, GDScript, assets, `project.godot`,
`export_presets.cfg`, `custom_html_shell.html`). Pure-Python or docs-only
changes do not need a re-export.

**You must re-export BEFORE committing and pushing your changes to
`patch/fixes-and-enhancements`,** so the committed `godot/build/web/` output
always matches the committed source.

**How** (from the repo root `g:\My Drive\AI_Projects\Wahoo-app\wahoo-app`):

```powershell
& "C:\Users\pc\OneDrive\Documents\Godot4\Godot_v4.6.3-stable_win64_console.exe" --headless --path godot --export-release "Web" "build/web/index.html"
```

Notes:

- The export preset is named `Web` and already points at
  `build/web/index.html` with the branded custom shell
  (`godot/custom_html_shell.html`) — do not rename the preset or change its path.
- `godot/build/web/` also contains hand-placed branded assets
  (`og_preview.png`, `wahulo_wordmark.svg`, `background_felt_tile_512.svg`,
  `index.png`, favicons). The export overwrites the engine files but these
  extras must remain — never delete the folder before exporting.

## Commit and Push

After verification passes and (if applicable) the HTML re-export is done:

```
git add <changed files, including godot/build/web if re-exported>
git commit -m "<concise description of this item's change>"
git push -u origin patch/fixes-and-enhancements
```
