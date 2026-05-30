class_name WahooBoardView
extends Control

const WahooLayout = preload("res://scripts/wahoo_layout.gd")
const WahooState = preload("res://scripts/wahoo_state.gd")
const BOARD_TEXTURE_PATH := "res://assets/textures/board_wood.svg"
const MARBLE_TEXTURE_PATH := "res://assets/textures/marble_gloss.svg"

signal move_selected(move: Dictionary)

const BOARD_BG := Color(0.57, 0.44, 0.30)
const BOARD_BG_INNER := Color(0.77, 0.66, 0.51, 0.80)
const BOARD_EDGE := Color(0.14, 0.11, 0.08)
const BOARD_GRAIN_DARK := Color(0.33, 0.24, 0.16, 0.20)
const BOARD_GRAIN_LIGHT := Color(0.86, 0.74, 0.59, 0.12)
const BOARD_VIGNETTE := Color(0.08, 0.06, 0.04, 0.23)
const TRACK_PATH_DARK := Color(0.34, 0.26, 0.17)
const TRACK_PATH_LIGHT := Color(0.73, 0.61, 0.46)
const TRACK_CELL := Color(0.88, 0.80, 0.67)
const TRACK_CELL_EDGE := Color(0.25, 0.20, 0.15)
const SPOT_CAVITY := Color(0.20, 0.15, 0.11, 0.24)
const AMBIENT_OCCLUSION := Color(0.07, 0.05, 0.03, 0.12)
const LANE_SHADOW := Color(0.09, 0.06, 0.04, 0.16)
const CENTER_FILL := Color(0.32, 0.24, 0.17)
const CENTER_EDGE := Color(0.12, 0.09, 0.07)
const MARBLE_EDGE := Color(0.10, 0.09, 0.07)
const MARBLE_HIGHLIGHT := Color(1.0, 1.0, 1.0, 0.48)
const MOVE_SOURCE_RING := Color(1.0, 0.97, 0.55, 0.95)
const MOVE_DEST_RING := Color(1.0, 0.78, 0.10, 1.0)
const MOVE_DEST_FILL_ALPHA := 0.42
const MOVE_DEST_RING_ALPHA := 0.98
const TURN_FOCUS_RING_ALPHA := 0.55
const BOARD_SCALE := 0.97
const POSITION_SPOT_RADIUS_RATIO := 0.37
const MARBLE_SIZE_RATIO := 0.71
const BOARD_EDGE_PADDING_UNITS := 0.75
const ANIMATION_STYLE_PRESETS := {
    "subtle": {
        "move_seconds": 0.28,
        "capture_seconds": 0.24,
        "lift_ratio": 0.38,
        "scale_lift": 1.08,
        "up_phase_ratio": 0.46,
        "shadow_alpha_ground": 0.20,
        "shadow_alpha_lifted": 0.11,
        "impact_pulse_seconds": 0.14,
        "impact_radius_min_ratio": 0.28,
        "impact_radius_max_ratio": 0.66,
        "impact_alpha": 0.28,
    },
    "arcade": {
        "move_seconds": 0.31,
        "capture_seconds": 0.26,
        "lift_ratio": 0.48,
        "scale_lift": 1.11,
        "up_phase_ratio": 0.43,
        "shadow_alpha_ground": 0.22,
        "shadow_alpha_lifted": 0.10,
        "impact_pulse_seconds": 0.16,
        "impact_radius_min_ratio": 0.34,
        "impact_radius_max_ratio": 0.78,
        "impact_alpha": 0.36,
    },
    "cinematic": {
        "move_seconds": 0.36,
        "capture_seconds": 0.30,
        "lift_ratio": 0.62,
        "scale_lift": 1.16,
        "up_phase_ratio": 0.42,
        "shadow_alpha_ground": 0.24,
        "shadow_alpha_lifted": 0.10,
        "impact_pulse_seconds": 0.18,
        "impact_radius_min_ratio": 0.36,
        "impact_radius_max_ratio": 0.86,
        "impact_alpha": 0.42,
    },
}
const DEFAULT_ANIMATION_STYLE := "cinematic"
const PLAYER_COLORS := [
    Color(0.86, 0.20, 0.17),
    Color(0.16, 0.60, 0.27),
    Color(0.93, 0.75, 0.17),
    Color(0.17, 0.34, 0.78),
]

var _state: WahooState = null
var _board_rect := Rect2()
var _cell_size := 0.0
var _marble_nodes: Array = []
var _legal_moves: Array = []
var _legal_move_player := -1
var _selected_marble := -1
var _animation_in_progress := false
var _seat_labels: Array = ["Red", "Green", "Yellow", "Blue"]
var _impact_active := false
var _impact_progress := 1.0
var _impact_center := Vector2.ZERO
var _impact_tween: Tween = null
var _animation_style: Dictionary = {}
var _board_texture: Texture2D = null
var _marble_texture: Texture2D = null

func _ready() -> void:
    _load_visual_assets()
    _ensure_marble_nodes()
    set_animation_style(DEFAULT_ANIMATION_STYLE)
    resized.connect(_on_resized)
    _refresh_marble_nodes()

func _load_visual_assets() -> void:
    if ResourceLoader.exists(BOARD_TEXTURE_PATH):
        _board_texture = load(BOARD_TEXTURE_PATH)
    if ResourceLoader.exists(MARBLE_TEXTURE_PATH):
        _marble_texture = load(MARBLE_TEXTURE_PATH)

func set_animation_style(style_name: String) -> void:
    var key := style_name.to_lower()
    if not ANIMATION_STYLE_PRESETS.has(key):
        key = DEFAULT_ANIMATION_STYLE
    _animation_style = ANIMATION_STYLE_PRESETS[key].duplicate(true)
    _refresh_shadow_style()
    queue_redraw()

func _style_float(key: String, fallback: float) -> float:
    if _animation_style.has(key):
        return float(_animation_style[key])
    return fallback

func _refresh_shadow_style() -> void:
    if _marble_nodes.size() != WahooState.NUM_PLAYERS:
        return
    var ground_alpha := _style_float("shadow_alpha_ground", 0.24)
    var lifted_alpha := _style_float("shadow_alpha_lifted", 0.10)
    for player in range(WahooState.NUM_PLAYERS):
        for marble_id in range(WahooState.MARBLES_PER_PLAYER):
            var token: Control = _marble_nodes[player][marble_id]
            token.set_shadow_profile(ground_alpha, lifted_alpha)

func set_state(state: WahooState) -> void:
    _state = state
    _ensure_marble_nodes()
    _refresh_marble_nodes()
    queue_redraw()

func set_legal_moves(moves: Array, player: int) -> void:
    _legal_moves = moves.duplicate(true)
    _legal_move_player = player
    _selected_marble = -1
    _refresh_marble_nodes()
    queue_redraw()

func clear_legal_moves() -> void:
    _legal_moves = []
    _legal_move_player = -1
    _selected_marble = -1
    _refresh_marble_nodes()
    queue_redraw()

func set_seat_labels(labels: Array) -> void:
    if labels.size() < WahooState.NUM_PLAYERS:
        return
    _seat_labels = labels.duplicate(true)
    queue_redraw()

func animate_move(move: Dictionary, player: int) -> void:
    if _state == null:
        return

    _animation_in_progress = true
    _refresh_marble_nodes()

    var marble_id := int(move["marble"])
    var moving_token: Control = _marble_nodes[player][marble_id]
    var moving_start := moving_token.position
    var moving_dest := _token_position_for_location(move["dest"], player, marble_id)
    var original_moving_z := moving_token.z_index
    moving_token.z_index = 100
    moving_token.pivot_offset = moving_token.size * 0.5
    moving_token.set_shadow_lift(0.0)

    var captured_token: Control = null
    var original_captured_z := 0
    var captures: Variant = move.get("captures", null)
    if captures != null:
        var cap_player := int(captures[0])
        var cap_marble := int(captures[1])
        captured_token = _marble_nodes[cap_player][cap_marble]
        original_captured_z = captured_token.z_index
        captured_token.z_index = 90
        captured_token.pivot_offset = captured_token.size * 0.5

    var move_seconds := _style_float("move_seconds", 0.36)
    var capture_seconds := _style_float("capture_seconds", 0.30)
    var up_phase_ratio := _style_float("up_phase_ratio", 0.42)
    var lift_ratio := _style_float("lift_ratio", 0.62)
    var scale_lift := _style_float("scale_lift", 1.16)

    var up_seconds := move_seconds * up_phase_ratio
    var down_seconds := move_seconds - up_seconds
    var lift_height := clampf(_cell_size * lift_ratio, 12.0, 42.0)
    var apex := moving_start.lerp(moving_dest, 0.45) + Vector2(0.0, -lift_height)

    var moving_tween := create_tween()
    moving_tween.set_parallel(true)
    moving_tween.tween_property(moving_token, "position", apex, up_seconds).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
    moving_tween.tween_property(moving_token, "scale", Vector2.ONE * scale_lift, up_seconds).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
    moving_tween.tween_method(Callable(moving_token, "set_shadow_lift"), 0.0, 1.0, up_seconds)
    moving_tween.set_parallel(false)
    moving_tween.set_parallel(true)
    moving_tween.tween_property(moving_token, "position", moving_dest, down_seconds).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_IN)
    moving_tween.tween_property(moving_token, "scale", Vector2.ONE, down_seconds).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
    moving_tween.tween_method(Callable(moving_token, "set_shadow_lift"), 1.0, 0.0, down_seconds)

    var capture_tween: Tween = null
    if captured_token != null:
        var captured_home := _token_position_for_location(WahooState.loc_base(), int(captures[0]), int(captures[1]))
        capture_tween = create_tween()
        capture_tween.set_parallel(true)
        capture_tween.tween_property(captured_token, "position", captured_home, capture_seconds).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
        capture_tween.tween_property(captured_token, "scale", Vector2.ONE * 0.85, capture_seconds * 0.55).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
        capture_tween.set_parallel(false)
        capture_tween.tween_property(captured_token, "scale", Vector2.ONE, capture_seconds * 0.45).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

    await moving_tween.finished
    if capture_tween != null:
        await capture_tween.finished

    moving_token.position = moving_dest
    moving_token.scale = Vector2.ONE
    moving_token.set_shadow_lift(0.0)
    moving_token.z_index = original_moving_z
    if captured_token != null:
        var captured_home_pos := _token_position_for_location(WahooState.loc_base(), int(captures[0]), int(captures[1]))
        captured_token.position = captured_home_pos
        captured_token.scale = Vector2.ONE
        captured_token.set_shadow_lift(0.0)
        captured_token.z_index = original_captured_z

    _start_impact_pulse(moving_dest + _token_size() * 0.5)
    _animation_in_progress = false

func _gui_input(event: InputEvent) -> void:
    if _animation_in_progress or _legal_moves.is_empty() or _legal_move_player < 0:
        return
    if event is InputEventMouseButton:
        var mouse_event := event as InputEventMouseButton
        if mouse_event.button_index == MOUSE_BUTTON_LEFT and mouse_event.pressed:
            _handle_pointer_press(mouse_event.position)
    elif event is InputEventScreenTouch:
        var touch_event := event as InputEventScreenTouch
        if touch_event.pressed:
            _handle_pointer_press(touch_event.position)

func _draw() -> void:
    _board_rect = _square_board_rect()
    _cell_size = _compute_cell_size(_board_rect)

    _draw_board_surface()
    _draw_ambient_occlusion()

    _draw_player_areas()
    _draw_current_player_focus()
    _draw_track_path()
    _draw_home_rows()
    _draw_track_cells()
    _draw_center()
    _draw_impact_pulse()
    _draw_legal_destinations()
    _draw_seat_labels()

func _draw_board_surface() -> void:
    draw_rect(_board_rect, BOARD_BG, true)
    if _board_texture != null:
        draw_texture_rect(_board_texture, _board_rect, true, Color(1.0, 1.0, 1.0, 0.72))

    var grain_rows := 28
    for i in range(grain_rows):
        var t := float(i) / float(grain_rows - 1)
        var y := lerpf(_board_rect.position.y, _board_rect.end.y, t)
        var sway := sinf(t * TAU * 2.4) * _cell_size * 0.22
        var line_from := Vector2(_board_rect.position.x, y + sway)
        var line_to := Vector2(_board_rect.end.x, y - sway * 0.55)
        var grain_color := BOARD_GRAIN_DARK if i % 2 == 0 else BOARD_GRAIN_LIGHT
        draw_line(line_from, line_to, grain_color, max(1.0, _cell_size * 0.05), true)

    var inner := Rect2(
        _board_rect.position + Vector2(_cell_size * 0.48, _cell_size * 0.48),
        _board_rect.size - Vector2(_cell_size * 0.96, _cell_size * 0.96)
    )
    draw_rect(inner, BOARD_BG_INNER, true)

    var bevel_light := BOARD_BG_INNER.lerp(Color.WHITE, 0.24)
    bevel_light.a = 0.62
    var bevel_dark := BOARD_EDGE
    bevel_dark.a = 0.84
    draw_rect(inner.grow(_cell_size * 0.08), bevel_light, false, max(2.0, _cell_size * 0.07))
    draw_rect(_board_rect, BOARD_EDGE, false, max(3.0, _cell_size * 0.10))
    draw_rect(_board_rect.grow(-_cell_size * 0.10), bevel_dark, false, max(1.0, _cell_size * 0.04))

    var vignette_inset := _cell_size * 0.82
    var top_band := Rect2(_board_rect.position, Vector2(_board_rect.size.x, vignette_inset))
    var bottom_band := Rect2(Vector2(_board_rect.position.x, _board_rect.end.y - vignette_inset), Vector2(_board_rect.size.x, vignette_inset))
    var left_band := Rect2(Vector2(_board_rect.position.x, _board_rect.position.y + vignette_inset), Vector2(vignette_inset, _board_rect.size.y - vignette_inset * 2.0))
    var right_band := Rect2(Vector2(_board_rect.end.x - vignette_inset, _board_rect.position.y + vignette_inset), Vector2(vignette_inset, _board_rect.size.y - vignette_inset * 2.0))
    draw_rect(top_band, BOARD_VIGNETTE, true)
    draw_rect(bottom_band, BOARD_VIGNETTE, true)
    draw_rect(left_band, BOARD_VIGNETTE, true)
    draw_rect(right_band, BOARD_VIGNETTE, true)

func _draw_ambient_occlusion() -> void:
    var lane_radius := _position_spot_radius() * 1.20
    for coord in WahooLayout.all_track_grid_coords():
        var center := _grid_to_local(coord)
        draw_circle(center + Vector2(0.0, lane_radius * 0.11), lane_radius, AMBIENT_OCCLUSION)

    for player in range(WahooState.NUM_PLAYERS):
        for home_coord in WahooLayout.home_row_grid_coords(player):
            var home_center := _grid_to_local(home_coord)
            draw_circle(home_center + Vector2(0.0, lane_radius * 0.09), lane_radius * 0.96, AMBIENT_OCCLUSION)
        for base_coord in WahooLayout.base_cluster_grid_coords(player):
            var base_center := _grid_to_local(base_coord)
            draw_circle(base_center + Vector2(0.0, lane_radius * 0.09), lane_radius * 0.96, AMBIENT_OCCLUSION)

    var center := _grid_to_local(WahooLayout.center_grid_coord())
    draw_circle(center + Vector2(0.0, lane_radius * 0.12), lane_radius * 1.24, AMBIENT_OCCLUSION)

func _draw_impact_pulse() -> void:
    if not _impact_active:
        return
    var ring := MOVE_DEST_RING
    ring.a = _style_float("impact_alpha", 0.42) * (1.0 - _impact_progress)
    var radius := _cell_size * lerpf(
        _style_float("impact_radius_min_ratio", 0.36),
        _style_float("impact_radius_max_ratio", 0.86),
        _impact_progress
    )
    var thickness := max(2.0, _cell_size * 0.10 * (1.0 - _impact_progress * 0.55))
    draw_arc(_impact_center, radius, 0.0, TAU, 36, ring, thickness, true)

func _set_impact_progress(progress: float) -> void:
    _impact_progress = clampf(progress, 0.0, 1.0)
    queue_redraw()

func _start_impact_pulse(center: Vector2) -> void:
    _impact_center = center
    _impact_active = true
    _set_impact_progress(0.0)
    if _impact_tween != null and _impact_tween.is_valid():
        _impact_tween.kill()
    _impact_tween = create_tween()
    _impact_tween.tween_method(Callable(self, "_set_impact_progress"), 0.0, 1.0, _style_float("impact_pulse_seconds", 0.18))
    _impact_tween.finished.connect(func() -> void:
        _impact_active = false
        _impact_progress = 1.0
        queue_redraw()
    )

func _square_board_rect() -> Rect2:
    var side: float = min(size.x, size.y) * BOARD_SCALE
    var origin := Vector2((size.x - side) * 0.5, (size.y - side) * 0.5)
    return Rect2(origin, Vector2(side, side))

func _compute_cell_size(board_rect: Rect2) -> float:
    var max_distance: float = _max_grid_distance_from_center()
    var half_span := max_distance + BOARD_EDGE_PADDING_UNITS
    return board_rect.size.x / max(1.0, half_span * 2.0)

func _max_grid_distance_from_center() -> float:
    var center_coord: Vector2i = WahooLayout.center_grid_coord()
    var max_distance := 0.0
    for coord in _all_board_coords():
        var dx := absf(float(coord.x - center_coord.x))
        var dy := absf(float(coord.y - center_coord.y))
        max_distance = maxf(max_distance, maxf(dx, dy))
    return max_distance

func _all_board_coords() -> Array:
    var coords := WahooLayout.all_track_grid_coords()
    coords.append(WahooLayout.center_grid_coord())
    for player in range(WahooState.NUM_PLAYERS):
        coords.append_array(WahooLayout.home_row_grid_coords(player))
        coords.append_array(WahooLayout.base_cluster_grid_coords(player))
    return coords

func _draw_player_areas() -> void:
    for player in range(WahooState.NUM_PLAYERS):
        _draw_base_cells(player, _base_spot_color(player))

func _draw_current_player_focus() -> void:
    if _state == null:
        return
    var player := _state.current_player
    var ring_color: Color = PLAYER_COLORS[player]
    ring_color.a = TURN_FOCUS_RING_ALPHA
    for coord in WahooLayout.base_cluster_grid_coords(player):
        var center := _grid_to_local(coord)
        var radius := _position_spot_radius() * 1.16
        draw_arc(center, radius, 0.0, TAU, 36, ring_color, max(2.0, _cell_size * 0.08), true)

func _base_cluster_bounds(player: int) -> Rect2:
    var coords := WahooLayout.base_cluster_grid_coords(player)
    var min_coord: Vector2i = coords[0]
    var max_coord: Vector2i = coords[0]
    for coord in coords:
        min_coord.x = mini(min_coord.x, coord.x)
        min_coord.y = mini(min_coord.y, coord.y)
        max_coord.x = maxi(max_coord.x, coord.x)
        max_coord.y = maxi(max_coord.y, coord.y)

    var top_left := _grid_to_cell_origin(min_coord) - Vector2(_cell_size * 0.32, _cell_size * 0.32)
    var bottom_right := _grid_to_cell_origin(max_coord) + Vector2(_cell_size * 1.32, _cell_size * 1.32)
    return Rect2(top_left, bottom_right - top_left)

func _draw_base_cells(player: int, color: Color) -> void:
    for coord in WahooLayout.base_cluster_grid_coords(player):
        _draw_grid_spot(coord, color, TRACK_CELL_EDGE)

func _draw_track_path() -> void:
    var coords := WahooLayout.all_track_grid_coords()
    var points := PackedVector2Array()
    for coord in coords:
        points.append(_grid_to_local(coord))
    points.append(_grid_to_local(coords[0]))

    var base_width := max(8.0, _cell_size * 0.82)
    draw_polyline(points, LANE_SHADOW, base_width * 1.30, true)
    draw_polyline(points, TRACK_PATH_DARK, base_width, true)
    draw_polyline(points, TRACK_PATH_LIGHT, base_width * 0.62, true)

func _draw_home_rows() -> void:
    for player in range(WahooState.NUM_PLAYERS):
        var row_color := _base_spot_color(player)
        var coords := WahooLayout.home_row_grid_coords(player)
        for coord in coords:
            _draw_grid_spot(coord, row_color, TRACK_CELL_EDGE)

func _draw_track_cells() -> void:
    for coord in WahooLayout.all_track_grid_coords():
        var fill := TRACK_CELL
        for player in range(WahooState.NUM_PLAYERS):
            if coord == WahooLayout.track_grid_coord(WahooState.base_exit(player)):
                fill = _lightened(PLAYER_COLORS[player], 0.72)
        _draw_grid_spot(coord, fill, TRACK_CELL_EDGE)

func _draw_center() -> void:
    var center := _grid_to_local(WahooLayout.center_grid_coord())
    var radius: float = _position_spot_radius()
    draw_circle(center + Vector2(0.0, radius * 0.16), radius * 1.02, SPOT_CAVITY)
    draw_circle(center, radius, CENTER_FILL)
    var glow := CENTER_FILL.lerp(Color.WHITE, 0.30)
    glow.a = 0.34
    draw_circle(center - Vector2(radius * 0.20, radius * 0.24), radius * 0.42, glow)
    draw_arc(center, radius, 0.0, TAU, 40, CENTER_EDGE, max(2.0, _cell_size * 0.08), true)

func _draw_legal_destinations() -> void:
    if _selected_marble < 0:
        return
    for move in _visible_legal_moves():
        var dest: Array = move["dest"]
        var coord := WahooLayout.location_grid_coord(dest, _legal_move_player, int(move["marble"]))
        var center := _grid_to_local(coord)
        var radius: float = _position_spot_radius() * 1.16
        var ring := MOVE_DEST_RING
        ring.a = MOVE_DEST_RING_ALPHA
        draw_arc(center, radius, 0.0, TAU, 40, ring, max(2.5, _cell_size * 0.10), true)

func _draw_grid_spot(coord: Vector2i, fill: Color, edge: Color) -> void:
    var center := _grid_to_local(coord)
    var radius: float = _position_spot_radius()
    draw_circle(center + Vector2(0.0, radius * 0.16), radius * 0.98, SPOT_CAVITY)
    draw_circle(center, radius, fill)
    var highlight := fill.lerp(Color.WHITE, 0.26)
    highlight.a = 0.46
    draw_circle(center - Vector2(radius * 0.22, radius * 0.28), radius * 0.38, highlight)
    draw_arc(center, radius * 0.72, 0.0, TAU, 24, fill.darkened(0.24), max(1.0, radius * 0.08), true)
    draw_arc(center, radius, 0.0, TAU, 32, edge, max(1.0, _cell_size * 0.06), true)

func _position_spot_radius() -> float:
    return max(7.0, _cell_size * POSITION_SPOT_RADIUS_RATIO)

func _base_spot_color(player: int) -> Color:
    return PLAYER_COLORS[player].lerp(BOARD_BG, 0.52)

func _draw_seat_labels() -> void:
    var font: Font = ThemeDB.fallback_font
    if font == null:
        return
    var font_size := int(max(12.0, _cell_size * 0.52))
    var font_height: float = font.get_height(font_size)
    for player in range(WahooState.NUM_PLAYERS):
        var label := String(_seat_labels[player]).strip_edges()
        if label.is_empty():
            continue
        var color: Color = PLAYER_COLORS[player].darkened(0.28)
        color.a = 0.95
        var anchor := _seat_label_anchor(player)
        if player == 1 or player == 3:
            var angle := PI * 0.5 if player == 1 else -PI * 0.5
            _draw_centered_rotated_text(font, font_size, font_height, label, anchor, angle, color)
        else:
            _draw_centered_text(font, font_size, font_height, label, anchor, color)

func _seat_label_anchor(player: int) -> Vector2:
    var bounds := _base_cluster_bounds(player)
    var padding := _cell_size * 0.30
    match player:
        0:
            return Vector2(bounds.get_center().x, bounds.end.y + padding)
        1:
            return Vector2(bounds.position.x - padding, bounds.get_center().y)
        2:
            return Vector2(bounds.get_center().x, bounds.position.y - padding)
        3:
            return Vector2(bounds.end.x + padding, bounds.get_center().y)
    return bounds.get_center()

func _draw_centered_text(font: Font, font_size: int, font_height: float, text: String, anchor: Vector2, color: Color) -> void:
    var text_size := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
    var shadow_pos := anchor + Vector2(-text_size.x * 0.5 + _cell_size * 0.05, font_height * 0.38 + _cell_size * 0.06)
    var shadow_color := Color(0.06, 0.05, 0.04, 0.52)
    draw_string(font, shadow_pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, shadow_color)
    var draw_pos := anchor + Vector2(-text_size.x * 0.5, font_height * 0.38)
    draw_string(font, draw_pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)

func _draw_centered_rotated_text(font: Font, font_size: int, font_height: float, text: String, anchor: Vector2, angle: float, color: Color) -> void:
    var text_size := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
    draw_set_transform(anchor, angle, Vector2.ONE)
    draw_string(font, Vector2(-text_size.x * 0.5 + _cell_size * 0.05, font_height * 0.38 + _cell_size * 0.06), text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color(0.06, 0.05, 0.04, 0.52))
    draw_string(font, Vector2(-text_size.x * 0.5, font_height * 0.38), text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)
    draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

func _grid_to_local(coord: Vector2i) -> Vector2:
    var center_coord: Vector2i = WahooLayout.center_grid_coord()
    var delta := Vector2(
        float(coord.x - center_coord.x),
        float(coord.y - center_coord.y)
    )
    return _board_rect.get_center() + delta * _cell_size

func _grid_to_cell_origin(coord: Vector2i) -> Vector2:
    return _grid_to_local(coord) - Vector2(_cell_size, _cell_size) * 0.5

func _lightened(color: Color, amount: float) -> Color:
    return color.lerp(Color.WHITE, amount)

func _on_resized() -> void:
    queue_redraw()
    _refresh_marble_nodes()

func _ensure_marble_nodes() -> void:
    if _marble_nodes.size() == WahooState.NUM_PLAYERS:
        return

    _marble_nodes = []
    for player in range(WahooState.NUM_PLAYERS):
        var player_nodes: Array = []
        for marble_id in range(WahooState.MARBLES_PER_PLAYER):
            var node_name := "Marble_%d_%d" % [player, marble_id]
            var token: Control = get_node_or_null(node_name)
            if token == null:
                token = MarbleToken.new()
                token.name = node_name
                token.mouse_filter = Control.MOUSE_FILTER_IGNORE
                add_child(token)
            token.set_meta("player", player)
            token.set_meta("marble_id", marble_id)
            token.set_color(PLAYER_COLORS[player])
            token.set_marble_texture(_marble_texture)
            player_nodes.append(token)
        _marble_nodes.append(player_nodes)

func _refresh_marble_nodes() -> void:
    if _state == null or _marble_nodes.size() != WahooState.NUM_PLAYERS:
        return

    _board_rect = _square_board_rect()
    _cell_size = _compute_cell_size(_board_rect)
    var token_side: float = max(12.0, _cell_size * MARBLE_SIZE_RATIO)

    for player in range(WahooState.NUM_PLAYERS):
        for marble_id in range(WahooState.MARBLES_PER_PLAYER):
            var token: Control = _marble_nodes[player][marble_id]
            var loc: Array = _state.marbles[player][marble_id]
            token.size = Vector2(token_side, token_side)
            token.pivot_offset = token.size * 0.5
            token.position = _token_position_for_location(loc, player, marble_id)
            token.scale = Vector2.ONE
            token.set_shadow_profile(
                _style_float("shadow_alpha_ground", 0.24),
                _style_float("shadow_alpha_lifted", 0.10)
            )
            token.set_shadow_lift(0.0)
            token.z_index = 10 + player
            token.visible = true
            token.set_selectable(_marble_has_legal_move(player, marble_id))
            token.set_selected(player == _legal_move_player and marble_id == _selected_marble)

func _token_position_for_location(loc: Array, player: int, marble_id: int) -> Vector2:
    var coord := WahooLayout.location_grid_coord(loc, player, marble_id)
    var center := _grid_to_local(coord)
    return center - _token_size() * 0.5

func _token_size() -> Vector2:
    var token_side: float = max(12.0, _cell_size * MARBLE_SIZE_RATIO)
    return Vector2(token_side, token_side)

func _marble_has_legal_move(player: int, marble_id: int) -> bool:
    if player != _legal_move_player:
        return false
    for move in _legal_moves:
        if int(move["marble"]) == marble_id:
            return true
    return false

func _visible_legal_moves() -> Array:
    if _selected_marble < 0:
        return _legal_moves

    var moves: Array = []
    for move in _legal_moves:
        if int(move["marble"]) == _selected_marble:
            moves.append(move)
    return moves

func _handle_pointer_press(local_position: Vector2) -> void:
    # Phase 2: if a marble is already selected, check for a destination click
    if _selected_marble >= 0:
        var dest_move: Variant = _move_at_destination(local_position)
        if dest_move != null:
            move_selected.emit(dest_move)
            return

    # Phase 1: click on a marble to select it (or execute if only one move)
    var marble_id := _marble_at_position(local_position)
    if marble_id >= 0:
        var marble_moves: Array = _moves_for_marble(marble_id)
        if not marble_moves.is_empty():
            if marble_moves.size() == 1:
                move_selected.emit(marble_moves[0])
                return
            # Toggle or switch selection
            _selected_marble = marble_id if _selected_marble != marble_id else -1
            _refresh_marble_nodes()
            queue_redraw()
            return

    # Clicked empty space — deselect
    if _selected_marble >= 0:
        _selected_marble = -1
        _refresh_marble_nodes()
        queue_redraw()

func _move_at_destination(local_position: Vector2) -> Variant:
    for move in _visible_legal_moves():
        var dest: Array = move["dest"]
        var coord := WahooLayout.location_grid_coord(dest, _legal_move_player, int(move["marble"]))
        var center := _grid_to_local(coord)
        var radius: float = _cell_size * (0.64 if String(dest[0]) == "CENTER" else 0.52)
        if local_position.distance_to(center) <= radius:
            return move
    return null

func _marble_at_position(local_position: Vector2) -> int:
    if _state == null:
        return -1

    var best_marble := -1
    var best_distance := INF
    for move in _legal_moves:
        var marble_id := int(move["marble"])
        var loc: Array = _state.marbles[_legal_move_player][marble_id]
        var coord := WahooLayout.location_grid_coord(loc, _legal_move_player, marble_id)
        var center := _grid_to_local(coord)
        var distance := local_position.distance_to(center)
        if distance < best_distance:
            best_distance = distance
            best_marble = marble_id

    var hit_radius: float = max(16.0, _cell_size * 0.52)
    return best_marble if best_distance <= hit_radius else -1

func _moves_for_marble(marble_id: int) -> Array:
    var moves: Array = []
    for move in _legal_moves:
        if int(move["marble"]) == marble_id:
            moves.append(move)
    return moves

class MarbleToken:
    extends Control

    var _color := Color.WHITE
    var _marble_texture: Texture2D = null
    var _selectable := false
    var _selected := false
    var _shadow_offset := Vector2(0.0, 6.0)
    var _shadow_scale := 0.95
    var _shadow_alpha := 0.24
    var _shadow_alpha_ground := 0.24
    var _shadow_alpha_lifted := 0.10

    func set_color(color: Color) -> void:
        _color = color
        queue_redraw()

    func set_marble_texture(texture: Texture2D) -> void:
        _marble_texture = texture
        queue_redraw()

    func set_selectable(selectable: bool) -> void:
        if _selectable == selectable:
            return
        _selectable = selectable
        queue_redraw()

    func set_selected(selected: bool) -> void:
        if _selected == selected:
            return
        _selected = selected
        queue_redraw()

    func set_shadow_profile(ground_alpha: float, lifted_alpha: float) -> void:
        _shadow_alpha_ground = ground_alpha
        _shadow_alpha_lifted = lifted_alpha
        _shadow_alpha = _shadow_alpha_ground
        queue_redraw()

    func set_shadow_lift(lift_ratio: float) -> void:
        var t := clampf(lift_ratio, 0.0, 1.0)
        _shadow_alpha = lerpf(_shadow_alpha_ground, _shadow_alpha_lifted, t)
        _shadow_scale = lerpf(0.95, 0.72, t)
        _shadow_offset = Vector2(0.0, lerpf(size.y * 0.16, size.y * 0.32, t))
        queue_redraw()

    func _draw() -> void:
        var radius: float = min(size.x, size.y) * 0.48
        var center := size * 0.5
        var shadow_color := Color(0.03, 0.03, 0.03, _shadow_alpha)
        draw_circle(center + _shadow_offset, radius * 0.84 * _shadow_scale, shadow_color)
        if _selectable:
            draw_arc(center, radius * 1.08, 0.0, TAU, 40, MOVE_SOURCE_RING, max(2.0, radius * 0.16), true)
        if _selected:
            draw_arc(center, radius * 1.22, 0.0, TAU, 44, MOVE_DEST_RING, max(2.0, radius * 0.13), true)
        var base_color := _color.darkened(0.30)
        var mid_color := _color.darkened(0.08)
        var top_color := _color.lerp(Color.WHITE, 0.24)
        var sparkle := MARBLE_HIGHLIGHT
        sparkle.a = 0.65

        if _marble_texture != null:
            draw_texture_rect(_marble_texture, Rect2(Vector2.ZERO, size), false, _color)
            var gloss := Color.WHITE
            gloss.a = 0.12
            draw_texture_rect(_marble_texture, Rect2(Vector2.ZERO, size), false, gloss)
            var lower_shade := Color(0.0, 0.0, 0.0, 0.16)
            draw_circle(center + Vector2(0.0, radius * 0.16), radius * 0.76, lower_shade)
        else:
            draw_circle(center, radius, base_color)
            draw_circle(center + Vector2(0.0, radius * 0.08), radius * 0.88, mid_color)
            draw_circle(center - Vector2(radius * 0.16, radius * 0.24), radius * 0.68, top_color)
        draw_arc(center, radius, 0.0, TAU, 36, MARBLE_EDGE, max(1.5, radius * 0.13), true)

        var rim_light := _color.lerp(Color.WHITE, 0.50)
        rim_light.a = 0.35
        draw_arc(center - Vector2(radius * 0.08, radius * 0.10), radius * 0.78, PI * 1.08, PI * 1.92, 24, rim_light, max(1.0, radius * 0.08), true)
        draw_circle(center - Vector2(radius * 0.30, radius * 0.34), radius * 0.25, sparkle)
