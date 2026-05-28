class_name WahooState
extends RefCounted

const LOOP_SIZE := 56
const SEGMENT_LEN := 14
const HOME_SLOTS := 4
const MARBLES_PER_PLAYER := 4
const NUM_PLAYERS := 4

var marbles: Array = []
var current_player := 0
var pending_roll: Variant = null
var center_occupant: Variant = null
var next_base_exit_marble: Array = []

static func new_game():
    var state = preload("res://scripts/wahoo_state.gd").new()
    state.marbles = []
    for _player in range(NUM_PLAYERS):
        var player_marbles: Array = []
        for _marble in range(MARBLES_PER_PLAYER):
            player_marbles.append(loc_base())
        state.marbles.append(player_marbles)
    state.current_player = 0
    state.pending_roll = null
    state.center_occupant = null
    state.next_base_exit_marble = [0, 0, 0, 0]
    return state

func clone():
    var copy = preload("res://scripts/wahoo_state.gd").new()
    copy.marbles = []
    for player_marbles in marbles:
        var cloned_player: Array = []
        for loc in player_marbles:
            cloned_player.append(loc.duplicate(true))
        copy.marbles.append(cloned_player)
    copy.current_player = current_player
    copy.pending_roll = pending_roll
    copy.center_occupant = center_occupant.duplicate(true) if center_occupant != null else null
    copy.next_base_exit_marble = next_base_exit_marble.duplicate(true)
    return copy

static func base_exit(player: int) -> int:
    return player * SEGMENT_LEN

static func home_entry(player: int) -> int:
    return posmod(player * SEGMENT_LEN - 2, LOOP_SIZE)

static func center_exit_dest(player: int) -> int:
    return ((player - 1 + NUM_PLAYERS) % NUM_PLAYERS) * SEGMENT_LEN + 5

static func segment_offset(player: int, loop_idx: int) -> int:
    return posmod(loop_idx - base_exit(player), LOOP_SIZE)

static func loc_base() -> Array:
    return ["BASE"]

static func loc_track(loop_idx: int) -> Array:
    return ["TRACK", loop_idx]

static func loc_home(slot: int) -> Array:
    return ["HOME", slot]

static func loc_center() -> Array:
    return ["CENTER"]

func marble_at_track(loop_idx: int) -> Variant:
    for player in range(NUM_PLAYERS):
        for marble_id in range(MARBLES_PER_PLAYER):
            var loc: Array = marbles[player][marble_id]
            if loc[0] == "TRACK" and loc[1] == loop_idx:
                return [player, marble_id]
    return null

func marble_at_home(player: int, slot: int) -> Variant:
    for marble_id in range(MARBLES_PER_PLAYER):
        var loc: Array = marbles[player][marble_id]
        if loc[0] == "HOME" and loc[1] == slot:
            return marble_id
    return null

func player_won(player: int) -> bool:
    for marble_id in range(MARBLES_PER_PLAYER):
        var loc: Array = marbles[player][marble_id]
        if loc[0] != "HOME":
            return false
    return true

static func format_location(loc: Array) -> String:
    if loc[0] == "BASE":
        return "base"
    if loc[0] == "TRACK":
        return "track:%d" % loc[1]
    if loc[0] == "HOME":
        return "home:%d" % (int(loc[1]) + 1)
    if loc[0] == "CENTER":
        return "center"
    return "?%s" % str(loc)