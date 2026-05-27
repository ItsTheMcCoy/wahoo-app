#!/usr/bin/env python3
"""Tune a GreedyPlayer profile to surpass sprinter using automated search.

This script implements the objective function and seed split policy from
`documents/AI_SPRINTER_BEATING_TRAINING_PLAN.md`.

Search method:
- random-plus-mutation evolutionary loop
- deterministic with --random-seed
- checkpointable to JSON after each generation

Evaluation method:
- Calls `wahoo.selfplay.benchmark_profiles(...)` directly for reliable,
  machine-readable metrics.
- For each seed, runs the candidate against three fixed-opponent fields:
  sprinter,sprinter,sprinter
  gambler,gambler,gambler
  balanced,balanced,balanced
- Aggregates win rates, unfinished rate, and seat spread.
"""

from __future__ import annotations

import argparse
import json
import random
import sys
from copy import deepcopy
from dataclasses import asdict, dataclass
from datetime import datetime, timezone
from pathlib import Path
from typing import Any

REPO_ROOT = Path(__file__).resolve().parents[1]
if str(REPO_ROOT) not in sys.path:
    sys.path.insert(0, str(REPO_ROOT))

from wahoo.ai import (  # noqa: E402
    BALANCED_WEIGHTS,
    DEFAULT_PHASE_WEIGHTS,
    GAMBLER_WEIGHTS,
    GreedyPlayer,
    PROFILES,
    SPRINTER_WEIGHTS,
)
from wahoo.selfplay import benchmark_profiles  # noqa: E402

FEATURE_KEYS = ("DEP", "RUN", "SPR", "CAP", "SAFE", "CTR", "DEN", "FLOW", "HOME", "FIN")
PHASE_KEYS = ("early", "mid", "late")

DEFAULT_SEARCH_SEEDS = (20260601, 20260602, 20260603)
DEFAULT_HOLDOUT_SEEDS = (20260526, 20260527, 20260528, 20260529, 20260530)
DEFAULT_OPPONENTS = ("sprinter", "gambler", "balanced")


@dataclass
class Candidate:
    """One candidate profile payload for evaluation and mutation."""

    candidate_id: str
    parent_id: str | None
    weights: dict[str, float]
    phase_weights: dict[str, dict[str, float]]


@dataclass
class SeedMetric:
    """Seed-level metrics vs one fixed opponent field."""

    seed: int
    opponent: str
    wins: int
    total_games: int
    unfinished_games: int
    seat_wins: tuple[int, int, int, int]
    seat_games: tuple[int, int, int, int]
    win_rate: float


@dataclass
class EvaluationSummary:
    """Aggregated objective and diagnostics for one candidate."""

    score: float
    wr_vs_sprinter: float
    wr_vs_gambler: float
    wr_vs_balanced: float
    min_seed_wr_vs_sprinter: float
    unfinished_rate: float
    seat_spread: float
    total_games: int
    seed_metrics: list[SeedMetric]


def _parse_csv_ints(value: str) -> tuple[int, ...]:
    items: list[int] = []
    for chunk in value.split(","):
        chunk = chunk.strip()
        if not chunk:
            continue
        items.append(int(chunk))
    if not items:
        raise argparse.ArgumentTypeError("at least one integer is required")
    return tuple(items)


def _blend_weights(a: dict[str, float], b: dict[str, float], alpha: float) -> dict[str, float]:
    out: dict[str, float] = {}
    for key in FEATURE_KEYS:
        out[key] = (1.0 - alpha) * float(a[key]) + alpha * float(b[key])
    return out


def _clone_phase_weights(phase_weights: dict[str, dict[str, float]]) -> dict[str, dict[str, float]]:
    return {
        phase: {key: float(value) for key, value in phase_weights.get(phase, {}).items()}
        for phase in PHASE_KEYS
    }


def _canonical_phase_weights(phase_weights: dict[str, dict[str, float]]) -> dict[str, dict[str, float]]:
    """Fill sparse phase maps so every phase has all feature keys."""
    out: dict[str, dict[str, float]] = {}
    for phase in PHASE_KEYS:
        phase_map = phase_weights.get(phase, {})
        out[phase] = {key: float(phase_map.get(key, 0.0)) for key in FEATURE_KEYS}
    return out


def _seed_candidates() -> list[Candidate]:
    blended = _blend_weights(SPRINTER_WEIGHTS, GAMBLER_WEIGHTS, alpha=0.5)
    base_phase = _clone_phase_weights(DEFAULT_PHASE_WEIGHTS)
    return [
        Candidate(
            candidate_id="seed_sprinter",
            parent_id=None,
            weights={key: float(SPRINTER_WEIGHTS[key]) for key in FEATURE_KEYS},
            phase_weights=_clone_phase_weights(base_phase),
        ),
        Candidate(
            candidate_id="seed_gambler",
            parent_id=None,
            weights={key: float(GAMBLER_WEIGHTS[key]) for key in FEATURE_KEYS},
            phase_weights=_clone_phase_weights(base_phase),
        ),
        Candidate(
            candidate_id="seed_balanced",
            parent_id=None,
            weights={key: float(BALANCED_WEIGHTS[key]) for key in FEATURE_KEYS},
            phase_weights=_clone_phase_weights(base_phase),
        ),
        Candidate(
            candidate_id="seed_blend_sprinter_gambler",
            parent_id=None,
            weights=blended,
            phase_weights=_clone_phase_weights(base_phase),
        ),
    ]


def _mutate_candidate(
    base: Candidate,
    *,
    rng: random.Random,
    weight_sigma: float,
    phase_sigma: float,
    max_weight: float,
    max_phase_weight: float,
    candidate_id: str,
) -> Candidate:
    weights = {}
    for key in FEATURE_KEYS:
        value = float(base.weights[key]) + rng.gauss(0.0, weight_sigma)
        weights[key] = max(0.0, min(max_weight, value))

    phase = _canonical_phase_weights(base.phase_weights)
    for phase_name in PHASE_KEYS:
        for key in FEATURE_KEYS:
            value = float(phase[phase_name][key]) + rng.gauss(0.0, phase_sigma)
            phase[phase_name][key] = max(0.0, min(max_phase_weight, value))

    return Candidate(
        candidate_id=candidate_id,
        parent_id=base.candidate_id,
        weights=weights,
        phase_weights=phase,
    )


def _register_temp_profile(profile_name: str, candidate: Candidate) -> None:
    if profile_name in PROFILES:
        raise ValueError(f"temporary profile name collision: {profile_name}")
    PROFILES[profile_name] = GreedyPlayer(candidate.weights, candidate.phase_weights)


def _unregister_temp_profile(profile_name: str) -> None:
    PROFILES.pop(profile_name, None)


def _evaluate_candidate(
    candidate: Candidate,
    *,
    search_seeds: tuple[int, ...],
    games_per_seat: int,
    max_turns: int,
) -> EvaluationSummary:
    temp_name = f"tmp_tune_{candidate.candidate_id}"
    _register_temp_profile(temp_name, candidate)
    seed_rows: list[SeedMetric] = []

    try:
        for opponent in DEFAULT_OPPONENTS:
            field = (opponent, opponent, opponent)
            for seed in search_seeds:
                summary = benchmark_profiles(
                    profiles=(temp_name,),
                    opponents=field,
                    games_per_seat=games_per_seat,
                    seed=seed,
                    max_turns=max_turns,
                )
                row = summary.profile_results[0]
                seed_rows.append(
                    SeedMetric(
                        seed=seed,
                        opponent=opponent,
                        wins=row.wins,
                        total_games=row.total_games,
                        unfinished_games=row.unfinished_games,
                        seat_wins=tuple(row.seat_wins),
                        seat_games=tuple(row.seat_games),
                        win_rate=(row.wins / row.total_games) if row.total_games else 0.0,
                    )
                )
    finally:
        _unregister_temp_profile(temp_name)

    wr_by_opp: dict[str, float] = {}
    for opponent in DEFAULT_OPPONENTS:
        wins = sum(r.wins for r in seed_rows if r.opponent == opponent)
        games = sum(r.total_games for r in seed_rows if r.opponent == opponent)
        wr_by_opp[opponent] = (wins / games) if games else 0.0

    sprinter_seed_rates: list[float] = [
        r.win_rate for r in seed_rows if r.opponent == "sprinter"
    ]

    total_games = sum(r.total_games for r in seed_rows)
    unfinished_games = sum(r.unfinished_games for r in seed_rows)

    seat_wins = [0, 0, 0, 0]
    seat_games = [0, 0, 0, 0]
    for row in seed_rows:
        for idx in range(4):
            seat_wins[idx] += row.seat_wins[idx]
            seat_games[idx] += row.seat_games[idx]

    seat_rates = [
        (seat_wins[i] / seat_games[i]) if seat_games[i] else 0.0
        for i in range(4)
    ]
    seat_spread = max(seat_rates) - min(seat_rates) if seat_rates else 0.0
    unfinished_rate = (unfinished_games / total_games) if total_games else 0.0
    min_seed_wr_vs_sprinter = min(sprinter_seed_rates) if sprinter_seed_rates else 0.0

    wr_vs_sprinter = wr_by_opp["sprinter"]
    wr_vs_gambler = wr_by_opp["gambler"]
    wr_vs_balanced = wr_by_opp["balanced"]

    # Objective from AI_SPRINTER_BEATING_TRAINING_PLAN.md
    score = (
        0.50 * wr_vs_sprinter
        + 0.20 * wr_vs_gambler
        + 0.15 * wr_vs_balanced
        + 0.10 * min_seed_wr_vs_sprinter
        - 0.30 * unfinished_rate
        - 0.10 * seat_spread
    )

    return EvaluationSummary(
        score=score,
        wr_vs_sprinter=wr_vs_sprinter,
        wr_vs_gambler=wr_vs_gambler,
        wr_vs_balanced=wr_vs_balanced,
        min_seed_wr_vs_sprinter=min_seed_wr_vs_sprinter,
        unfinished_rate=unfinished_rate,
        seat_spread=seat_spread,
        total_games=total_games,
        seed_metrics=seed_rows,
    )


def _evaluate_holdout(
    candidate: Candidate,
    *,
    holdout_seeds: tuple[int, ...],
    games_per_seat: int,
    max_turns: int,
) -> EvaluationSummary:
    return _evaluate_candidate(
        candidate,
        search_seeds=holdout_seeds,
        games_per_seat=games_per_seat,
        max_turns=max_turns,
    )


def _candidate_to_dict(candidate: Candidate) -> dict[str, Any]:
    return {
        "candidate_id": candidate.candidate_id,
        "parent_id": candidate.parent_id,
        "weights": {key: float(candidate.weights[key]) for key in FEATURE_KEYS},
        "phase_weights": {
            phase: {
                key: float(candidate.phase_weights.get(phase, {}).get(key, 0.0))
                for key in FEATURE_KEYS
            }
            for phase in PHASE_KEYS
        },
    }


def _summary_to_dict(summary: EvaluationSummary) -> dict[str, Any]:
    return {
        "score": summary.score,
        "wr_vs_sprinter": summary.wr_vs_sprinter,
        "wr_vs_gambler": summary.wr_vs_gambler,
        "wr_vs_balanced": summary.wr_vs_balanced,
        "min_seed_wr_vs_sprinter": summary.min_seed_wr_vs_sprinter,
        "unfinished_rate": summary.unfinished_rate,
        "seat_spread": summary.seat_spread,
        "total_games": summary.total_games,
        "seed_metrics": [asdict(row) for row in summary.seed_metrics],
    }


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(
        description="Search for a new GreedyPlayer profile to beat sprinter consistently."
    )
    parser.add_argument("--generations", type=int, default=8, help="number of search generations")
    parser.add_argument("--population-size", type=int, default=20, help="candidates per generation")
    parser.add_argument("--elite-count", type=int, default=4, help="top candidates kept each generation")
    parser.add_argument("--games-per-seat", type=int, default=15, help="mini-benchmark games per seat")
    parser.add_argument("--max-turns", type=int, default=20000, help="max turns per game")
    parser.add_argument(
        "--search-seeds",
        type=_parse_csv_ints,
        default=DEFAULT_SEARCH_SEEDS,
        help="CSV seed list for candidate selection (default: 20260601,20260602,20260603)",
    )
    parser.add_argument(
        "--holdout-seeds",
        type=_parse_csv_ints,
        default=DEFAULT_HOLDOUT_SEEDS,
        help="CSV seed list for holdout verification",
    )
    parser.add_argument("--weight-sigma", type=float, default=0.18, help="mutation sigma for base weights")
    parser.add_argument("--phase-sigma", type=float, default=0.08, help="mutation sigma for phase weights")
    parser.add_argument("--max-weight", type=float, default=3.0, help="upper clamp for base feature weights")
    parser.add_argument("--max-phase-weight", type=float, default=1.5, help="upper clamp for phase feature weights")
    parser.add_argument("--random-seed", type=int, default=20260601, help="RNG seed for search")
    parser.add_argument(
        "--checkpoint-json",
        default="documents/sprinter_tuning_checkpoint.json",
        help="checkpoint output path",
    )
    parser.add_argument(
        "--output-json",
        default="documents/sprinter_tuning_results.json",
        help="final result output path",
    )
    parser.add_argument(
        "--output-md",
        default="documents/sprinter_tuning_results.md",
        help="markdown summary output path",
    )
    return parser


def _validate_args(args: argparse.Namespace) -> None:
    if args.generations < 1:
        raise SystemExit("--generations must be >= 1")
    if args.population_size < 2:
        raise SystemExit("--population-size must be >= 2")
    if args.elite_count < 1 or args.elite_count >= args.population_size:
        raise SystemExit("--elite-count must be >= 1 and < --population-size")
    if args.games_per_seat < 1:
        raise SystemExit("--games-per-seat must be >= 1")
    if args.max_turns < 1:
        raise SystemExit("--max-turns must be >= 1")


def _write_json(path: Path, payload: dict[str, Any]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("w", encoding="utf-8") as handle:
        json.dump(payload, handle, indent=2)


def _write_markdown(path: Path, payload: dict[str, Any]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)

    best = payload["best_candidate"]
    search = best["search_metrics"]
    holdout = best["holdout_metrics"]

    lines: list[str] = []
    lines.append("# Sprinter Tuning Results")
    lines.append("")
    lines.append(f"Generated (UTC): {payload['generated_at_utc']}")
    lines.append("")
    lines.append("## Configuration")
    lines.append("")
    cfg = payload["config"]
    lines.append(f"- Generations: {cfg['generations']}")
    lines.append(f"- Population size: {cfg['population_size']}")
    lines.append(f"- Elite count: {cfg['elite_count']}")
    lines.append(f"- Games per seat: {cfg['games_per_seat']}")
    lines.append(f"- Search seeds: {', '.join(str(seed) for seed in cfg['search_seeds'])}")
    lines.append(f"- Holdout seeds: {', '.join(str(seed) for seed in cfg['holdout_seeds'])}")
    lines.append("")
    lines.append("## Best Candidate")
    lines.append("")
    lines.append(f"- Candidate ID: {best['candidate']['candidate_id']}")
    lines.append(f"- Parent ID: {best['candidate']['parent_id']}")
    lines.append(f"- Search score: {search['score']:.4f}")
    lines.append(f"- Search wr vs sprinter: {search['wr_vs_sprinter'] * 100:.2f}%")
    lines.append(f"- Search wr vs gambler: {search['wr_vs_gambler'] * 100:.2f}%")
    lines.append(f"- Search wr vs balanced: {search['wr_vs_balanced'] * 100:.2f}%")
    lines.append(f"- Search unfinished rate: {search['unfinished_rate'] * 100:.2f}%")
    lines.append(f"- Search seat spread: {search['seat_spread'] * 100:.2f}%")
    lines.append(f"- Holdout score: {holdout['score']:.4f}")
    lines.append(f"- Holdout wr vs sprinter: {holdout['wr_vs_sprinter'] * 100:.2f}%")
    lines.append("")
    lines.append("## Weights")
    lines.append("")
    lines.append("```json")
    lines.append(json.dumps(best["candidate"]["weights"], indent=2))
    lines.append("```")
    lines.append("")
    lines.append("## Phase Weights")
    lines.append("")
    lines.append("```json")
    lines.append(json.dumps(best["candidate"]["phase_weights"], indent=2))
    lines.append("```")

    with path.open("w", encoding="utf-8") as handle:
        handle.write("\n".join(lines) + "\n")


def main(argv: list[str] | None = None) -> int:
    args = build_parser().parse_args(argv)
    _validate_args(args)

    rng = random.Random(args.random_seed)
    checkpoint_path = (REPO_ROOT / args.checkpoint_json).resolve()
    output_json_path = (REPO_ROOT / args.output_json).resolve()
    output_md_path = (REPO_ROOT / args.output_md).resolve()

    generation_history: list[dict[str, Any]] = []

    base_seeds = _seed_candidates()
    all_candidates: list[Candidate] = []
    all_candidates.extend(base_seeds)

    print("Starting sprinter-tuning search...")
    print(f"Generations: {args.generations}")
    print(f"Population size: {args.population_size} | Elite count: {args.elite_count}")
    print(f"Search seeds: {', '.join(str(seed) for seed in args.search_seeds)}")

    serial = 0
    for generation in range(1, args.generations + 1):
        print()
        print(f"Generation {generation}/{args.generations}")

        if generation == 1:
            population = deepcopy(all_candidates)
            while len(population) < args.population_size:
                parent = rng.choice(base_seeds)
                serial += 1
                population.append(
                    _mutate_candidate(
                        parent,
                        rng=rng,
                        weight_sigma=args.weight_sigma,
                        phase_sigma=args.phase_sigma,
                        max_weight=args.max_weight,
                        max_phase_weight=args.max_phase_weight,
                        candidate_id=f"g{generation}_m{serial}",
                    )
                )
        else:
            previous_elites = [Candidate(**entry["candidate"]) for entry in generation_history[-1]["elites"]]
            population = previous_elites[:]
            while len(population) < args.population_size:
                parent = rng.choice(previous_elites)
                serial += 1
                population.append(
                    _mutate_candidate(
                        parent,
                        rng=rng,
                        weight_sigma=args.weight_sigma,
                        phase_sigma=args.phase_sigma,
                        max_weight=args.max_weight,
                        max_phase_weight=args.max_phase_weight,
                        candidate_id=f"g{generation}_m{serial}",
                    )
                )

        evaluated: list[dict[str, Any]] = []
        for idx, candidate in enumerate(population, start=1):
            print(f"  Evaluating {idx}/{len(population)}: {candidate.candidate_id}")
            summary = _evaluate_candidate(
                candidate,
                search_seeds=tuple(args.search_seeds),
                games_per_seat=args.games_per_seat,
                max_turns=args.max_turns,
            )
            evaluated.append(
                {
                    "candidate": _candidate_to_dict(candidate),
                    "search_metrics": _summary_to_dict(summary),
                }
            )

        evaluated.sort(key=lambda row: row["search_metrics"]["score"], reverse=True)
        elites = evaluated[: args.elite_count]
        best = evaluated[0]

        print(
            "  Best this generation: "
            f"{best['candidate']['candidate_id']} score={best['search_metrics']['score']:.4f} "
            f"wr_sprinter={best['search_metrics']['wr_vs_sprinter'] * 100:.2f}%"
        )

        generation_history.append(
            {
                "generation": generation,
                "best": best,
                "elites": elites,
            }
        )

        checkpoint_payload = {
            "generated_at_utc": datetime.now(timezone.utc).isoformat(),
            "config": {
                "generations": args.generations,
                "population_size": args.population_size,
                "elite_count": args.elite_count,
                "games_per_seat": args.games_per_seat,
                "max_turns": args.max_turns,
                "search_seeds": tuple(args.search_seeds),
                "holdout_seeds": tuple(args.holdout_seeds),
                "weight_sigma": args.weight_sigma,
                "phase_sigma": args.phase_sigma,
                "max_weight": args.max_weight,
                "max_phase_weight": args.max_phase_weight,
                "random_seed": args.random_seed,
            },
            "generation_history": generation_history,
        }
        _write_json(checkpoint_path, checkpoint_payload)

    overall_best = max(
        (entry["best"] for entry in generation_history),
        key=lambda row: row["search_metrics"]["score"],
    )

    best_candidate = Candidate(**overall_best["candidate"])
    holdout_summary = _evaluate_holdout(
        best_candidate,
        holdout_seeds=tuple(args.holdout_seeds),
        games_per_seat=args.games_per_seat,
        max_turns=args.max_turns,
    )

    result_payload = {
        "generated_at_utc": datetime.now(timezone.utc).isoformat(),
        "config": {
            "generations": args.generations,
            "population_size": args.population_size,
            "elite_count": args.elite_count,
            "games_per_seat": args.games_per_seat,
            "max_turns": args.max_turns,
            "search_seeds": tuple(args.search_seeds),
            "holdout_seeds": tuple(args.holdout_seeds),
            "weight_sigma": args.weight_sigma,
            "phase_sigma": args.phase_sigma,
            "max_weight": args.max_weight,
            "max_phase_weight": args.max_phase_weight,
            "random_seed": args.random_seed,
            "objective": {
                "score": "0.50*wr_sprinter + 0.20*wr_gambler + 0.15*wr_balanced + 0.10*min_seed_wr_sprinter - 0.30*unfinished_rate - 0.10*seat_spread"
            },
        },
        "best_candidate": {
            "candidate": _candidate_to_dict(best_candidate),
            "search_metrics": overall_best["search_metrics"],
            "holdout_metrics": _summary_to_dict(holdout_summary),
        },
        "generation_history": generation_history,
    }

    _write_json(output_json_path, result_payload)
    _write_markdown(output_md_path, result_payload)

    print()
    print("Search complete.")
    print(f"Checkpoint: {checkpoint_path}")
    print(f"Final JSON: {output_json_path}")
    print(f"Final markdown: {output_md_path}")
    print(
        "Best candidate: "
        f"{best_candidate.candidate_id} "
        f"search_score={overall_best['search_metrics']['score']:.4f} "
        f"holdout_score={holdout_summary.score:.4f}"
    )

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
