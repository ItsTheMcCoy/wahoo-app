#!/usr/bin/env python3
"""Run Stage 3 mixed-opponent gauntlets across standard seeds.

This script executes benchmark mode for gauntlets A/B/C and writes:
- A markdown report suitable for copying into documents/AI_BENCHMARK_RESULTS.md
- A JSON file with structured per-seed and aggregated metrics

Default setup matches documents/AI_TESTING_PLAN.md Stage 3:
- Candidates: sprinter,gambler,expectimax
- Seeds: 20260526..20260530
- Games per seat: 100
- Max turns: 20000
- Gauntlet A opponents: assassin,tortoise,balanced
- Gauntlet B opponents: gambler,gatekeeper,engineer
- Gauntlet C opponents: random,balanced,balanced
"""

from __future__ import annotations

import argparse
import json
import sys
from dataclasses import asdict
from datetime import datetime, timezone
from pathlib import Path
from typing import Iterable

# Allow execution from anywhere while still importing local package modules.
REPO_ROOT = Path(__file__).resolve().parents[1]
if str(REPO_ROOT) not in sys.path:
    sys.path.insert(0, str(REPO_ROOT))

from wahoo.selfplay import benchmark_profiles, parse_benchmark_profiles  # noqa: E402

STANDARD_SEEDS = (20260526, 20260527, 20260528, 20260529, 20260530)
DEFAULT_PROFILES = ("sprinter", "gambler", "expectimax")
DEFAULT_GAUNTLETS = {
    "A": ("assassin", "tortoise", "balanced"),
    "B": ("gambler", "gatekeeper", "engineer"),
    "C": ("random", "balanced", "balanced"),
}


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


def _parse_gauntlet_keys(value: str) -> tuple[str, ...]:
    keys = tuple(part.strip().upper() for part in value.split(",") if part.strip())
    invalid = [key for key in keys if key not in DEFAULT_GAUNTLETS]
    if invalid:
        raise argparse.ArgumentTypeError(
            f"invalid gauntlet key(s): {', '.join(invalid)}; valid: A,B,C"
        )
    if not keys:
        raise argparse.ArgumentTypeError("at least one gauntlet key is required")
    return keys


def _weighted_mean(pairs: Iterable[tuple[float, int]]) -> float:
    total_weight = 0
    weighted_sum = 0.0
    for value, weight in pairs:
        weighted_sum += value * weight
        total_weight += weight
    if total_weight == 0:
        return 0.0
    return weighted_sum / total_weight


def _aggregate_seed_rows(seed_rows: list[dict]) -> list[dict]:
    grouped: dict[str, dict] = {}
    for row in seed_rows:
        profile = row["profile"]
        bucket = grouped.setdefault(
            profile,
            {
                "profile": profile,
                "total_games": 0,
                "completed_games": 0,
                "unfinished_games": 0,
                "wins": 0,
                "seat_wins": [0, 0, 0, 0],
                "seat_games": [0, 0, 0, 0],
                "avg_turns_pairs": [],
                "avg_rolls_pairs": [],
                "avg_captures_pairs": [],
            },
        )

        games = int(row["total_games"])
        bucket["total_games"] += games
        bucket["completed_games"] += int(row["completed_games"])
        bucket["unfinished_games"] += int(row["unfinished_games"])
        bucket["wins"] += int(row["wins"])
        bucket["avg_turns_pairs"].append((float(row["avg_turns"]), games))
        bucket["avg_rolls_pairs"].append((float(row["avg_rolls"]), games))
        bucket["avg_captures_pairs"].append((float(row["avg_captures"]), games))

        for idx in range(4):
            bucket["seat_wins"][idx] += int(row["seat_wins"][idx])
            bucket["seat_games"][idx] += int(row["seat_games"][idx])

    output: list[dict] = []
    for profile, bucket in grouped.items():
        total_games = bucket["total_games"]
        completed_games = bucket["completed_games"]
        wins = bucket["wins"]
        output.append(
            {
                "profile": profile,
                "total_games": total_games,
                "completed_games": completed_games,
                "unfinished_games": bucket["unfinished_games"],
                "wins": wins,
                "win_rate": (wins / total_games) if total_games else 0.0,
                "completed_win_rate": (wins / completed_games) if completed_games else 0.0,
                "avg_turns": _weighted_mean(bucket["avg_turns_pairs"]),
                "avg_rolls": _weighted_mean(bucket["avg_rolls_pairs"]),
                "avg_captures": _weighted_mean(bucket["avg_captures_pairs"]),
                "seat_wins": tuple(bucket["seat_wins"]),
                "seat_games": tuple(bucket["seat_games"]),
            }
        )

    output.sort(key=lambda r: (r["win_rate"], r["completed_win_rate"], -r["avg_turns"]), reverse=True)
    return output


def _leaderboard_table(rows: list[dict]) -> str:
    lines = []
    lines.append("| Rank | Profile | Wins | Win % | Completed | Avg Turns | Avg Rolls | Avg Captures | Seat (R/G/Y/B) |")
    lines.append("|------|---------|------|-------|-----------|-----------|-----------|--------------|----------------|")
    for rank, row in enumerate(rows, start=1):
        seat = f"{row['seat_wins'][0]} / {row['seat_wins'][1]} / {row['seat_wins'][2]} / {row['seat_wins'][3]}"
        completed = f"{row['completed_games']}/{row['total_games']}"
        lines.append(
            "| "
            f"{rank} | {row['profile']} | {row['wins']} | {row['win_rate'] * 100:.1f}% | {completed} "
            f"| {row['avg_turns']:.1f} | {row['avg_rolls']:.1f} | {row['avg_captures']:.1f} | {seat} |"
        )
    return "\n".join(lines)


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(
        description="Run all Stage 3 mixed-opponent gauntlets across standard seeds and export results."
    )
    parser.add_argument(
        "--profiles",
        default=",".join(DEFAULT_PROFILES),
        help="candidate profiles as CSV (default: sprinter,gambler,expectimax)",
    )
    parser.add_argument(
        "--seeds",
        type=_parse_seed_csv,
        default=STANDARD_SEEDS,
        help="seed CSV (default: 20260526,20260527,20260528,20260529,20260530)",
    )
    parser.add_argument(
        "--gauntlets",
        type=_parse_gauntlet_keys,
        default=tuple(DEFAULT_GAUNTLETS.keys()),
        help="gauntlets to run as CSV of A,B,C (default: A,B,C)",
    )
    parser.add_argument(
        "--games-per-seat",
        type=int,
        default=100,
        help="benchmark games per seat (default: 100)",
    )
    parser.add_argument(
        "--max-turns",
        type=int,
        default=20000,
        help="per-game turn cap (default: 20000)",
    )
    parser.add_argument(
        "--output-md",
        default="documents/stage3_mixed_opponent_results.md",
        help="markdown output path (default: documents/stage3_mixed_opponent_results.md)",
    )
    parser.add_argument(
        "--output-json",
        default="documents/stage3_mixed_opponent_results.json",
        help="JSON output path (default: documents/stage3_mixed_opponent_results.json)",
    )
    return parser


def main(argv: list[str] | None = None) -> int:
    args = build_parser().parse_args(argv)

    profiles = parse_benchmark_profiles(_parse_csv(args.profiles))
    seeds = tuple(int(seed) for seed in args.seeds)

    if args.games_per_seat < 1:
        raise SystemExit("--games-per-seat must be at least 1")
    if args.max_turns < 1:
        raise SystemExit("--max-turns must be at least 1")

    md_path = (REPO_ROOT / args.output_md).resolve()
    json_path = (REPO_ROOT / args.output_json).resolve()
    md_path.parent.mkdir(parents=True, exist_ok=True)
    json_path.parent.mkdir(parents=True, exist_ok=True)

    started_at = datetime.now(timezone.utc)
    gauntlet_results: dict[str, dict] = {}

    print("Running mixed-opponent gauntlets...")
    print(f"Profiles: {', '.join(profiles)}")
    print(f"Seeds: {', '.join(str(seed) for seed in seeds)}")
    print(f"Games per seat: {args.games_per_seat} | Max turns: {args.max_turns}")

    for gauntlet_key in args.gauntlets:
        opponents = DEFAULT_GAUNTLETS[gauntlet_key]
        print()
        print(f"Gauntlet {gauntlet_key}: opponents={','.join(opponents)}")

        seed_data: list[dict] = []
        for seed in seeds:
            print(f"  - Seed {seed} ...", end="", flush=True)
            summary = benchmark_profiles(
                profiles=profiles,
                opponents=opponents,
                games_per_seat=args.games_per_seat,
                seed=seed,
                max_turns=args.max_turns,
            )
            print(" done")
            seed_data.append(
                {
                    "seed": seed,
                    "profiles": [asdict(row) for row in summary.profile_results],
                }
            )

        aggregate = _aggregate_seed_rows(
            [row for seed_block in seed_data for row in seed_block["profiles"]]
        )

        gauntlet_results[gauntlet_key] = {
            "opponents": opponents,
            "seeds": seed_data,
            "aggregate": aggregate,
        }

    ended_at = datetime.now(timezone.utc)

    report = {
        "metadata": {
            "generated_at_utc": ended_at.isoformat(),
            "started_at_utc": started_at.isoformat(),
            "completed_at_utc": ended_at.isoformat(),
            "profiles": profiles,
            "seeds": seeds,
            "games_per_seed_per_profile": args.games_per_seat * 4,
            "games_per_profile_per_gauntlet": args.games_per_seat * 4 * len(seeds),
            "games_per_seat": args.games_per_seat,
            "max_turns": args.max_turns,
        },
        "gauntlets": gauntlet_results,
    }

    with json_path.open("w", encoding="utf-8") as handle:
        json.dump(report, handle, indent=2)

    md_lines: list[str] = []
    md_lines.append("# Stage 3 Mixed-Opponent Gauntlet Results")
    md_lines.append("")
    md_lines.append(f"Generated (UTC): {ended_at.isoformat()}")
    md_lines.append("")
    md_lines.append("## Run Configuration")
    md_lines.append("")
    md_lines.append(f"- Profiles: {','.join(profiles)}")
    md_lines.append(f"- Seeds: {', '.join(str(seed) for seed in seeds)}")
    md_lines.append(f"- Games per seat: {args.games_per_seat}")
    md_lines.append(f"- Max turns: {args.max_turns}")
    md_lines.append("")

    for gauntlet_key in args.gauntlets:
        block = gauntlet_results[gauntlet_key]
        opponents = block["opponents"]

        md_lines.append(f"## Gauntlet {gauntlet_key}")
        md_lines.append("")
        md_lines.append(f"Opponents: {','.join(opponents)}")
        md_lines.append("")
        md_lines.append("### Commands Run")
        md_lines.append("")
        for seed in seeds:
            md_lines.append(
                "```powershell\n"
                "python -m wahoo.selfplay "
                f"--benchmark-profiles {','.join(profiles)} "
                f"--benchmark-opponents {','.join(opponents)} "
                f"--benchmark-games-per-seat {args.games_per_seat} "
                f"--max-turns {args.max_turns} "
                f"--seed {seed}\n"
                "```"
            )
        md_lines.append("")

        for seed_block in block["seeds"]:
            seed = seed_block["seed"]
            rows = sorted(
                seed_block["profiles"],
                key=lambda r: (r["win_rate"], r["completed_win_rate"], -r["avg_turns"]),
                reverse=True,
            )
            md_lines.append(f"### Seed {seed}")
            md_lines.append("")
            md_lines.append(_leaderboard_table(rows))
            md_lines.append("")

        md_lines.append("### Aggregate Across Standard Seeds")
        md_lines.append("")
        md_lines.append(_leaderboard_table(block["aggregate"]))
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
