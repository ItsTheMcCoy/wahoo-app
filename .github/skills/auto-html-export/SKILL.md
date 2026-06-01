---
name: auto-html-export
description: "Automatically export the Godot HTML/Web build when relevant game files change. Use when: watch Godot files, auto-export web build, keep godot/build/web in sync after scene/script/asset edits."
---

# Auto HTML Export

Use this skill to keep `godot/build/web` current while editing gameplay files.

## What this skill does

1. Starts a file watcher for relevant Godot files.
2. Debounces bursts of changes.
3. Runs `scripts/launch_godot.ps1 -Mode export -SkipSmoke` automatically.
4. Prints export success/failure in the terminal.

## Relevant files

- `godot/scenes/**`
- `godot/scripts/**`
- `godot/assets/textures/**`
- `godot/project.godot`
- `godot/export_presets.cfg`
- `godot/custom_html_shell.html`

Excluded:

- `godot/build/web/**` (export output)
- `godot/.godot/**` (editor cache)
- `*.import` files

## How to run

Run this in an async terminal from the repo root:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .github/skills/auto-html-export/assets/watch_godot_html_export.ps1 -RunInitialExport
```

Optional flags:

- `-DebounceMs 1500` to tune debounce timing
- omit `-RunInitialExport` to wait for the first change before exporting

## Agent behavior

When the user asks to keep web export updated automatically:

1. Start the watcher command above in async mode.
2. Report the terminal id so it can be stopped later.
3. If asked to stop, kill that terminal.

If the user asks for a one-time rebuild only, run:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/launch_godot.ps1 -Mode export -SkipSmoke
```