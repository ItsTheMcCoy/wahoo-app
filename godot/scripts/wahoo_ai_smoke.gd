class_name WahooAISmoke
extends RefCounted

const WahooState = preload("res://scripts/wahoo_state.gd")
const WahooRules = preload("res://scripts/wahoo_rules.gd")
const WahooAI = preload("res://scripts/wahoo_ai.gd")

static func run() -> Dictionary:
	var failures: Array[String] = []
	var passed := 0
	var total := 0

	for test in [
		_test_win_guardrail,
		_test_center_temptation,
		_test_capture_vs_deploy,
		_test_finish_or_fight,
		_test_center_denial,
		_test_threat_escape,
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

static func _legal_moves(state, player: int, roll: int) -> Array:
	return WahooRules.new().call("legal_moves", state, player, roll)

# ---------------------------------------------------------------------------
# Probe 1 — Win guardrail (all profiles must take the immediate win)
# ---------------------------------------------------------------------------

static func _test_win_guardrail() -> Dictionary:
	var name := "win guardrail: all profiles take the immediate win"
	var roll := 1
	var he := WahooState.home_entry(0)

	# P0: HOME(1), HOME(2), HOME(3), TRACK(he). Roll 1 brings TRACK(he) → HOME(0) = win.
	# HOME slots 1/2/3 are blocked; HOME(3)+1 overshoots. Only one legal move.
	var state = WahooState.new_game()
	state.marbles[0][0] = WahooState.loc_home(1)
	state.marbles[0][1] = WahooState.loc_home(2)
	state.marbles[0][2] = WahooState.loc_home(3)
	state.marbles[0][3] = WahooState.loc_track(he)

	var moves := _legal_moves(state, 0, roll)
	var winning_moves: Array = moves.filter(func(m): return m["dest"] == WahooState.loc_home(0))
	if winning_moves.size() != 1:
		return _fail(name, "expected exactly one winning move, got %d" % winning_moves.size())
	var winning: Dictionary = winning_moves[0]

	var profiles := WahooAI.make_profiles()
	for profile_name in profiles:
		var player_obj = profiles[profile_name]
		var chosen: Dictionary = player_obj.choose_move(state, 0, roll, moves)
		if chosen != winning:
			return _fail(name, "profile '%s' did not take the winning move" % profile_name)

	return _ok(name)

# ---------------------------------------------------------------------------
# Probe 2 — Center temptation (shortcut-friendly profiles prefer center)
# ---------------------------------------------------------------------------

static func _test_center_temptation() -> Dictionary:
	var name := "center temptation: shortcut profiles enter center"
	var roll := 1

	# P0 marble at TRACK(5) = base_exit(0)+5; roll 1 = 6-5 → center eligible.
	# Moves: enter_center, advance TRACK(6), advance TRACK(19), exit_base to TRACK(0) (x2).
	var state = WahooState.new_game()
	state.marbles[0][2] = WahooState.loc_track(5)
	state.marbles[0][3] = WahooState.loc_track(18)

	var moves := _legal_moves(state, 0, roll)
	var center_moves: Array = moves.filter(func(m): return String(m["kind"]) == "enter_center")
	if center_moves.size() == 0:
		return _fail(name, "expected an enter_center move in move list")
	var center_move: Dictionary = center_moves[0]

	var profiles := WahooAI.make_profiles()

	for profile_name in ["sprinter", "gambler"]:
		var chosen: Dictionary = profiles[profile_name].choose_move(state, 0, roll, moves)
		if chosen != center_move:
			return _fail(name, "profile '%s' should prefer entering center" % profile_name)

	var swarm_choice: Dictionary = profiles["swarm"].choose_move(state, 0, roll, moves)
	if String(swarm_choice["kind"]) != "exit_base":
		return _fail(name, "profile 'swarm' should prefer deploying a new marble")

	var tortoise_choice: Dictionary = profiles["tortoise"].choose_move(state, 0, roll, moves)
	if String(tortoise_choice["kind"]) == "enter_center":
		return _fail(name, "profile 'tortoise' should avoid entering center")

	return _ok(name)

# ---------------------------------------------------------------------------
# Probe 3 — Capture vs deploy (Assassin and Gatekeeper prefer capture)
# ---------------------------------------------------------------------------

static func _test_capture_vs_deploy() -> Dictionary:
	var name := "capture vs deploy: assassin/gatekeeper capture, swarm deploys"
	var roll := 6

	# P0 marble at TRACK(7); roll 6 → TRACK(13) capturing P1 marble 0.
	# P0 also has base marbles that can exit on roll 6.
	var state = WahooState.new_game()
	state.marbles[0][2] = WahooState.loc_track(7)
	state.marbles[0][3] = WahooState.loc_track(22)
	state.marbles[1][0] = WahooState.loc_track(13)

	var moves := _legal_moves(state, 0, roll)
	var capture_moves: Array = moves.filter(func(m): return m.get("captures", null) != null)
	if capture_moves.size() == 0:
		return _fail(name, "expected at least one capture move")
	var capture_move: Dictionary = capture_moves[0]
	if capture_move["dest"] != WahooState.loc_track(13):
		return _fail(name, "capture move destination should be TRACK(13), got %s" % str(capture_move["dest"]))

	var has_deploy := moves.any(func(m): return String(m["kind"]) == "exit_base")
	if not has_deploy:
		return _fail(name, "expected at least one deploy move on roll 6")

	var profiles := WahooAI.make_profiles()

	for profile_name in ["assassin", "gatekeeper"]:
		var chosen: Dictionary = profiles[profile_name].choose_move(state, 0, roll, moves)
		if chosen != capture_move:
			return _fail(name, "profile '%s' should prefer capturing" % profile_name)

	var swarm_choice: Dictionary = profiles["swarm"].choose_move(state, 0, roll, moves)
	if String(swarm_choice["kind"]) != "exit_base":
		return _fail(name, "profile 'swarm' should prefer deploying a new marble")

	return _ok(name)

# ---------------------------------------------------------------------------
# Probe 4 — Finish or fight (closers prefer home, fighters prefer capture)
# ---------------------------------------------------------------------------

static func _test_finish_or_fight() -> Dictionary:
	var name := "finish or fight: engineer/tortoise/balanced go home, assassin/gatekeeper capture"
	var roll := 3

	# P0: HOME(3) deep, BASE marble, TRACK(home_entry) → HOME(2) on roll 3,
	#     TRACK(10) → TRACK(13) capturing P1 marble 0.
	var state = WahooState.new_game()
	state.marbles[0][0] = WahooState.loc_home(3)
	state.marbles[0][2] = WahooState.loc_track(WahooState.home_entry(0))
	state.marbles[0][3] = WahooState.loc_track(10)
	state.marbles[1][0] = WahooState.loc_track(13)

	var moves := _legal_moves(state, 0, roll)
	var home_moves: Array = moves.filter(func(m): return m["dest"] == WahooState.loc_home(2))
	if home_moves.size() == 0:
		return _fail(name, "expected a home move to HOME(2)")
	var home_move: Dictionary = home_moves[0]

	var capture_moves: Array = moves.filter(func(m): return m.get("captures", null) != null)
	if capture_moves.size() == 0:
		return _fail(name, "expected a capture move")
	var capture_move: Dictionary = capture_moves[0]
	if capture_move["dest"] != WahooState.loc_track(13):
		return _fail(name, "capture move destination should be TRACK(13), got %s" % str(capture_move["dest"]))

	var profiles := WahooAI.make_profiles()

	for profile_name in ["engineer", "tortoise", "balanced"]:
		var chosen: Dictionary = profiles[profile_name].choose_move(state, 0, roll, moves)
		if chosen != home_move:
			return _fail(name, "profile '%s' should prefer home progress" % profile_name)

	for profile_name in ["assassin", "gatekeeper"]:
		var chosen: Dictionary = profiles[profile_name].choose_move(state, 0, roll, moves)
		if chosen != capture_move:
			return _fail(name, "profile '%s' should prefer the capture" % profile_name)

	return _ok(name)

# ---------------------------------------------------------------------------
# Probe 5 — Center denial (Gatekeeper and Assassin bump opponent from center)
# ---------------------------------------------------------------------------

static func _test_center_denial() -> Dictionary:
	var name := "center denial: gatekeeper/assassin bump opponent from center"
	var roll := 1

	# P1 marble 0 is in center. P0 marble at TRACK(5) can enter center and bump it.
	var state = WahooState.new_game()
	state.marbles[0][2] = WahooState.loc_track(5)
	state.marbles[0][3] = WahooState.loc_track(18)
	state.marbles[1][0] = WahooState.loc_center()
	state.center_occupant = [1, 0]

	var moves := _legal_moves(state, 0, roll)
	var denial_moves: Array = moves.filter(func(m): return String(m["kind"]) == "enter_center")
	if denial_moves.size() == 0:
		return _fail(name, "expected an enter_center (denial) move")
	var denial_move: Dictionary = denial_moves[0]
	if denial_move.get("captures", null) != [1, 0]:
		return _fail(name, "denial move should capture [1, 0] from center, got %s" % str(denial_move.get("captures", null)))

	var has_advance := moves.any(func(m): return String(m["kind"]) == "advance")
	if not has_advance:
		return _fail(name, "expected at least one non-center advance alternative")

	var profiles := WahooAI.make_profiles()

	for profile_name in ["gatekeeper", "assassin"]:
		var chosen: Dictionary = profiles[profile_name].choose_move(state, 0, roll, moves)
		if chosen != denial_move:
			return _fail(name, "profile '%s' should bump the opponent from center" % profile_name)

	return _ok(name)

# ---------------------------------------------------------------------------
# Probe 6 — Threat escape (Tortoise and Gatekeeper move away from danger)
# ---------------------------------------------------------------------------

static func _test_threat_escape() -> Dictionary:
	var name := "threat escape: tortoise/gatekeeper move threatened marble"
	var roll := 4

	# P0 marble 0 at TRACK(24) is threatened: P1 at TRACK(20) can roll 4 to capture it.
	# P0 marble 1 at TRACK(30) can advance to TRACK(34).
	# Safety-focused profiles should move marble 0 to TRACK(28) to escape.
	var state = WahooState.new_game()
	state.marbles[0][0] = WahooState.loc_track(24)
	state.marbles[0][1] = WahooState.loc_track(30)
	state.marbles[1][0] = WahooState.loc_track(20)

	var moves := _legal_moves(state, 0, roll)
	var escape_moves: Array = moves.filter(func(m): return int(m["marble"]) == 0)
	if escape_moves.size() == 0:
		return _fail(name, "expected a move for marble 0 (the threatened marble)")
	var escape_move: Dictionary = escape_moves[0]
	if escape_move["dest"] != WahooState.loc_track(28):
		return _fail(name, "escape move should go to TRACK(28), got %s" % str(escape_move["dest"]))

	var has_other_advance := moves.any(func(m): return m["dest"] == WahooState.loc_track(34))
	if not has_other_advance:
		return _fail(name, "expected a non-escape advance to TRACK(34)")

	var profiles := WahooAI.make_profiles()

	for profile_name in ["tortoise", "gatekeeper"]:
		var chosen: Dictionary = profiles[profile_name].choose_move(state, 0, roll, moves)
		if chosen != escape_move:
			return _fail(name, "profile '%s' should move away from capture danger" % profile_name)

	return _ok(name)
