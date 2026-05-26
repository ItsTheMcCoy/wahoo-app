"""Export human move-reasoning samples from replay JSON into JSONL.

Run examples:
  python -m wahoo.reasoning_export --input game2.json --output human_reasoning.jsonl
  python -m wahoo.reasoning_export --input-glob "game*.json" --output human_reasoning.jsonl
"""

from __future__ import annotations

import argparse
import glob
import json
import os
from typing import Iterable

try:
    from .game_state import GameState
    from .play import deserialize_game_state, serialize_game_state, update_exit_base_cursor
    from .rules import apply_move, legal_moves
except ImportError:
    from game_state import GameState
    from play import deserialize_game_state, serialize_game_state, update_exit_base_cursor
    from rules import apply_move, legal_moves


def _jsonify_move(move: dict) -> dict:
    """Convert move tuple fields into JSON-friendly lists."""
    captures = move.get("captures")
    return {
        "marble": move["marble"],
        "dest": list(move["dest"]),
        "kind": move["kind"],
        "captures": list(captures) if captures is not None else None,
    }


def _states_match_for_move(sim: GameState, target: GameState) -> bool:
    """Compare the parts of state affected by move application."""
    return (
        sim.marbles == target.marbles
        and sim.center_occupant == target.center_occupant
        and sim.next_base_exit_marble == target.next_base_exit_marble
    )


def _infer_chosen_move(pre_state: GameState, post_state: GameState, player: int, roll: int) -> dict | None:
    """Infer which legal move produced post_state from pre_state."""
    moves = legal_moves(pre_state, player, roll)
    for move in moves:
        sim = pre_state.clone()
        update_exit_base_cursor(sim, player, move)
        apply_move(sim, move)
        if _states_match_for_move(sim, post_state):
            return move
    return None


def extract_reasoning_examples_from_recording(recording: dict, source_name: str) -> list[dict]:
    """Extract non-optimal human rationale samples from one recording payload."""
    entries = recording.get("entries", [])
    samples: list[dict] = []

    for idx, entry in enumerate(entries):
        event = entry.get("event", {})
        reasoning = event.get("human_reasoning")
        if not reasoning:
            continue
        if event.get("type") != "turn":
            continue
        if idx == 0:
            continue

        player = event.get("player")
        roll = event.get("roll")
        if not isinstance(player, int) or not isinstance(roll, int):
            continue

        pre_payload = entries[idx - 1]["state"]
        post_payload = entry["state"]
        pre_state = deserialize_game_state(pre_payload)
        post_state = deserialize_game_state(post_payload)
        pre_state.current_player = player
        pre_state.pending_roll = None

        legal = legal_moves(pre_state, player, roll)
        chosen = _infer_chosen_move(pre_state, post_state, player, roll)

        sample = {
            "source_file": source_name,
            "entry_index": entry.get("index", idx),
            "player": player,
            "roll": roll,
            "reasoning": reasoning,
            # Human reasons are context signals, never best-play labels.
            "human_reasoning_non_optimal": True,
            "is_optimal_target": False,
            "state_before": serialize_game_state(pre_state),
            "state_after": serialize_game_state(post_state),
            "legal_moves": [_jsonify_move(m) for m in legal],
            "chosen_move": _jsonify_move(chosen) if chosen is not None else None,
            "chosen_move_inferred": chosen is not None,
            "recorded_outcome": event.get("outcome"),
        }
        samples.append(sample)

    return samples


def extract_reasoning_examples_from_path(path: str) -> list[dict]:
    """Load one recording file and extract reasoning samples."""
    with open(path, "r", encoding="utf-8") as handle:
        recording = json.load(handle)
    return extract_reasoning_examples_from_recording(recording, source_name=path)


def write_jsonl(path: str, records: Iterable[dict]) -> int:
    """Write records as JSONL and return number of rows written."""
    count = 0
    with open(path, "w", encoding="utf-8") as handle:
        for record in records:
            handle.write(json.dumps(record, ensure_ascii=False) + "\n")
            count += 1
    return count


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(
        description="Export human move-reasoning examples from Wahoo replay JSON files to JSONL."
    )
    parser.add_argument("--input", help="single replay file path, e.g. game2.json")
    parser.add_argument("--input-glob", help="glob pattern for replay files, e.g. 'game*.json'")
    parser.add_argument(
        "--output",
        default="human_reasoning_examples.jsonl",
        help="output JSONL path (default: human_reasoning_examples.jsonl)",
    )
    return parser


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


def main(argv: list[str] | None = None) -> int:
    parser = build_parser()
    args = parser.parse_args(argv)

    try:
        input_paths = _resolve_inputs(args)
    except ValueError as exc:
        print(f"Error: {exc}")
        return 2

    all_records: list[dict] = []
    for path in input_paths:
        try:
            all_records.extend(extract_reasoning_examples_from_path(path))
        except (OSError, json.JSONDecodeError, KeyError, TypeError, ValueError) as exc:
            print(f"Skipping {path}: {exc}")

    rows = write_jsonl(args.output, all_records)
    print(f"Wrote {rows} reasoning samples to {args.output}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
