# Godot Bootstrap (Phase 2a)

This folder contains the initial Godot 4 project scaffold for Phase 2a in `documents/DEVELOPMENT_PLAN.md`.

## Current scope

- Minimal project file and icon
- Minimal main scene with a Roll button and status text
- GDScript state model scaffold (`wahoo_state.gd`)
- Rules interface scaffold (`wahoo_rules.gd`) ready for porting logic from Python
- Startup rules smoke checks (`wahoo_rules_smoke.gd`) shown in the main status panel

## Open in Godot

1. Install Godot 4.6.3 (stable).
2. In Godot Project Manager, click **Import**.
3. Select `godot/project.godot`.
4. Run the project.

## Version and VCS policy

- The repository is standardized on Godot `4.6.3`.
- Commit project-side Godot metadata files that live alongside source assets/scripts (for example `*.uid` and `*.import`).
- Continue ignoring editor cache folders (`.godot/` and `.import/`) as configured in `.gitignore`.

## What this validates right now

- Project opens and runs on desktop.
- Main scene loads and UI responds to Roll clicks.
- Core translated rule behaviors are smoke-tested at startup and summarized in the UI.
- Script wiring and state container are in place for the full rule-port step.

## Run parity smoke tests headlessly

Run this from the `godot/` directory:

```powershell
Godot_v4.6.3-stable_win64_console.exe --headless --script res://scripts/run_smoke.gd
```

This executes the Godot parity smoke suite without opening the game UI and exits non-zero if any test fails.

### Windows PATH note

- Add the folder (not the file) to your user PATH: `C:\Users\macwe\OneDrive\Documents\Gdot4`
- The stock Windows zip build executable name is `Godot_v4.6.3-stable_win64_console.exe`, not `godot`
- If you create a `godot` alias or wrapper on your machine, `godot --headless --script res://scripts/run_smoke.gd` works the same way

## Next implementation step

- Continue expanding `godot/scripts/wahoo_rules_smoke.gd` toward parity with high-value scenarios from `tests/test_wahoo.py`.
- After parity confidence improves, configure HTML5 export and validate in desktop and mobile browsers.

## HTML5 export (Phase 2a)

This project now includes a `Web` export preset in `godot/export_presets.cfg`.

Run from the `godot/` directory:

```powershell
Godot_v4.6.3-stable_win64_console.exe --headless --path . --export-release Web build/web/index.html
```

If export fails with missing template errors, install the matching Godot export templates for your engine version (4.6.3) and rerun the command.

Validation checklist after a successful export:

- Open `godot/build/web/index.html` in a desktop browser and confirm scene load + Roll interaction.
- Open the same build on a mobile browser and confirm layout and input are functional.