"""Headless AI self-play runner.

Run:
  python -m wahoo.selfplay --games 50 --players balanced,balanced,balanced,balanced
"""

from __future__ import annotations

import argparse
import random
from dataclasses import dataclass
from typing import Sequence

try:
    from .ai import PROFILES, _random as ai_random
    from .game_state import GameState, NUM_PLAYERS
    from .play import PLAYER_NAMES, update_exit_base_cursor
    from .rules import apply_move, legal_moves
except ImportError:
    from ai import PROFILES, _random as ai_random
    from game_state import GameState, NUM_PLAYERS
    from play import PLAYER_NAMES, update_exit_base_cursor
    from rules import apply_move, legal_moves


DEFAULT_GAMES = 50
DEFAULT_MAX_TURNS = 10_000
DEFAULT_PLAYERS = ("balanced", "balanced", "balanced", "balanced")
DEFAULT_BENCHMARK_OPPONENTS = ("balanced", "balanced", "balanced")
DEFAULT_BENCHMARK_GAMES_PER_SEAT = 25


@dataclass
class GameResult:
    """Summary for one completed or aborted self-play game."""

    game_index: int
    winner: int | None
    players: tuple[str, ...]
    starting_player: int
    top_roll: int
    turns: int
    rolls: int
    moves: int
    captures: int
    seed: int | None
    max_turns_reached: bool = False


@dataclass
class SeriesSummary:
    """Aggregated summary for a self-play series."""

    results: list[GameResult]
    players: tuple[str, ...]

    @property
    def completed_games(self) -> int:
        return sum(1 for result in self.results if result.winner is not None)

    @property
    def unfinished_games(self) -> int:
        return len(self.results) - self.completed_games

    def wins_by_player(self) -> dict[int, int]:
        wins = {player: 0 for player in range(NUM_PLAYERS)}
        for result in self.results:
            if result.winner is not None:
                wins[result.winner] += 1
        return wins

    def average_turns(self) -> float:
        return _average(result.turns for result in self.results)

    def average_rolls(self) -> float:
        return _average(result.rolls for result in self.results)

    def average_captures(self) -> float:
        return _average(result.captures for result in self.results)


@dataclass
class BenchmarkProfileSummary:
    """Aggregated benchmark metrics for one candidate profile."""

    profile: str
    opponents: tuple[str, ...]
    total_games: int
    completed_games: int
    unfinished_games: int
    wins: int
    win_rate: float
    completed_win_rate: float
    avg_turns: float
    avg_rolls: float
    avg_captures: float
    seat_wins: tuple[int, ...]
    seat_games: tuple[int, ...]


@dataclass
class BenchmarkSummary:
    """Comparison report for multiple candidate profiles."""

    profile_results: list[BenchmarkProfileSummary]
    games_per_seat: int
    opponents: tuple[str, ...]


def _average(values) -> float:
    values = list(values)
    if not values:
        return 0.0
    return sum(values) / len(values)


def parse_players(value: str | Sequence[str]) -> tuple[str, ...]:
    """Parse and validate the four self-play profile names."""
    if isinstance(value, str):
        players = tuple(part.strip().lower() for part in value.split(",") if part.strip())
    else:
        players = tuple(part.strip().lower() for part in value)

    if len(players) != NUM_PLAYERS:
        raise ValueError(f"Expected exactly {NUM_PLAYERS} AI profiles, got {len(players)}")

    invalid = [profile for profile in players if profile not in PROFILES]
    if invalid:
        valid = ", ".join(sorted(PROFILES))
        raise ValueError(f"Unknown profile(s): {', '.join(invalid)}. Valid profiles: {valid}")

    return players


def parse_benchmark_profiles(value: str | Sequence[str]) -> tuple[str, ...]:
    """Parse candidate profile names for benchmark mode."""
    if isinstance(value, str):
        profiles = tuple(part.strip().lower() for part in value.split(",") if part.strip())
    else:
        profiles = tuple(part.strip().lower() for part in value if part.strip())

    if not profiles:
        raise ValueError("benchmark-profiles must include at least one AI profile")

    invalid = [profile for profile in profiles if profile not in PROFILES]
    if invalid:
        valid = ", ".join(sorted(PROFILES))
        raise ValueError(f"Unknown profile(s): {', '.join(invalid)}. Valid profiles: {valid}")

    return profiles


def parse_benchmark_opponents(value: str | Sequence[str]) -> tuple[str, ...]:
    """Parse and validate the three fixed opponent profiles for benchmark mode."""
    if isinstance(value, str):
        opponents = tuple(part.strip().lower() for part in value.split(",") if part.strip())
    else:
        opponents = tuple(part.strip().lower() for part in value if part.strip())

    if len(opponents) != NUM_PLAYERS - 1:
        raise ValueError(
            f"Expected exactly {NUM_PLAYERS - 1} benchmark opponents, got {len(opponents)}"
        )

    invalid = [profile for profile in opponents if profile not in PROFILES]
    if invalid:
        valid = ", ".join(sorted(PROFILES))
        raise ValueError(f"Unknown profile(s): {', '.join(invalid)}. Valid profiles: {valid}")

    return opponents


def _lineup_for_candidate(
    candidate: str,
    seat: int,
    opponents: Sequence[str],
) -> tuple[str, ...]:
    """Build a 4-seat lineup with candidate in one seat and fixed opponents elsewhere."""
    lineup: list[str] = [""] * NUM_PLAYERS
    lineup[seat] = candidate

    opp_idx = 0
    for player in range(NUM_PLAYERS):
        if player == seat:
            continue
        lineup[player] = opponents[opp_idx]
        opp_idx += 1

    return tuple(lineup)


def benchmark_profiles(
    profiles: Sequence[str],
    *,
    opponents: Sequence[str] = DEFAULT_BENCHMARK_OPPONENTS,
    games_per_seat: int = DEFAULT_BENCHMARK_GAMES_PER_SEAT,
    seed: int | None = None,
    max_turns: int = DEFAULT_MAX_TURNS,
) -> BenchmarkSummary:
    """Benchmark candidate profiles by rotating each through all four seats.

    Each candidate plays `games_per_seat` games in each seat against the same
    three fixed opponent profiles. This reduces seat-order bias and gives one
    comparable win-rate per candidate profile.
    """
    if games_per_seat < 1:
        raise ValueError("games_per_seat must be at least 1")
    if max_turns < 1:
        raise ValueError("max_turns must be at least 1")

    profiles = parse_benchmark_profiles(profiles)
    opponents = parse_benchmark_opponents(opponents)

    seed_rng = random.Random(seed)
    profile_results: list[BenchmarkProfileSummary] = []

    for profile in profiles:
        results: list[GameResult] = []
        seat_wins = [0] * NUM_PLAYERS
        seat_games = [0] * NUM_PLAYERS

        for seat in range(NUM_PLAYERS):
            lineup = _lineup_for_candidate(profile, seat, opponents)
            for game_index in range(1, games_per_seat + 1):
                game_seed = seed_rng.randrange(1_000_000_000) if seed is not None else None
                result = play_game(
                    lineup,
                    seed=game_seed,
                    game_index=game_index,
                    max_turns=max_turns,
                )
                results.append(result)
                seat_games[seat] += 1
                if result.winner == seat:
                    seat_wins[seat] += 1

        total_games = len(results)
        completed = sum(1 for result in results if result.winner is not None)
        unfinished = total_games - completed
        wins = sum(seat_wins)
        win_rate = wins / total_games if total_games else 0.0
        completed_win_rate = wins / completed if completed else 0.0

        profile_results.append(
            BenchmarkProfileSummary(
                profile=profile,
                opponents=tuple(opponents),
                total_games=total_games,
                completed_games=completed,
                unfinished_games=unfinished,
                wins=wins,
                win_rate=win_rate,
                completed_win_rate=completed_win_rate,
                avg_turns=_average(result.turns for result in results),
                avg_rolls=_average(result.rolls for result in results),
                avg_captures=_average(result.captures for result in results),
                seat_wins=tuple(seat_wins),
                seat_games=tuple(seat_games),
            )
        )

    profile_results.sort(
        key=lambda row: (row.win_rate, row.completed_win_rate, -row.avg_turns),
        reverse=True,
    )

    return BenchmarkSummary(
        profile_results=profile_results,
        games_per_seat=games_per_seat,
        opponents=tuple(opponents),
    )


def choose_starting_player(rng: random.Random) -> tuple[int, int]:
    """Choose the opening player using the same highest-roll rule as play.py."""
    top_player = 0
    top_roll = -1
    for player in range(NUM_PLAYERS):
        roll = rng.randint(1, 6)
        if roll > top_roll:
            top_player = player
            top_roll = roll
    return top_player, top_roll


def play_game(
    players: Sequence[str] = DEFAULT_PLAYERS,
    *,
    seed: int | None = None,
    game_index: int = 1,
    max_turns: int = DEFAULT_MAX_TURNS,
) -> GameResult:
    """Run one headless AI game and return its summary."""
    players = parse_players(players)
    rng = random.Random(seed)
    if seed is not None:
        ai_random.seed(seed)
    state = GameState()
    starting_player, top_roll = choose_starting_player(rng)
    state.current_player = starting_player

    turns = 0
    rolls = 0
    moves = 0
    captures = 0

    while turns < max_turns:
        player = state.current_player
        turns += 1

        while True:
            roll = rng.randint(1, 6)
            rolls += 1
            legal = legal_moves(state, player, roll)

            if legal:
                profile = PROFILES[players[player]]
                chosen = profile.choose_move(state, player, roll, legal)
                if chosen["captures"] is not None:
                    captures += 1
                update_exit_base_cursor(state, player, chosen)
                apply_move(state, chosen)
                moves += 1

                if state.player_won(player):
                    return GameResult(
                        game_index=game_index,
                        winner=player,
                        players=players,
                        starting_player=starting_player,
                        top_roll=top_roll,
                        turns=turns,
                        rolls=rolls,
                        moves=moves,
                        captures=captures,
                        seed=seed,
                    )

            if roll != 6:
                break

        state.current_player = (player + 1) % NUM_PLAYERS

    return GameResult(
        game_index=game_index,
        winner=None,
        players=players,
        starting_player=starting_player,
        top_roll=top_roll,
        turns=turns,
        rolls=rolls,
        moves=moves,
        captures=captures,
        seed=seed,
        max_turns_reached=True,
    )


def run_series(
    games: int = DEFAULT_GAMES,
    players: Sequence[str] = DEFAULT_PLAYERS,
    *,
    seed: int | None = None,
    max_turns: int = DEFAULT_MAX_TURNS,
) -> SeriesSummary:
    """Run N independent AI games and aggregate their results."""
    if games < 1:
        raise ValueError("games must be at least 1")
    if max_turns < 1:
        raise ValueError("max_turns must be at least 1")

    players = parse_players(players)
    seed_rng = random.Random(seed)
    results = []
    for index in range(1, games + 1):
        game_seed = seed_rng.randrange(1_000_000_000) if seed is not None else None
        results.append(
            play_game(
                players,
                seed=game_seed,
                game_index=index,
                max_turns=max_turns,
            )
        )
    return SeriesSummary(results=results, players=players)


def format_summary(summary: SeriesSummary) -> str:
    """Return a compact console report for a self-play series."""
    lines = []
    game_count = len(summary.results)
    lines.append(f"Self-play games: {game_count}")
    lines.append("Players: " + ", ".join(
        f"{PLAYER_NAMES[player]}={summary.players[player]}"
        for player in range(NUM_PLAYERS)
    ))
    lines.append(
        f"Completed: {summary.completed_games}  "
        f"Unfinished: {summary.unfinished_games}"
    )
    lines.append("")
    lines.append("Wins:")

    wins = summary.wins_by_player()
    denominator = summary.completed_games or 1
    for player in range(NUM_PLAYERS):
        win_count = wins[player]
        win_rate = (win_count / denominator) * 100
        lines.append(
            f"  {PLAYER_NAMES[player]:<6} {summary.players[player]:<10} "
            f"{win_count:>4} wins  {win_rate:>5.1f}%"
        )

    lines.append("")
    lines.append(f"Avg turns:   {summary.average_turns():.1f}")
    lines.append(f"Avg rolls:   {summary.average_rolls():.1f}")
    lines.append(f"Avg captures:{summary.average_captures():.1f}")
    return "\n".join(lines)


def format_benchmark_summary(summary: BenchmarkSummary) -> str:
    """Render a leaderboard-style report for benchmark mode."""
    lines = []
    lines.append("Benchmark Mode")
    lines.append(
        "Opponents: "
        + ", ".join(
            f"{PLAYER_NAMES[idx+1]}={name}"
            for idx, name in enumerate(summary.opponents)
        )
    )
    lines.append(
        f"Games per seat: {summary.games_per_seat} "
        f"(total per profile: {summary.games_per_seat * NUM_PLAYERS})"
    )
    lines.append("")
    lines.append("Leaderboard:")

    for rank, row in enumerate(summary.profile_results, start=1):
        lines.append(
            f"  {rank:>2}. {row.profile:<12} "
            f"wins {row.wins:>4}/{row.total_games:<4} "
            f"({row.win_rate * 100:>5.1f}%) "
            f"completed {row.completed_games}/{row.total_games}"
        )
        seat_bits = []
        for seat in range(NUM_PLAYERS):
            seat_bits.append(
                f"{PLAYER_NAMES[seat]} {row.seat_wins[seat]}/{row.seat_games[seat]}"
            )
        lines.append("      by seat: " + " | ".join(seat_bits))
        lines.append(
            f"      avg turns {row.avg_turns:.1f} | "
            f"avg rolls {row.avg_rolls:.1f} | "
            f"avg captures {row.avg_captures:.1f}"
        )

    return "\n".join(lines)


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description="Run headless Wahoo AI self-play.")
    parser.add_argument(
        "--games",
        type=int,
        default=DEFAULT_GAMES,
        help=f"number of games to run (default: {DEFAULT_GAMES})",
    )
    parser.add_argument(
        "--players",
        default=",".join(DEFAULT_PLAYERS),
        help="comma-separated AI profiles for Red,Green,Yellow,Blue",
    )
    parser.add_argument(
        "--seed",
        type=int,
        default=None,
        help="optional deterministic seed for the series",
    )
    parser.add_argument(
        "--max-turns",
        type=int,
        default=DEFAULT_MAX_TURNS,
        help=f"abort a game after this many player turns (default: {DEFAULT_MAX_TURNS})",
    )
    parser.add_argument(
        "--list-profiles",
        action="store_true",
        help="list available AI profile names and exit",
    )
    parser.add_argument(
        "--benchmark-profiles",
        default=None,
        help=(
            "comma-separated candidate profiles to rank in seat-rotated "
            "benchmark mode"
        ),
    )
    parser.add_argument(
        "--benchmark-opponents",
        default=",".join(DEFAULT_BENCHMARK_OPPONENTS),
        help="comma-separated fixed opponent profiles (exactly 3)",
    )
    parser.add_argument(
        "--benchmark-games-per-seat",
        type=int,
        default=DEFAULT_BENCHMARK_GAMES_PER_SEAT,
        help=(
            "games per seat for each candidate in benchmark mode "
            f"(default: {DEFAULT_BENCHMARK_GAMES_PER_SEAT})"
        ),
    )
    return parser


def main(argv: Sequence[str] | None = None) -> int:
    parser = build_parser()
    args = parser.parse_args(argv)

    if args.list_profiles:
        print("\n".join(sorted(PROFILES)))
        return 0

    try:
        if args.benchmark_profiles:
            summary = benchmark_profiles(
                profiles=parse_benchmark_profiles(args.benchmark_profiles),
                opponents=parse_benchmark_opponents(args.benchmark_opponents),
                games_per_seat=args.benchmark_games_per_seat,
                seed=args.seed,
                max_turns=args.max_turns,
            )
            print(format_benchmark_summary(summary))
            return 0

        players = parse_players(args.players)
        summary = run_series(
            games=args.games,
            players=players,
            seed=args.seed,
            max_turns=args.max_turns,
        )
    except ValueError as exc:
        parser.error(str(exc))

    print(format_summary(summary))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
