# How-To-Play Overlay — Implementation Handoff

## Context

We are adding a paginated "How to Play" instructions overlay to the Wahulo Godot game. The overlay is accessible from three places: HomeScreen, Lobby, and in-game side panel. It uses a shared subscene (`HowToPlayOverlay.tscn`) matching the existing `SetupOverlay`/`HostPromptLayer` modal pattern.

## What Has Been Done

### ✅ Phase 1 — Shared overlay subscene (complete)

**`godot/scripts/how_to_play_overlay.gd`** — NEW file, complete.
- 5-page paginated overlay (Goal & Setup / Your Turn / Moving Your Marbles / The Center Shortcut / Winning)
- Content sourced from `documents/HOW_TO_PLAY.md`
- `show_overlay()` public method — call this to open it
- Emits `closed` signal when dismissed
- Prev/Next navigation + page indicator ("1 / 5")
- `_apply_theme()` matches project's brown/wood colour palette; responsive via `WahooResponsiveLayout.is_mobile_like_layout()`
- Registers/deregisters browser back handler via `WahooResponsiveLayout.push_back_handler` / `pop_back_handler`

**`godot/scenes/HowToPlayOverlay.tscn`** — NEW file, complete.
Node tree:
```
HowToPlayOverlay (Control, layout_mode=1, anchors_preset=15, visible=false, script=how_to_play_overlay.gd)
├── DimBg (ColorRect, full-rect, color black@0.55)
└── Center (CenterContainer, full-rect)
    └── HowToPlayPanel (PanelContainer)
        └── HowToPlayContent (VBoxContainer, min_width=480)
            ├── HowToPlayTitle (Label, centered)
            ├── BodyScroll (ScrollContainer, min_height=220)
            │   └── HowToPlayBody (RichTextLabel, bbcode_enabled, fit_content, autowrap)
            ├── NavRow (HBoxContainer)
            │   ├── PrevBtn (Button, min_width=100, disabled=true initially)
            │   ├── PageIndicator (Label, size_flags_h=expand, "1 / 5")
            │   └── NextBtn (Button, min_width=100)
            └── CloseBtn (Button, full-width)
```

---

## What Still Needs to Be Done

### ⬜ Phase 2 — HomeScreen integration

#### 2a. `godot/scenes/HomeScreen.tscn`

Three changes needed in one file:

1. **Header** — increment `load_steps` from `2` to `3`.

2. **New ext_resource** — add after the existing `[ext_resource type="Script" ...]` line:
```
[ext_resource type="PackedScene" path="res://scenes/HowToPlayOverlay.tscn" id="2_hs002"]
```

3. **New Button node** — add after the `JoinButton` node block (before `HostPromptLayer`):
```
[node name="HowToPlayButton" type="Button" parent="MainCenter/HomePanel/Content"]
layout_mode = 2
custom_minimum_size = Vector2(0, 56)
text = "How to Play"
```

4. **Overlay instance** — add at the very end of the file:
```
[node name="HowToPlayOverlay" parent="." instance=ExtResource("2_hs002")]
layout_mode = 1
anchors_preset = 15
anchor_right = 1.0
anchor_bottom = 1.0
grow_horizontal = 2
grow_vertical = 2
```

#### 2b. `godot/scripts/home_screen.gd`

Four changes:

1. **New @onready vars** — add after `@onready var _join_content: VBoxContainer = ...`:
```gdscript
# How to Play
@onready var _how_to_play_btn: Button  = $MainCenter/HomePanel/Content/HowToPlayButton
@onready var _how_to_play_overlay: Control = $HowToPlayOverlay
```

2. **Connect button in `_ready()`** — add after the last button connection (before `_host_name_field.text_submitted...`):
```gdscript
_how_to_play_btn.pressed.connect(func(): _how_to_play_overlay.show_overlay())
```

3. **Style the button in `_apply_theme()`** — add `_how_to_play_btn` to the `all_buttons` array:
```gdscript
var all_buttons: Array = [
    _play_solo_btn, _host_game_btn, _join_btn, _how_to_play_btn,
    _host_cancel_btn, _host_create_btn,
    _join_cancel_btn, _join_player_btn, _join_spectator_btn,
]
```

4. **Size the button in `_apply_responsive_layout()`** — add `_how_to_play_btn` to the main button sizing loop. Find the `for btn in [_play_solo_btn, _host_game_btn, _join_btn]:` line and add `_how_to_play_btn`:
```gdscript
for btn in [_play_solo_btn, _host_game_btn, _join_btn, _how_to_play_btn]:
    btn.custom_minimum_size = Vector2(0, main_button_height)
    btn.add_theme_font_size_override("font_size", main_button_font)
```

---

### ⬜ Phase 3 — Lobby integration

#### 3a. `godot/scenes/Lobby.tscn`

Three changes:

1. **Header** — increment `load_steps` from `2` to `3`.

2. **New ext_resource** — add after the existing `[ext_resource type="Script" ...]` line:
```
[ext_resource type="PackedScene" path="res://scenes/HowToPlayOverlay.tscn" id="2_lob02"]
```

3. **New Button node** — add after the `ActionRow` section (after the `StartGameBtn` node block, before `LobbyBackButton`). Insert into the Content VBoxContainer, not inside ActionRow:
```
[node name="HowToPlayButton" type="Button" parent="ScrollContainer/Center/LobbyPanel/Content"]
layout_mode = 2
custom_minimum_size = Vector2(0, 56)
text = "How to Play"
```

4. **Overlay instance** — add at the very end of the file:
```
[node name="HowToPlayOverlay" parent="." instance=ExtResource("2_lob02")]
layout_mode = 1
anchors_preset = 15
anchor_right = 1.0
anchor_bottom = 1.0
grow_horizontal = 2
grow_vertical = 2
```

#### 3b. `godot/scripts/lobby.gd`

Three changes:

1. **New @onready vars** — add after `@onready var _back_btn: Button = $LobbyBackButton`:
```gdscript
@onready var _how_to_play_btn: Button  = $ScrollContainer/Center/LobbyPanel/Content/HowToPlayButton
@onready var _how_to_play_overlay: Control = $HowToPlayOverlay
```

2. **Connect button in `_setup_ui()`** — add after `_leave_btn.pressed.connect(_on_leave)`:
```gdscript
_how_to_play_btn.pressed.connect(func(): _how_to_play_overlay.show_overlay())
```

3. **Style button in `_apply_theme()`** — add `_how_to_play_btn` to the button loop. Find the line:
```gdscript
for btn: Button in [_copy_code_btn, _copy_link_btn, _chat_send_btn, _leave_btn, _start_game_btn]:
```
Change to:
```gdscript
for btn: Button in [_copy_code_btn, _copy_link_btn, _chat_send_btn, _leave_btn, _start_game_btn, _how_to_play_btn]:
```

4. **Size button in `_apply_responsive_layout()`** — add after `_start_game_btn.custom_minimum_size = ...`:
```gdscript
_how_to_play_btn.custom_minimum_size = Vector2(0, action_height)
```

---

### ⬜ Phase 4 — In-game side panel integration

#### 4a. `godot/scenes/Main.tscn`

Three changes:

1. **Header** — increment `load_steps` from `4` to `5`.

2. **New ext_resource** — add after the last existing `[ext_resource ...]` line (after `id="3_0dv5w"`):
```
[ext_resource type="PackedScene" path="res://scenes/HowToPlayOverlay.tscn" id="5_htp01"]
```

3. **New Button node in SidePanel** — add after the `EndTurnButton` node block (before the `ChatSection` node):
```
[node name="HowToPlayButton" type="Button" parent="Root/SidePanel"]
layout_mode = 2
custom_minimum_size = Vector2(0, 52)
text = "How to Play"
theme_override_font_sizes/font_size = 18
```

4. **Overlay instance** — add at the very end of the file (after the entire `SetupOverlay` section):
```
[node name="HowToPlayOverlay" parent="." instance=ExtResource("5_htp01")]
layout_mode = 1
anchors_preset = 15
anchor_right = 1.0
anchor_bottom = 1.0
grow_horizontal = 2
grow_vertical = 2
```

#### 4b. `godot/scripts/main.gd`

Three changes:

1. **New @onready vars** — add after the last `@onready var _seat_label_3: ...` line:
```gdscript
@onready var _how_to_play_btn: Button  = $Root/SidePanel/HowToPlayButton
@onready var _how_to_play_overlay: Control = $HowToPlayOverlay
```

2. **Connect button in `_ready()`** — add after `_start_button.pressed.connect(_on_start_pressed)`:
```gdscript
_how_to_play_btn.pressed.connect(func(): _how_to_play_overlay.show_overlay())
```

3. **Style button in `_apply_visual_theme()`** — add `_how_to_play_btn` to the `action_buttons` array:
```gdscript
var action_buttons: Array = [
    _roll_button,
    _end_turn_button,
    _chat_send_btn,
    _new_game_button,
    _start_button,
    _game_menu_button,
    _how_to_play_btn,
]
```

---

## Key File Paths

| File | Status |
|------|--------|
| `godot/scripts/how_to_play_overlay.gd` | ✅ Created |
| `godot/scenes/HowToPlayOverlay.tscn` | ✅ Created |
| `godot/scenes/HomeScreen.tscn` | ⬜ Needs edits |
| `godot/scripts/home_screen.gd` | ⬜ Needs edits |
| `godot/scenes/Lobby.tscn` | ⬜ Needs edits |
| `godot/scripts/lobby.gd` | ⬜ Needs edits |
| `godot/scenes/Main.tscn` | ⬜ Needs edits |
| `godot/scripts/main.gd` | ⬜ Needs edits |
| `documents/HOW_TO_PLAY.md` | Source content (read-only) |

## Patterns and Conventions to Follow

- **Overlay pattern**: full-rect `Control`, `layout_mode=1`, `anchors_preset=15`; opened by toggling `visible = true`; `ColorRect` DimBg at `Color(0,0,0,0.55)` underneath
- **Button theme**: all buttons styled in `_apply_theme()` / `_apply_visual_theme()` via `StyleBoxFlat` (normal bg `Color(0.30,0.22,0.15,0.98)`, border `Color(0.73,0.56,0.39,0.98)`, hover bg `Color(0.38,0.28,0.19,0.98)`)
- **Font colours**: `Color(0.97,0.93,0.86)` for button text
- **Panel style**: bg `Color(0.17,0.13,0.10,0.94)`, border `Color(0.46,0.34,0.24,0.95)`, corner radius 14
- **Back handler**: always pair `push_back_handler` in `show_overlay()` with `pop_back_handler` in `_close()`
- **No state mutation**: the overlay is read-only; never touches game state, network, or save files
- **Lobby `_apply_button_theme()`**: lobby.gd has a helper `_apply_button_theme(btn, normal, hover, pressed, disabled)` — however the loop approach (adding `_how_to_play_btn` to the existing for loop) is simpler and already used for other lobby buttons

## Verification Steps

After completing all phases:
1. Launch the game; confirm "How to Play" button visible on HomeScreen → opens overlay → pages 1–5 navigate → Close dismisses
2. Enter a Lobby → same button present and functional
3. Start a solo game → "How to Play" button visible in side panel → opens overlay → Close dismisses without affecting game state
4. On narrow viewport (< 480px wide) confirm body scrolls and panel doesn't overflow screen
5. Confirm overlay renders on top of all other UI (it is the last child in each scene's tree)
