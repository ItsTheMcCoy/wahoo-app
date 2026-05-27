class_name WahooState
extends RefCounted

const LOOP_SIZE := 56
const SEGMENT_LEN := 14
const HOME_SLOTS := 4
const MARBLES_PER_PLAYER := 4
const NUM_PLAYERS := 4

var marbles: Array = []

static func new_game() -> WahooState:
    var state := WahooState.new()
    state.marbles = []
    for _player in range(NUM_PLAYERS):
        var player_marbles: Array = []
        for _marble in range(MARBLES_PER_PLAYER):
            player_marbles.append(["BASE"])
        state.marbles.append(player_marbles)
    return state

func clone() -> WahooState:
    var copy := WahooState.new()
    copy.marbles = []
    for player_marbles in marbles:
        var cloned_player: Array = []
        for loc in player_marbles:
            cloned_player.append(loc.duplicate(true))
        copy.marbles.append(cloned_player)
    return copy

static func base_exit(player: int) -> int:
    return player * SEGMENT_LEN

static func home_entry(player: int) -> int:
    return posmod(player * SEGMENT_LEN - 2, LOOP_SIZE)

static func center_exit_dest(player: int) -> int:
    return ((player - 1 + NUM_PLAYERS) % NUM_PLAYERS) * SEGMENT_LEN + 5