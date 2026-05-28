# Godot Bootstrap (Phase 2a)

This folder contains the initial Godot 4 project scaffold for Phase 2a in `documents/DEVELOPMENT_PLAN.md`.

## Current scope

- Minimal project file and icon
- Responsive main scene with a Roll button and status text (fills viewport; mobile-friendly font sizes)
- GDScript state model (`wahoo_state.gd`) — complete port of Python's `game_state.py`
- GDScript rules engine (`wahoo_rules.gd`) — complete port of Python's `rules.py`
- Startup parity smoke tests (`wahoo_rules_smoke.gd`) — 27 checks covering all major rule behaviours, all passing
- HTML5 export configured and validated on desktop and mobile browsers

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
- Main scene loads and UI responds to Roll clicks on desktop and mobile (responsive layout).
- 27 rule parity smoke tests run at startup and all pass, covering base-exit, track advance, center entry/exit, home lane, capture, win condition, and edge cases (pass-over-opponent, other-player home-entry, slot-0 blocking).
- HTML5 export builds and loads correctly in desktop and mobile browsers.

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

## Next phase: Phase 2b — Visual Board

Phase 2a is complete. The next work is tracked in `documents/DEVELOPMENT_PLAN.md` under **Phase 2b**:

- Add a layout module mapping `Location` tuples → pixel coordinates (separate from rules code)
- Draw the board, marble pieces, home rows, and center hole
- Highlight legal-move destinations after a roll
- Tap-to-move interaction
- Animate marble movement, roll button, current-player indicator, and win screen

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

Current status:

- Desktop browser validation: complete (scene load + repeated Roll interaction verified).
- Mobile browser validation: complete (Roll interaction and state updates verified over HTTPS).
- Mobile text readability: fixed (responsive full-viewport layout, 22 px title, 16 px status, 60 px tap target for Roll).