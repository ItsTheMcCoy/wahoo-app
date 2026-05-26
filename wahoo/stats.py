"""Per-turn and per-game statistics for Wahoo recordings."""

from __future__ import annotations

from dataclasses import dataclass
import csv
import os

try:
    from .ai import _marble_progress, compute_features
    from .game_state import GameState, MARBLES_PER_PLAYER, NUM_PLAYERS
except ImportError:
    from ai import _marble_progress, compute_features
    from game_state import GameState, MARBLES_PER_PLAYER, NUM_PLAYERS


FEATURE_KEYS = ("DEP", "RUN", "SPR", "CAP", "SAFE", "CTR", "DEN", "FLOW", "HOME", "FIN")


@dataclass
class TurnRecord:
    game_id: str
    turn_index: int
    player: int
    player_type: str
    roll: int
    roll_index: int
    forced_move: bool
    decision_type: str
    num_legal_moves: int
    chosen_kind: str
    chosen_move: dict
    chosen_features: dict
    capture_made: bool
    capture_victim_progress: float
    center_entered: bool
    center_denied: bool
    home_move_made: bool
    home_slot_reached: int | None
    exit_base_made: bool
    opportunity_flags: dict
    pre_state_snapshot: dict
    candidate_moves: list[dict]
    chosen_move_index: int


@dataclass
class PlayerGameStats:
    game_id: str
    player: int
    player_type: str
    won: bool
    final_marbles_in_home: int
    final_marbles_on_track: int
    final_marbles_in_base: int
    total_turns: int
    total_rolls: int
    ones_rolled: int
    sixes_rolled: int
    no_move_turns: int
    forced_move_turns: int
    discretionary_turns: int
    captures_made: int
    captures_suffered: int
    center_entries: int
    center_exits: int
    center_bumps_suffered: int
    base_exits_on_1: int
    base_exits_on_6: int
    base_exit_on_6_opportunities: int
    base_exit_on_6_chosen: int
    home_moves_made: int
    first_marble_home_turn: int | None
    capture_conversion_rate: float | None
    center_entry_rate: float | None
    base_exit_on_6_rate: float | None
    home_move_rate: float | None
    style_vector: dict


@dataclass
class GameSummary:
    game_id: str
    player_types: list[str]
    winner: int | None
    winner_type: str
    total_turns: int
    total_rolls: int
    player_stats: list[PlayerGameStats]


def _move_signature(move: dict) -> tuple:
    captures = move.get("captures")
    captures_sig = tuple(captures) if captures is not None else None
    return (move["marble"], tuple(move["dest"]), move["kind"], captures_sig)


def _jsonify_move(move: dict) -> dict:
    captures = move.get("captures")
    return {
        "marble": move["marble"],
        "dest": list(move["dest"]),
        "kind": move["kind"],
        "captures": list(captures) if captures is not None else None,
    }


def _decision_type(all_moves: list[dict]) -> str:
    if len(all_moves) <= 1:
        return "forced"

    has_capture = any(m.get("captures") is not None for m in all_moves)
    has_exit = any(m["kind"] == "exit_base" for m in all_moves)
    has_center = any(m["kind"] == "enter_center" for m in all_moves)
    has_denial = any(m["kind"] == "enter_center" and m.get("captures") is not None for m in all_moves)
    has_home = any(m["dest"][0] == "HOME" for m in all_moves)
    only_exit = all(m["kind"] == "exit_base" for m in all_moves)

    if only_exit:
        return "exit_only"
    if has_denial:
        return "center_denial"
    if has_home and (has_capture or has_denial):
        return "finish_vs_fight"
    if has_center:
        return "center_opportunity"
    if has_capture and has_exit:
        return "capture_vs_deploy"
    if has_capture:
        return "capture_vs_advance"
    if has_home:
        return "home_vs_advance"
    return "mixed"


def _safe_rate(numerator: int, denominator: int) -> float | None:
    if denominator == 0:
        return None
    return numerator / denominator


def compute_turn_record(
    game_id: str,
    turn_index: int,
    state_before: GameState,
    player: int,
    player_type: str,
    roll: int,
    roll_index: int,
    all_moves: list,
    chosen_move: dict,
) -> TurnRecord:
    """Compute one turn-decision record from pre-move state and legal moves."""
    candidate_moves: list[dict] = []
    chosen_sig = _move_signature(chosen_move)
    chosen_move_index = 0

    for idx, move in enumerate(all_moves):
        features = compute_features(state_before, player, roll, move, all_moves)
        candidate_moves.append({
            "kind": move["kind"],
            "marble": move["marble"],
            "dest": list(move["dest"]),
            "captures": list(move["captures"]) if move.get("captures") is not None else None,
            "features": features,
        })
        if _move_signature(move) == chosen_sig:
            chosen_move_index = idx

    chosen_features = candidate_moves[chosen_move_index]["features"] if candidate_moves else {
        key: 0.0 for key in FEATURE_KEYS
    }

    capture_victim_progress = 0.0
    if chosen_move.get("captures") is not None:
        victim_player, victim_marble = chosen_move["captures"]
        capture_victim_progress = _marble_progress(state_before, victim_player, victim_marble)

    opportunity_flags = {
        "has_capture": any(m.get("captures") is not None for m in all_moves),
        "has_center": any(m["kind"] == "enter_center" for m in all_moves),
        "has_home": any(m["dest"][0] == "HOME" for m in all_moves),
        "has_exit_base": any(m["kind"] == "exit_base" for m in all_moves),
    }

    marbles_in_home = [
        sum(1 for marble in state_before.marbles[p] if marble[0] == "HOME")
        for p in range(NUM_PLAYERS)
    ]
    marbles_in_base = [
        sum(1 for marble in state_before.marbles[p] if marble[0] == "BASE")
        for p in range(NUM_PLAYERS)
    ]

    return TurnRecord(
        game_id=game_id,
        turn_index=turn_index,
        player=player,
        player_type=player_type,
        roll=roll,
        roll_index=roll_index,
        forced_move=(len(all_moves) == 1),
        decision_type=_decision_type(all_moves),
        num_legal_moves=len(all_moves),
        chosen_kind=chosen_move["kind"],
        chosen_move=_jsonify_move(chosen_move),
        chosen_features=chosen_features,
        capture_made=(chosen_move.get("captures") is not None),
        capture_victim_progress=capture_victim_progress,
        center_entered=(chosen_move["kind"] == "enter_center"),
        center_denied=(chosen_move["kind"] == "enter_center" and chosen_move.get("captures") is not None),
        home_move_made=(chosen_move["dest"][0] == "HOME"),
        home_slot_reached=(chosen_move["dest"][1] if chosen_move["dest"][0] == "HOME" else None),
        exit_base_made=(chosen_move["kind"] == "exit_base"),
        opportunity_flags=opportunity_flags,
        pre_state_snapshot={
            "own_marble_locations": [list(loc) for loc in state_before.marbles[player]],
            "center_occupant": list(state_before.center_occupant) if state_before.center_occupant else None,
            "marbles_in_home": marbles_in_home,
            "marbles_in_base": marbles_in_base,
        },
        candidate_moves=candidate_moves,
        chosen_move_index=chosen_move_index,
    )


def turn_record_to_event(record: TurnRecord) -> dict:
    """Convert TurnRecord into recording JSON event payload."""
    return {
        "type": "turn_detail",
        "game_id": record.game_id,
        "turn_index": record.turn_index,
        "player": record.player,
        "player_type": record.player_type,
        "roll": record.roll,
        "roll_index": record.roll_index,
        "forced_move": record.forced_move,
        "decision_type": record.decision_type,
        "num_legal_moves": record.num_legal_moves,
        "chosen_kind": record.chosen_kind,
        "chosen_move": record.chosen_move,
        "chosen_features": record.chosen_features,
        "capture_made": record.capture_made,
        "capture_victim_progress": record.capture_victim_progress,
        "center_entered": record.center_entered,
        "center_denied": record.center_denied,
        "home_move_made": record.home_move_made,
        "home_slot_reached": record.home_slot_reached,
        "exit_base_made": record.exit_base_made,
        "opportunity_flags": record.opportunity_flags,
        "pre_state_snapshot": record.pre_state_snapshot,
        "candidate_moves": record.candidate_moves,
        "chosen_move_index": record.chosen_move_index,
    }


def _default_player_types(recording: dict) -> list[str]:
    players = recording.get("players")
    if isinstance(players, list) and len(players) == NUM_PLAYERS:
        return [str(p) for p in players]
    return ["unknown"] * NUM_PLAYERS


def compile_game_stats(recording: dict) -> GameSummary:
    """Compile per-player and game-level stats from a v2 recording payload."""
    if recording.get("version", 1) < 2:
        raise ValueError("compile_game_stats requires recording version 2 with turn_detail events")

    entries = recording.get("entries", [])
    turn_detail_events = [e.get("event", {}) for e in entries if e.get("event", {}).get("type") == "turn_detail"]
    if not turn_detail_events:
        raise ValueError("No turn_detail events found in recording")

    player_types = _default_player_types(recording)
    game_id = str(recording.get("game_id") or "game")

    counters = {
        p: {
            "total_turns": 0,
            "total_rolls": 0,
            "ones_rolled": 0,
            "sixes_rolled": 0,
            "no_move_turns": 0,
            "forced_move_turns": 0,
            "discretionary_turns": 0,
            "captures_made": 0,
            "captures_suffered": 0,
            "center_entries": 0,
            "center_exits": 0,
            "center_bumps_suffered": 0,
            "base_exits_on_1": 0,
            "base_exits_on_6": 0,
            "base_exit_on_6_opportunities": 0,
            "base_exit_on_6_chosen": 0,
            "home_moves_made": 0,
            "first_marble_home_turn": None,
            "capture_opps": 0,
            "center_opps": 0,
            "home_opps": 0,
            "style_sum": {key: 0.0 for key in FEATURE_KEYS},
            "style_count": 0,
        }
        for p in range(NUM_PLAYERS)
    }

    winner = None
    streak_player = None

    for entry in entries:
        event = entry.get("event", {})
        event_type = event.get("type")
        if event_type == "turn":
            player = event.get("player")
            roll = event.get("roll")
            if not isinstance(player, int) or not (0 <= player < NUM_PLAYERS):
                continue

            if streak_player is None or player != streak_player:
                counters[player]["total_turns"] += 1

            if isinstance(roll, int):
                counters[player]["total_rolls"] += 1
                if roll == 1:
                    counters[player]["ones_rolled"] += 1
                elif roll == 6:
                    counters[player]["sixes_rolled"] += 1

            if isinstance(event.get("outcome"), str) and event["outcome"].lower().startswith("no legal move"):
                counters[player]["no_move_turns"] += 1

            if event.get("won"):
                winner = player

            streak_player = player if event.get("reroll") else None

        elif event_type == "turn_detail":
            player = event.get("player")
            if not isinstance(player, int) or not (0 <= player < NUM_PLAYERS):
                continue

            forced = bool(event.get("forced_move"))
            if forced:
                counters[player]["forced_move_turns"] += 1
            else:
                counters[player]["discretionary_turns"] += 1

            opp = event.get("opportunity_flags", {})
            if opp.get("has_capture"):
                counters[player]["capture_opps"] += 1
            if opp.get("has_center"):
                counters[player]["center_opps"] += 1
            if opp.get("has_home"):
                counters[player]["home_opps"] += 1

            if event.get("capture_made"):
                counters[player]["captures_made"] += 1
                chosen_move = event.get("chosen_move", {})
                captures = chosen_move.get("captures")
                if isinstance(captures, list) and len(captures) == 2:
                    victim = captures[0]
                    if isinstance(victim, int) and 0 <= victim < NUM_PLAYERS:
                        counters[victim]["captures_suffered"] += 1

            if event.get("center_entered"):
                counters[player]["center_entries"] += 1
            if event.get("chosen_kind") == "exit_center":
                counters[player]["center_exits"] += 1
            if event.get("center_denied"):
                chosen_move = event.get("chosen_move", {})
                captures = chosen_move.get("captures")
                if isinstance(captures, list) and len(captures) == 2:
                    victim = captures[0]
                    if isinstance(victim, int) and 0 <= victim < NUM_PLAYERS:
                        counters[victim]["center_bumps_suffered"] += 1

            roll = event.get("roll")
            if event.get("exit_base_made"):
                if roll == 1:
                    counters[player]["base_exits_on_1"] += 1
                if roll == 6:
                    counters[player]["base_exits_on_6"] += 1
                    counters[player]["base_exit_on_6_chosen"] += 1

            if roll == 6 and opp.get("has_exit_base"):
                counters[player]["base_exit_on_6_opportunities"] += 1

            if event.get("home_move_made"):
                counters[player]["home_moves_made"] += 1
                if counters[player]["first_marble_home_turn"] is None:
                    turn_idx = event.get("turn_index")
                    if isinstance(turn_idx, int):
                        counters[player]["first_marble_home_turn"] = turn_idx

            if not forced:
                chosen_features = event.get("chosen_features", {})
                for key in FEATURE_KEYS:
                    counters[player]["style_sum"][key] += float(chosen_features.get(key, 0.0))
                counters[player]["style_count"] += 1

    final_state_payload = entries[-1].get("state") if entries else None
    final_state = None
    if isinstance(final_state_payload, dict):
        try:
            from .play import deserialize_game_state
        except ImportError:
            from play import deserialize_game_state
        final_state = deserialize_game_state(final_state_payload)

    player_stats: list[PlayerGameStats] = []
    for player in range(NUM_PLAYERS):
        c = counters[player]
        style_count = c["style_count"]
        if style_count:
            style_vector = {key: c["style_sum"][key] / style_count for key in FEATURE_KEYS}
        else:
            style_vector = {key: 0.0 for key in FEATURE_KEYS}

        if final_state is None:
            final_home = 0
            final_track = 0
            final_base = MARBLES_PER_PLAYER
        else:
            final_home = sum(1 for loc in final_state.marbles[player] if loc[0] == "HOME")
            final_track = sum(1 for loc in final_state.marbles[player] if loc[0] == "TRACK")
            final_base = sum(1 for loc in final_state.marbles[player] if loc[0] == "BASE")

        player_stats.append(
            PlayerGameStats(
                game_id=game_id,
                player=player,
                player_type=player_types[player],
                won=(winner == player),
                final_marbles_in_home=final_home,
                final_marbles_on_track=final_track,
                final_marbles_in_base=final_base,
                total_turns=c["total_turns"],
                total_rolls=c["total_rolls"],
                ones_rolled=c["ones_rolled"],
                sixes_rolled=c["sixes_rolled"],
                no_move_turns=c["no_move_turns"],
                forced_move_turns=c["forced_move_turns"],
                discretionary_turns=c["discretionary_turns"],
                captures_made=c["captures_made"],
                captures_suffered=c["captures_suffered"],
                center_entries=c["center_entries"],
                center_exits=c["center_exits"],
                center_bumps_suffered=c["center_bumps_suffered"],
                base_exits_on_1=c["base_exits_on_1"],
                base_exits_on_6=c["base_exits_on_6"],
                base_exit_on_6_opportunities=c["base_exit_on_6_opportunities"],
                base_exit_on_6_chosen=c["base_exit_on_6_chosen"],
                home_moves_made=c["home_moves_made"],
                first_marble_home_turn=c["first_marble_home_turn"],
                capture_conversion_rate=_safe_rate(c["captures_made"], c["capture_opps"]),
                center_entry_rate=_safe_rate(c["center_entries"], c["center_opps"]),
                base_exit_on_6_rate=_safe_rate(c["base_exit_on_6_chosen"], c["base_exit_on_6_opportunities"]),
                home_move_rate=_safe_rate(c["home_moves_made"], c["home_opps"]),
                style_vector=style_vector,
            )
        )

    return GameSummary(
        game_id=game_id,
        player_types=player_types,
        winner=winner,
        winner_type=(player_types[winner] if winner is not None else "none"),
        total_turns=sum(s.total_turns for s in player_stats),
        total_rolls=sum(s.total_rolls for s in player_stats),
        player_stats=player_stats,
    )


def print_game_report(summary: GameSummary) -> None:
    """Print a concise post-game stats report."""
    print("\n=== Game Stats ===")
    print(f"Game ID: {summary.game_id}")
    if summary.winner is None:
        print("Winner: none")
    else:
        print(f"Winner: P{summary.winner} ({summary.winner_type})")
    print(f"Total turns: {summary.total_turns}")
    print(f"Total rolls: {summary.total_rolls}")

    for row in summary.player_stats:
        print(
            f"P{row.player} {row.player_type}: turns={row.total_turns}, rolls={row.total_rolls}, "
            f"captures={row.captures_made}/{row.captures_suffered}, "
            f"discretionary={row.discretionary_turns}, won={row.won}"
        )


def append_stats_csv(summary: GameSummary, path: str) -> None:
    """Append one row per player for the game to CSV."""
    headers = [
        "game_id", "player", "player_type", "won", "final_home", "total_turns", "total_rolls",
        "ones_rolled", "sixes_rolled", "captures_made", "captures_suffered", "net_captures",
        "center_entries", "center_exits", "center_bumps_suffered", "base_exit_on_6_rate",
        "capture_conversion_rate", "center_entry_rate", "home_move_rate", "discretionary_turns",
        "forced_turns", "no_move_turns", "first_marble_home_turn",
        "style_DEP", "style_RUN", "style_SPR", "style_CAP", "style_SAFE",
        "style_CTR", "style_DEN", "style_FLOW", "style_HOME", "style_FIN",
    ]

    exists = os.path.exists(path)
    with open(path, "a", encoding="utf-8", newline="") as handle:
        writer = csv.DictWriter(handle, fieldnames=headers)
        if not exists:
            writer.writeheader()

        for row in summary.player_stats:
            writer.writerow({
                "game_id": row.game_id,
                "player": row.player,
                "player_type": row.player_type,
                "won": row.won,
                "final_home": row.final_marbles_in_home,
                "total_turns": row.total_turns,
                "total_rolls": row.total_rolls,
                "ones_rolled": row.ones_rolled,
                "sixes_rolled": row.sixes_rolled,
                "captures_made": row.captures_made,
                "captures_suffered": row.captures_suffered,
                "net_captures": row.captures_made - row.captures_suffered,
                "center_entries": row.center_entries,
                "center_exits": row.center_exits,
                "center_bumps_suffered": row.center_bumps_suffered,
                "base_exit_on_6_rate": row.base_exit_on_6_rate,
                "capture_conversion_rate": row.capture_conversion_rate,
                "center_entry_rate": row.center_entry_rate,
                "home_move_rate": row.home_move_rate,
                "discretionary_turns": row.discretionary_turns,
                "forced_turns": row.forced_move_turns,
                "no_move_turns": row.no_move_turns,
                "first_marble_home_turn": row.first_marble_home_turn,
                "style_DEP": row.style_vector["DEP"],
                "style_RUN": row.style_vector["RUN"],
                "style_SPR": row.style_vector["SPR"],
                "style_CAP": row.style_vector["CAP"],
                "style_SAFE": row.style_vector["SAFE"],
                "style_CTR": row.style_vector["CTR"],
                "style_DEN": row.style_vector["DEN"],
                "style_FLOW": row.style_vector["FLOW"],
                "style_HOME": row.style_vector["HOME"],
                "style_FIN": row.style_vector["FIN"],
            })
