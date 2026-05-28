class_name WahooRulesSmoke
extends RefCounted

static func run() -> Dictionary:
    var failures: Array[String] = []
    var passed := 0
    var total := 0

    for test in [
        _test_base_exit,
        _test_base_exit_capture,
        _test_cannot_exit_onto_own_marble,
        _test_center_entry_optional,
        _test_cannot_enter_center_by_jumping_own_marble,
        _test_no_center_after_first_6,
        _test_center_capture_on_entry,
        _test_center_exit,
        _test_capture_opponent_on_track,
        _test_cannot_pass_own_marble,
        _test_wrap_around_track,
        _test_home_entry_indices_all_players,
        _test_home_entry_no_exact,
        _test_home_overshoot_illegal,
        _test_home_blocked_by_own_marble,
        _test_win_condition,
        _test_format_location_uses_human_friendly_home_numbers,
        _test_exact_landing_on_home_entry_stays_on_track,
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

static func _find_move(moves: Array, kind: String, dest: Variant = null) -> Variant:
    for move in moves:
        if String(move["kind"]) != kind:
            continue
        if dest == null or move["dest"] == dest:
            return move
    return null

static func _test_base_exit() -> Dictionary:
    var name := "base exit on 1 and 6"
    var state := WahooState.new_game()
    for roll in [1, 6]:
        var moves := WahooRules.legal_moves(state, 0, roll)
        var move = _find_move(moves, "exit_base", WahooState.loc_track(0))
        if move == null:
            return _fail(name, "missing exit_base for roll %d" % roll)
    for roll in [2, 3, 4, 5]:
        var moves := WahooRules.legal_moves(state, 0, roll)
        if _find_move(moves, "exit_base") != null:
            return _fail(name, "unexpected exit_base for roll %d" % roll)
    return _ok(name)

static func _test_base_exit_capture() -> Dictionary:
    var name := "base exit captures opponent"
    var state := WahooState.new_game()
    state.marbles[1][0] = WahooState.loc_track(0)
    var moves := WahooRules.legal_moves(state, 0, 1)
    var move = _find_move(moves, "exit_base")
    if move == null:
        return _fail(name, "missing exit_base capture move")
    if move["captures"] != [1, 0]:
        return _fail(name, "expected capture [1, 0], got %s" % str(move["captures"]))
    WahooRules.apply_move(state, move)
    if state.marbles[1][0] != WahooState.loc_base():
        return _fail(name, "captured marble did not return to base")
    if state.marbles[0][0] != WahooState.loc_track(0):
        return _fail(name, "moving marble did not land on exit square")
    return _ok(name)

static func _test_cannot_exit_onto_own_marble() -> Dictionary:
    var name := "cannot exit base onto own marble"
    var state := WahooState.new_game()
    state.marbles[0][0] = WahooState.loc_track(0)
    var moves := WahooRules.legal_moves(state, 0, 6)
    for move in moves:
        if String(move["kind"]) == "exit_base":
            return _fail(name, "exit_base should be blocked by own marble on base-exit")
    return _ok(name)

static func _test_center_entry_optional() -> Dictionary:
    var name := "center entry remains optional"
    var state := WahooState.new_game()
    state.marbles[0][0] = WahooState.loc_track(WahooState.base_exit(0) + 2)
    var moves := WahooRules.legal_moves(state, 0, 4)
    if _find_move(moves, "enter_center") == null:
        return _fail(name, "missing enter_center option")
    if _find_move(moves, "advance") == null:
        return _fail(name, "missing advance option alongside center")
    return _ok(name)

static func _test_cannot_enter_center_by_jumping_own_marble() -> Dictionary:
    var name := "own marble blocks center entry"
    var state := WahooState.new_game()
    state.marbles[0][0] = WahooState.loc_track(WahooState.base_exit(0) + 2)
    state.marbles[0][1] = WahooState.loc_track(WahooState.base_exit(0) + 3)
    var moves := WahooRules.legal_moves(state, 0, 4)
    if _find_move(moves, "enter_center") != null:
        return _fail(name, "center entry should be blocked")
    for move in moves:
        if int(move["marble"]) == 0:
            return _fail(name, "blocked marble should have no legal moves")
    return _ok(name)

static func _test_no_center_after_first_6() -> Dictionary:
    var name := "no center entry after offset 5"
    var state := WahooState.new_game()
    state.marbles[0][0] = WahooState.loc_track(WahooState.base_exit(0) + 6)
    for roll in [1, 2, 3, 4, 5, 6]:
        var moves := WahooRules.legal_moves(state, 0, roll)
        if _find_move(moves, "enter_center") != null:
            return _fail(name, "unexpected center entry from offset 6 on roll %d" % roll)
    return _ok(name)

static func _test_center_capture_on_entry() -> Dictionary:
    var name := "entering center captures occupant"
    var state := WahooState.new_game()
    state.marbles[0][0] = WahooState.loc_track(WahooState.base_exit(0))
    state.marbles[1][0] = WahooState.loc_center()
    state.center_occupant = [1, 0]
    var moves := WahooRules.legal_moves(state, 0, 6)
    var move = _find_move(moves, "enter_center")
    if move == null:
        return _fail(name, "missing center entry move")
    if move["captures"] != [1, 0]:
        return _fail(name, "expected center capture [1, 0], got %s" % str(move["captures"]))
    WahooRules.apply_move(state, move)
    if state.marbles[1][0] != WahooState.loc_base():
        return _fail(name, "captured center marble did not return to base")
    if state.center_occupant != [0, 0]:
        return _fail(name, "center occupant did not update to entering marble")
    return _ok(name)

static func _test_center_exit() -> Dictionary:
    var name := "center exit lands on previous segment offset 5"
    for player in range(WahooState.NUM_PLAYERS):
        var state := WahooState.new_game()
        state.marbles[player][0] = WahooState.loc_center()
        state.center_occupant = [player, 0]
        var moves := WahooRules.legal_moves(state, player, 1)
        var expected_dest := WahooState.loc_track(WahooState.center_exit_dest(player))
        var move = _find_move(moves, "exit_center", expected_dest)
        if move == null:
            return _fail(name, "player %d missing exit_center to %s" % [player, str(expected_dest)])
    return _ok(name)

static func _test_capture_opponent_on_track() -> Dictionary:
    var name := "landing on opponent captures"
    var state := WahooState.new_game()
    state.marbles[0][0] = WahooState.loc_track(5)
    state.marbles[1][0] = WahooState.loc_track(8)
    var moves := WahooRules.legal_moves(state, 0, 3)
    var move = _find_move(moves, "advance", WahooState.loc_track(8))
    if move == null:
        return _fail(name, "missing advance capture to track 8")
    if move["captures"] != [1, 0]:
        return _fail(name, "expected capture [1, 0], got %s" % str(move["captures"]))
    WahooRules.apply_move(state, move)
    if state.marbles[1][0] != WahooState.loc_base():
        return _fail(name, "captured marble did not return to base")
    if state.marbles[0][0] != WahooState.loc_track(8):
        return _fail(name, "moving marble did not land on capture square")
    return _ok(name)

static func _test_cannot_pass_own_marble() -> Dictionary:
    var name := "cannot pass own marble on track"
    var state := WahooState.new_game()
    state.marbles[0][0] = WahooState.loc_track(5)
    state.marbles[0][1] = WahooState.loc_track(7)
    var moves := WahooRules.legal_moves(state, 0, 3)
    for move in moves:
        if int(move["marble"]) == 0 and String(move["kind"]) == "advance":
            return _fail(name, "advance should be blocked when own marble is in the path")
    return _ok(name)

static func _test_wrap_around_track() -> Dictionary:
    var name := "track wraps around 55 to 0"
    var state := WahooState.new_game()
    state.marbles[1][0] = WahooState.loc_track(54)
    var moves := WahooRules.legal_moves(state, 1, 3)
    if _find_move(moves, "advance", WahooState.loc_track(1)) == null:
        return _fail(name, "expected wraparound advance to track 1")
    return _ok(name)

static func _test_home_entry_indices_all_players() -> Dictionary:
    var name := "home_entry indices match board mapping"
    var expected := [54, 12, 26, 40]
    for player in range(WahooState.NUM_PLAYERS):
        var actual := WahooState.home_entry(player)
        if actual != expected[player]:
            return _fail(name, "player %d expected %d got %d" % [player, expected[player], actual])
    return _ok(name)

static func _test_home_entry_no_exact() -> Dictionary:
    var name := "home entry does not require exact roll"
    var state := WahooState.new_game()
    state.marbles[0][0] = WahooState.loc_track(WahooState.home_entry(0))
    for roll in [1, 2, 3, 4]:
        var expected_kind := "enter_home" if roll == 1 else "advance_home"
        var expected_dest := WahooState.loc_home(roll - 1)
        var moves := WahooRules.legal_moves(state, 0, roll)
        if _find_move(moves, expected_kind, expected_dest) == null:
            return _fail(name, "roll %d missing %s to %s" % [roll, expected_kind, str(expected_dest)])
    return _ok(name)

static func _test_home_overshoot_illegal() -> Dictionary:
    var name := "home overshoot is illegal"
    var state := WahooState.new_game()
    state.marbles[0][0] = WahooState.loc_home(2)
    var moves := WahooRules.legal_moves(state, 0, 2)
    if _find_move(moves, "advance_home") != null:
        return _fail(name, "overshoot from home slot 2 by roll 2 should be illegal")
    moves = WahooRules.legal_moves(state, 0, 1)
    if _find_move(moves, "advance_home", WahooState.loc_home(3)) == null:
        return _fail(name, "roll 1 from home slot 2 should reach home slot 3")
    return _ok(name)

static func _test_home_blocked_by_own_marble() -> Dictionary:
    var name := "cannot land on occupied home slot"
    var state := WahooState.new_game()
    state.marbles[0][0] = WahooState.loc_home(2)
    state.marbles[0][1] = WahooState.loc_home(3)
    var moves := WahooRules.legal_moves(state, 0, 1)
    for move in moves:
        if int(move["marble"]) == 0:
            return _fail(name, "marble 0 should be blocked by own marble in home slot 3")
    return _ok(name)

static func _test_win_condition() -> Dictionary:
    var name := "player wins with four marbles in home"
    var state := WahooState.new_game()
    for marble in range(WahooState.MARBLES_PER_PLAYER):
        state.marbles[0][marble] = WahooState.loc_home(marble)
    if not state.player_won(0):
        return _fail(name, "expected player 0 to be in a winning state")
    if state.player_won(1):
        return _fail(name, "player 1 should not be in a winning state")
    return _ok(name)

static func _test_format_location_uses_human_friendly_home_numbers() -> Dictionary:
    var name := "format_location uses one-based home labels"
    if WahooState.format_location(WahooState.loc_home(0)) != "home:1":
        return _fail(name, "home slot 0 should format as home:1")
    if WahooState.format_location(WahooState.loc_home(3)) != "home:4":
        return _fail(name, "home slot 3 should format as home:4")
    return _ok(name)

static func _test_exact_landing_on_home_entry_stays_on_track() -> Dictionary:
    var name := "exact landing on home entry stays on track"
    var state := WahooState.new_game()
    state.marbles[3][0] = WahooState.loc_track(38)
    state.current_player = 3

    var moves := WahooRules.legal_moves(state, 3, 2)
    var advance = _find_move(moves, "advance", WahooState.loc_track(WahooState.home_entry(3)))
    if advance == null:
        return _fail(name, "expected advance to home-entry square")

    state.marbles[3][0] = WahooState.loc_track(WahooState.home_entry(3))
    moves = WahooRules.legal_moves(state, 3, 2)
    if _find_move(moves, "advance", WahooState.loc_track(WahooState.base_exit(3))) != null:
        return _fail(name, "should not continue on loop from home-entry square")
    if _find_move(moves, "advance_home", WahooState.loc_home(1)) == null:
        return _fail(name, "expected advance_home to slot 1 from home-entry square")

    for roll in [5, 6]:
        moves = WahooRules.legal_moves(state, 3, roll)
        for move in moves:
            if int(move["marble"]) == 0:
                return _fail(name, "roll %d should leave marble 0 without a legal move" % roll)
    return _ok(name)