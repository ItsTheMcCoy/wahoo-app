"""Tests for human reasoning export utility."""

from wahoo.game_state import GameState, loc_base, loc_track
from wahoo.play import serialize_game_state
from wahoo.reasoning_export import extract_reasoning_examples_from_recording


def test_extract_reasoning_examples_from_recording_infers_choice_and_marks_non_optimal():
    # Pre-state with two legal moves for player 0 on roll 1:
    # - exit_base for another marble
    # - advance existing marble from track 5 to 6
    pre = GameState()
    pre.current_player = 0
    pre.marbles[0][0] = loc_track(5)

    post = pre.clone()
    post.marbles[0][0] = loc_track(6)

    recording = {
        "version": 1,
        "seed": None,
        "entries": [
            {
                "index": 0,
                "event": {"type": "start", "starting_player": 0, "top_roll": 6},
                "state": serialize_game_state(pre),
            },
            {
                "index": 1,
                "event": {
                    "type": "turn",
                    "player": 0,
                    "roll": 1,
                    "outcome": "Move A1 + 1 positions",
                    "reroll": False,
                    "won": False,
                    "human_reasoning": "I wanted to keep pressure in lane",
                    "human_reasoning_non_optimal": True,
                },
                "state": serialize_game_state(post),
            },
        ],
    }

    samples = extract_reasoning_examples_from_recording(recording, source_name="gameX.json")
    assert len(samples) == 1

    sample = samples[0]
    assert sample["source_file"] == "gameX.json"
    assert sample["entry_index"] == 1
    assert sample["player"] == 0
    assert sample["roll"] == 1
    assert sample["reasoning"] == "I wanted to keep pressure in lane"
    assert sample["human_reasoning_non_optimal"] is True
    assert sample["is_optimal_target"] is False
    assert sample["chosen_move_inferred"] is True
    assert sample["chosen_move"]["kind"] == "advance"
    assert sample["chosen_move"]["dest"] == ["TRACK", 6]
    # Ensure we still exported full legal-move context for training/analysis.
    kinds = {m["kind"] for m in sample["legal_moves"]}
    assert "advance" in kinds
    assert "exit_base" in kinds


def test_extract_reasoning_examples_skips_entries_without_reasoning():
    state = GameState()
    state.current_player = 0
    state.marbles[0][0] = loc_base()
    recording = {
        "version": 1,
        "seed": None,
        "entries": [
            {
                "index": 0,
                "event": {"type": "start", "starting_player": 0, "top_roll": 6},
                "state": serialize_game_state(state),
            },
            {
                "index": 1,
                "event": {
                    "type": "turn",
                    "player": 0,
                    "roll": 1,
                    "outcome": "Move A1 out of base",
                    "reroll": False,
                    "won": False,
                },
                "state": serialize_game_state(state),
            },
        ],
    }

    samples = extract_reasoning_examples_from_recording(recording, source_name="gameY.json")
    assert samples == []
