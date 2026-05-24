"""
Wahoo text-mode game loop. Pass-and-play, 4 players, console UI.

Run: python play.py
"""

import random
import sys
import os

from game_state import (
    GameState, LOOP_SIZE, SEGMENT_LEN, HOME_SLOTS, MARBLES_PER_PLAYER,
    NUM_PLAYERS, base_exit, format_location,
)
from rules import legal_moves, apply_move


PLAYER_NAMES = ["Red", "Green", "Yellow", "Blue"]

PLAYER_COLOR = {
    0: "31",  # red
    1: "32",  # green
    2: "33",  # yellow
    3: "34",  # blue
}


def colorize(text: str, player: int) -> str:
    """Colorize text for a player when ANSI output is available."""
    if os.getenv("NO_COLOR") is not None or not sys.stdout.isatty():
        return text
    code = PLAYER_COLOR.get(player)
    if code is None:
        return text
    return f"\033[{code}m{text}\033[0m"


def player_label(player: int, colored: bool = True) -> str:
    """Player display name as color text (with optional ANSI color)."""
    name = PLAYER_NAMES[player]
    return colorize(name, player) if colored else name


def colorize_marble_cell(cell_text: str, tint_player: int | None = None) -> str:
    """Color marble tokens; optionally tint empty '..' cells for ownership."""
    raw = cell_text.rstrip()
    if len(raw) < 2:
        return cell_text
    token = raw[-2:]
    prefix = raw[:-2]
    trailing_spaces = " " * (len(cell_text) - len(raw))

    if token[0].isdigit() and token[1].isdigit():
        player = int(token[0])
        if 0 <= player < NUM_PLAYERS:
            return f"{prefix}{colorize(token, player)}{trailing_spaces}"

    if token == ".." and tint_player is not None and 0 <= tint_player < NUM_PLAYERS:
        return f"{prefix}{colorize(token, tint_player)}{trailing_spaces}"

    return cell_text


def render_board(state: GameState) -> str:
    """Physical plus-board renderer: 56-square loop + center + bases + home rows."""

    CELL_W = 4

    def draw_token(p: int, m: int | None) -> str:
        if m is None:
            return f"{p}."
        return f"{p}{m}"

    def cell(text: str) -> str:
        """Render a fixed-width cell to keep board columns aligned."""
        return text[:CELL_W].center(CELL_W)

    owner_tints = [[None for _ in range(21)] for _ in range(21)]

    def put(grid: list, r: int, c: int, value: str, tint_player: int | None = None) -> None:
        if 0 <= r < len(grid) and 0 <= c < len(grid[0]):
            grid[r][c] = cell(value)
            owner_tints[r][c] = tint_player

    # Absolute loop index -> board coordinate for a physical-style plus outline.
    # Each player segment has: inward spoke (0-5), armpit (6-10), outward spoke (11-13),
    # and then one step to the next player's base-exit (next segment offset 0).
    track_coords = []
    # Segment 0 (top arm -> right arm)
    track_coords.extend([(2, 10), (3, 10), (4, 10), (5, 10), (6, 10), (7, 10)])
    track_coords.extend([(7, 11), (7, 12), (7, 13), (7, 14), (7, 15)])
    track_coords.extend([(8, 15), (9, 15), (10, 15)])
    # Segment 1 (right arm -> bottom arm)
    track_coords.extend([(11, 15), (11, 14), (11, 13), (11, 12), (11, 11), (11, 10)])
    track_coords.extend([(12, 10), (13, 10), (14, 10), (15, 10), (16, 10)])
    track_coords.extend([(16, 9), (16, 8), (16, 7)])
    # Segment 2 (bottom arm -> left arm)
    track_coords.extend([(16, 6), (15, 6), (14, 6), (13, 6), (12, 6), (11, 6)])
    track_coords.extend([(11, 5), (11, 4), (11, 3), (11, 2), (11, 1)])
    track_coords.extend([(10, 1), (9, 1), (8, 1)])
    # Segment 3 (left arm -> top arm)
    track_coords.extend([(7, 1), (7, 2), (7, 3), (7, 4), (7, 5), (7, 6)])
    track_coords.extend([(6, 6), (5, 6), (4, 6), (3, 6), (2, 6)])
    track_coords.extend([(2, 7), (2, 8), (2, 9)])

    lines = []
    lines.append("=" * 112)
    lines.append("Wahoo plus-board: each marble circles all 4 segments before entering its own home row")

    grid = [[cell("") for _ in range(21)] for _ in range(21)]
    exit_owner_by_idx = {base_exit(p): p for p in range(NUM_PLAYERS)}

    for idx, (r, c) in enumerate(track_coords):
        occ = state.marble_at_track(idx)
        occ_token = ".." if occ is None else f"{occ[0]}{occ[1]}"
        marker = "  "
        tint_player = exit_owner_by_idx.get(idx)
        put(grid, r, c, f"{marker}{occ_token}", tint_player=tint_player)

    # Home rows: 4 slots each, parallel to the player's inward spoke, toward center.
    home_coords = {
        0: [(3, 8), (4, 8), (5, 8), (6, 8)],
        1: [(9, 14), (9, 13), (9, 12), (9, 11)],
        2: [(15, 8), (14, 8), (13, 8), (12, 8)],
        3: [(9, 2), (9, 3), (9, 4), (9, 5)],
    }
    for p in range(NUM_PLAYERS):
        for slot, (r, c) in enumerate(home_coords[p]):
            m = state.marble_at_home(p, slot)
            token = ".." if m is None else f"{p}{m}"
            put(grid, r, c, token, tint_player=p)

    # 2x2 base clusters outside the track, opposite each player's home row side.
    base_coords = {
        0: [(0, 11), (0, 12), (1, 11), (1, 12)],
        1: [(12, 18), (12, 19), (13, 18), (13, 19)],
        2: [(18, 4), (18, 5), (19, 4), (19, 5)],
        3: [(4, 0), (4, 1), (5, 0), (5, 1)],
    }
    for p in range(NUM_PLAYERS):
        base_marbles = [
            m for m in range(MARBLES_PER_PLAYER)
            if state.marbles[p][m][0] == "BASE"
        ]
        for i, (r, c) in enumerate(base_coords[p]):
            token = draw_token(p, base_marbles[i]) if i < len(base_marbles) else ".."
            put(grid, r, c, token, tint_player=p)

    co = state.center_occupant
    put(grid, 9, 8, f"C{draw_token(co[0], co[1])}" if co else "C..")

    for r, row in enumerate(grid):
        lines.append(" ".join(
            colorize_marble_cell(cell, owner_tints[r][c])
            for c, cell in enumerate(row)
        ))
        lines.append("")

    lines.append("=" * 112)
    return "\n".join(lines)


def format_move(move: dict) -> str:
    """Short human-readable move."""
    if move["kind"] == "exit_base":
        desc = f"M{move['marble']} exit base"
    else:
        desc = f"M{move['marble']} {move['kind']} -> {format_location(move['dest'])}"
    if move["captures"]:
        cp, cm = move["captures"]
        desc += f" [captures {player_label(cp)} M{cm}]"
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


def decide_starting_player(rng: random.Random) -> int:
    """Choose opening player by highest roll in a single round.

    If multiple players tie for highest, earliest clockwise player wins.
    """
    print("\n=== Starting Phase: Who Goes First? ===")
    top_player = None
    top_roll = -1

    for player in range(NUM_PLAYERS):
        input(f"{player_label(player)}: press Enter to roll for first turn. ")
        roll = rng.randint(1, 6)
        print(f"  {player_label(player)} rolled a {roll}.")
        if roll > top_roll:
            top_roll = roll
            top_player = player
            print(f"  Highest so far: {player_label(top_player)} with {top_roll}.")

    print(f"{player_label(top_player)} had the highest roll, with {top_roll}, they go first!")
    return top_player


def format_turn_summary(turn_result: dict) -> str:
    """Human-readable summary shown after the updated board."""
    lines = [f"{player_label(turn_result['player'])} turn results:"]
    for event in turn_result["events"]:
        line = f"  Rolled {event['roll']}: {event['outcome']}"
        if event["reroll"]:
            line += " -> rolled a 6, goes again"
        lines.append(line)
    return "\n".join(lines)


def take_turn(state: GameState, rng: random.Random) -> dict:
    """One full turn for state.current_player, including 6-rerolls."""
    player = state.current_player
    turn_result = {
        "player": player,
        "events": [],
        "won": False,
    }

    while True:
        input(f"\n--- {player_label(player)}'s turn. Press Enter to roll. ")
        roll = rng.randint(1, 6)
        moves = legal_moves(state, player, roll)
        if not moves:
            outcome = "no legal move"
        else:
            auto_move = maybe_auto_choose_move(state, player, roll, moves)
            if auto_move is not None:
                chosen = auto_move
                outcome = f"auto-selected {format_move(chosen)}"
            else:
                print(f"{player_label(player)} rolled a {roll}.")
                prompt_moves = build_prompt_moves(state, player, roll, moves)
                chosen = choose_move(prompt_moves)
                outcome = format_move(chosen)

            update_exit_base_cursor(state, player, chosen)
            apply_move(state, chosen)
            if state.player_won(player):
                turn_result["won"] = True

        turn_result["events"].append({
            "roll": roll,
            "outcome": outcome,
            "reroll": (roll == 6 and not turn_result["won"]),
        })

        event_result = {
            "player": player,
            "events": [turn_result["events"][-1]],
            "won": turn_result["won"],
        }
        print(render_board(state))
        print(format_turn_summary(event_result))

        if turn_result["won"]:
            break
        if roll != 6:
            break

    state.current_player = (player + 1) % NUM_PLAYERS
    return turn_result


def main():
    seed_arg = sys.argv[1] if len(sys.argv) > 1 else None
    rng = random.Random(int(seed_arg) if seed_arg else None)
    state = GameState()
    state.current_player = decide_starting_player(rng)
    print("Wahoo — text mode, 4 players, pass-and-play.")
    print(render_board(state))
    while True:
        turn_result = take_turn(state, rng)
        if turn_result["won"]:
            print(f"\n*** {player_label(turn_result['player'])} WINS! ***")
            sys.exit(0)


if __name__ == "__main__":
    main()
