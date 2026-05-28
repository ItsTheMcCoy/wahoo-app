class_name WahooLayoutSmoke
extends RefCounted

const WahooLayout = preload("res://scripts/wahoo_layout.gd")
const WahooState = preload("res://scripts/wahoo_state.gd")

static func run() -> Dictionary:
    var failures: Array[String] = []
    var passed := 0
    var total := 0

    for test in [
        _test_track_has_56_unique_coordinates,
        _test_key_rule_locations_match_layout,
        _test_home_and_base_clusters_have_expected_sizes,
        _test_location_lookup_needs_owner_for_owned_areas,
        _test_all_normalized_coordinates_are_in_unit_square,
    ]:
        total += 1
        var result: Dictionary = test.call()
        if bool(result["passed"]):
            passed += 1
        else:
            failures.append(String(result["name"]) + ": " + String(result["message"]))

    return {
        "passed": passed,
        "total": total,
        "failures": failures,
    }

static func _ok(name: String) -> Dictionary:
    return {"name": name, "passed": true, "message": ""}

static func _fail(name: String, message: String) -> Dictionary:
    return {"name": name, "passed": false, "message": message}

static func _test_track_has_56_unique_coordinates() -> Dictionary:
    var name := "layout track has 56 unique coordinates"
    var coords := WahooLayout.all_track_grid_coords()
    if coords.size() != WahooState.LOOP_SIZE:
        return _fail(name, "expected 56 track coords, got %d" % coords.size())

    var seen := {}
    for coord in coords:
        var key := "%d,%d" % [coord.x, coord.y]
        if seen.has(key):
            return _fail(name, "duplicate track coordinate %s" % key)
        seen[key] = true

    return _ok(name)

static func _test_key_rule_locations_match_layout() -> Dictionary:
    var name := "layout key rule locations match board topology"
    var expected_base_exits := [
        Vector2i(10, 2),
        Vector2i(15, 11),
        Vector2i(6, 16),
        Vector2i(1, 7),
    ]
    var expected_home_entries := [
        Vector2i(8, 2),
        Vector2i(15, 9),
        Vector2i(8, 16),
        Vector2i(1, 9),
    ]
    var expected_center_exits := [
        Vector2i(6, 7),
        Vector2i(10, 7),
        Vector2i(10, 11),
        Vector2i(6, 11),
    ]

    for player in range(WahooState.NUM_PLAYERS):
        if WahooLayout.track_grid_coord(WahooState.base_exit(player)) != expected_base_exits[player]:
            return _fail(name, "player %d base-exit coordinate mismatch" % player)
        if WahooLayout.track_grid_coord(WahooState.home_entry(player)) != expected_home_entries[player]:
            return _fail(name, "player %d home-entry coordinate mismatch" % player)
        if WahooLayout.track_grid_coord(WahooState.center_exit_dest(player)) != expected_center_exits[player]:
            return _fail(name, "player %d center-exit coordinate mismatch" % player)

    return _ok(name)

static func _test_home_and_base_clusters_have_expected_sizes() -> Dictionary:
    var name := "layout home rows and base clusters have expected sizes"
    for player in range(WahooState.NUM_PLAYERS):
        if WahooLayout.home_row_grid_coords(player).size() != WahooState.HOME_SLOTS:
            return _fail(name, "player %d home row size mismatch" % player)
        if WahooLayout.base_cluster_grid_coords(player).size() != WahooState.MARBLES_PER_PLAYER:
            return _fail(name, "player %d base cluster size mismatch" % player)
    return _ok(name)

static func _test_location_lookup_needs_owner_for_owned_areas() -> Dictionary:
    var name := "layout location lookup maps owned areas by owner"
    if WahooLayout.location_grid_coord(WahooState.loc_track(0)) != WahooLayout.track_grid_coord(0):
        return _fail(name, "track location lookup mismatch")
    if WahooLayout.location_grid_coord(WahooState.loc_center()) != WahooLayout.center_grid_coord():
        return _fail(name, "center location lookup mismatch")
    if WahooLayout.location_grid_coord(WahooState.loc_home(2), 1) != WahooLayout.home_grid_coord(1, 2):
        return _fail(name, "home location lookup mismatch")
    if WahooLayout.location_grid_coord(WahooState.loc_base(), 3, 2) != WahooLayout.base_grid_coord(3, 2):
        return _fail(name, "base location lookup mismatch")
    return _ok(name)

static func _test_all_normalized_coordinates_are_in_unit_square() -> Dictionary:
    var name := "layout normalized coordinates are inside unit square"
    var coords := WahooLayout.all_track_grid_coords()
    coords.append(WahooLayout.center_grid_coord())
    for player in range(WahooState.NUM_PLAYERS):
        coords.append_array(WahooLayout.home_row_grid_coords(player))
        coords.append_array(WahooLayout.base_cluster_grid_coords(player))

    for coord in coords:
        var normalized := WahooLayout.grid_to_normalized(coord)
        if normalized.x <= 0.0 or normalized.x >= 1.0 or normalized.y <= 0.0 or normalized.y >= 1.0:
            return _fail(name, "coordinate %s normalized out of bounds as %s" % [str(coord), str(normalized)])

    return _ok(name)
