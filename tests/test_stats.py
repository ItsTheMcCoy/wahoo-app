"""Tests for statistics tracking and turn-detail recording helpers."""

from pathlib import Path

import pytest

from wahoo.game_state import GameState, NUM_PLAYERS
from wahoo.play import append_recording_entry, serialize_game_state, update_exit_base_cursor
from wahoo.rules import apply_move, legal_moves
from wahoo.stats import (
    append_stats_csv,
    compile_game_stats,
    compute_turn_record,
    turn_record_to_event,
)


def _build_sample_recording() -> dict:
    state = GameState()
    recording = {
        "version": 2,
        "game_id": "game_test",
        "seed": 1,
        "players": ["balanced", "balanced", "balanced", "balanced"],
        "entries": [],
    }

    append_recording_entry(recording, state, {
        "type": "start",
        "starting_player": 0,
        "top_roll": 6,
    })

    player = 0
    roll = 6
    moves = legal_moves(state, player, roll)
    chosen = moves[0]
    detail = compute_turn_record(
        game_id="game_test",
        turn_index=1,
        state_before=state.clone(),
        player=player,
        player_type="balanced",
        roll=roll,
        roll_index=1,
        all_moves=moves,
        chosen_move=chosen,
    )
    update_exit_base_cursor(state, player, chosen)
    apply_move(state, chosen)

    append_recording_entry(recording, state, {
        "type": "turn",
        "player": player,
        "roll": roll,
        "outcome": "test move",
        "reroll": True,
        "won": False,
    })
    append_recording_entry(recording, state, turn_record_to_event(detail))

    roll = 2
    moves = legal_moves(state, player, roll)
    chosen = moves[0]
    detail = compute_turn_record(
        game_id="game_test",
        turn_index=2,
        state_before=state.clone(),
        player=player,
        player_type="balanced",
        roll=roll,
        roll_index=2,
        all_moves=moves,
        chosen_move=chosen,
    )
    update_exit_base_cursor(state, player, chosen)
    apply_move(state, chosen)

    append_recording_entry(recording, state, {
        "type": "turn",
        "player": player,
        "roll": roll,
        "outcome": "test move 2",
        "reroll": False,
        "won": False,
    })
    append_recording_entry(recording, state, turn_record_to_event(detail))
    return recording


def test_compute_turn_record_exit_only_profile():
    state = GameState()
    moves = legal_moves(state, 0, 6)

    record = compute_turn_record(
        game_id="game_test",
        turn_index=1,
        state_before=state,
        player=0,
        player_type="balanced",
        roll=6,
        roll_index=1,
        all_moves=moves,
        chosen_move=moves[0],
    )

    assert record.decision_type == "exit_only"
    assert record.num_legal_moves == 4
    assert record.chosen_move_index == 0
    assert set(record.chosen_features.keys()) == {
        "DEP", "RUN", "SPR", "CAP", "SAFE", "CTR", "DEN", "FLOW", "HOME", "FIN"
    }
    assert "opp_center_exit_threat" in record.opportunity_flags
    assert "intercept_hold_available" in record.opportunity_flags
    assert "bait_line_available" in record.opportunity_flags
    assert "took_guard_exit_hold" in record.tendency_flags
    assert "bait_line_taken" in record.tendency_flags


def test_compile_game_stats_from_turn_detail_recording():
    recording = _build_sample_recording()

    summary = compile_game_stats(recording)

    assert summary.game_id == "game_test"
    assert summary.total_rolls == 2
    assert summary.total_turns == 1
    assert len(summary.player_stats) == NUM_PLAYERS

    red = summary.player_stats[0]
    assert red.total_rolls == 2
    assert red.total_turns == 1
    assert red.base_exit_on_6_opportunities == 1
    assert red.base_exit_on_6_chosen == 1
    assert red.base_exit_on_6_rate == 1.0
    assert red.discretionary_turns >= 1
    assert red.intercept_hold_rate is None or 0.0 <= red.intercept_hold_rate <= 1.0
    assert red.guard_exit_hold_rate is None or 0.0 <= red.guard_exit_hold_rate <= 1.0
    assert red.sandwich_trap_preserve_rate is None or 0.0 <= red.sandwich_trap_preserve_rate <= 1.0
    assert red.bait_line_success_rate is None or 0.0 <= red.bait_line_success_rate <= 1.0


def test_compile_game_stats_rejects_legacy_recording():
    with pytest.raises(ValueError, match="version 2"):
        compile_game_stats({"version": 1, "entries": []})


def test_append_stats_csv_writes_header_and_rows(tmp_path: Path):
    recording = _build_sample_recording()
    summary = compile_game_stats(recording)
    out_path = tmp_path / "stats.csv"

    append_stats_csv(summary, str(out_path))

    rows = out_path.read_text(encoding="utf-8").strip().splitlines()
    assert rows[0].startswith("game_id,player,player_type")
    assert len(rows) == 1 + NUM_PLAYERS
