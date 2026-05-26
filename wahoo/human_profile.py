"""Train a human-like greedy profile from replay reasoning data.

Run examples:
  python -m wahoo.human_profile --input wahoo/game1.json --output wahoo/human_like_profile.json
  python -m wahoo.human_profile --input-glob "wahoo/game*.json" --output wahoo/human_like_profile.json
"""

from __future__ import annotations

import argparse
import glob
import json
import os
from collections import Counter
from datetime import datetime, timezone

FEATURE_KEYS = ("DEP", "RUN", "SPR", "CAP", "SAFE", "CTR", "DEN", "FLOW", "HOME", "FIN")
BASELINE_WEIGHTS = {
    "DEP": 0.6,
    "RUN": 0.5,
    "SPR": 0.6,
    "CAP": 0.6,
    "SAFE": 0.6,
    "CTR": 0.5,
    "DEN": 0.6,
    "FLOW": 0.7,
    "HOME": 0.7,
    "FIN": 0.7,
}


def _resolve_inputs(args: argparse.Namespace) -> list[str]:
    if bool(args.input) == bool(args.input_glob):
        raise ValueError("Provide exactly one of --input or --input-glob.")

    if args.input:
        if not os.path.exists(args.input):
            raise ValueError(f"Input file not found: {args.input}")
        return [args.input]

    matches = sorted(glob.glob(args.input_glob))
    if not matches:
        raise ValueError(f"No files matched pattern: {args.input_glob}")
    return matches


def _iter_reasoned_discretionary_details(recording: dict):
    entries = recording.get("entries", [])
    turn_events = [e.get("event", {}) for e in entries if e.get("event", {}).get("type") == "turn"]
    detail_by_turn_index = {
        e.get("event", {}).get("turn_index"): e.get("event", {})
        for e in entries
        if e.get("event", {}).get("type") == "turn_detail"
    }

    for turn_index, turn_event in enumerate(turn_events, start=1):
        if not turn_event.get("human_reasoning"):
            continue
        detail = detail_by_turn_index.get(turn_index)
        if not detail:
            continue
        candidates = detail.get("candidate_moves", [])
        chosen_idx = detail.get("chosen_move_index", 0)
        if len(candidates) < 2:
            continue
        if not isinstance(chosen_idx, int) or not (0 <= chosen_idx < len(candidates)):
            continue
        yield detail


def fit_human_like_profile(recordings: list[dict], *, scale: float = 2.0, floor: float = 0.0) -> dict:
    """Fit a simple preference profile from reasoned discretionary turns.

    For each feature key, compute:
      avg_delta = mean(chosen_feature - mean(other_features))

    Then produce profile weights:
      weight = max(floor, baseline + scale * avg_delta)
    """
    if scale < 0:
        raise ValueError("scale must be non-negative")

    deltas = {key: 0.0 for key in FEATURE_KEYS}
    samples = 0
    decision_type_counts: Counter[str] = Counter()

    for recording in recordings:
        for detail in _iter_reasoned_discretionary_details(recording):
            candidates = detail["candidate_moves"]
            chosen_idx = detail["chosen_move_index"]
            chosen_features = candidates[chosen_idx].get("features", {})
            others = [
                candidates[idx].get("features", {})
                for idx in range(len(candidates))
                if idx != chosen_idx
            ]
            if not others:
                continue

            for key in FEATURE_KEYS:
                chosen_val = float(chosen_features.get(key, 0.0))
                other_mean = sum(float(other.get(key, 0.0)) for other in others) / len(others)
                deltas[key] += chosen_val - other_mean

            samples += 1
            decision_type_counts[detail.get("decision_type", "unknown")] += 1

    if samples == 0:
        raise ValueError("No reasoned discretionary samples found. Need turns with reasoning and 2+ legal moves.")

    avg_delta = {key: deltas[key] / samples for key in FEATURE_KEYS}
    weights = {
        key: max(floor, BASELINE_WEIGHTS[key] + scale * avg_delta[key])
        for key in FEATURE_KEYS
    }

    return {
        "weights": weights,
        "avg_delta": avg_delta,
        "sample_count": samples,
        "decision_type_counts": dict(decision_type_counts),
    }


def _load_recordings(paths: list[str]) -> tuple[list[dict], list[str]]:
    loaded = []
    used_paths = []
    for path in paths:
        try:
            with open(path, "r", encoding="utf-8") as handle:
                loaded.append(json.load(handle))
            used_paths.append(path)
        except (OSError, json.JSONDecodeError):
            continue
    if not loaded:
        raise ValueError("None of the input files could be read as valid JSON replay files.")
    return loaded, used_paths


def _build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(
        description="Fit a human-like greedy profile from replay files containing human reasoning."
    )
    parser.add_argument("--input", help="single replay JSON path")
    parser.add_argument("--input-glob", help="glob for replay JSON files")
    parser.add_argument(
        "--output",
        default="wahoo/human_like_profile.json",
        help="output JSON path (default: wahoo/human_like_profile.json)",
    )
    parser.add_argument(
        "--scale",
        type=float,
        default=2.0,
        help="multiplier for average feature preference deltas (default: 2.0)",
    )
    parser.add_argument(
        "--floor",
        type=float,
        default=0.0,
        help="minimum allowed weight value (default: 0.0)",
    )
    return parser


def main(argv: list[str] | None = None) -> int:
    parser = _build_parser()
    args = parser.parse_args(argv)

    try:
        input_paths = _resolve_inputs(args)
        recordings, used_paths = _load_recordings(input_paths)
        fit = fit_human_like_profile(recordings, scale=args.scale, floor=args.floor)
    except ValueError as exc:
        print(f"Error: {exc}")
        return 2

    payload = {
        "profile_name": "human_like",
        "source_files": used_paths,
        "generated_at": datetime.now(timezone.utc).isoformat(),
        "fit_options": {"scale": args.scale, "floor": args.floor},
        "sample_count": fit["sample_count"],
        "decision_type_counts": fit["decision_type_counts"],
        "avg_delta": fit["avg_delta"],
        "weights": fit["weights"],
    }

    os.makedirs(os.path.dirname(args.output) or ".", exist_ok=True)
    with open(args.output, "w", encoding="utf-8") as handle:
        json.dump(payload, handle, indent=2)

    print(f"Wrote human-like profile to {args.output}")
    print(f"Samples used: {fit['sample_count']}")
    print("Weights:")
    for key in FEATURE_KEYS:
        print(f"  {key}: {fit['weights'][key]:.4f}")

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
