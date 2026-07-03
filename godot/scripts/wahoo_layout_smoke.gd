class_name WahooLayoutSmoke
extends RefCounted

const WahooLayout = preload("res://scripts/wahoo_layout.gd")
const WahooResponsiveLayout = preload("res://scripts/wahoo_responsive_layout.gd")
const WahooState = preload("res://scripts/wahoo_state.gd")

static func run() -> Dictionary:
    var failures: Array[String] = []
    var passed := 0
    var total := 0

    for test in [
        _test_track_has_56_unique_coordinates,
        _test_key_rule_locations_match_layout,
        _test_home_and_base_clusters_have_expected_sizes,
        _test_base_clusters_are_consistently_placed_from_exits,
        _test_location_lookup_needs_owner_for_owned_areas,
        _test_all_normalized_coordinates_are_in_unit_square,
        _test_main_scene_uses_compact_layout_for_mobile_landscape,
        _test_main_scene_uses_short_landscape_sizing_for_wide_short_viewports,
        _test_mobile_like_detection_covers_phone_portrait_and_landscape,
        _test_phone_browser_detection_uses_css_pixels,
        _test_phone_browser_unit_scale_converts_css_to_virtual_units,
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

static func _test_base_clusters_are_consistently_placed_from_exits() -> Dictionary:
    var name := "layout base positions form perpendicular lines from base exits"
    for player in range(WahooState.NUM_PLAYERS):
        var exit_coord := WahooLayout.track_grid_coord(WahooState.base_exit(player))
        var base_coords := WahooLayout.base_cluster_grid_coords(player)
        if base_coords.size() != WahooState.MARBLES_PER_PLAYER:
            return _fail(name, "player %d base size mismatch" % player)

        var opening_next: Vector2i = WahooLayout.track_grid_coord(WahooState.base_exit(player) + 1)
        var track_dir: Vector2i = opening_next - exit_coord
        var first_offset: Vector2i = base_coords[0] - exit_coord
        var line_step := Vector2i(signi(first_offset.x), signi(first_offset.y))

        if abs(first_offset.x) + abs(first_offset.y) != 1:
            return _fail(name, "player %d first base spot should be 1 cell from base exit" % player)

        # Perpendicular means dot(track_dir, first_offset) == 0.
        var dot_value := track_dir.x * first_offset.x + track_dir.y * first_offset.y
        if dot_value != 0:
            return _fail(name, "player %d base line is not perpendicular to opening track" % player)

        for i in range(1, base_coords.size()):
            var step: Vector2i = base_coords[i] - base_coords[i - 1]
            if step != line_step:
                return _fail(name, "player %d base line step mismatch at index %d" % [player, i])
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

static func _test_main_scene_uses_compact_layout_for_mobile_landscape() -> Dictionary:
    var name := "main scene uses compact layout for mobile landscape viewports"
    if not WahooResponsiveLayout.is_main_scene_compact(Vector2(844, 390)):
        return _fail(name, "expected 844x390 viewport to use compact layout")
    if WahooResponsiveLayout.is_main_scene_compact(Vector2(1366, 768)):
        return _fail(name, "expected 1366x768 viewport to remain in two-column layout")
    return _ok(name)

static func _test_main_scene_uses_short_landscape_sizing_for_wide_short_viewports() -> Dictionary:
    var name := "main scene slims side panel for wide short landscape viewports"
    if not WahooResponsiveLayout.is_short_landscape(Vector2(1024, 600)):
        return _fail(name, "expected 1024x600 viewport to use short-landscape side-panel sizing")
    if WahooResponsiveLayout.is_short_landscape(Vector2(1366, 900)):
        return _fail(name, "expected 1366x900 viewport to keep full desktop side-panel sizing")
    return _ok(name)

static func _test_mobile_like_detection_covers_phone_portrait_and_landscape() -> Dictionary:
    var name := "responsive layout detects phone-sized portrait and landscape canvases"
    if not WahooResponsiveLayout.is_mobile_like_layout(Vector2(390, 844)):
        return _fail(name, "expected 390x844 viewport to use mobile-like layout")
    if not WahooResponsiveLayout.is_mobile_like_layout(Vector2(844, 390)):
        return _fail(name, "expected 844x390 viewport to use mobile-like layout")
    if WahooResponsiveLayout.is_mobile_like_layout(Vector2(1280, 720)):
        return _fail(name, "expected 1280x720 viewport to remain desktop-like")
    return _ok(name)

static func _test_phone_browser_detection_uses_css_pixels() -> Dictionary:
    var name := "phone browser detection classifies CSS window sizes"
    if not WahooResponsiveLayout.is_phone_browser_portrait(Vector2(390, 844)):
        return _fail(name, "expected 390x844 CSS window to be a portrait phone")
    if WahooResponsiveLayout.is_phone_browser_landscape(Vector2(390, 844)):
        return _fail(name, "portrait phone must not classify as landscape")
    if not WahooResponsiveLayout.is_phone_browser_landscape(Vector2(844, 390)):
        return _fail(name, "expected 844x390 CSS window to be a landscape phone")
    if WahooResponsiveLayout.is_phone_browser_portrait(Vector2(1920, 1080)):
        return _fail(name, "desktop window must not classify as portrait phone")
    if WahooResponsiveLayout.is_phone_browser_landscape(Vector2(1900, 550)):
        return _fail(name, "short wide desktop window must keep desktop layout")
    if WahooResponsiveLayout.is_phone_browser_portrait(Vector2(768, 1024)):
        return _fail(name, "tablet portrait must keep current behavior")
    if WahooResponsiveLayout.is_phone_browser_portrait(Vector2.ZERO):
        return _fail(name, "native builds (no CSS size) must not classify as phone")
    return _ok(name)

static func _test_phone_browser_unit_scale_converts_css_to_virtual_units() -> Dictionary:
    var name := "phone browser unit scale converts CSS px to virtual units"
    # Portrait phone: CSS 390x844 stretches to a 1280-wide virtual viewport.
    var portrait_scale: float = WahooResponsiveLayout.phone_browser_unit_scale(
        Vector2(1280, 2770), Vector2(390, 844))
    if absf(portrait_scale - 1280.0 / 390.0) > 0.001:
        return _fail(name, "portrait scale was %f, expected %f" % [portrait_scale, 1280.0 / 390.0])
    # Landscape phone: CSS 844x390 stretches to a 720-tall virtual viewport.
    var landscape_scale: float = WahooResponsiveLayout.phone_browser_unit_scale(
        Vector2(1558, 720), Vector2(844, 390))
    if absf(landscape_scale - 720.0 / 390.0) > 0.001:
        return _fail(name, "landscape scale was %f, expected %f" % [landscape_scale, 720.0 / 390.0])
    # Desktop windows and native builds must stay unscaled.
    if WahooResponsiveLayout.phone_browser_unit_scale(Vector2(1920, 1080), Vector2(1920, 1080)) != 1.0:
        return _fail(name, "desktop window must stay unscaled")
    if WahooResponsiveLayout.phone_browser_unit_scale(Vector2(2487, 720), Vector2(1900, 550)) != 1.0:
        return _fail(name, "short wide desktop window must stay unscaled")
    if WahooResponsiveLayout.phone_browser_unit_scale(Vector2(1280, 720), Vector2.ZERO) != 1.0:
        return _fail(name, "native builds must stay unscaled")
    return _ok(name)
