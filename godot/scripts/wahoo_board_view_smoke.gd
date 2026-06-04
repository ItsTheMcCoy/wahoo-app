class_name WahooBoardViewSmoke
extends RefCounted

const WahooBoardView = preload("res://scripts/wahoo_board_view.gd")

static func run() -> Dictionary:
    var failures: Array[String] = []
    var passed := 0
    var total := 0

    for test in [
        _test_touch_mouse_press_debounce,
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

static func _test_touch_mouse_press_debounce() -> Dictionary:
    var name := "touch mouse press debounce"
    var board = WahooBoardView.new()
    board._cell_size = 50.0
    board._last_touch_press_msec = Time.get_ticks_msec()
    board._last_touch_press_position = Vector2(100.0, 100.0)

    if not board.call("_is_duplicate_mouse_press_after_touch", Vector2(110.0, 108.0)):
        board.free()
        return _fail(name, "expected nearby mouse press after touch to be ignored")
    if board.call("_is_duplicate_mouse_press_after_touch", Vector2(170.0, 170.0)):
        board.free()
        return _fail(name, "expected distant mouse press after touch to be allowed")

    board._last_touch_press_msec = Time.get_ticks_msec() - 1000
    if board.call("_is_duplicate_mouse_press_after_touch", Vector2(100.0, 100.0)):
        board.free()
        return _fail(name, "expected stale mouse press after touch to be allowed")

    board.free()
    return _ok(name)
