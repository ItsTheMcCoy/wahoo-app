"""
Rule-engine sanity tests. Run: python -m tests.test_wahoo
Each test asserts a specific rule scenario.
"""

from wahoo.game_state import (
    GameState, base_exit, home_entry, center_exit_dest,
    loc_base, loc_track, loc_home, loc_center, format_location,
)
from wahoo.rules import legal_moves, apply_move
from wahoo.play import (
    maybe_auto_choose_move,
    choose_computer_move,
    format_move,
    update_exit_base_cursor,
    build_prompt_moves,
    read_user_input,
    show_intro_and_choose_action,
    prompt_replay_path,
    prompt_replay_index,
    decide_starting_player,
    serialize_game_state,
    deserialize_game_state,
    append_recording_entry,
    make_recording_path,
    load_recording_entry,
    run_replay,
    take_turn,
    normalize_player_settings,
    configure_players,
    prompt_human_reasoning,
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


def test_format_move_labels_center_exit_clearly():
    print("test: center exit move text is explicit")
    state = GameState()
    state.marbles[0][0] = loc_center()
    state.center_occupant = (0, 0)
    moves = legal_moves(state, 0, 1)
    move = find_move(moves, "exit_center")
    text = format_move(move, 0, 1)
    assert "> exit center" in text, f"expected explicit center-exit label, got: {text}"


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


def test_exact_landing_on_home_entry_stays_on_track():
    print("test: exact landing on home-entry stays on track")
    state = GameState()
    # For P3, home_entry is 40; from 38 with roll 2, marble lands on 40.
    state.marbles[3][0] = loc_track(38)
    state.current_player = 3

    moves = legal_moves(state, 3, 2)
    m = find_move(moves, "advance", dest=loc_track(home_entry(3)))
    assert m is not None, f"expected exact landing on home-entry, got {moves}"

    # On the next roll from home_entry, owner must enter/advance in home and
    # cannot continue on the outer loop.
    state.marbles[3][0] = loc_track(home_entry(3))
    moves = legal_moves(state, 3, 2)
    assert find_move(moves, "advance", dest=loc_track(base_exit(3))) is None
    assert find_move(moves, "advance_home", dest=loc_home(1)) is not None

    # From home_entry, rolls above 4 would overshoot home slot 3 and are illegal
    # for this marble.
    for roll in (5, 6):
        moves = legal_moves(state, 3, roll)
        marble_moves = [mv for mv in moves if mv["marble"] == 0]
        assert marble_moves == [], f"roll {roll}: expected no legal move for marble on home-entry"


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


def test_format_location_uses_human_friendly_home_numbers():
    print("test: format_location shows home slots as 1-based")
    assert_eq(format_location(loc_home(0)), "home:1", "home slot 0 should format as home:1")
    assert_eq(format_location(loc_home(3)), "home:4", "home slot 3 should format as home:4")


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
    # P1's home_entry is at (1*14 - 2) mod 56 = 12.
    # Walking forward from 54: 55, 0, 1, ... but P1 would cross 12 (home_entry)
    # only after a long walk. Let's test simple wrap: roll 3 from 54 -> land at 1.
    moves = legal_moves(state, 1, 3)
    m = find_move(moves, "advance", dest=loc_track(1))
    assert m is not None, f"expected advance to track:1, got {moves}"


def test_home_entry_indices_all_players():
    print("test: home-entry indices are correct for all players")
    assert_eq(home_entry(0), 54, "P0 home-entry")
    assert_eq(home_entry(1), 12, "P1 home-entry")
    assert_eq(home_entry(2), 26, "P2 home-entry")
    assert_eq(home_entry(3), 40, "P3 home-entry")


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


def test_computer_prefers_capture_then_exit_then_home():
    print("test: computer priority is capture, then exit, then home")
    # Capture should beat exit/home.
    state = GameState()
    state.marbles[0][0] = loc_track(5)
    state.marbles[0][1] = loc_base()
    state.marbles[1][0] = loc_track(8)
    moves = legal_moves(state, 0, 3)
    chosen = choose_computer_move(state, 0, 3, moves)
    assert_eq(chosen["captures"], (1, 0), "capture chosen before other options")

    # Exit should beat plain advance when no capture/home.
    state = GameState()
    state.marbles[0][0] = loc_track(10)
    moves = legal_moves(state, 0, 6)
    chosen = choose_computer_move(state, 0, 6, moves)
    assert_eq(chosen["kind"], "exit_base", "exit chosen before non-home advance")

    # Home should beat plain advance when no capture/exit.
    state = GameState()
    state.marbles[0][0] = loc_track(home_entry(0))
    state.marbles[0][1] = loc_track(20)
    moves = legal_moves(state, 0, 2)
    chosen = choose_computer_move(state, 0, 2, moves)
    assert_eq(chosen["kind"], "advance_home", "home move chosen before plain advance")


def test_computer_center_rule_requires_other_marble_in_play():
    print("test: computer only chooses center when another marble is in play")
    # One marble in play with center + advance options: should avoid center.
    state = GameState()
    state.marbles[0][0] = loc_track(base_exit(0) + 2)
    moves = legal_moves(state, 0, 4)
    chosen = choose_computer_move(state, 0, 4, moves)
    assert_eq(chosen["kind"], "advance", "center avoided without another marble in play")

    # Add another marble in play; center is now allowed and selected over plain advance.
    state.marbles[0][1] = loc_track(20)
    moves = legal_moves(state, 0, 4)
    chosen = choose_computer_move(state, 0, 4, moves)
    assert_eq(chosen["kind"], "enter_center", "center selected with another marble in play")


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
    settings = {"auto_roll": False}
    with patch("wahoo.play.input", return_value=""):
        starter, top_roll = decide_starting_player(rng, settings)
    assert_eq(starter, 1, "highest roll starts game")
    assert_eq(top_roll, 5, "highest roll value returned")


def test_decide_starting_player_tie_keeps_first_highest():
    print("test: opening tie keeps earliest highest in clockwise order")
    # Single round: P0=6, P1=6, P2=2, P3=1 -> P0 wins tie by order.
    rng = SeqRng([6, 6, 2, 1])
    settings = {"auto_roll": False}
    with patch("wahoo.play.input", return_value=""):
        starter, top_roll = decide_starting_player(rng, settings)
    assert_eq(starter, 0, "earliest highest roll starts game")
    assert_eq(top_roll, 6, "tied highest roll value returned")


def test_intro_menu_accepts_replay_option():
    print("test: intro menu accepts replay option")
    settings = {"auto_roll": False}
    with patch("wahoo.play.input", return_value="r"):
        action = show_intro_and_choose_action(settings)
    assert_eq(action, "replay", "replay action selected from intro menu")


def test_intro_menu_accepts_computer_option():
    print("test: intro menu accepts computer self-play option")
    settings = {"auto_roll": False, "computer_self_play": False}
    with patch("wahoo.play.input", return_value="c"):
        action = show_intro_and_choose_action(settings)
    assert_eq(action, "computer", "computer self-play selected from intro menu")


def test_legacy_computer_setting_maps_to_balanced_slots():
    print("test: legacy computer self-play setting maps to four balanced slots")
    settings = {"auto_roll": False, "computer_self_play": True}
    players = normalize_player_settings(settings)
    assert_eq(players, ["balanced", "balanced", "balanced", "balanced"], "legacy setting upgraded")


def test_configure_players_accepts_human_and_profiles():
    print("test: player setup accepts mixed human and AI profiles")
    settings = {"auto_roll": False}
    with patch("wahoo.play.input", side_effect=["", "assassin", "human", "random"]):
        players = configure_players(settings)
    assert_eq(players, ["human", "assassin", "human", "random"], "mixed player config stored")


def test_take_turn_routes_ai_slot_through_profile():
    print("test: AI slot chooses move through configured profile")
    state = GameState()
    state.current_player = 0
    settings = {"auto_roll": False, "players": ["balanced", "human", "human", "human"]}
    rng = SeqRng([1])

    with patch("wahoo.play.input", side_effect=AssertionError("AI turn should not prompt")):
        turn_result = take_turn(state, rng, settings)

    assert_eq(turn_result["events"][0]["outcome"].startswith("[balanced]"), True, "AI outcome labeled")
    assert_eq(state.marbles[0][0], loc_track(0), "AI move applied")


def test_prompt_human_reasoning_optional_blank_or_text():
    print("test: optional human reasoning accepts blank or text")
    settings = {"auto_roll": False}

    with patch("wahoo.play.input", side_effect=[""]):
        blank = prompt_human_reasoning(settings)
    assert_eq(blank, None, "blank reasoning skipped")

    with patch("wahoo.play.input", side_effect=["felt safer"]):
        note = prompt_human_reasoning(settings)
    assert_eq(note, "felt safer", "reasoning text captured")


def test_take_turn_captures_human_reasoning_for_manual_multi_choice():
    print("test: turn captures optional human reasoning for manual multi-choice")
    state = GameState()
    state.current_player = 0
    state.pending_roll = 1
    state.marbles[0][0] = loc_track(5)
    settings = {"auto_roll": False, "players": ["human", "human", "human", "human"]}
    rng = SeqRng([6])

    # Enter to roll, choose first listed move, then provide optional reasoning.
    with patch("wahoo.play.input", side_effect=["", "1", "building pressure"]):
        result = take_turn(state, rng, settings)

    event = result["events"][0]
    assert_eq(event["human_reasoning"], "building pressure", "reasoning stored on event")
    assert_eq(event["human_reasoning_non_optimal"], True, "reasoning marked non-optimal")


def test_prompt_replay_path_requires_filename():
    print("test: replay prompt requires a filename")
    settings = {"auto_roll": False}
    with patch("wahoo.play.input", side_effect=["", "game4.json"]):
        replay_path = prompt_replay_path(settings)
    assert_eq(replay_path, "game4.json", "replay filename returned after blank retry")


def test_prompt_replay_index_accepts_blank_or_number():
    print("test: replay index prompt accepts blank or number")
    settings = {"auto_roll": False}
    with patch("wahoo.play.input", side_effect=[""]):
        idx_blank = prompt_replay_index(settings)
    assert_eq(idx_blank, None, "blank index means latest state")

    with patch("wahoo.play.input", side_effect=["61"]):
        idx_num = prompt_replay_index(settings)
    assert_eq(idx_num, 61, "numeric index parsed")


def test_global_toggle_command_flips_auto_roll_during_prompt():
    print("test: /auto toggles auto-roll during prompts")
    settings = {"auto_roll": False}
    with patch("wahoo.play.input", side_effect=["/auto", "s"]):
        response = read_user_input("Enter choice: ", settings)
    assert_eq(settings["auto_roll"], True, "auto-roll toggled on")
    assert_eq(response, "s", "input accepted after toggle")


def test_roll_prompt_toggle_can_continue_immediately_when_enabled():
    print("test: roll prompt toggle can continue immediately")
    settings = {"auto_roll": False}
    with patch("wahoo.play.input", side_effect=["/auto"]):
        response = read_user_input("Press Enter to roll: ", settings, allow_auto_continue=True)
    assert_eq(settings["auto_roll"], True, "auto-roll toggled on")
    assert_eq(response, "", "roll prompt continues immediately after toggle")


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


def test_make_recording_path_uses_sequential_history_filename():
    print("test: new games use sequential history filenames")
    with tempfile.TemporaryDirectory() as tmpdir:
        open(os.path.join(tmpdir, "game1.json"), "w", encoding="utf-8").close()
        open(os.path.join(tmpdir, "game2.json"), "w", encoding="utf-8").close()
        open(os.path.join(tmpdir, "notes.json"), "w", encoding="utf-8").close()
        path = make_recording_path(tmpdir)
        assert_eq(os.path.basename(path), "game3.json", "next sequential game history filename")


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
        with patch("wahoo.play.input", side_effect=["c"]):
            loaded_recording, loaded_state = run_replay(path, {"auto_roll": False})
        assert_eq(loaded_recording["entries"][0]["event"]["type"], "start", "recording returned from replay")
        assert_eq(loaded_state.marbles[0][0], loc_track(7), "state returned for continue")
        assert_eq(loaded_state.current_player, 0, "start entry keeps starting player")
    finally:
        os.remove(path)


def test_load_recording_entry_at_specific_index():
    print("test: load recording entry by index")
    state0 = GameState()
    state0.marbles[0][0] = loc_track(4)
    state1 = GameState()
    state1.marbles[0][0] = loc_track(9)

    recording = {
        "version": 1,
        "seed": None,
        "entries": [
            {
                "index": 0,
                "event": {"type": "start", "starting_player": 0, "top_roll": 6},
                "state": serialize_game_state(state0),
            },
            {
                "index": 1,
                "event": {"type": "turn", "player": 0, "roll": 5, "outcome": "x", "reroll": False, "won": False},
                "state": serialize_game_state(state1),
            },
        ],
    }

    with tempfile.NamedTemporaryFile("w", delete=False, suffix=".json", encoding="utf-8") as handle:
        json.dump(recording, handle)
        path = handle.name

    try:
        _recording, entry, loaded_state = load_recording_entry(path, replay_index=1)
        assert_eq(entry["index"], 1, "selected index returned")
        assert_eq(loaded_state.marbles[0][0], loc_track(9), "state at selected index returned")
        assert_eq(loaded_state.current_player, 1, "continuation advances to player after recorded turn")
    finally:
        os.remove(path)


def test_run_replay_can_resume_from_specific_index():
    print("test: replay can resume from requested index")
    state0 = GameState()
    state0.marbles[0][0] = loc_track(3)
    state1 = GameState()
    state1.marbles[0][0] = loc_track(8)
    recording = {
        "version": 1,
        "seed": None,
        "entries": [
            {
                "index": 0,
                "event": {"type": "start", "starting_player": 0, "top_roll": 6},
                "state": serialize_game_state(state0),
            },
            {
                "index": 1,
                "event": {"type": "turn", "player": 0, "roll": 5, "outcome": "x", "reroll": False, "won": False},
                "state": serialize_game_state(state1),
            },
        ],
    }

    with tempfile.NamedTemporaryFile("w", delete=False, suffix=".json", encoding="utf-8") as handle:
        json.dump(recording, handle)
        path = handle.name

    try:
        with patch("wahoo.play.input", side_effect=["c"]):
            loaded_recording, loaded_state = run_replay(path, {"auto_roll": False}, replay_index=1)
        assert_eq(loaded_recording["entries"][1]["index"], 1, "recording loaded for indexed replay")
        assert_eq(loaded_state.marbles[0][0], loc_track(8), "indexed replay returns selected state")
        assert_eq(loaded_state.current_player, 1, "indexed replay resumes on next player")
    finally:
        os.remove(path)


def test_run_replay_index_navigation_allows_back_next_and_decision_continue():
    print("test: indexed replay supports back/next and decision continue")
    s0 = GameState()
    s0.current_player = 2
    s0.marbles[3][0] = loc_track(38)

    s1 = GameState()
    s1.current_player = 3
    s1.marbles[3][0] = loc_track(40)

    s2 = GameState()
    s2.current_player = 0
    s2.marbles[3][0] = loc_home(0)

    recording = {
        "version": 1,
        "seed": None,
        "entries": [
            {
                "index": 0,
                "event": {"type": "turn", "player": 2, "roll": 5, "outcome": "y", "reroll": False, "won": False},
                "state": serialize_game_state(s0),
            },
            {
                "index": 1,
                "event": {"type": "turn", "player": 3, "roll": 2, "outcome": "b", "reroll": False, "won": False},
                "state": serialize_game_state(s1),
            },
            {
                "index": 2,
                "event": {"type": "turn", "player": 3, "roll": 3, "outcome": "b", "reroll": False, "won": False},
                "state": serialize_game_state(s2),
            },
        ],
    }

    with tempfile.NamedTemporaryFile("w", delete=False, suffix=".json", encoding="utf-8") as handle:
        json.dump(recording, handle)
        path = handle.name

    try:
        # Start at index 2, step back and forward, switch to decision view, continue.
        with patch("wahoo.play.input", side_effect=["b", "n", "d", "c"]):
            _rec, state = run_replay(path, {"auto_roll": False}, replay_index=2)

        # Decision state for index 2 should be the board from index 1, player 3, roll 3.
        assert_eq(state.marbles[3][0], loc_track(40), "decision view uses previous board state")
        assert_eq(state.current_player, 3, "decision view sets current player to turn owner")
        assert_eq(state.pending_roll, 3, "decision view preserves recorded roll for prompt")
    finally:
        os.remove(path)


def test_take_turn_uses_pending_roll_before_rng():
    print("test: take_turn consumes pending_roll before RNG")
    state = GameState()
    state.current_player = 0
    state.pending_roll = 1
    settings = {"auto_roll": False, "players": ["human", "human", "human", "human"]}
    rng = SeqRng([6])

    with patch("wahoo.play.input", side_effect=["", "1"]):
        result = take_turn(state, rng, settings)

    assert_eq(result["events"][0]["roll"], 1, "pending roll used for turn")


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
        test_format_move_labels_center_exit_clearly,
        test_home_entry_no_exact,
        test_exact_landing_on_home_entry_stays_on_track,
        test_home_overshoot_illegal,
        test_home_blocked_by_own_marble,
        test_cannot_pass_own_marble,
        test_capture_opponent_on_track,
        test_win_condition,
        test_wrap_around_track,
        test_home_entry_indices_all_players,
        test_auto_choose_when_only_one_legal_move,
        test_auto_choose_rotating_base_exit_when_only_exit_moves,
        test_no_auto_base_exit_if_other_move_exists,
        test_computer_prefers_capture_then_exit_then_home,
        test_computer_center_rule_requires_other_marble_in_play,
        test_prompt_shows_single_rotating_exit_base_option,
        test_prompt_does_not_collapse_without_track_marble,
        test_decide_starting_player_highest_roll,
        test_decide_starting_player_tie_keeps_first_highest,
        test_intro_menu_accepts_replay_option,
        test_intro_menu_accepts_computer_option,
        test_legacy_computer_setting_maps_to_balanced_slots,
        test_configure_players_accepts_human_and_profiles,
        test_take_turn_routes_ai_slot_through_profile,
        test_prompt_human_reasoning_optional_blank_or_text,
        test_take_turn_captures_human_reasoning_for_manual_multi_choice,
        test_prompt_replay_path_requires_filename,
        test_prompt_replay_index_accepts_blank_or_number,
        test_global_toggle_command_flips_auto_roll_during_prompt,
        test_roll_prompt_toggle_can_continue_immediately_when_enabled,
        test_serialize_game_state_roundtrip,
        test_recording_entry_captures_snapshot_immediately,
        test_make_recording_path_uses_sequential_history_filename,
        test_run_replay_can_return_state_for_continue,
        test_load_recording_entry_at_specific_index,
        test_run_replay_can_resume_from_specific_index,
        test_run_replay_index_navigation_allows_back_next_and_decision_continue,
        test_take_turn_uses_pending_roll_before_rng,
    ]
    for t in tests:
        t()
    print("\nAll tests passed.")


if __name__ == "__main__":
    main()
