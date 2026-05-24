"""
Rule-engine sanity tests. Run: python tests.py
Each test asserts a specific rule scenario.
"""

from game_state import (
    GameState, base_exit, home_entry, center_exit_dest,
    loc_base, loc_track, loc_home, loc_center,
)
from rules import legal_moves, apply_move
from play import (
    maybe_auto_choose_move,
    update_exit_base_cursor,
    build_prompt_moves,
    decide_starting_player,
    serialize_game_state,
    deserialize_game_state,
    append_recording_entry,
    make_recording_path,
    run_replay,
)
from unittest.mock import patch
import json
import os
import tempfile


class SeqRng:
    """Deterministic randint provider for test scenarios."""

    def __init__(self, rolls):
        self.rolls = list(rolls)
        self.idx = 0

    def randint(self, _a, _b):
        if self.idx >= len(self.rolls):
            raise AssertionError("ran out of scripted rolls")
        value = self.rolls[self.idx]
        self.idx += 1
        return value


def assert_eq(actual, expected, label):
    if actual != expected:
        raise AssertionError(f"FAIL [{label}]: expected {expected}, got {actual}")
    print(f"  OK: {label}")


def find_move(moves, kind, dest=None):
    """Find first move of given kind (and optional dest), or None."""
    for m in moves:
        if m["kind"] == kind and (dest is None or m["dest"] == dest):
            return m
    return None


def test_base_exit():
    print("test: base exit on 1 and 6, not on other rolls")
    state = GameState()
    for roll in (1, 6):
        moves = legal_moves(state, 0, roll)
        m = find_move(moves, "exit_base")
        assert m is not None, f"expected exit_base move on roll {roll}"
        assert m["dest"] == loc_track(0), f"expected dest=track:0, got {m['dest']}"
    for roll in (2, 3, 4, 5):
        moves = legal_moves(state, 0, roll)
        assert find_move(moves, "exit_base") is None, f"no exit on roll {roll}"
    print("  OK")


def test_base_exit_capture():
    print("test: exiting base captures opponent on exit square")
    state = GameState()
    state.marbles[1][0] = loc_track(0)  # P1's marble parked on P0's exit
    moves = legal_moves(state, 0, 1)
    m = find_move(moves, "exit_base")
    assert m["captures"] == (1, 0), f"expected capture (1,0), got {m['captures']}"
    apply_move(state, m)
    assert_eq(state.marbles[1][0], loc_base(), "captured marble back to base")
    assert_eq(state.marbles[0][0], loc_track(0), "P0 marble on exit square")


def test_cannot_exit_onto_own_marble():
    print("test: cannot exit base onto own marble")
    state = GameState()
    state.marbles[0][0] = loc_track(0)  # own marble on exit
    moves = legal_moves(state, 0, 6)
    # M0 is on track. M1, M2, M3 still in base — they cannot exit.
    for m in moves:
        assert m["kind"] != "exit_base", "should not allow exit onto own marble"
    print("  OK")


def test_center_entry_from_each_offset():
    print("test: center entry from each of first 6 squares with matching roll")
    for offset in range(6):
        state = GameState()
        state.marbles[0][0] = loc_track(base_exit(0) + offset)
        required_roll = 6 - offset
        moves = legal_moves(state, 0, required_roll)
        m = find_move(moves, "enter_center")
        assert m is not None, f"offset {offset} roll {required_roll} should allow center"
        # Wrong rolls: no center entry
        for wrong in range(1, 7):
            if wrong == required_roll:
                continue
            moves = legal_moves(state, 0, wrong)
            assert find_move(moves, "enter_center") is None, \
                f"offset {offset} roll {wrong} should NOT allow center"
    print("  OK")


def test_center_entry_optional():
    print("test: center entry is optional; advance also legal")
    state = GameState()
    state.marbles[0][0] = loc_track(base_exit(0) + 2)  # offset 2
    moves = legal_moves(state, 0, 4)  # 6 - 2 = 4
    assert find_move(moves, "enter_center") is not None
    assert find_move(moves, "advance") is not None
    print("  OK")


def test_cannot_enter_center_by_jumping_own_marble():
    print("test: cannot enter center by jumping own marble")
    state = GameState()
    state.marbles[0][0] = loc_track(base_exit(0) + 2)  # exact center roll would be 4
    state.marbles[0][1] = loc_track(base_exit(0) + 3)  # blocks path to center
    moves = legal_moves(state, 0, 4)
    assert find_move(moves, "enter_center") is None, "should not enter center through own marble"
    blocked_moves = [m for m in moves if m["marble"] == 0]
    assert blocked_moves == [], f"blocked marble should have no legal moves, got {blocked_moves}"
    print("  OK")


def test_no_center_after_first_6():
    print("test: no center entry from offset 6+")
    state = GameState()
    state.marbles[0][0] = loc_track(base_exit(0) + 6)
    for roll in range(1, 7):
        moves = legal_moves(state, 0, roll)
        assert find_move(moves, "enter_center") is None, \
            f"should not enter center from offset 6 on roll {roll}"
    print("  OK")


def test_center_capture_on_entry():
    print("test: entering center captures occupant")
    state = GameState()
    state.marbles[0][0] = loc_track(base_exit(0))  # offset 0, needs roll 6
    state.marbles[1][0] = loc_center()
    state.center_occupant = (1, 0)
    moves = legal_moves(state, 0, 6)
    m = find_move(moves, "enter_center")
    assert m["captures"] == (1, 0)
    apply_move(state, m)
    assert_eq(state.marbles[1][0], loc_base(), "captured center marble to base")
    assert_eq(state.center_occupant, (0, 0), "new center occupant")


def test_center_exit():
    print("test: center exit on 1 to previous segment offset 5")
    for p in range(4):
        state = GameState()
        state.marbles[p][0] = loc_center()
        state.center_occupant = (p, 0)
        moves = legal_moves(state, p, 1)
        m = find_move(moves, "exit_center")
        expected_dest = loc_track(center_exit_dest(p))
        assert m is not None, f"P{p} should have exit_center on roll 1"
        assert m["dest"] == expected_dest, \
            f"P{p}: expected {expected_dest}, got {m['dest']}"
        # No other rolls allow exit
        for roll in range(2, 7):
            moves = legal_moves(state, p, roll)
            assert find_move(moves, "exit_center") is None


def test_home_entry_no_exact():
    print("test: home entry needs no exact roll")
    state = GameState()
    # Place marble at home_entry square; any roll should turn into home.
    state.marbles[0][0] = loc_track(home_entry(0))
    for roll in (1, 2, 3, 4):
        moves = legal_moves(state, 0, roll)
        # Should land in home slot (roll - 1) since step 1 turns into home slot 0
        m = find_move(moves, "enter_home" if roll == 1 else "advance_home")
        # Actually: step 1 enters home as slot 0; remaining roll-1 climb up.
        expected_slot = roll - 1
        assert m is not None, f"roll {roll}: expected home move"
        assert m["dest"] == loc_home(expected_slot), \
            f"roll {roll}: expected home:{expected_slot}, got {m['dest']}"


def test_home_overshoot_illegal():
    print("test: cannot overshoot final home slot")
    state = GameState()
    # Marble in home slot 2; roll 2 would land slot 4 (illegal).
    state.marbles[0][0] = loc_home(2)
    moves = legal_moves(state, 0, 2)
    assert find_move(moves, "advance_home") is None, "should not overshoot"
    # Roll 1: slot 3 (legal).
    moves = legal_moves(state, 0, 1)
    m = find_move(moves, "advance_home")
    assert m and m["dest"] == loc_home(3)


def test_home_blocked_by_own_marble():
    print("test: cannot land in home slot occupied by own marble")
    state = GameState()
    state.marbles[0][0] = loc_home(2)
    state.marbles[0][1] = loc_home(3)
    moves = legal_moves(state, 0, 1)
    # M0 advancing to slot 3 is blocked.
    blocked = [m for m in moves if m["marble"] == 0]
    assert blocked == [], f"M0 advance should be blocked, got {blocked}"


def test_cannot_pass_own_marble():
    print("test: cannot pass own marble on the track")
    state = GameState()
    state.marbles[0][0] = loc_track(5)
    state.marbles[0][1] = loc_track(7)  # 2 squares ahead
    # M0 rolling 3 would pass M1 — illegal.
    moves = legal_moves(state, 0, 3)
    m0_moves = [m for m in moves if m["marble"] == 0]
    # Center entry might be available on offset 5 with roll 1, but not roll 3.
    # On roll 3 from offset 5, advance is the only candidate, and it's blocked.
    advance_moves = [m for m in m0_moves if m["kind"] == "advance"]
    assert advance_moves == [], "should not pass own marble"


def test_capture_opponent_on_track():
    print("test: landing on opponent captures them")
    state = GameState()
    state.marbles[0][0] = loc_track(5)
    state.marbles[1][0] = loc_track(8)
    moves = legal_moves(state, 0, 3)
    m = find_move(moves, "advance", dest=loc_track(8))
    assert m and m["captures"] == (1, 0)
    apply_move(state, m)
    assert_eq(state.marbles[1][0], loc_base(), "captured opponent to base")
    assert_eq(state.marbles[0][0], loc_track(8), "moved")


def test_win_condition():
    print("test: win when all 4 marbles in home")
    state = GameState()
    for m in range(4):
        state.marbles[0][m] = loc_home(m)
    assert state.player_won(0)
    assert not state.player_won(1)


def test_wrap_around_track():
    print("test: track wraps around 55 -> 0")
    state = GameState()
    state.marbles[1][0] = loc_track(54)  # P1 near end of loop
    # P1's home_entry is at (1*14 - 1) mod 56 = 13.
    # Walking forward from 54: 55, 0, 1, ... but P1 would cross 13 (home_entry)
    # only after a long walk. Let's test simple wrap: roll 3 from 54 -> land at 1.
    moves = legal_moves(state, 1, 3)
    m = find_move(moves, "advance", dest=loc_track(1))
    assert m is not None, f"expected advance to track:1, got {moves}"


def test_auto_choose_when_only_one_legal_move():
    print("test: auto-choose when exactly one legal move")
    state = GameState()
    state.marbles[0][0] = loc_home(1)
    state.marbles[0][1] = loc_home(0)
    state.marbles[0][2] = loc_base()
    state.marbles[0][3] = loc_base()
    # Only legal move should be M0 -> home:3
    moves = legal_moves(state, 0, 2)
    assert_eq(len(moves), 1, "single legal move setup")
    chosen = maybe_auto_choose_move(state, 0, 2, moves)
    assert chosen is not None, "should auto-select single legal move"
    assert_eq(chosen["dest"], loc_home(3), "auto-selected expected destination")


def test_auto_choose_rotating_base_exit_when_only_exit_moves():
    print("test: auto-choose rotating base exit on roll 1/6 when only exits")
    state = GameState()

    # Initial state: all legal moves are exit_base, cursor starts at marble 0.
    moves = legal_moves(state, 0, 6)
    chosen = maybe_auto_choose_move(state, 0, 6, moves)
    assert chosen is not None and chosen["kind"] == "exit_base"
    assert_eq(chosen["marble"], 0, "first auto-exit uses marble 0")
    update_exit_base_cursor(state, 0, chosen)
    apply_move(state, chosen)

    # Put M0 back in base so multiple exit moves are available again.
    state.marbles[0][0] = loc_base()

    moves = legal_moves(state, 0, 6)
    chosen = maybe_auto_choose_move(state, 0, 6, moves)
    assert chosen is not None and chosen["kind"] == "exit_base"
    assert_eq(chosen["marble"], 1, "second auto-exit rotates to marble 1")


def test_no_auto_base_exit_if_other_move_exists():
    print("test: no auto base-exit when non-exit legal move exists")
    state = GameState()
    state.marbles[0][0] = loc_track(10)  # can advance on roll 6
    moves = legal_moves(state, 0, 6)
    has_exit = any(m["kind"] == "exit_base" for m in moves)
    has_non_exit = any(m["kind"] != "exit_base" for m in moves)
    assert has_exit and has_non_exit, "setup should include exit and non-exit moves"
    chosen = maybe_auto_choose_move(state, 0, 6, moves)
    assert chosen is None, "should not auto-select exit_base when non-exit exists"


def test_prompt_shows_single_rotating_exit_base_option():
    print("test: prompt collapses multiple exit_base options to one rotating choice")
    state = GameState()
    state.marbles[0][0] = loc_track(10)  # ensure at least one track marble
    moves = legal_moves(state, 0, 6)
    prompt_moves = build_prompt_moves(state, 0, 6, moves)
    prompt_exit_moves = [m for m in prompt_moves if m["kind"] == "exit_base"]
    assert_eq(len(prompt_exit_moves), 1, "single exit_base option in prompt")
    assert_eq(prompt_exit_moves[0]["marble"], 1, "uses next sequential base marble")


def test_prompt_does_not_collapse_without_track_marble():
    print("test: prompt keeps all exit_base options when no marble is on track")
    state = GameState()
    moves = legal_moves(state, 0, 6)
    prompt_moves = build_prompt_moves(state, 0, 6, moves)
    raw_exit = [m for m in moves if m["kind"] == "exit_base"]
    prompt_exit = [m for m in prompt_moves if m["kind"] == "exit_base"]
    assert_eq(len(prompt_exit), len(raw_exit), "no collapse when no track marble")


def test_decide_starting_player_highest_roll():
    print("test: highest opening roll starts")
    # Players 0..3 rolls are 2, 5, 3, 1 => player 1 starts.
    rng = SeqRng([2, 5, 3, 1])
    with patch("play.input", return_value=""):
        starter, top_roll = decide_starting_player(rng)
    assert_eq(starter, 1, "highest roll starts game")
    assert_eq(top_roll, 5, "highest roll value returned")


def test_decide_starting_player_tie_keeps_first_highest():
    print("test: opening tie keeps earliest highest in clockwise order")
    # Single round: P0=6, P1=6, P2=2, P3=1 -> P0 wins tie by order.
    rng = SeqRng([6, 6, 2, 1])
    with patch("play.input", return_value=""):
        starter, top_roll = decide_starting_player(rng)
    assert_eq(starter, 0, "earliest highest roll starts game")
    assert_eq(top_roll, 6, "tied highest roll value returned")


def test_serialize_game_state_roundtrip():
    print("test: game state serializes and deserializes cleanly")
    state = GameState()
    state.marbles[0][0] = loc_track(5)
    state.marbles[1][1] = loc_home(2)
    state.marbles[2][2] = loc_center()
    state.center_occupant = (2, 2)
    state.current_player = 3
    state.next_base_exit_marble = [1, 2, 3, 0]

    payload = serialize_game_state(state)
    restored = deserialize_game_state(payload)

    assert_eq(restored.marbles, state.marbles, "marbles roundtrip")
    assert_eq(restored.center_occupant, state.center_occupant, "center occupant roundtrip")
    assert_eq(restored.current_player, state.current_player, "current player roundtrip")
    assert_eq(restored.next_base_exit_marble, state.next_base_exit_marble, "exit cursor roundtrip")


def test_recording_entry_captures_snapshot_immediately():
    print("test: recording entry captures snapshot immediately")
    state = GameState()
    state.marbles[0][0] = loc_track(4)
    recording = {"entries": []}

    append_recording_entry(recording, state, {"type": "turn", "player": 0, "roll": 4, "outcome": "x"})
    state.marbles[0][0] = loc_track(9)

    saved = deserialize_game_state(recording["entries"][0]["state"])
    assert_eq(saved.marbles[0][0], loc_track(4), "recorded snapshot unchanged by later mutations")


def test_make_recording_path_uses_unique_history_filename():
    print("test: new games use unique history filenames")
    path1 = make_recording_path()
    path2 = make_recording_path()
    assert path1.startswith("wahoo_history_") and path1.endswith(".json")
    assert path2.startswith("wahoo_history_") and path2.endswith(".json")
    assert path1 != path2, "recording filenames should be unique"
    print("  OK")


def test_run_replay_can_return_state_for_continue():
    print("test: replay can return resumable state")
    state = GameState()
    state.marbles[0][0] = loc_track(7)
    recording = {
        "version": 1,
        "seed": None,
        "entries": [
            {
                "index": 0,
                "event": {"type": "start", "starting_player": 0, "top_roll": 6},
                "state": serialize_game_state(state),
            }
        ],
    }

    with tempfile.NamedTemporaryFile("w", delete=False, suffix=".json", encoding="utf-8") as handle:
        json.dump(recording, handle)
        path = handle.name

    try:
        with patch("play.input", side_effect=["c"]):
            loaded_recording, loaded_state = run_replay(path)
        assert_eq(loaded_recording["entries"][0]["event"]["type"], "start", "recording returned from replay")
        assert_eq(loaded_state.marbles[0][0], loc_track(7), "state returned for continue")
    finally:
        os.remove(path)


def main():
    tests = [
        test_base_exit,
        test_base_exit_capture,
        test_cannot_exit_onto_own_marble,
        test_center_entry_from_each_offset,
        test_center_entry_optional,
        test_cannot_enter_center_by_jumping_own_marble,
        test_no_center_after_first_6,
        test_center_capture_on_entry,
        test_center_exit,
        test_home_entry_no_exact,
        test_home_overshoot_illegal,
        test_home_blocked_by_own_marble,
        test_cannot_pass_own_marble,
        test_capture_opponent_on_track,
        test_win_condition,
        test_wrap_around_track,
        test_auto_choose_when_only_one_legal_move,
        test_auto_choose_rotating_base_exit_when_only_exit_moves,
        test_no_auto_base_exit_if_other_move_exists,
        test_prompt_shows_single_rotating_exit_base_option,
        test_prompt_does_not_collapse_without_track_marble,
        test_decide_starting_player_highest_roll,
        test_decide_starting_player_tie_keeps_first_highest,
        test_serialize_game_state_roundtrip,
        test_recording_entry_captures_snapshot_immediately,
        test_make_recording_path_uses_unique_history_filename,
        test_run_replay_can_return_state_for_continue,
    ]
    for t in tests:
        t()
    print("\nAll tests passed.")


if __name__ == "__main__":
    main()
