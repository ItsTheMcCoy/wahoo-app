#!/usr/bin/env python3
"""Run Stage 4 pairwise confirmation runs across direct seating layouts.

This script executes the direct matchup layouts from
documents/AI_TESTING_PLAN.md Stage 4 and writes:
- a markdown report suitable for copying into documents/AI_BENCHMARK_RESULTS.md
- a JSON file with structured per-layout and aggregate metrics

Default setup matches the full Stage 4 confirmation block:
- Profiles: sprinter,gambler,expectimax
- Layouts: 1,2,3,4
- Seeds: 20260531,20260532,20260533,20260534
- Games per layout: 500
- Max turns: 20000

Layout patterns:
- 1: A,B,A,B
- 2: B,A,B,A
- 3: A,A,B,B
- 4: B,B,A,A
"""

from __future__ import annotations

import argparse
import json
import sys
from dataclasses import asdict, dataclass
from datetime import datetime, timezone
from itertools import combinations
from pathlib import Path
from typing import Iterable, Sequence

# Allow execution from anywhere while still importing local package modules.
REPO_ROOT = Path(__file__).resolve().parents[1]
if str(REPO_ROOT) not in sys.path:
    sys.path.insert(0, str(REPO_ROOT))

from wahoo.selfplay import parse_benchmark_profiles, play_game  # noqa: E402

STANDARD_LAYOUTS = (1, 2, 3, 4)
STANDARD_SEEDS = (20260531, 20260532, 20260533, 20260534)
DEFAULT_PROFILES = (
    "sprinter",
    "gambler",
    "expectimax",
)
DEFAULT_GAMES_PER_LAYOUT = 500
DEFAULT_MAX_TURNS = 20_000


LAYOUT_PATTERNS: dict[int, tuple[int, int, int, int]] = {
    1: (0, 1, 0, 1),
    2: (1, 0, 1, 0),
    3: (0, 0, 1, 1),
    4: (1, 1, 0, 0),
}


@dataclass
class LayoutRunSummary:
    """Summary for one layout and seed combination."""

    layout: int
    seed: int
    lineup: tuple[str, ...]
    games: int
    completed_games: int
    unfinished_games: int
    wins_by_profile: dict[str, int]
    total_games_by_profile: dict[str, int]
    avg_turns: float
    avg_rolls: float
    avg_captures: float


@dataclass
class PairProfileSummary:
    """Aggregate summary for one profile within a pair matchup."""

    profile: str
    total_games: int
    completed_games: int
    unfinished_games: int
    wins: int
    win_rate: float
    completed_win_rate: float
    avg_turns: float
    avg_rolls: float
    avg_captures: float


def _parse_csv(value: str) -> tuple[str, ...]:
    return tuple(part.strip().lower() for part in value.split(",") if part.strip())


def _parse_seed_csv(value: str) -> tuple[int, ...]:
    seeds: list[int] = []
    for chunk in value.split(","):
        chunk = chunk.strip()
        if not chunk:
            continue
        seeds.append(int(chunk))
    if not seeds:
        raise argparse.ArgumentTypeError("at least one seed is required")
    return tuple(seeds)


def _parse_layout_csv(value: str) -> tuple[int, ...]:
    layouts: list[int] = []
    for chunk in value.split(","):
        chunk = chunk.strip()
        if not chunk:
            continue
        layout = int(chunk)
        if layout not in LAYOUT_PATTERNS:
            raise argparse.ArgumentTypeError(
                f"invalid layout {layout}; valid layouts: 1,2,3,4"
            )
        layouts.append(layout)
    if not layouts:
        raise argparse.ArgumentTypeError("at least one layout is required")
    if len(set(layouts)) != len(layouts):
        raise argparse.ArgumentTypeError("layouts must not repeat")
    return tuple(layouts)


def _format_lineup(layout: int, profiles: Sequence[str]) -> str:
    pattern = LAYOUT_PATTERNS[layout]
    return ",".join(profiles[idx] for idx in pattern)


def _average(values: Iterable[float]) -> float:
    values = list(values)
    if not values:
        return 0.0
    return sum(values) / len(values)


def _run_layout(
    profiles: Sequence[str],
    *,
    layout: int,
    seed: int,
    games: int,
    max_turns: int,
) -> LayoutRunSummary:
    lineup = tuple(profiles[idx] for idx in LAYOUT_PATTERNS[layout])
    wins_by_profile = {profile: 0 for profile in profiles}
    total_games_by_profile = {profile: games for profile in profiles}

    turns: list[int] = []
    rolls: list[int] = []
    captures: list[int] = []
    completed_games = 0

    for game_index in range(1, games + 1):
        game_seed = seed * 10_000 + game_index
        result = play_game(
            lineup,
            seed=game_seed,
            game_index=game_index,
            max_turns=max_turns,
        )
        turns.append(result.turns)
        rolls.append(result.rolls)
        captures.append(result.captures)

        if result.winner is not None:
            completed_games += 1
            winning_profile = lineup[result.winner]
            wins_by_profile[winning_profile] += 1

    unfinished_games = games - completed_games
    return LayoutRunSummary(
        layout=layout,
        seed=seed,
        lineup=lineup,
        games=games,
        completed_games=completed_games,
        unfinished_games=unfinished_games,
        wins_by_profile=wins_by_profile,
        total_games_by_profile=total_games_by_profile,
        avg_turns=_average(turns),
        avg_rolls=_average(rolls),
        avg_captures=_average(captures),
    )


def _aggregate_pair_runs(
    profiles: Sequence[str],
    layout_runs: Sequence[LayoutRunSummary],
) -> list[PairProfileSummary]:
    grouped: dict[str, dict[str, float | int]] = {
        profile: {
            "total_games": 0,
            "completed_games": 0,
            "unfinished_games": 0,
            "wins": 0,
            "avg_turns_sum": 0.0,
            "avg_rolls_sum": 0.0,
            "avg_captures_sum": 0.0,
        }
        for profile in profiles
    }

    for run in layout_runs:
        for profile in profiles:
            bucket = grouped[profile]
            games = run.total_games_by_profile[profile]
            bucket["total_games"] += games
            bucket["completed_games"] += run.completed_games
            bucket["unfinished_games"] += run.unfinished_games
            bucket["wins"] += run.wins_by_profile[profile]
            bucket["avg_turns_sum"] += run.avg_turns * games
            bucket["avg_rolls_sum"] += run.avg_rolls * games
            bucket["avg_captures_sum"] += run.avg_captures * games

    summaries: list[PairProfileSummary] = []
    for profile in profiles:
        bucket = grouped[profile]
        total_games = int(bucket["total_games"])
        completed_games = int(bucket["completed_games"])
        wins = int(bucket["wins"])
        summaries.append(
            PairProfileSummary(
                profile=profile,
                total_games=total_games,
                completed_games=completed_games,
                unfinished_games=int(bucket["unfinished_games"]),
                wins=wins,
                win_rate=(wins / total_games) if total_games else 0.0,
                completed_win_rate=(wins / completed_games) if completed_games else 0.0,
                avg_turns=(bucket["avg_turns_sum"] / total_games) if total_games else 0.0,
                avg_rolls=(bucket["avg_rolls_sum"] / total_games) if total_games else 0.0,
                avg_captures=(bucket["avg_captures_sum"] / total_games) if total_games else 0.0,
            )
        )

    summaries.sort(key=lambda row: (row.win_rate, row.completed_win_rate, -row.avg_turns), reverse=True)
    return summaries


def _profile_table(rows: Sequence[PairProfileSummary]) -> str:
    lines = []
    lines.append("| Rank | Profile | Wins | Win % | Completed | Unfinished | Avg Turns | Avg Rolls | Avg Captures |")
    lines.append("|------|---------|------|-------|-----------|------------|-----------|-----------|--------------|")
    for rank, row in enumerate(rows, start=1):
        lines.append(
            "| "
            f"{rank} | {row.profile} | {row.wins} | {row.win_rate * 100:.1f}% | "
            f"{row.completed_games}/{row.total_games} | {row.unfinished_games} | "
            f"{row.avg_turns:.1f} | {row.avg_rolls:.1f} | {row.avg_captures:.1f} |"
        )
    return "\n".join(lines)


def _layout_table(rows: Sequence[LayoutRunSummary], profiles: Sequence[str]) -> str:
    lines = []
    lines.append(
        f"| Layout | Seed | Lineup | Games | Completed | Unfinished | Wins {profiles[0]} | Wins {profiles[1]} | Avg Turns | Avg Rolls | Avg Captures |"
    )
    lines.append("|--------|------|--------|-------|-----------|------------|----------------|----------------|-----------|-----------|--------------|")
    for row in rows:
        lineup = ",".join(row.lineup)
        lines.append(
            "| "
            f"{row.layout} | {row.seed} | {lineup} | {row.games} | "
            f"{row.completed_games} | {row.unfinished_games} | "
            f"{row.wins_by_profile[profiles[0]]} | {row.wins_by_profile[profiles[1]]} | "
            f"{row.avg_turns:.1f} | {row.avg_rolls:.1f} | {row.avg_captures:.1f} |"
        )
    return "\n".join(lines)


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(
        description="Run Stage 4 pairwise confirmation matchups and export results."
    )
    parser.add_argument(
        "--profiles",
        default=",".join(DEFAULT_PROFILES),
        help="candidate profiles as CSV (default: sprinter,gambler,expectimax)",
    )
    parser.add_argument(
        "--layouts",
        type=_parse_layout_csv,
        default=STANDARD_LAYOUTS,
        help="layout CSV from 1,2,3,4 (default: 1,2,3,4)",
    )
    parser.add_argument(
        "--seeds",
        type=_parse_seed_csv,
        default=STANDARD_SEEDS,
        help="seed CSV aligned with layouts (default: 20260531,20260532,20260533,20260534)",
    )
    parser.add_argument(
        "--games-per-layout",
        type=int,
        default=DEFAULT_GAMES_PER_LAYOUT,
        help="games per pair per layout (default: 500)",
    )
    parser.add_argument(
        "--max-turns",
        type=int,
        default=DEFAULT_MAX_TURNS,
        help="per-game turn cap (default: 20000)",
    )
    parser.add_argument(
        "--output-md",
        default="documents/stage4_pairwise_confirmation_results.md",
        help="markdown output path (default: documents/stage4_pairwise_confirmation_results.md)",
    )
    parser.add_argument(
        "--output-json",
        default="documents/stage4_pairwise_confirmation_results.json",
        help="JSON output path (default: documents/stage4_pairwise_confirmation_results.json)",
    )
    return parser


def main(argv: Sequence[str] | None = None) -> int:
    args = build_parser().parse_args(argv)

    profiles = parse_benchmark_profiles(_parse_csv(args.profiles))
    layouts = tuple(int(layout) for layout in args.layouts)
    seeds = tuple(int(seed) for seed in args.seeds)

    if len(profiles) < 2:
        raise SystemExit("--profiles must include at least two AI profiles")
    if len(layouts) != len(seeds):
        raise SystemExit("--layouts and --seeds must have the same number of entries")
    if args.games_per_layout < 1:
        raise SystemExit("--games-per-layout must be at least 1")
    if args.max_turns < 1:
        raise SystemExit("--max-turns must be at least 1")

    md_path = (REPO_ROOT / args.output_md).resolve()
    json_path = (REPO_ROOT / args.output_json).resolve()
    md_path.parent.mkdir(parents=True, exist_ok=True)
    json_path.parent.mkdir(parents=True, exist_ok=True)

    started_at = datetime.now(timezone.utc)
    pair_results: dict[str, dict] = {}

    print("Running Stage 4 pairwise confirmation matchups...")
    print(f"Profiles: {', '.join(profiles)}")
    print(f"Layouts: {', '.join(str(layout) for layout in layouts)}")
    print(f"Seeds: {', '.join(str(seed) for seed in seeds)}")
    print(f"Games per layout: {args.games_per_layout} | Max turns: {args.max_turns}")

    for profile_a, profile_b in combinations(profiles, 2):
        pair_name = f"{profile_a}_vs_{profile_b}"
        print()
        print(f"Pair {profile_a} vs {profile_b}")

        layout_runs: list[LayoutRunSummary] = []
        for layout, seed in zip(layouts, seeds, strict=True):
            lineup = _format_lineup(layout, (profile_a, profile_b))
            print(f"  - Layout {layout} seed {seed} lineup {lineup} ...", end="", flush=True)
            run = _run_layout(
                (profile_a, profile_b),
                layout=layout,
                seed=seed,
                games=args.games_per_layout,
                max_turns=args.max_turns,
            )
            layout_runs.append(run)
            print(" done")

        aggregate = _aggregate_pair_runs((profile_a, profile_b), layout_runs)
        pair_results[pair_name] = {
            "profiles": (profile_a, profile_b),
            "layouts": [asdict(row) for row in layout_runs],
            "aggregate": [asdict(row) for row in aggregate],
        }

    ended_at = datetime.now(timezone.utc)
    report = {
        "metadata": {
            "generated_at_utc": ended_at.isoformat(),
            "started_at_utc": started_at.isoformat(),
            "completed_at_utc": ended_at.isoformat(),
            "profiles": profiles,
            "layouts": layouts,
            "seeds": seeds,
            "games_per_layout": args.games_per_layout,
            "total_games_per_profile_per_pair": args.games_per_layout * len(layouts),
            "max_turns": args.max_turns,
        },
        "pairs": pair_results,
    }

    with json_path.open("w", encoding="utf-8") as handle:
        json.dump(report, handle, indent=2)

    md_lines: list[str] = []
    md_lines.append("# Stage 4 Pairwise Confirmation Results")
    md_lines.append("")
    md_lines.append(f"Generated (UTC): {ended_at.isoformat()}")
    md_lines.append("")
    md_lines.append("## Run Configuration")
    md_lines.append("")
    md_lines.append(f"- Profiles: {','.join(profiles)}")
    md_lines.append(f"- Layouts: {', '.join(str(layout) for layout in layouts)}")
    md_lines.append(f"- Seeds: {', '.join(str(seed) for seed in seeds)}")
    md_lines.append(f"- Games per layout: {args.games_per_layout}")
    md_lines.append(f"- Max turns: {args.max_turns}")
    md_lines.append("")

    for pair_name, block in pair_results.items():
        profile_a, profile_b = block["profiles"]
        layout_runs = [LayoutRunSummary(**row) for row in block["layouts"]]
        aggregate = [PairProfileSummary(**row) for row in block["aggregate"]]

        md_lines.append(f"## Pair {profile_a} vs {profile_b}")
        md_lines.append("")
        md_lines.append("### Commands Run")
        md_lines.append("")
        for layout, seed in zip(layouts, seeds, strict=True):
            lineup = _format_lineup(layout, (profile_a, profile_b))
            md_lines.append(
                "```powershell\n"
                "python -m wahoo.selfplay "
                f"--games {args.games_per_layout} "
                f"--players {lineup} "
                f"--max-turns {args.max_turns} "
                f"--seed {seed}\n"
                "```"
            )
        md_lines.append("")
        md_lines.append("### Layout Results")
        md_lines.append("")
        md_lines.append(_layout_table(layout_runs, (profile_a, profile_b)))
        md_lines.append("")
        md_lines.append("### Aggregate Across Layouts")
        md_lines.append("")
        md_lines.append(_profile_table(aggregate))
        if len(aggregate) == 2:
            left, right = aggregate
            margin = left.win_rate - right.win_rate
            winner = left.profile if margin >= 0 else right.profile
            md_lines.append("")
            md_lines.append(
                f"Winner: {winner} by {abs(margin) * 100:.1f} percentage points on aggregate win rate."
            )
        md_lines.append("")

    with md_path.open("w", encoding="utf-8") as handle:
        handle.write("\n".join(md_lines).rstrip() + "\n")

    print()
    print(f"Wrote markdown report: {md_path}")
    print(f"Wrote JSON report: {json_path}")
    print("Finished.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())