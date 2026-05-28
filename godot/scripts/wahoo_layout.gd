class_name WahooLayout
extends RefCounted

const WahooState = preload("res://scripts/wahoo_state.gd")

const GRID_SIZE := 21

# Coordinates use Godot's Vector2i(x, y), where x is the column and y is the row.
# The source topology matches the Python console renderer's 21x21 physical board.
const TRACK_COORDS := [
    Vector2i(10, 2), Vector2i(10, 3), Vector2i(10, 4), Vector2i(10, 5), Vector2i(10, 6), Vector2i(10, 7),
    Vector2i(11, 7), Vector2i(12, 7), Vector2i(13, 7), Vector2i(14, 7), Vector2i(15, 7),
    Vector2i(15, 8), Vector2i(15, 9), Vector2i(15, 10),
    Vector2i(15, 11), Vector2i(14, 11), Vector2i(13, 11), Vector2i(12, 11), Vector2i(11, 11), Vector2i(10, 11),
    Vector2i(10, 12), Vector2i(10, 13), Vector2i(10, 14), Vector2i(10, 15), Vector2i(10, 16),
    Vector2i(9, 16), Vector2i(8, 16), Vector2i(7, 16),
    Vector2i(6, 16), Vector2i(6, 15), Vector2i(6, 14), Vector2i(6, 13), Vector2i(6, 12), Vector2i(6, 11),
    Vector2i(5, 11), Vector2i(4, 11), Vector2i(3, 11), Vector2i(2, 11), Vector2i(1, 11),
    Vector2i(1, 10), Vector2i(1, 9), Vector2i(1, 8),
    Vector2i(1, 7), Vector2i(2, 7), Vector2i(3, 7), Vector2i(4, 7), Vector2i(5, 7), Vector2i(6, 7),
    Vector2i(6, 6), Vector2i(6, 5), Vector2i(6, 4), Vector2i(6, 3), Vector2i(6, 2),
    Vector2i(7, 2), Vector2i(8, 2), Vector2i(9, 2),
]

const HOME_COORDS := [
    [Vector2i(8, 3), Vector2i(8, 4), Vector2i(8, 5), Vector2i(8, 6)],
    [Vector2i(14, 9), Vector2i(13, 9), Vector2i(12, 9), Vector2i(11, 9)],
    [Vector2i(8, 15), Vector2i(8, 14), Vector2i(8, 13), Vector2i(8, 12)],
    [Vector2i(2, 9), Vector2i(3, 9), Vector2i(4, 9), Vector2i(5, 9)],
]

const BASE_COORDS := [
    [Vector2i(11, 0), Vector2i(12, 0), Vector2i(11, 1), Vector2i(12, 1)],
    [Vector2i(18, 12), Vector2i(19, 12), Vector2i(18, 13), Vector2i(19, 13)],
    [Vector2i(4, 18), Vector2i(5, 18), Vector2i(4, 19), Vector2i(5, 19)],
    [Vector2i(0, 4), Vector2i(1, 4), Vector2i(0, 5), Vector2i(1, 5)],
]

const CENTER_COORD := Vector2i(8, 9)

static func track_grid_coord(loop_idx: int) -> Vector2i:
    return TRACK_COORDS[posmod(loop_idx, WahooState.LOOP_SIZE)]

static func home_grid_coord(player: int, slot: int) -> Vector2i:
    _assert_player(player)
    _assert_index(slot, WahooState.HOME_SLOTS, "home slot")
    return HOME_COORDS[player][slot]

static func base_grid_coord(player: int, marble_id: int) -> Vector2i:
    _assert_player(player)
    _assert_index(marble_id, WahooState.MARBLES_PER_PLAYER, "marble id")
    return BASE_COORDS[player][marble_id]

static func center_grid_coord() -> Vector2i:
    return CENTER_COORD

static func location_grid_coord(loc: Array, player: int = -1, marble_id: int = 0) -> Vector2i:
    var kind := String(loc[0])
    if kind == "TRACK":
        return track_grid_coord(int(loc[1]))
    if kind == "HOME":
        _assert_player(player)
        return home_grid_coord(player, int(loc[1]))
    if kind == "BASE":
        _assert_player(player)
        return base_grid_coord(player, marble_id)
    if kind == "CENTER":
        return center_grid_coord()
    push_error("Unknown Wahoo location: %s" % str(loc))
    return Vector2i.ZERO

static func grid_to_normalized(coord: Vector2i) -> Vector2:
    return Vector2(
        (float(coord.x) + 0.5) / float(GRID_SIZE),
        (float(coord.y) + 0.5) / float(GRID_SIZE)
    )

static func track_normalized(loop_idx: int) -> Vector2:
    return grid_to_normalized(track_grid_coord(loop_idx))

static func home_normalized(player: int, slot: int) -> Vector2:
    return grid_to_normalized(home_grid_coord(player, slot))

static func base_normalized(player: int, marble_id: int) -> Vector2:
    return grid_to_normalized(base_grid_coord(player, marble_id))

static func center_normalized() -> Vector2:
    return grid_to_normalized(center_grid_coord())

static func location_normalized(loc: Array, player: int = -1, marble_id: int = 0) -> Vector2:
    return grid_to_normalized(location_grid_coord(loc, player, marble_id))

static func all_track_grid_coords() -> Array:
    return TRACK_COORDS.duplicate(true)

static func home_row_grid_coords(player: int) -> Array:
    _assert_player(player)
    return HOME_COORDS[player].duplicate(true)

static func base_cluster_grid_coords(player: int) -> Array:
    _assert_player(player)
    return BASE_COORDS[player].duplicate(true)

static func _assert_player(player: int) -> void:
    assert(player >= 0 and player < WahooState.NUM_PLAYERS, "player must be in 0..3")

static func _assert_index(value: int, limit: int, label: String) -> void:
    assert(value >= 0 and value < limit, "%s must be in 0..%d" % [label, limit - 1])
