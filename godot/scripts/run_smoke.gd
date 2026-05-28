extends SceneTree

const WahooRulesSmoke = preload("res://scripts/wahoo_rules_smoke.gd")
const WahooLayoutSmoke = preload("res://scripts/wahoo_layout_smoke.gd")

func _init() -> void:
    var suites := [
        ["rules", WahooRulesSmoke.run()],
        ["layout", WahooLayoutSmoke.run()],
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
