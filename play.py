"""
Wahoo text-mode game loop. Pass-and-play, 4 players, console UI.

Run: python play.py
"""

import random
import sys

from game_state import (
    GameState, LOOP_SIZE, SEGMENT_LEN, HOME_SLOTS, MARBLES_PER_PLAYER,
    NUM_PLAYERS, base_exit, home_entry, format_location,
)
from rules import legal_moves, apply_move


PLAYER_NAMES = ["P1", "P2", "P3", "P4"]


def render_board(state: GameState) -> str:
    """Crude text board: per-player segment readout + center + summary."""
    lines = []
    lines.append("=" * 60)
    # Loop view: walk all 56 squares, show occupant.
    loop_view = []
    for i in range(LOOP_SIZE):
        occ = state.marble_at_track(i)
        if occ is None:
            cell = "."
        else:
            cell = f"{occ[0]}{occ[1]}"
        # Mark special squares
        marker = ""
        for p in range(NUM_PLAYERS):
            if i == base_exit(p):
                marker = f"<{p}exit>"
            elif i == home_entry(p):
                marker = f"<{p}home>"
        loop_view.append(f"{i:2d}{marker}:{cell}")
    # Display 8 squares per row
    for row_start in range(0, LOOP_SIZE, 8):
        lines.append("  ".join(loop_view[row_start:row_start + 8]))
    lines.append("")
    # Center
    co = state.center_occupant
    lines.append(f"CENTER: {f'P{co[0]}M{co[1]}' if co else 'empty'}")
    # Per-player summary
    for p in range(NUM_PLAYERS):
        marbles_str = ", ".join(
            f"M{m}={format_location(state.marbles[p][m])}"
            for m in range(MARBLES_PER_PLAYER)
        )
        lines.append(f"P{p}: {marbles_str}")
    lines.append("=" * 60)
    return "\n".join(lines)


def format_move(move: dict) -> str:
    """Short human-readable move."""
    if move["kind"] == "exit_base":
        desc = f"M{move['marble']} exit base"
    else:
        desc = f"M{move['marble']} {move['kind']} -> {format_location(move['dest'])}"
    if move["captures"]:
        cp, cm = move["captures"]
        desc += f" [captures P{cp}M{cm}]"
    return desc


def choose_move(moves: list) -> dict:
    """Prompt human to pick a move from the list."""
    print("\nLegal moves:")
    for i, mv in enumerate(moves):
        print(f"  [{i}] {format_move(mv)}")
    while True:
        choice = input("Pick a move number: ").strip()
        if choice.isdigit() and 0 <= int(choice) < len(moves):
            return moves[int(choice)]
        print(f"Invalid. Enter 0..{len(moves) - 1}.")


def choose_next_exit_base_move(state: GameState, player: int, moves: list) -> dict:
    """Pick the next marble (rotating by id) among exit_base moves."""
    exit_moves = [m for m in moves if m["kind"] == "exit_base"]
    start = state.next_base_exit_marble[player]
    for step in range(MARBLES_PER_PLAYER):
        target = (start + step) % MARBLES_PER_PLAYER
        for mv in exit_moves:
            if mv["marble"] == target:
                return mv
    # Fallback should be unreachable, but keeps behavior safe.
    return exit_moves[0]


def build_prompt_moves(state: GameState, player: int, roll: int, moves: list) -> list:
    """Reduce repeated base-exit choices in the prompt to one rotating option.

    When rolling 1 or 6 with multiple base exits available and at least one
    marble already on track, show only one "MN exit base" prompt entry.
    """
    if roll not in (1, 6):
        return moves

    exit_moves = [m for m in moves if m["kind"] == "exit_base"]
    if len(exit_moves) <= 1:
        return moves

    has_track_marble = any(
        state.marbles[player][m][0] == "TRACK"
        for m in range(MARBLES_PER_PLAYER)
    )
    if not has_track_marble:
        return moves

    preferred_exit = choose_next_exit_base_move(state, player, moves)
    prompt_moves = []
    inserted_exit = False
    for mv in moves:
        if mv["kind"] != "exit_base":
            prompt_moves.append(mv)
            continue
        if not inserted_exit:
            prompt_moves.append(preferred_exit)
            inserted_exit = True
    return prompt_moves


def maybe_auto_choose_move(state: GameState, player: int, roll: int, moves: list) -> dict | None:
    """Auto-pick a move based on convenience rules for local play.

    Rules:
    - If there is exactly one legal move, auto-pick it.
    - If roll is 1 or 6 and all legal moves are exit_base moves,
      auto-pick the next rotating exit marble.
    """
    if len(moves) == 1:
        return moves[0]

    if roll in (1, 6):
        non_exit_moves = [m for m in moves if m["kind"] != "exit_base"]
        if not non_exit_moves:
            return choose_next_exit_base_move(state, player, moves)

    return None


def update_exit_base_cursor(state: GameState, player: int, chosen: dict) -> None:
    """Advance per-player base-exit cursor after an exit_base move."""
    if chosen["kind"] == "exit_base":
        state.next_base_exit_marble[player] = (chosen["marble"] + 1) % MARBLES_PER_PLAYER


def take_turn(state: GameState, rng: random.Random) -> None:
    """One full turn for state.current_player, including 6-rerolls."""
    player = state.current_player
    while True:
        input(f"\n--- P{player}'s turn. Press Enter to roll. ")
        roll = rng.randint(1, 6)
        print(f"P{player} rolled a {roll}.")
        moves = legal_moves(state, player, roll)
        if not moves:
            print("No legal moves.")
        else:
            auto_move = maybe_auto_choose_move(state, player, roll, moves)
            if auto_move is not None:
                chosen = auto_move
                print(f"Auto-selected move: {format_move(chosen)}")
            else:
                prompt_moves = build_prompt_moves(state, player, roll, moves)
                chosen = choose_move(prompt_moves)

            update_exit_base_cursor(state, player, chosen)
            apply_move(state, chosen)
            print(render_board(state))
            if state.player_won(player):
                print(f"\n*** P{player} WINS! ***")
                sys.exit(0)
        if roll != 6:
            break
        print("Rolled a 6 — go again.")
    state.current_player = (player + 1) % NUM_PLAYERS


def main():
    seed_arg = sys.argv[1] if len(sys.argv) > 1 else None
    rng = random.Random(int(seed_arg) if seed_arg else None)
    state = GameState()
    print("Wahoo — text mode, 4 players, pass-and-play.")
    print(render_board(state))
    while True:
        take_turn(state, rng)


if __name__ == "__main__":
    main()
