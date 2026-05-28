extends SceneTree

const WahooRulesSmoke = preload("res://scripts/wahoo_rules_smoke.gd")
const WahooLayoutSmoke = preload("res://scripts/wahoo_layout_smoke.gd")
const WahooAI = preload("res://scripts/wahoo_ai.gd")
const WahooAISmoke = preload("res://scripts/wahoo_ai_smoke.gd")

func _ai_load_smoke() -> Dictionary:
    var passed := 0
    var total := 0
    var failures: Array[String] = []

    # Verify all named profiles can be instantiated
    var profiles := WahooAI.make_profiles()
    var expected_keys := ["random", "sprinter", "swarm", "assassin", "gambler",
        "tortoise", "gatekeeper", "engineer", "balanced", "human_like"]
    for key in expected_keys:
        total += 1
        if profiles.has(key) and profiles[key] != null:
            passed += 1
        else:
            failures.append("profile '%s' missing or null" % key)

    # Verify RandomPlayer responds to choose_move
    total += 1
    var state = preload("res://scripts/wahoo_state.gd").new_game()
    state.marbles[0][0] = ["TRACK", 0]
    var moves := [{"marble": 0, "dest": ["TRACK", 1], "kind": "advance", "captures": null}]
    var rand_player = profiles["random"]
    var chosen: Dictionary = rand_player.choose_move(state, 0, 1, moves)
    if chosen == moves[0]:
        passed += 1
    else:
        failures.append("RandomPlayer.choose_move returned unexpected result")

    # Verify GreedyPlayer responds to choose_move
    total += 1
    var greedy_player = profiles["sprinter"]
    var greedy_chosen: Dictionary = greedy_player.choose_move(state, 0, 1, moves)
    if greedy_chosen == moves[0]:
        passed += 1
    else:
        failures.append("GreedyPlayer.choose_move returned unexpected result")

    return {"passed": passed, "total": total, "failures": failures}

func _init() -> void:
    var suites := [
        ["rules", WahooRulesSmoke.run()],
        ["layout", WahooLayoutSmoke.run()],
        ["ai_load", _ai_load_smoke()],
        ["ai_smoke", WahooAISmoke.run()],
    ]
    var passed := 0
    var total := 0
    var failures: Array[String] = []

    for suite in suites:
        var suite_name := String(suite[0])
        var result: Dictionary = suite[1]
        passed += int(result.get("passed", 0))
        total += int(result.get("total", 0))
        for failure in result.get("failures", []):
            failures.append("%s: %s" % [suite_name, String(failure)])

    print("Wahoo Godot smoke tests: %d/%d passed" % [passed, total])
    if failures.is_empty():
        quit(0)
        return

    print("Failures:")
    for failure in failures:
        print("- %s" % String(failure))

    quit(1)
