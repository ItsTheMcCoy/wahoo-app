# Godot Project (Phase 2a/2b)

This folder contains the Godot 4 project for the browser port tracked in `documents/DEVELOPMENT_PLAN.md`. Phase 2a and Phase 2b are complete; the next Godot phase is AI opponent integration.

## Current scope

- Minimal project file and icon
- Responsive board-first main scene with a Roll button, current-player indicator, compact status/debug output, and win overlay
- GDScript state model (`wahoo_state.gd`) — complete port of Python's `game_state.py`
- GDScript rules engine (`wahoo_rules.gd`) — complete port of Python's `rules.py`
- Startup parity smoke tests (`wahoo_rules_smoke.gd`) — 27 checks covering all major rule behaviours, all passing
- Visual board layout mapping (`wahoo_layout.gd`) — normalized coordinates for track, base, home, and center locations
- Layout smoke tests (`wahoo_layout_smoke.gd`) — 5 checks covering board topology and normalized coordinate bounds
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
- Main scene loads as a visual board surface and UI responds to Roll clicks and tap-to-move choices on desktop and mobile (responsive layout).
- 32 headless smoke tests pass: 27 rule parity checks plus 5 visual layout checks.
- HTML5 export builds and loads correctly in desktop and mobile browsers.

## Run smoke tests headlessly

Run this from the `godot/` directory:

```powershell
Godot_v4.6.3-stable_win64_console.exe --headless --script res://scripts/run_smoke.gd
```

This executes the Godot rule and layout smoke suites without opening the game UI and exits non-zero if any test fails.

### Windows PATH note

- Add the folder (not the file) to your user PATH: `C:\Users\macwe\OneDrive\Documents\Gdot4`
- The stock Windows zip build executable name is `Godot_v4.6.3-stable_win64_console.exe`, not `godot`
- If you create a `godot` alias or wrapper on your machine, `godot --headless --script res://scripts/run_smoke.gd` works the same way

## Current phase: Phase 3 — Single-Device AI

Phase 2a and Phase 2b are complete. Phase 3 is tracked in `documents/DEVELOPMENT_PLAN.md` under **Phase 3**.

Current Godot state:

- `scenes/Main.tscn` is a board-first scene with a header, visual board surface, compact status/debug footer, and Roll button.
- `scripts/main.gd` currently rolls, finds legal moves, waits for a highlighted tap/click move choice, animates the selected move, advances the player, refreshes the board surface, and updates compact status text.
- `scripts/wahoo_layout.gd` maps rules locations to normalized visual board coordinates for static geometry, marbles, legal-move highlighting, tap/click targets, and movement animation.
- `scripts/wahoo_board_view.gd` owns the board canvas and currently draws static board geometry plus marble nodes from `WahooState`.

Completed Phase 2b order:

1. Done: add `scripts/wahoo_layout.gd` for abstract `Location` -> normalized board coordinate mapping.
2. Done: replace the text-first scene with a board-first surface and compact status/debug footer.
3. Done: draw static track/base/home/center geometry.
4. Done: render marble nodes from `WahooState` using player colors.
5. Done: change Roll behavior to highlight legal move choices instead of auto-applying the first move.
6. Done: add tap/click move selection, then refresh from authoritative state.
7. Done: add basic movement animation, current-player indicator, turn announcements, and win screen.
8. Done: re-run headless smoke tests and Web export validation after interaction works.

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
- Phase 2b final validation on May 28, 2026: Godot smoke checks `32/32 passed`, Python tests `80 passed`, Web export rebuilt successfully, and required Web artifacts verified.
