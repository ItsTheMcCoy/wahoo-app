class_name WahooRules
extends RefCounted

static func legal_moves(state: WahooState, player: int, roll: int) -> Array:
    var moves: Array = []
    for marble_id in range(WahooState.MARBLES_PER_PLAYER):
        var loc: Array = state.marbles[player][marble_id]
        if loc[0] == "BASE":
            moves.append_array(_moves_from_base(state, player, marble_id, roll))
        elif loc[0] == "TRACK":
            moves.append_array(_moves_from_track(state, player, marble_id, roll, int(loc[1])))
        elif loc[0] == "HOME":
            moves.append_array(_moves_from_home(state, player, marble_id, roll, int(loc[1])))
        elif loc[0] == "CENTER":
            moves.append_array(_moves_from_center(state, player, marble_id, roll))
    return moves

static func _moves_from_base(state: WahooState, player: int, marble_id: int, roll: int) -> Array:
    if roll != 1 and roll != 6:
        return []
    var dest_idx := WahooState.base_exit(player)
    var occupant: Variant = state.marble_at_track(dest_idx)
    if occupant != null and int(occupant[0]) == player:
        return []
    return [{
        "marble": marble_id,
        "dest": WahooState.loc_track(dest_idx),
        "kind": "exit_base",
        "captures": occupant,
    }]

static func _moves_from_track(state: WahooState, player: int, marble_id: int, roll: int, current_idx: int) -> Array:
    var moves: Array = []
    var own_offset := WahooState.segment_offset(player, current_idx)

    if own_offset <= 5 and roll == (6 - own_offset):
        if not _path_to_center_blocked_by_own_marble(state, player, current_idx):
            var center_capture: Variant = state.center_occupant
            if center_capture == null or int(center_capture[0]) != player:
                moves.append({
                    "marble": marble_id,
                    "dest": WahooState.loc_center(),
                    "kind": "enter_center",
                    "captures": center_capture,
                })

    var move: Variant = _walk_forward(state, player, marble_id, current_idx, roll)
    if move != null:
        moves.append(move)

    return moves

static func _path_to_center_blocked_by_own_marble(state: WahooState, player: int, current_idx: int) -> bool:
    var own_offset := WahooState.segment_offset(player, current_idx)
    for offset in range(own_offset + 1, 6):
        var idx := posmod(WahooState.base_exit(player) + offset, WahooState.LOOP_SIZE)
        var occupant: Variant = state.marble_at_track(idx)
        if occupant != null and int(occupant[0]) == player:
            return true
    return false

static func _walk_forward(state: WahooState, player: int, marble_id: int, start_idx: int, steps: int) -> Variant:
    var own_home_entry := WahooState.home_entry(player)
    var idx := start_idx
    var remaining := steps
    var entered_home := false
    var home_slot := -1

    while remaining > 0 and not entered_home:
        var next_idx := posmod(idx + 1, WahooState.LOOP_SIZE)

        if idx == own_home_entry:
            entered_home = true
            home_slot = 0
            remaining -= 1
            if remaining == 0:
                if state.marble_at_home(player, 0) != null:
                    return null
                return {
                    "marble": marble_id,
                    "dest": WahooState.loc_home(0),
                    "kind": "enter_home",
                    "captures": null,
                }
            break

        var occupant: Variant = state.marble_at_track(next_idx)
        if occupant != null and int(occupant[0]) == player:
            return null

        idx = next_idx
        remaining -= 1

        if remaining == 0:
            return {
                "marble": marble_id,
                "dest": WahooState.loc_track(idx),
                "kind": "advance",
                "captures": occupant,
            }

    while remaining > 0:
        var next_slot := home_slot + 1
        if next_slot > WahooState.HOME_SLOTS - 1:
            return null
        if state.marble_at_home(player, next_slot) != null:
            return null
        home_slot = next_slot
        remaining -= 1

    return {
        "marble": marble_id,
        "dest": WahooState.loc_home(home_slot),
        "kind": "advance_home",
        "captures": null,
    }

static func _moves_from_home(state: WahooState, player: int, marble_id: int, roll: int, current_slot: int) -> Array:
    var new_slot := current_slot + roll
    if new_slot > WahooState.HOME_SLOTS - 1:
        return []
    for slot in range(current_slot + 1, new_slot + 1):
        if state.marble_at_home(player, slot) != null:
            return []
    return [{
        "marble": marble_id,
        "dest": WahooState.loc_home(new_slot),
        "kind": "advance_home",
        "captures": null,
    }]

static func _moves_from_center(state: WahooState, player: int, marble_id: int, roll: int) -> Array:
    if roll != 1:
        return []
    var dest_idx := WahooState.center_exit_dest(player)
    var occupant: Variant = state.marble_at_track(dest_idx)
    if occupant != null and int(occupant[0]) == player:
        return []
    return [{
        "marble": marble_id,
        "dest": WahooState.loc_track(dest_idx),
        "kind": "exit_center",
        "captures": occupant,
    }]

static func apply_move(state: WahooState, move: Dictionary) -> WahooState:
    var player := state.current_player
    var marble_id: int = int(move["marble"])

    var captures: Variant = move.get("captures", null)
    if captures != null:
        var cap_player: int = int(captures[0])
        var cap_marble: int = int(captures[1])
        state.marbles[cap_player][cap_marble] = WahooState.loc_base()
        if state.center_occupant != null and int(state.center_occupant[0]) == cap_player and int(state.center_occupant[1]) == cap_marble:
            state.center_occupant = null

    state.marbles[player][marble_id] = move["dest"].duplicate(true)

    var dest: Array = move["dest"]
    if dest[0] == "CENTER":
        state.center_occupant = [player, marble_id]
    elif String(move["kind"]) == "exit_center":
        state.center_occupant = null

    return state