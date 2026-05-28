extends SceneTree

const WahooRulesSmoke = preload("res://scripts/wahoo_rules_smoke.gd")

func _init() -> void:
    var result := WahooRulesSmoke.run()
    var passed := int(result.get("passed", 0))
    var total := int(result.get("total", 0))
    var failures: Array = result.get("failures", [])

    print("Wahoo Godot smoke tests: %d/%d passed" % [passed, total])
    if failures.is_empty():
        quit(0)
        return

    print("Failures:")
    for failure in failures:
        print("- %s" % String(failure))

    quit(1)
