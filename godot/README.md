# Godot Project (Phases 2a–3e Complete)

This folder contains the Godot 4 project for the browser port tracked in `documents/DEVELOPMENT_PLAN.md`. Phases 2a, 2b, 3a, 3b, 3c, 3e, and 3f are complete. The game is fully playable with human and AI opponents on a single device.

## Current scope

- Minimal project file and icon
- Two-column main scene: board fills the left, right-side panel holds turn indicator, large die display, status log, and action buttons (Roll, End Turn, Menu)
- GDScript state model (`wahoo_state.gd`) — complete port of Python's `game_state.py`
- GDScript rules engine (`wahoo_rules.gd`) — complete port of Python's `rules.py`
- Startup parity smoke tests (`wahoo_rules_smoke.gd`) — 27 checks covering all major rule behaviours, all passing
- Visual board layout mapping (`wahoo_layout.gd`) — normalized coordinates for track, base, home, and center locations
- Layout smoke tests (`wahoo_layout_smoke.gd`) — 5 checks covering board topology and normalized coordinate bounds
- GDScript AI engine (`wahoo_ai.gd`) — port of Python `ai.py`: helpers, 10 features, RandomPlayer, GreedyPlayer, 9 profile weight dicts, `make_profiles()`
- AI load/scenario smoke tests (`wahoo_ai_smoke.gd`) — 18 checks (12 AI load + 6 scenario probes matching Python `test_ai.py`)
- Per-seat profile dropdowns in setup: Human or any of 10 named AI profiles
- Auto-played AI turns with pre-move pause; human turns use an End Turn button to advance
- Board move polish in `wahoo_board_view.gd`: lift-and-place marble motion, dynamic marble shadow, and destination impact pulse with style presets (`subtle`, `arcade`, `cinematic`)
- HTML5 export configured and validated on desktop and mobile browsers

## Open in Godot

1. Install Godot 4.6.3 (stable).
2. In Godot Project Manager, click **Import**.
3. Select `godot/project.godot`.
4. Run the project.

## Packaged launch commands

Run these commands from the repository root:

```powershell
cd "C:\Users\macwe\OneDrive\Documents\Claude\Projects\Wahoo-app"
```

Launch the playable Godot game:

```powershell
.\Launch-Godot-Wahoo.bat
```

Open the Godot editor:

```powershell
.\Launch-Godot-Wahoo.bat editor
```

Run only the Godot smoke checks:

```powershell
.\Launch-Godot-Wahoo.bat smoke
```

Rebuild the Web export:

```powershell
.\Launch-Godot-Wahoo.bat export
```

Rebuild and serve the Web export locally:

```powershell
.\Launch-Godot-Wahoo.bat web 8000
```

Then open `http://localhost:8000` in a browser.

## Version and VCS policy

- The repository is standardized on Godot `4.6.3`.
- Commit project-side Godot metadata files that live alongside source assets/scripts (for example `*.uid` and `*.import`).
- Continue ignoring editor cache folders (`.godot/` and `.import/`) as configured in `.gitignore`.

## What this validates right now

- Project opens and runs on desktop.
- Main scene loads as a visual board surface and UI responds to Roll clicks and tap-to-move choices on desktop and mobile (responsive layout).
- 50 headless smoke tests pass: 27 rule parity checks, 5 visual layout checks, 12 AI load checks, and 6 AI scenario probes.
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

## Current phase: Phase 4 — Internet Multiplayer (Not Started)

Phases 2a, 2b, 3a, 3b, 3c, 3e, and 3f are complete. The game is fully playable as a single-device hot-seat game with configurable human and AI opponents. Phase 4 (WebRTC internet multiplayer) is tracked in `documents/DEVELOPMENT_PLAN.md`.

Current Godot state:

- `scenes/Main.tscn` is a two-column layout: the board fills the left column (`PanelContainer` with `EXPAND+FILL`); the right `SidePanel` (280 px min width) holds, top to bottom: `GameMenuButton`, `Status` log (expands), `DieFrame/DieLabel` (96 px Unicode die face), `TurnLabel` (26 px, bold via 2 px outline, player-colored), `RollButton` (72 px tall), and `EndTurnButton` (72 px tall).
- `scripts/main.gd` manages game flow: opening roll phase, human turn (Roll → select move by clicking → End Turn), and AI turn (auto-roll → auto-move → auto-advance). No move hints are shown; players must recall legal moves themselves. Die rolling shows Unicode faces (⚀–⚅) with a 14-frame cycle and a center-pivoted scale pop on settle.
- `scripts/wahoo_layout.gd` maps rules locations to normalized visual board coordinates for static geometry, marbles, tap/click targets, and movement animation.
- `scripts/wahoo_board_view.gd` draws the board canvas, marble tokens, and selected-marble ring; legal move hints remain hidden (no destination circles or moveable-marble rings), while movement uses a lift-and-place tween with dynamic shadow and a brief landing pulse.
- `scripts/wahoo_ai.gd` implements RandomPlayer and GreedyPlayer with 9 named profile weight dicts and a `make_profiles()` factory.

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
