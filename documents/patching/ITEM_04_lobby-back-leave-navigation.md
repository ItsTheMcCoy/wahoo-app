# Patch Plan — Item 4: Lobby Back/Leave button exits the site instead of returning to the home screen

## Item

In the HOST GAME setup screen (multiplayer lobby), for both the host and a
joined player, pressing the floating back button (`<`) or the Leave button does
not return to the home screen. Instead the browser appears to close the current
tab / navigate to a blank page ("a new one with nothing in the address bar").

## Architecture Context

Browser-back integration lives in two places:

1. **GDScript side** — `godot/scripts/wahoo_responsive_layout.gd`:
   - `push_back_handler(callback)` (~line 38): wraps the callback with
     `JavaScriptBridge.create_callback()` and calls JS `wahuloPushBack(cb)`.
   - `pop_back_handler()` (~line 48): calls JS `wahuloPopBack()`.
2. **JS side** — `godot/custom_html_shell.html` (~lines 224–286): keeps a
   single `backCallback` slot; `wahuloPushBack` stores the callback and does
   `history.pushState(...)`; `wahuloPopBack` sets `suppressNextPopstate` and
   calls `history.back()`; a `popstate` listener runs the stored callback.

Callers: `home_screen.gd` pushes `_close_prompts` when a prompt opens and pops
on room created/joined; `lobby.gd` `_ready()` pushes `_on_leave` and `_on_leave()`
pops before changing scene back to `HomeScreen.tscn`.

## Root-Cause Hypotheses (investigate in this order)

**H1 — The bridge callback is garbage-collected (most likely).**
In `push_back_handler()` the result of `JavaScriptBridge.create_callback()` is
stored in a *local* variable (`js_callback`). Godot's documentation explicitly
warns the returned `JavaScriptObject` must be kept referenced for the lifetime
of the callback; once the function returns, it can be freed, leaving the JS
side holding a dead reference. Result: a browser-back press consumes the pushed
history entry but the callback does nothing (or errors), so the app doesn't
navigate; the NEXT back press (or the `history.back()` issued by
`wahuloPopBack` when state is misaligned) walks past the app's first history
entry — the browser leaves the site (mobile browsers show this as the tab
closing / a blank new-tab page).

**H2 — Callable arity mismatch.**
Godot invokes a `create_callback` callable with ONE argument (an Array of JS
args). `_on_leave()` and `_close_prompts()` take zero arguments, so the
invocation fails at call time even when the reference is alive.

**H3 — pushState/back() ordering race.**
`wahuloPopBack` uses `history.back()`, which is asynchronous; the scene change
and the next scene's `wahuloPushBack` (synchronous `pushState`) can interleave
with it, corrupting the single-slot callback/entry bookkeeping.

Reproduce first: serve the web build locally, open devtools console, host a
game, click Leave, and capture any JS/Godot errors plus the
`history.length` before/after. Test both the in-app buttons and the browser
back button, on desktop Chrome and (if possible) a mobile device.

## Implementation Plan

1. `git switch patch/fixes-and-enhancements`.
2. **Keep bridge callbacks alive (H1).** `WahooResponsiveLayout` is a
   `RefCounted` used statically; add a static stack to hold the JS objects:
   ```gdscript
   static var _back_callback_refs: Array = []

   static func push_back_handler(callback: Callable) -> void:
       if not OS.has_feature("web"):
           return
       var window := JavaScriptBridge.get_interface("window")
       var js_callback := JavaScriptBridge.create_callback(
           func(_args): callback.call()   # also fixes H2 arity
       )
       _back_callback_refs.append(js_callback)
       window.call("wahuloPushBack", js_callback)

   static func pop_back_handler() -> void:
       if not OS.has_feature("web"):
           return
       var window := JavaScriptBridge.get_interface("window")
       window.call("wahuloPopBack")
       if not _back_callback_refs.is_empty():
           _back_callback_refs.pop_back()
   ```
   Also release the stored ref when the JS popstate handler consumes the
   callback: simplest is to also pop the ref inside the wrapped lambda
   (`func(_args): _back_callback_refs.erase(js_callback); callback.call()` —
   restructure as needed since the lambda can't see `js_callback` before it is
   created; a small helper or deferred erase is fine).
3. **Harden the JS side (H3 + safety) in `godot/custom_html_shell.html`:**
   - In `wahuloPopBack`, only call `history.back()` when the current entry is
     one the app pushed: `if (history.state && history.state.wahuloBack)`.
     Otherwise just clear `backCallback` — never navigate. This is the direct
     guard against ever leaving the site.
   - Consider converting the single `backCallback` slot into a small stack so
     nested pushes (home prompt → lobby) can't overwrite each other.
4. **Re-check the callers** (`home_screen.gd` `_on_host_game`,
   `_open_join_prompt`, `_on_room_created/_on_room_joined/_on_spectator_joined_ok`,
   `_close_prompts`; `lobby.gd` `_ready`, `_on_leave`, `_on_game_started`) to
   confirm every `push_back_handler` has exactly one matching
   `pop_back_handler` on every exit path.
5. IMPORTANT: changes to `custom_html_shell.html` only reach the deployed page
   through the export (the shell is baked into `build/web/index.html`), so the
   re-export step below is mandatory.

### Acceptance Criteria (test host AND joined player, desktop AND mobile-sized)

- Lobby `<` back button → returns to home screen, same tab, URL unchanged.
- Lobby Leave button → same.
- Browser/device back button in the lobby → returns to home screen (one press).
- Browser back on the home screen (nothing pushed) → normal browser behavior
  (may leave the site — that is correct there).
- Repeating host → lobby → leave → host → lobby → leave several times stays
  stable (no accumulating history entries requiring multiple back presses).
- No errors in the browser console during any of the above.

### Verification

- Headless smoke tests still pass:
  ```powershell
  & "C:\Users\pc\OneDrive\Documents\Godot4\Godot_v4.6.3-stable_win64_console.exe" --headless --path godot --script scripts/run_smoke.gd
  ```
- Serve the re-exported build (`python -m http.server` from `godot/build/web`)
  and run the acceptance list above. Note: two browser tabs can host/join the
  same room to test the joined-player path if the relay server is reachable.

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

Search `documents/**/*.md` (Grep) for `back`, `history`, `pushState`,
`navigation`, `leave`. Likely candidates:

- `documents/MULTIPLAYER_PLAN.md` — lobby/leave flow.
- `documents/CURRENT_DEVELOPMENT_STATE_REVIEW.md`

If a document covers this behavior, treat it as the spec while implementing,
and after the change UPDATE it if it no longer aligns with the current state of
the game. If nothing covers it, note that in your final report.

## Godot Executable Location

The Godot .exe lives in:

```
C:\Users\pc\OneDrive\Documents\Godot4
```

- `Godot_v4.6.3-stable_win64.exe` — editor/GUI
- `Godot_v4.6.3-stable_win64_console.exe` — use for headless/CLI work

## Re-Exporting the HTML (Web Build)

This item changes `godot/` scripts AND the HTML shell, so a re-export IS
required (the shell is baked into the exported `index.html`).

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
git add godot/scripts/wahoo_responsive_layout.gd godot/custom_html_shell.html godot/scripts/lobby.gd godot/scripts/home_screen.gd godot/build/web <other changed files>
git commit -m "Fix lobby back/leave navigation exiting the site on web"
git push -u origin patch/fixes-and-enhancements
```
