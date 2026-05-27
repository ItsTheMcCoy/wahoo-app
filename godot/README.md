# Godot Bootstrap (Phase 2a)

This folder contains the initial Godot 4 project scaffold for Phase 2a in `documents/DEVELOPMENT_PLAN.md`.

## Current scope

- Minimal project file and icon
- Minimal main scene with a Roll button and status text
- GDScript state model scaffold (`wahoo_state.gd`)
- Rules interface scaffold (`wahoo_rules.gd`) ready for porting logic from Python

## Open in Godot

1. Install Godot 4.x (stable).
2. In Godot Project Manager, click **Import**.
3. Select `godot/project.godot`.
4. Run the project.

## What this validates right now

- Project opens and runs on desktop.
- Main scene loads and UI responds to Roll clicks.
- Script wiring and state container are in place for the full rule-port step.

## Next implementation step

Port Python logic from:

- `wahoo/game_state.py` -> `godot/scripts/wahoo_state.gd`
- `wahoo/rules.py` -> `godot/scripts/wahoo_rules.gd`

Then add Godot-side rule parity tests matching `tests/test_wahoo.py` scenarios.