# Patching Batch — July 2026

All items in this folder are implemented on the branch
**`patch/fixes-and-enhancements`** (never on `main`) and follow the structure
in `_PLAN_TEMPLATE.md`. Each plan is self-contained: branch instructions,
a documentation-alignment check, the Godot executable location
(`C:\Users\pc\OneDrive\Documents\Godot4`), and the rule that the web build must
be re-exported before any commit that touches `godot/`.

| Plan | Item | Primary files |
|------|------|---------------|
| `ITEM_01_lobby-wordmark-missing-text.md` | Lobby wordmark missing "WAHULO" text (SVG `<text>` not rendered by Godot) | `godot/scripts/lobby.gd` |
| `ITEM_02_chat-send-button-icon.md` | Chat send button renders a missing-glyph box (U+2192); replace with SVG send icon | `godot/scenes/Lobby.tscn`, `godot/scenes/Main.tscn`, `godot/scripts/lobby.gd` |
| `ITEM_03_enter-name-button-padding.md` | Enter-name prompt buttons: smaller text + horizontal padding | `godot/scripts/home_screen.gd` |
| `ITEM_04_lobby-back-leave-navigation.md` | Back/Leave in lobby exits the site instead of returning home | `godot/scripts/wahoo_responsive_layout.gd`, `godot/custom_html_shell.html` |
| `ITEM_05_realistic-rolling-die.md` | Animated pip-face rolling die instead of a number | `godot/scripts/main.gd`, new `godot/scripts/die_view.gd` |
| `ITEM_06_board-realism-no-clipping.md` | Board realism; nothing may clip the track circles | `godot/scripts/wahoo_board_view.gd` |
| `ITEM_07_game-menu-button-styling.md` | In-game Menu: closer to wordmark, styled as a real button | `godot/scenes/Main.tscn`, `godot/scripts/main.gd` |

Coordination notes for agents:

- Items 1, 2, and 4 all touch `lobby.gd`; items 2, 5, and 7 all touch
  `Main.tscn`/`main.gd`. If working in parallel, pull the branch before
  starting and rebase before pushing to avoid clobbering each other.
- Suggested order if done sequentially: 1 → 2 → 3 → 4 (small, independent
  fixes), then 7 → 5 → 6 (progressively larger visual work).
- Every item ends with a web re-export; if several items are completed in one
  session, one final re-export before the final push is sufficient.
