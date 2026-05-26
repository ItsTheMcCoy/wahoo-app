"""Tests for the headless self-play runner."""

import pytest

from wahoo.game_state import NUM_PLAYERS
from wahoo.selfplay import (
    benchmark_profiles,
    format_benchmark_summary,
    format_summary,
    main,
    parse_benchmark_opponents,
    parse_benchmark_profiles,
    parse_players,
    play_game,
    run_series,
)


def test_parse_players_accepts_four_profile_names():
    players = parse_players("balanced,assassin,tortoise,random")

    assert players == ("balanced", "assassin", "tortoise", "random")


def test_parse_players_rejects_wrong_count():
    with pytest.raises(ValueError, match=f"exactly {NUM_PLAYERS}"):
        parse_players("balanced,balanced")


def test_parse_players_rejects_unknown_profile():
    with pytest.raises(ValueError, match="Unknown profile"):
        parse_players("balanced,balanced,balanced,nope")


def test_parse_benchmark_profiles_accepts_candidates():
    candidates = parse_benchmark_profiles("balanced,assassin,expectimax")

    assert candidates == ("balanced", "assassin", "expectimax")


def test_parse_benchmark_opponents_requires_three_profiles():
    with pytest.raises(ValueError, match="exactly 3"):
        parse_benchmark_opponents("balanced,balanced")


def test_play_game_can_abort_at_max_turns():
    result = play_game(seed=123, max_turns=1)

    assert result.winner is None
    assert result.max_turns_reached
    assert result.turns == 1


def test_play_game_completes_seeded_balanced_game():
    result = play_game(seed=123, max_turns=20_000)

    assert result.winner in range(NUM_PLAYERS)
    assert not result.max_turns_reached
    assert result.turns > 0
    assert result.rolls >= result.turns


def test_play_game_seed_controls_random_profile_choices():
    players = ("random", "random", "random", "random")

    first = play_game(players, seed=456, max_turns=25)
    second = play_game(players, seed=456, max_turns=25)

    assert second == first


def test_run_series_and_format_summary():
    summary = run_series(games=1, seed=123, max_turns=20_000)
    report = format_summary(summary)

    assert summary.completed_games == 1
    assert summary.unfinished_games == 0
    assert "Self-play games: 1" in report
    assert "Red=balanced" in report
    assert "Avg turns:" in report


def test_benchmark_profiles_and_format_summary():
    summary = benchmark_profiles(
        profiles=("balanced", "random"),
        opponents=("balanced", "balanced", "balanced"),
        games_per_seat=1,
        seed=123,
        max_turns=20_000,
    )
    report = format_benchmark_summary(summary)

    assert len(summary.profile_results) == 2
    assert "Benchmark Mode" in report
    assert "Leaderboard:" in report
    assert "balanced" in report
    assert "random" in report


def test_main_lists_profiles(capsys):
    exit_code = main(["--list-profiles"])

    assert exit_code == 0
    output = capsys.readouterr().out
    assert "balanced" in output
    assert "random" in output


def test_main_benchmark_mode(capsys):
    exit_code = main([
        "--benchmark-profiles",
        "balanced,random",
        "--benchmark-games-per-seat",
        "1",
        "--seed",
        "123",
        "--max-turns",
        "20000",
    ])

    assert exit_code == 0
    output = capsys.readouterr().out
    assert "Benchmark Mode" in output
    assert "Leaderboard:" in output
