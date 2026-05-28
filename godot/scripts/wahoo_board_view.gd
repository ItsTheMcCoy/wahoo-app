class_name WahooBoardView
extends Control

const WahooLayout = preload("res://scripts/wahoo_layout.gd")
const WahooState = preload("res://scripts/wahoo_state.gd")

signal move_selected(move: Dictionary)

const BOARD_BG := Color(0.90, 0.86, 0.76)
const BOARD_EDGE := Color(0.23, 0.22, 0.18)
const TRACK_PATH := Color(0.67, 0.62, 0.51)
const TRACK_CELL := Color(0.84, 0.80, 0.69)
const TRACK_CELL_EDGE := Color(0.29, 0.27, 0.21)
const BASE_PAD := Color(0.78, 0.73, 0.62)
const CENTER_FILL := Color(0.43, 0.39, 0.31)
const CENTER_EDGE := Color(0.18, 0.17, 0.14)
const MARBLE_EDGE := Color(0.10, 0.09, 0.07)
const MARBLE_HIGHLIGHT := Color(1.0, 1.0, 1.0, 0.48)
const MOVE_SOURCE_RING := Color(1.0, 0.97, 0.55, 0.95)
const MOVE_DEST_FILL := Color(1.0, 0.92, 0.18, 0.26)
const MOVE_DEST_RING := Color(1.0, 0.78, 0.10, 0.95)
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
    _cell_size = _board_rect.size.x / float(WahooLayout.GRID_SIZE)

    draw_rect(_board_rect, BOARD_BG, true)
    draw_rect(_board_rect, BOARD_EDGE, false, 3.0)

    _draw_player_areas()
    _draw_track_path()
    _draw_home_rows()
    _draw_track_cells()
    _draw_center()
    _draw_move_destinations()

func _square_board_rect() -> Rect2:
    var side: float = min(size.x, size.y)
    var origin := Vector2((size.x - side) * 0.5, (size.y - side) * 0.5)
    return Rect2(origin, Vector2(side, side))

func _draw_player_areas() -> void:
    for player in range(WahooState.NUM_PLAYERS):
        var player_color: Color = PLAYER_COLORS[player]
        var tint := Color(player_color.r, player_color.g, player_color.b, 0.16)

        _draw_base_pad(player, tint)
        _draw_base_cells(player, _lightened(player_color, 0.78))

func _draw_base_pad(player: int, color: Color) -> void:
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
    draw_rect(Rect2(top_left, bottom_right - top_left), color, true)
    draw_rect(Rect2(top_left, bottom_right - top_left), BASE_PAD, false, max(1.0, _cell_size * 0.04))

func _draw_base_cells(player: int, color: Color) -> void:
    for coord in WahooLayout.base_cluster_grid_coords(player):
        _draw_grid_square(coord, color, TRACK_CELL_EDGE, 0.70)

func _draw_track_path() -> void:
    var coords := WahooLayout.all_track_grid_coords()
    var points := PackedVector2Array()
    for coord in coords:
        points.append(_grid_to_local(coord))
    points.append(_grid_to_local(coords[0]))

    draw_polyline(points, TRACK_PATH, max(8.0, _cell_size * 0.82), true)

func _draw_home_rows() -> void:
    for player in range(WahooState.NUM_PLAYERS):
        var player_color: Color = PLAYER_COLORS[player]
        var row_color := _lightened(player_color, 0.68)
        var path_color := Color(player_color.r, player_color.g, player_color.b, 0.36)
        var coords := WahooLayout.home_row_grid_coords(player)
        var points := PackedVector2Array()

        points.append(_grid_to_local(WahooLayout.track_grid_coord(WahooState.home_entry(player))))
        for coord in coords:
            points.append(_grid_to_local(coord))

        draw_polyline(points, path_color, max(7.0, _cell_size * 0.56), true)
        for coord in coords:
            _draw_grid_square(coord, row_color, TRACK_CELL_EDGE, 0.66)

func _draw_track_cells() -> void:
    for coord in WahooLayout.all_track_grid_coords():
        var fill := TRACK_CELL
        for player in range(WahooState.NUM_PLAYERS):
            if coord == WahooLayout.track_grid_coord(WahooState.base_exit(player)):
                fill = _lightened(PLAYER_COLORS[player], 0.72)
            elif coord == WahooLayout.track_grid_coord(WahooState.home_entry(player)):
                fill = _lightened(PLAYER_COLORS[player], 0.82)
        _draw_grid_square(coord, fill, TRACK_CELL_EDGE, 0.62)

func _draw_center() -> void:
    var center := _grid_to_local(WahooLayout.center_grid_coord())
    var radius: float = max(8.0, _cell_size * 0.72)
    draw_circle(center, radius, CENTER_FILL)
    draw_arc(center, radius, 0.0, TAU, 40, CENTER_EDGE, max(2.0, _cell_size * 0.08), true)

func _draw_move_destinations() -> void:
    if _legal_moves.is_empty() or _legal_move_player < 0:
        return

    var drawn := {}
    for move in _visible_legal_moves():
        var dest: Array = move["dest"]
        var coord := WahooLayout.location_grid_coord(dest, _legal_move_player, int(move["marble"]))
        var key := "%d,%d" % [coord.x, coord.y]
        if drawn.has(key):
            continue
        drawn[key] = true

        var center := _grid_to_local(coord)
        var radius: float = _cell_size * (0.58 if String(dest[0]) == "CENTER" else 0.46)
        draw_circle(center, radius, MOVE_DEST_FILL)
        draw_arc(center, radius, 0.0, TAU, 44, MOVE_DEST_RING, max(2.0, _cell_size * 0.08), true)

func _draw_grid_square(coord: Vector2i, fill: Color, edge: Color, scale: float) -> void:
    var rect := _grid_cell_rect(coord, scale)
    draw_rect(rect, fill, true)
    draw_rect(rect, edge, false, max(1.0, _cell_size * 0.035))

func _grid_to_local(coord: Vector2i) -> Vector2:
    var normalized := WahooLayout.grid_to_normalized(coord)
    return _board_rect.position + Vector2(
        normalized.x * _board_rect.size.x,
        normalized.y * _board_rect.size.y
    )

func _grid_to_cell_origin(coord: Vector2i) -> Vector2:
    return _board_rect.position + Vector2(coord.x * _cell_size, coord.y * _cell_size)

func _grid_cell_rect(coord: Vector2i, scale: float) -> Rect2:
    var side: float = _cell_size * scale
    var center := _grid_to_local(coord)
    return Rect2(center - Vector2(side, side) * 0.5, Vector2(side, side))

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
    _cell_size = _board_rect.size.x / float(WahooLayout.GRID_SIZE)
    var token_side: float = max(14.0, _cell_size * 0.72)

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
    var normalized := WahooLayout.location_normalized(loc, player, marble_id)
    var center := _board_rect.position + Vector2(
        normalized.x * _board_rect.size.x,
        normalized.y * _board_rect.size.y
    )
    return center - _token_size() * 0.5

func _token_size() -> Vector2:
    var token_side: float = max(14.0, _cell_size * 0.72)
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
    var dest_move: Variant = _move_at_destination(local_position)
    if dest_move != null:
        move_selected.emit(dest_move)
        return

    var marble_id := _marble_at_position(local_position)
    if marble_id < 0:
        return

    var marble_moves: Array = _moves_for_marble(marble_id)
    if marble_moves.is_empty():
        return
    if marble_moves.size() == 1:
        move_selected.emit(marble_moves[0])
        return

    _selected_marble = marble_id
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
        var center := _board_rect.position + WahooLayout.location_normalized(
            loc,
            _legal_move_player,
            marble_id
        ) * _board_rect.size
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
