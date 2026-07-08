# Patch Plan — Item 2: Chat send button shows a missing-glyph box instead of a Send icon

## Item

In the HOST GAME setup screen (multiplayer lobby), the send button next to the
"Type a message..." box shows an odd square containing four digits in a 2×2
layout. It should show a recognizable "Send" symbol like chat applications use
(paper-plane / arrow icon).

## Root Cause (already diagnosed — verify, then fix)

The button's text is the Unicode character `→` (U+2192 RIGHTWARDS ARROW):

- `godot/scenes/Lobby.tscn`, node `ChatSendBtn` (~line 157): `text = "→"`
- `godot/scenes/Main.tscn`, node `ChatSendBtn` (~line 135): `text = "→"`
  (the in-game multiplayer chat has the identical bug)

The font shipped in the web export has no glyph for U+2192, so it renders the
standard "tofu" fallback: a box containing the codepoint hex `2192` as four
digits in a 2×2 grid — exactly what the user described.

The fix pattern already exists in this codebase: the floating back button uses
an SVG icon, `godot/assets/textures/back_chevron.svg`, applied via `btn.icon`
in `WahooResponsiveLayout.style_icon_button()`
(`godot/scripts/wahoo_responsive_layout.gd` lines 4, 56–60). SVG **shapes**
(paths) rasterize fine in Godot — only SVG `<text>` doesn't (see Item 1).

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

Search `documents/**/*.md` (Grep) for keywords like `chat`, `send`, `icon`,
`arrow`, `glyph`. Likely candidates:

- `documents/ASSET_DESIGN_GUIDE.md` — follow its visual system (colors, stroke
  style) when drawing the new send icon; add the new icon asset to its asset
  inventory if it lists assets.
- `documents/MULTIPLAYER_PLAN.md` — describes lobby chat.

If a document covers this area, treat it as the spec while implementing, and
after the change UPDATE it if it no longer aligns with the current state of the
game. If nothing covers it, note that in your final report.

## Implementation Plan

1. `git switch patch/fixes-and-enhancements`.
2. Create `godot/assets/textures/send_icon.svg` — a paper-plane (or clean
   right-pointing triangle-arrow) icon, roughly 40×40 viewBox:
   - Use ONLY `<path>`/`<polygon>` shapes — absolutely no `<text>` elements
     (Godot cannot rasterize them) and no external references.
   - Color it to match the button font color used in the lobby theme,
     approximately `#f7eddb` (`Color(0.97, 0.93, 0.86)`), matching how
     `back_chevron.svg` is styled. Open `back_chevron.svg` and copy its
     conventions (fill color, stroke style, size).
3. In `godot/scripts/lobby.gd`, in `_apply_theme()` (or `_setup_ui()`), apply
   the icon to the send button:
   ```gdscript
   const SEND_ICON = preload("res://assets/textures/send_icon.svg")
   ...
   _chat_send_btn.text = ""
   _chat_send_btn.icon = SEND_ICON
   _chat_send_btn.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
   _chat_send_btn.expand_icon = false
   ```
   Also remove/replace `text = "→"` on `ChatSendBtn` in `godot/scenes/Lobby.tscn`.
4. Apply the same fix to the in-game chat send button:
   `godot/scenes/Main.tscn` node `ChatSendBtn` and wherever `main.gd` themes it
   (search `main.gd` for `ChatSendBtn` / `_chat_send`). Keep both buttons
   visually identical.
5. Sweep for other at-risk non-ASCII glyphs in UI strings so this class of bug
   is caught in one pass: Grep `godot/scripts` and `godot/scenes` for
   non-ASCII characters in `text =` / `.text` assignments. Known instances to
   check on an actual web build: the `👁` eye emoji in
   `lobby.gd` `_refresh_spectator_count()` (~line 414) and chat messages
   (~line 438), and the `–` en-dash die placeholder in `main.gd` (~line 124).
   Fix only the ones that render as tofu boxes in the web build; leave ones
   that render correctly.
6. Add a tooltip to both send buttons: `tooltip_text = "Send"`.

### Acceptance Criteria

- The lobby chat send button and the in-game chat send button both show a
  clean send icon (no tofu box) in the web build on desktop and mobile.
- Icon is visually centered in the 60×48 (desktop) / 74×48 (compact) button.

### Verification

- Headless smoke tests still pass:
  ```powershell
  & "C:\Users\pc\OneDrive\Documents\Godot4\Godot_v4.6.3-stable_win64_console.exe" --headless --path godot --script scripts/run_smoke.gd
  ```
- Re-export the web build (see below), serve `godot/build/web/` locally
  (e.g., `python -m http.server`), host a game, and confirm the send button
  renders the icon and still sends chat messages.

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
- `godot/build/web/` also contains hand-placed branded assets (`og_preview.png`,
  `wahulo_wordmark.svg`, `background_felt_tile_512.svg`, `index.png`, favicons)
  that must remain — never delete the folder before exporting.

## Commit and Push

After verification passes and the re-export is done:

```
git add godot/assets/textures/send_icon.svg godot/scripts/lobby.gd godot/scenes/Lobby.tscn godot/scenes/Main.tscn godot/scripts/main.gd godot/build/web <other changed files>
git commit -m "Replace tofu-box arrow with SVG send icon on chat send buttons"
git push -u origin patch/fixes-and-enhancements
```
