class_name WahooBoardView
extends Control

const WahooLayout = preload("res://scripts/wahoo_layout.gd")
const WahooState = preload("res://scripts/wahoo_state.gd")

signal move_selected(move: Dictionary)

const BOARD_BG := Color(0.92, 0.88, 0.78)
const BOARD_BG_INNER := Color(0.95, 0.92, 0.84, 0.70)
const BOARD_EDGE := Color(0.23, 0.22, 0.18)
const TRACK_PATH := Color(0.62, 0.56, 0.45)
const TRACK_CELL := Color(0.86, 0.82, 0.71)
const TRACK_CELL_EDGE := Color(0.29, 0.27, 0.21)
const CENTER_FILL := Color(0.43, 0.39, 0.31)
const CENTER_EDGE := Color(0.18, 0.17, 0.14)
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
const MOVE_ANIMATION_SECONDS := 0.36
const CAPTURE_ANIMATION_SECONDS := 0.30
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

func _ready() -> void:
    _ensure_marble_nodes()
    resized.connect(_on_resized)
    _refresh_marble_nodes()

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
    var moving_dest := _token_position_for_location(move["dest"], player, marble_id)
    var original_moving_z := moving_token.z_index
    moving_token.z_index = 100

    var captured_token: Control = null
    var original_captured_z := 0
    var captures: Variant = move.get("captures", null)
    if captures != null:
        var cap_player := int(captures[0])
        var cap_marble := int(captures[1])
        captured_token = _marble_nodes[cap_player][cap_marble]
        original_captured_z = captured_token.z_index
        captured_token.z_index = 90

    var tween := create_tween()
    tween.set_parallel(true)
    tween.tween_property(moving_token, "position", moving_dest, MOVE_ANIMATION_SECONDS).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
    if captured_token != null:
        var captured_home := _token_position_for_location(WahooState.loc_base(), int(captures[0]), int(captures[1]))
        tween.tween_property(captured_token, "position", captured_home, CAPTURE_ANIMATION_SECONDS).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

    await tween.finished
    moving_token.z_index = original_moving_z
    if captured_token != null:
        captured_token.z_index = original_captured_z
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

    draw_rect(_board_rect, BOARD_BG, true)
    var inner := Rect2(
        _board_rect.position + Vector2(_cell_size * 0.45, _cell_size * 0.45),
        _board_rect.size - Vector2(_cell_size * 0.9, _cell_size * 0.9)
    )
    draw_rect(inner, BOARD_BG_INNER, true)
    draw_rect(_board_rect, BOARD_EDGE, false, 3.0)

    _draw_player_areas()
    _draw_current_player_focus()
    _draw_track_path()
    _draw_home_rows()
    _draw_track_cells()
    _draw_center()
    _draw_legal_destinations()
    _draw_seat_labels()

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

    draw_polyline(points, TRACK_PATH, max(8.0, _cell_size * 0.82), true)

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
    draw_circle(center, radius, CENTER_FILL)
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
    draw_circle(center, radius, fill)
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
    var draw_pos := anchor + Vector2(-text_size.x * 0.5, font_height * 0.38)
    draw_string(font, draw_pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)

func _draw_centered_rotated_text(font: Font, font_size: int, font_height: float, text: String, anchor: Vector2, angle: float, color: Color) -> void:
    var text_size := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
    draw_set_transform(anchor, angle, Vector2.ONE)
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
            token.position = _token_position_for_location(loc, player, marble_id)
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
    var _selectable := false
    var _selected := false

    func set_color(color: Color) -> void:
        _color = color
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

    func _draw() -> void:
        var radius: float = min(size.x, size.y) * 0.48
        var center := size * 0.5
        if _selectable:
            draw_arc(center, radius * 1.08, 0.0, TAU, 40, MOVE_SOURCE_RING, max(2.0, radius * 0.16), true)
        if _selected:
            draw_arc(center, radius * 1.22, 0.0, TAU, 44, MOVE_DEST_RING, max(2.0, radius * 0.13), true)
        draw_circle(center, radius, _color)
        draw_arc(center, radius, 0.0, TAU, 36, MARBLE_EDGE, max(1.5, radius * 0.13), true)
        draw_circle(center - Vector2(radius * 0.28, radius * 0.30), radius * 0.23, MARBLE_HIGHLIGHT)
