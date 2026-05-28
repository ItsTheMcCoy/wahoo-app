"""
Wahoo text-mode game loop. Pass-and-play, 4 players, console UI.

Run: python -m wahoo.play
"""

import random
import sys
import os
import json
import re
import time

try:
    from .game_state import (
        GameState, LOOP_SIZE, SEGMENT_LEN, HOME_SLOTS, MARBLES_PER_PLAYER,
        NUM_PLAYERS, base_exit,
    )
    from .rules import legal_moves, apply_move
    from .ai import PROFILES
    from .stats import (
        append_stats_csv,
        compile_game_stats,
        compute_turn_record,
        print_game_report,
        turn_record_to_event,
    )
except ImportError:
    from game_state import (
        GameState, LOOP_SIZE, SEGMENT_LEN, HOME_SLOTS, MARBLES_PER_PLAYER,
        NUM_PLAYERS, base_exit,
    )
    from rules import legal_moves, apply_move
    from ai import PROFILES
    from stats import (
        append_stats_csv,
        compile_game_stats,
        compute_turn_record,
        print_game_report,
        turn_record_to_event,
    )


PLAYER_NAMES = ["Red", "Green", "Yellow", "Blue"]

PLAYER_COLOR = {
    0: "31",  # red
    1: "32",  # green
    2: "33",  # yellow
    3: "34",  # blue
}

INTRO_ART = r"""
__        __    _                    
\ \      / /_ _| |__   ___   ___     
 \ \ /\ / / _` | '_ \ / _ \ / _ \ 
  \ V  V / (_| | | | | (_) | (_) |   
   \_/\_/ \__,_|_| |_|\___/ \___/ 
"""

DEFAULT_RECORDING_PATH = "wahoo_history.json"
RECORDING_BASENAME = "game"
DEFAULT_STATS_CSV_PATH = "wahoo_stats.csv"
AUTO_TOGGLE_COMMANDS = {"/auto", "/a", "auto"}
HUMAN_PLAYER_TYPE = "human"
DEFAULT_AI_PROFILE = "balanced"
DEFAULT_AI_DELAY = 1.5  # seconds to pause after each AI move when humans are in the game

DIFFICULTY_LEVELS = [
    ("beginner", ["swarm", "tortoise"], "tortoise"),
    ("easy", ["engineer", "balanced"], "balanced"),
    ("normal", ["assassin", "gatekeeper"], "gatekeeper"),
    ("hard", ["human_like", "expectimax"], "expectimax"),
    ("expert", ["gambler", "sprinter"], "sprinter"),
]

DIFFICULTY_TO_DEFAULT_PROFILE = {
    name: default_profile
    for name, _profiles, default_profile in DIFFICULTY_LEVELS
}

PROFILE_DESCRIPTIONS = {
    "random":     "Makes completely random moves — useful as a baseline",
    "sprinter":   "Rushes one marble home as fast as possible; loves the center shortcut",
    "swarm":      "Deploys all marbles early and spreads across the board",
    "assassin":   "Aggressively hunts and captures high-progress opponents",
    "gambler":    "Takes big risks on center shortcuts for massive leaps forward",
    "tortoise":   "Plays it safe, avoids capture danger, and finishes methodically",
    "gatekeeper": "Defends the center hole and punishes opponents who try to use it",
    "engineer":   "Focuses on precise home-lane navigation and efficient finishing",
    "balanced":   "Well-rounded pragmatic strategy balancing all goals",
    "human_like": "Attempts to mimic recorded human play tendencies",
    "expectimax": "One-ply lookahead that considers likely opponent responses",
}

# Profiles ordered easiest → hardest based on Stage 2.2 benchmark win rates
# (vs balanced,balanced,balanced over 2000 games per profile, 5 seeds).
PROFILE_DISPLAY_ORDER = [
    "random",      # random baseline
    "swarm",       # 7.9%
    "tortoise",    # 20.2%
    "engineer",    # 22.1%
    "balanced",    # 24.2%
    "assassin",    # 35.2%
    "gatekeeper",  # 42.6%
    "human_like",  # 62.0%
    "expectimax",  # 83.3%
    "gambler",     # 88.8%
    "sprinter",    # 90.8%
]


def colorize(text: str, player: int) -> str:
    """Colorize text for a player when ANSI output is available."""
    if os.getenv("NO_COLOR") is not None or not sys.stdout.isatty():
        return text
    code = PLAYER_COLOR.get(player)
    if code is None:
        return text
    return f"\033[{code}m{text}\033[0m"


def read_user_input(prompt: str, settings: dict, allow_auto_continue: bool = False) -> str:
    """Read input and process global prompt commands.

    Supported commands:
    - /auto (or /a): toggle auto-roll on/off from any prompt.
    """
    while True:
        response = input(prompt)
        normalized = response.strip().lower()
        if normalized in AUTO_TOGGLE_COMMANDS:
            settings["auto_roll"] = not settings["auto_roll"]
            mode = "ON" if settings["auto_roll"] else "OFF"
            print(f"Auto-roll is now {mode}.")
            if allow_auto_continue and settings["auto_roll"]:
                return ""
            continue
        return response


def serialize_game_state(state: GameState) -> dict:
    """Convert game state to a JSON-friendly structure."""
    return {
        "marbles": [[list(loc) for loc in row] for row in state.marbles],
        "current_player": state.current_player,
        "pending_roll": state.pending_roll,
        "center_occupant": list(state.center_occupant) if state.center_occupant else None,
        "next_base_exit_marble": list(state.next_base_exit_marble),
    }


def deserialize_game_state(payload: dict) -> GameState:
    """Rebuild a GameState from serialized JSON-friendly data."""
    state = GameState()
    state.marbles = [[tuple(loc) for loc in row] for row in payload["marbles"]]
    state.current_player = payload["current_player"]
    state.pending_roll = payload["pending_roll"]
    state.center_occupant = tuple(payload["center_occupant"]) if payload["center_occupant"] else None
    state.next_base_exit_marble = list(payload["next_base_exit_marble"])
    return state


def make_recording_path(directory: str = ".") -> str:
    """Create a simple sequential recording filename for a new game."""
    pattern = re.compile(rf"^{RECORDING_BASENAME}(\d+)\.json$")
    max_index = 0
    for name in os.listdir(directory):
        match = pattern.match(name)
        if match:
            max_index = max(max_index, int(match.group(1)))
    return os.path.join(directory, f"{RECORDING_BASENAME}{max_index + 1}.json")


def write_recording(recording: dict, path: str = DEFAULT_RECORDING_PATH) -> None:
    """Persist recording history to disk."""
    with open(path, "w", encoding="utf-8") as handle:
        json.dump(recording, handle, indent=2)


def append_recording_entry(recording: dict, state: GameState, event: dict) -> None:
    """Append one snapshot entry after a resolved roll/move."""
    entry = {
        "index": len(recording["entries"]),
        "event": event,
        "state": serialize_game_state(state),
    }
    recording["entries"].append(entry)


def _state_for_continuation(entry: dict, state: GameState) -> GameState:
    """Return the state that should be used when resuming from one entry.

    Older recordings captured board snapshots before current_player advanced to
    the next seat at turn end. For non-reroll, non-winning turn events, resuming
    should start with the next player.
    """
    event = entry.get("event", {})
    if event.get("type") != "turn":
        return state
    if event.get("won") or event.get("reroll"):
        return state

    player = event.get("player")
    if isinstance(player, int) and 0 <= player < NUM_PLAYERS:
        state.current_player = (player + 1) % NUM_PLAYERS
    return state


def _decision_state_for_entry(recording: dict, entry_index: int) -> GameState:
    """Rebuild the pre-move decision state for a turn entry.

    The returned state is the board before the recorded turn event, with
    pending_roll set so the first action after continue uses the recorded roll.
    """
    entries = recording.get("entries", [])
    if entry_index <= 0 or entry_index >= len(entries):
        raise ValueError("Decision view requires a turn entry with a previous state.")

    entry = entries[entry_index]
    event = entry.get("event", {})
    if event.get("type") != "turn":
        raise ValueError("Decision view is only available for turn entries.")

    previous_state = deserialize_game_state(entries[entry_index - 1]["state"])
    player = event.get("player")
    roll = event.get("roll")
    if not isinstance(player, int) or not (0 <= player < NUM_PLAYERS):
        raise ValueError("Turn entry has an invalid player.")
    if not isinstance(roll, int) or not (1 <= roll <= 6):
        raise ValueError("Turn entry has an invalid roll.")

    previous_state.current_player = player
    previous_state.pending_roll = roll
    return previous_state


def load_recording_entry(path: str, replay_index: int | None = None) -> tuple[dict, dict, GameState]:
    """Load recording JSON and return one entry/state (last by default)."""
    with open(path, "r", encoding="utf-8") as handle:
        recording = json.load(handle)

    entries = recording.get("entries", [])
    if not entries:
        raise ValueError(f"Recording '{path}' has no entries.")

    if replay_index is None:
        entry = entries[-1]
    else:
        if replay_index < 0:
            raise ValueError("Replay index must be a non-negative integer.")
        entry = next((e for e in entries if e.get("index") == replay_index), None)
        if entry is None:
            min_idx = min(e.get("index", 0) for e in entries)
            max_idx = max(e.get("index", 0) for e in entries)
            raise ValueError(
                f"Replay index {replay_index} not found in '{path}'. Available range: {min_idx}..{max_idx}."
            )

    return recording, entry, _state_for_continuation(entry, deserialize_game_state(entry["state"]))


def run_replay(
    path: str,
    settings: dict,
    replay_index: int | None = None,
) -> tuple[dict | None, GameState | None]:
    """Load a saved recording, replay board states, optionally continue play."""
    try:
        recording, selected_entry, selected_state = load_recording_entry(path, replay_index)
    except (OSError, json.JSONDecodeError, ValueError) as exc:
        print(f"Unable to load replay: {exc}")
        return None, None

    if replay_index is not None:
        entries = recording["entries"]
        pos = next((i for i, e in enumerate(entries) if e.get("index") == selected_entry.get("index")), 0)
        decision_view = False

        while True:
            entry = entries[pos]
            event = entry["event"]
            continue_state = _state_for_continuation(entry, deserialize_game_state(entry["state"]))

            print(f"Loaded state index {entry['index']} from {path}")
            if decision_view:
                try:
                    decision_state = _decision_state_for_entry(recording, pos)
                    print(render_board(decision_state))
                    print(
                        f"Decision view: {player_label(event['player'])} rolled {event['roll']} and must choose a move."
                    )
                    continue_from = decision_state
                except ValueError as exc:
                    print(f"Decision view unavailable: {exc}")
                    decision_view = False
                    continue
            else:
                print(render_board(continue_state))
                if event["type"] == "start":
                    print(
                        f"Start: {player_label(event['starting_player'])} won the opening roll with {event['top_roll']}."
                    )
                elif event["type"] == "turn_detail":
                    print(format_turn_detail_summary(event))
                else:
                    print(format_turn_summary({
                        "player": event["player"],
                        "events": [event],
                        "won": event.get("won", False),
                    }))
                continue_from = continue_state

            prompt = "Enter [B]ack, [N]ext, [D]ecision view, [C]ontinue, or [E]xit replay: "
            choice = read_user_input(prompt, settings).strip().lower()
            if choice in ("b", "back"):
                if pos > 0:
                    pos -= 1
                else:
                    print("Already at the first entry.")
                continue
            if choice in ("n", "next"):
                if pos < len(entries) - 1:
                    pos += 1
                else:
                    print("Already at the last entry.")
                continue
            if choice in ("d", "decision"):
                decision_view = not decision_view
                continue
            if choice in ("c", "continue"):
                return recording, continue_from
            if choice in ("e", "exit"):
                return None, None
            print("Please enter B, N, D, C, or E.")

    print(f"Replaying {len(recording['entries'])} recorded states from {path}")
    last_state = None
    for entry in recording["entries"]:
        state = deserialize_game_state(entry["state"])
        last_state = _state_for_continuation(entry, deserialize_game_state(entry["state"]))
        event = entry["event"]
        print(render_board(state))
        if event["type"] == "start":
            print(
                f"Start: {player_label(event['starting_player'])} won the opening roll with {event['top_roll']}."
            )
        elif event["type"] == "turn_detail":
            print(format_turn_detail_summary(event))
        else:
            print(format_turn_summary({
                "player": event["player"],
                "events": [event],
                "won": event.get("won", False),
            }))
        if entry["index"] != len(recording["entries"]) - 1:
            read_user_input("Press Enter for next recorded state. ", settings)

    while True:
        choice = read_user_input(
            "Enter [C]ontinue this game or [E]xit replay: ",
            settings,
        ).strip().lower()
        if choice in ("c", "continue"):
            return recording, last_state
        if choice in ("e", "exit"):
            return None, None
        print("Please enter C to continue or E to exit replay.")


def player_label(player: int, colored: bool = True) -> str:
    """Player display name as color text (with optional ANSI color)."""
    name = PLAYER_NAMES[player]
    return colorize(name, player) if colored else name


def marble_label(marble_id: int) -> str:
    """Backward-compatible marble index label."""
    return str(marble_id + 1)


def marble_token(player: int, marble_id: int) -> str:
    """Two-character user-facing marble token, e.g. A1, B3."""
    return f"{chr(ord('A') + player)}{marble_id + 1}"


def colored_marble_token(player: int, marble_id: int) -> str:
    """Colorized user-facing marble token."""
    return colorize(marble_token(player, marble_id), player)


def colorize_marble_cell(
    cell_text: str,
    tint_player: int | None = None,
    marble_player: int | None = None,
) -> str:
    """Color marble tokens; optionally tint empty '..' cells for ownership."""
    raw = cell_text.rstrip()
    if len(raw) < 2:
        return cell_text
    token = raw[-2:]
    prefix = raw[:-2]
    trailing_spaces = " " * (len(cell_text) - len(raw))

    if marble_player is not None and 0 <= marble_player < NUM_PLAYERS and token != "..":
        return f"{prefix}{colorize(token, marble_player)}{trailing_spaces}"

    if token == ".." and tint_player is not None and 0 <= tint_player < NUM_PLAYERS:
        return f"{prefix}{colorize(token, tint_player)}{trailing_spaces}"

    return cell_text


def render_board(state: GameState) -> str:
    """Physical plus-board renderer: 56-square loop + center + bases + home rows."""

    CELL_W = 4

    def draw_token(player: int | None, m: int | None) -> str:
        if m is None:
            return ".."
        return marble_token(player, m)

    def cell(text: str) -> str:
        """Render a fixed-width cell to keep board columns aligned."""
        return text[:CELL_W].center(CELL_W)

    owner_tints = [[None for _ in range(21)] for _ in range(21)]
    marble_owners = [[None for _ in range(21)] for _ in range(21)]

    def put(
        grid: list,
        r: int,
        c: int,
        value: str,
        tint_player: int | None = None,
        marble_player: int | None = None,
    ) -> None:
        if 0 <= r < len(grid) and 0 <= c < len(grid[0]):
            grid[r][c] = cell(value)
            owner_tints[r][c] = tint_player
            marble_owners[r][c] = marble_player

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

    grid = [[cell("") for _ in range(21)] for _ in range(21)]
    exit_owner_by_idx = {base_exit(p): p for p in range(NUM_PLAYERS)}

    for idx, (r, c) in enumerate(track_coords):
        occ = state.marble_at_track(idx)
        occ_token = ".." if occ is None else draw_token(occ[0], occ[1])
        marker = "  "
        tint_player = exit_owner_by_idx.get(idx)
        marble_player = None if occ is None else occ[0]
        put(grid, r, c, f"{marker}{occ_token}", tint_player=tint_player, marble_player=marble_player)

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
            token = draw_token(p, m)
            put(grid, r, c, token, tint_player=p, marble_player=(None if m is None else p))

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
            marble_player = p if i < len(base_marbles) else None
            put(grid, r, c, token, tint_player=p, marble_player=marble_player)

    co = state.center_occupant
    put(
        grid,
        9,
        8,
        f"C{draw_token(co[0], co[1])}" if co else "C..",
        marble_player=(None if co is None else co[0]),
    )

    for r, row in enumerate(grid):
        lines.append(" ".join(
            colorize_marble_cell(cell, owner_tints[r][c], marble_owners[r][c])
            for c, cell in enumerate(row)
        ))
        lines.append("")

    lines.append("=" * 112)
    return "\n".join(lines)


def format_move(move: dict, player: int, roll: int) -> str:
    """Short human-readable move."""
    token = colored_marble_token(player, move["marble"])
    if move["kind"] == "exit_base":
        desc = f"Move {token} out of base"
    elif move["kind"] == "exit_center":
        desc = f"Move {token} > exit center"
    elif move["kind"] == "enter_center":
        desc = f"Move {token} to center"
    elif move["kind"] in ("enter_home", "advance_home"):
        desc = f"Move {token} to home {move['dest'][1] + 1}"
    else:
        desc = f"Move {token} + {roll} positions"
    if move["captures"]:
        cp, cm = move["captures"]
        desc += f" [captures {player_label(cp)} {colored_marble_token(cp, cm)}]"
    return desc


def choose_move(moves: list, player: int, roll: int, settings: dict) -> dict:
    """Prompt human to pick a move from the list."""
    print("\nLegal moves:")
    for i, mv in enumerate(moves):
        print(f"  [{i + 1}] {format_move(mv, player, roll)}")
    print("Type /auto to toggle auto-roll mode.")
    while True:
        choice = read_user_input("Pick a move number: ", settings).strip()
        if choice.isdigit() and 1 <= int(choice) <= len(moves):
            return moves[int(choice) - 1]
        print(f"Invalid. Enter 1..{len(moves)}.")


def prompt_human_reasoning(settings: dict) -> str | None:
    """Optional free-text rationale for a manually selected move.

    This note is captured as training context and is not treated as optimal play.
    """
    note = read_user_input(
        "Optional reasoning for this choice (press Enter to skip): ",
        settings,
    ).strip()
    return note or None


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


def has_other_marble_in_play(state: GameState, player: int, marble_id: int) -> bool:
    """True when this player has another marble that is not in base."""
    for other in range(MARBLES_PER_PLAYER):
        if other == marble_id:
            continue
        if state.marbles[player][other][0] != "BASE":
            return True
    return False


def choose_computer_move(state: GameState, player: int, roll: int, moves: list) -> dict:
    """Pick computer move by priority rules.

    Priority:
    1) Capturing
    2) Exiting base
    3) Getting home
    4) Center entry (only when another marble is in play)
    5) Other moves
    """
    # Center rule: only prefer center if another marble is already in play.
    preferred = []
    for mv in moves:
        if mv["kind"] == "enter_center" and not has_other_marble_in_play(state, player, mv["marble"]):
            continue
        preferred.append(mv)
    if not preferred:
        preferred = moves

    captures = [m for m in preferred if m["captures"] is not None]
    if captures:
        return captures[0]

    exits = [m for m in preferred if m["kind"] == "exit_base"]
    if exits:
        return choose_next_exit_base_move(state, player, exits)

    home_moves = [m for m in preferred if m["kind"] in ("enter_home", "advance_home")]
    if home_moves:
        return home_moves[0]

    center_moves = [m for m in preferred if m["kind"] == "enter_center"]
    if center_moves:
        return center_moves[0]

    non_center = [m for m in preferred if m["kind"] != "enter_center"]
    if non_center:
        return non_center[0]

    return preferred[0]


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


def normalize_player_settings(settings: dict) -> list:
    """Return the four-seat player config, upgrading legacy settings if needed."""
    if "players" not in settings:
        if settings.get("computer_self_play"):
            settings["players"] = [DEFAULT_AI_PROFILE] * NUM_PLAYERS
        else:
            settings["players"] = [HUMAN_PLAYER_TYPE] * NUM_PLAYERS

    players = settings["players"]
    if len(players) != NUM_PLAYERS:
        raise ValueError(f"settings['players'] must contain exactly {NUM_PLAYERS} entries")

    valid_types = {HUMAN_PLAYER_TYPE, *PROFILES.keys()}
    invalid = [player_type for player_type in players if player_type not in valid_types]
    if invalid:
        valid = ", ".join(sorted(valid_types))
        raise ValueError(f"Invalid player type(s): {', '.join(invalid)}. Valid values: {valid}")
    return players


def player_type_for(settings: dict, player: int) -> str:
    """Return the configured controller type for one seat."""
    return normalize_player_settings(settings)[player]


def is_ai_slot(settings: dict, player: int) -> bool:
    """True when this seat is controlled by an AI profile."""
    return player_type_for(settings, player) != HUMAN_PLAYER_TYPE


def should_auto_roll_for(settings: dict, player: int) -> bool:
    """AI seats always auto-roll; humans follow the global auto-roll toggle."""
    return settings["auto_roll"] or is_ai_slot(settings, player)


def _pause_for_ai_turn(settings: dict, player: int) -> None:
    """Sleep after an AI move so human players can read the board."""
    if not is_ai_slot(settings, player):
        return
    if HUMAN_PLAYER_TYPE not in settings.get("players", []):
        return
    delay = settings.get("ai_delay", 0.0)
    if delay > 0:
        time.sleep(delay)


def _prompt_ai_delay(settings: dict) -> None:
    """Ask how long to pause after each AI turn. Press Enter to keep default."""
    current = settings.get("ai_delay", DEFAULT_AI_DELAY)
    while True:
        raw = read_user_input(
            f"Pause after each AI turn in seconds [{current}] (0 to disable): ",
            settings,
        ).strip()
        if raw == "":
            settings["ai_delay"] = current
            return
        try:
            delay = float(raw)
            if delay >= 0:
                settings["ai_delay"] = delay
                return
        except ValueError:
            pass
        print("Please enter a number of seconds (0 to disable).")


def _resolve_profile_from_difficulty(response: str) -> str | None:
    """Return default profile for a difficulty token or numbered choice."""
    token = response.strip().lower()
    if not token:
        return None

    if token.isdigit():
        idx = int(token)
        if 1 <= idx <= len(DIFFICULTY_LEVELS):
            return DIFFICULTY_LEVELS[idx - 1][2]

    return DIFFICULTY_TO_DEFAULT_PROFILE.get(token)


def prompt_difficulty_profile(settings: dict, prompt_label: str = "Choose difficulty") -> str:
    """Prompt for a difficulty level and return its default AI profile."""
    print("\nDifficulty levels:")
    for idx, (name, profiles, default_profile) in enumerate(DIFFICULTY_LEVELS, start=1):
        available = ", ".join(p for p in profiles if p in PROFILES)
        print(f"  [{idx}] {name.title()} (default: {default_profile}; profiles: {available})")

    while True:
        response = read_user_input(
            f"{prompt_label} [1-{len(DIFFICULTY_LEVELS)} or name]: ",
            settings,
        )
        profile = _resolve_profile_from_difficulty(response)
        if profile and profile in PROFILES:
            return profile
        print("Please enter a valid difficulty number or name.")


def _resolve_profile_choice(response: str, profile_names: list[str]) -> str | None:
    """Return AI profile from number or direct profile name token."""
    token = response.strip().lower()
    if not token:
        return None

    if token.isdigit():
        idx = int(token)
        if 1 <= idx <= len(profile_names):
            return profile_names[idx - 1]

    if token in PROFILES:
        return token
    return None


def prompt_ai_profile(settings: dict, prompt_label: str = "Choose AI profile") -> str:
    """Prompt for an AI profile using a numbered list or profile name."""
    known = set(PROFILES.keys())
    ordered = [p for p in PROFILE_DISPLAY_ORDER if p in known]
    ordered += sorted(known - set(ordered))  # append any new profiles not in the order list
    profile_names = ordered
    print("\nAI profiles (easiest → hardest):")
    for idx, profile in enumerate(profile_names, start=1):
        desc = PROFILE_DESCRIPTIONS.get(profile, "")
        print(f"  [{idx}] {profile:<12} — {desc}")

    while True:
        response = read_user_input(
            f"{prompt_label} [1-{len(profile_names)} or name]: ",
            settings,
        )
        profile = _resolve_profile_choice(response, profile_names)
        if profile is not None:
            return profile
        print("Please enter a valid profile number or profile name.")


def prompt_controller_for_player(settings: dict, player: int) -> str:
    """Prompt for one seat controller via numbered menu."""
    print(f"\n{player_label(player)} controller setup:")
    print("  [1] Human")
    print("  [2] AI by difficulty")
    print("  [3] AI by profile")

    while True:
        response = read_user_input("Choose controller [1-3]: ", settings).strip().lower()

        # Check numbered menu options first so "2" and "3" aren't mistaken for
        # difficulty/profile indices.
        if response in ("1", "human", "h", ""):
            return HUMAN_PLAYER_TYPE
        if response in ("2", "difficulty", "d"):
            return prompt_difficulty_profile(settings, prompt_label=f"{player_label(player)} difficulty")
        if response in ("3", "profile", "p"):
            return prompt_ai_profile(settings, prompt_label=f"{player_label(player)} profile")

        # Allow typing a profile name or difficulty name directly.
        direct_profile = _resolve_profile_choice(response, sorted(PROFILES.keys()))
        if direct_profile is not None:
            return direct_profile
        direct_difficulty_profile = _resolve_profile_from_difficulty(response)
        if direct_difficulty_profile is not None and direct_difficulty_profile in PROFILES:
            return direct_difficulty_profile

        print("Please enter 1 (human), 2 (difficulty), or 3 (profile).")


def configure_players(settings: dict) -> list:
    """Prompt for the controller assigned to each player seat."""
    print("\n=== Player Setup ===")
    print("Use numbered choices for each seat.")
    print("Type /auto anytime to toggle auto-roll mode.")

    players = []
    for player in range(NUM_PLAYERS):
        players.append(prompt_controller_for_player(settings, player))

    settings["players"] = players
    if any(p != HUMAN_PLAYER_TYPE for p in players):
        _prompt_ai_delay(settings)
    return players


def configure_computer_self_play(settings: dict) -> list:
    """Prompt setup for all-AI self-play with numbered choices."""
    print("\n=== Computer Self-Play Setup ===")
    print("  [1] Use one difficulty for all seats")
    print("  [2] Use one profile for all seats")
    print("  [3] Configure each seat individually")

    while True:
        response = read_user_input("Choose setup [1-3]: ", settings).strip().lower()
        if response in ("1", "difficulty", "d"):
            profile = prompt_difficulty_profile(settings, prompt_label="Self-play difficulty")
            players = [profile] * NUM_PLAYERS
            settings["players"] = players
            return players
        if response in ("2", "profile", "p"):
            profile = prompt_ai_profile(settings, prompt_label="Self-play profile")
            players = [profile] * NUM_PLAYERS
            settings["players"] = players
            return players
        if response in ("3", "mixed", "m"):
            return configure_players(settings)
        print("Please enter 1 (difficulty), 2 (profile), or 3 (per-seat setup).")


def prompt_game_type(settings: dict) -> None:
    """Ask whether to start a standard or training game."""
    print("\nGame type:")
    print("  [S] Standard  — normal play, no reasoning prompts")
    print("  [T] Training  — prompts for human reasoning after each manual choice")
    while True:
        choice = read_user_input("Choose game type [S/T]: ", settings).strip().lower()
        if choice in ("s", "standard", ""):
            settings["training_mode"] = False
            return
        if choice in ("t", "training"):
            settings["training_mode"] = True
            return
        print("Please enter S for Standard or T for Training.")


def show_intro_and_choose_action(settings: dict) -> str:
    """Display intro art and let the user start, replay, self-play, or exit."""
    print(INTRO_ART)
    print("[S] Start a new game")
    print("[C] Computer self-play")
    print("[R] Replay a saved game")
    print("[E] Exit")
    print("Type /auto to toggle auto-roll mode.")
    while True:
        choice = read_user_input("Enter choice: ", settings).strip().lower()
        if choice in ("s", "start"):
            return "start"
        if choice in ("c", "computer"):
            return "computer"
        if choice in ("r", "replay"):
            return "replay"
        if choice in ("e", "exit"):
            return "exit"
        print("Please enter S to start, C for computer self-play, R to replay, or E to exit.")


def prompt_replay_path(settings: dict) -> str:
    """Prompt for the replay filename to load."""
    while True:
        replay_path = read_user_input("Enter replay filename: ", settings).strip()
        if replay_path:
            return replay_path
        print("Please enter a saved game filename.")


def prompt_replay_index(settings: dict) -> int | None:
    """Prompt for an optional replay index to resume from."""
    while True:
        raw = read_user_input(
            "Enter replay index to resume from (blank = end of game): ",
            settings,
        ).strip()
        if raw == "":
            return None
        if raw.isdigit():
            return int(raw)
        print("Please enter a non-negative integer index, or press Enter to use the latest state.")


def decide_starting_player(rng: random.Random, settings: dict) -> tuple[int, int]:
    """Choose opening player by highest roll in a single round.

    If multiple players tie for highest, earliest clockwise player wins.
    """
    print("\n=== Starting Phase: Who Goes First? ===")
    top_player = None
    top_roll = -1
    leaders = []

    for player in range(NUM_PLAYERS):
        if should_auto_roll_for(settings, player):
            print(f"{player_label(player)} auto-rolling for first turn.")
        else:
            read_user_input(
                f"{player_label(player)}: press Enter to roll for first turn. ",
                settings,
                allow_auto_continue=True,
            )
        roll = rng.randint(1, 6)
        print(f"  {player_label(player)} rolled a {roll}.")
        print("")
        if roll > top_roll:
            top_roll = roll
            top_player = player
            leaders = [player]
        elif roll == top_roll:
            leaders.append(player)

        if len(leaders) == 1:
            print(f"  Highest so far: {player_label(leaders[0])} with {top_roll}.")
        else:
            tied_players = " and ".join(player_label(p) for p in leaders)
            print(f"  {tied_players} are tied with {top_roll}.")
        print("")

    return top_player, top_roll


def format_turn_summary(turn_result: dict) -> str:
    """Human-readable summary shown after the updated board."""
    lines = [f"{player_label(turn_result['player'])} turn results:"]
    for event in turn_result["events"]:
        line = f"  Rolled {event['roll']}: {event['outcome']}"
        if event["reroll"]:
            line += " -> rolled a 6, goes again"
        lines.append(line)
        if event.get("human_reasoning"):
            lines.append(f"    Human note: {event['human_reasoning']}")
    return "\n".join(lines)


def format_turn_detail_summary(event: dict) -> str:
    """Human-readable line for replaying a turn_detail event."""
    decision = event.get("decision_type", "mixed")
    player_type = event.get("player_type", "unknown")
    chosen = event.get("chosen_kind", "?")
    count = event.get("num_legal_moves", 0)
    return (
        f"Turn detail: [{player_type}] decision={decision}, "
        f"chosen={chosen}, legal_moves={count}"
    )


def take_turn(state: GameState, rng: random.Random, settings: dict) -> dict:
    """One full turn for state.current_player, including 6-rerolls."""
    player = state.current_player
    settings["turn_number"] = settings.get("turn_number", 0) + 1
    turn_num = settings["turn_number"]
    turn_result = {
        "player": player,
        "turn_number": turn_num,
        "events": [],
        "detail_events": [],
        "won": False,
    }
    roll_index = 0

    while True:
        roll_index += 1
        player_type = player_type_for(settings, player)
        if should_auto_roll_for(settings, player):
            print(f"\n--- Turn {turn_num} — {player_label(player)}'s turn. Auto-rolling.")
        else:
            read_user_input(
                f"\n--- Turn {turn_num} — {player_label(player)}'s turn. Press Enter to roll. ",
                settings,
                allow_auto_continue=True,
            )

        if state.pending_roll is not None:
            roll = state.pending_roll
            state.pending_roll = None
            print(f"  Using loaded roll {roll}.")
        else:
            roll = rng.randint(1, 6)
        moves = legal_moves(state, player, roll)
        detail_event = None
        if not moves:
            outcome = "no legal move"
            human_reasoning = None
            reasoning_non_optimal = None
        else:
            if player_type == HUMAN_PLAYER_TYPE:
                auto_move = maybe_auto_choose_move(state, player, roll, moves)
                if auto_move is not None:
                    chosen = auto_move
                    outcome = f"auto-selected {format_move(chosen, player, roll)}"
                    human_reasoning = None
                    reasoning_non_optimal = None
                else:
                    print(f"{player_label(player)} rolled a {roll}.")
                    prompt_moves = build_prompt_moves(state, player, roll, moves)
                    chosen = choose_move(prompt_moves, player, roll, settings)
                    outcome = format_move(chosen, player, roll)
                    if settings.get("training_mode"):
                        human_reasoning = prompt_human_reasoning(settings)
                        reasoning_non_optimal = True if human_reasoning is not None else None
                    else:
                        human_reasoning = None
                        reasoning_non_optimal = None
            else:
                chosen = PROFILES[player_type].choose_move(state, player, roll, moves)
                outcome = f"[{player_type}] {format_move(chosen, player, roll)}"
                human_reasoning = None
                reasoning_non_optimal = None

            if settings.get("track_stats"):
                detail_index = settings.get("_turn_detail_index", 0) + 1
                settings["_turn_detail_index"] = detail_index
                detail = compute_turn_record(
                    game_id=settings.get("_game_id", "game"),
                    turn_index=detail_index,
                    state_before=state.clone(),
                    player=player,
                    player_type=player_type,
                    roll=roll,
                    roll_index=roll_index,
                    all_moves=moves,
                    chosen_move=chosen,
                )
                detail_event = turn_record_to_event(detail)

            update_exit_base_cursor(state, player, chosen)
            apply_move(state, chosen)
            if state.player_won(player):
                turn_result["won"] = True

        event_payload = {
            "roll": roll,
            "outcome": outcome,
            "reroll": (roll == 6 and not turn_result["won"]),
            "state": serialize_game_state(state),
        }
        if human_reasoning is not None:
            event_payload["human_reasoning"] = human_reasoning
            event_payload["human_reasoning_non_optimal"] = reasoning_non_optimal
        if detail_event is not None:
            event_payload["turn_detail"] = detail_event
            turn_result["detail_events"].append(detail_event)
        turn_result["events"].append(event_payload)

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
            _pause_for_ai_turn(settings, player)
            break

        _pause_for_ai_turn(settings, player)

    state.current_player = (player + 1) % NUM_PLAYERS
    return turn_result


def main():
    args = sys.argv[1:]
    recording_path = None
    settings = {
        "auto_roll": False,
        "players": [HUMAN_PLAYER_TYPE] * NUM_PLAYERS,
        "track_stats": True,
        "stats_csv_path": DEFAULT_STATS_CSV_PATH,
        "ai_delay": DEFAULT_AI_DELAY,
        "training_mode": False,
        "turn_number": 0,
    }
    if args and args[0] == "replay":
        replay_path = args[1] if len(args) > 1 else DEFAULT_RECORDING_PATH
        replay_index = None
        if len(args) > 2:
            try:
                replay_index = int(args[2])
                if replay_index < 0:
                    raise ValueError
            except ValueError:
                print("Replay index must be a non-negative integer.")
                return

        recording, state = run_replay(replay_path, settings, replay_index=replay_index)
        if recording is None:
            return
        settings["_game_id"] = os.path.splitext(os.path.basename(replay_path))[0]
        detail_turns = [
            e.get("event", {}).get("turn_index")
            for e in recording.get("entries", [])
            if e.get("event", {}).get("type") == "turn_detail"
        ]
        settings["_turn_detail_index"] = max((i for i in detail_turns if isinstance(i, int)), default=0)
        recording_path = replay_path
        rng = random.Random()
        if replay_index is None:
            print(f"Continuing recorded game from {replay_path}")
        else:
            print(f"Continuing recorded game from {replay_path} at index {replay_index}")
    else:
        seed_arg = args[0] if args else None
        rng = random.Random(int(seed_arg) if seed_arg else None)
        action = show_intro_and_choose_action(settings)
        if action == "exit":
            return
        if action == "replay":
            replay_path = prompt_replay_path(settings)
            replay_index = prompt_replay_index(settings)
            recording, state = run_replay(replay_path, settings, replay_index=replay_index)
            if recording is None:
                return
            settings["_game_id"] = os.path.splitext(os.path.basename(replay_path))[0]
            detail_turns = [
                e.get("event", {}).get("turn_index")
                for e in recording.get("entries", [])
                if e.get("event", {}).get("type") == "turn_detail"
            ]
            settings["_turn_detail_index"] = max((i for i in detail_turns if isinstance(i, int)), default=0)
            recording_path = replay_path
            if replay_index is None:
                print(f"Continuing recorded game from {replay_path}")
            else:
                print(f"Continuing recorded game from {replay_path} at index {replay_index}")
        else:
            if action == "computer":
                configure_computer_self_play(settings)
                settings["auto_roll"] = True
            else:
                prompt_game_type(settings)
                configure_players(settings)
            state = GameState()
            state.current_player, top_roll = decide_starting_player(rng, settings)
            recording = {
                "version": 2,
                "seed": int(seed_arg) if seed_arg else None,
                "players": list(settings["players"]),
                "entries": [],
            }
            recording_path = make_recording_path()
            settings["_game_id"] = os.path.splitext(os.path.basename(recording_path))[0]
            settings["_turn_detail_index"] = 0
            append_recording_entry(recording, state, {
                "type": "start",
                "starting_player": state.current_player,
                "top_roll": top_roll,
            })
            write_recording(recording, recording_path)
            print(render_board(state))
            print(f"{player_label(state.current_player)} had the highest roll, with {top_roll}, they go first!")
            ai_players = [p for p in settings["players"] if p != HUMAN_PLAYER_TYPE]
            if ai_players:
                print("Players: " + ", ".join(settings["players"]))
            print(f"Recording game history to {recording_path}")

    while True:
        turn_result = take_turn(state, rng, settings)
        for event in turn_result["events"]:
            snapshot = deserialize_game_state(event["state"])
            # Persist the true next player for non-reroll turn events.
            if not event["reroll"] and not turn_result["won"]:
                snapshot.current_player = (turn_result["player"] + 1) % NUM_PLAYERS

            append_recording_entry(recording, snapshot, {
                "type": "turn",
                "player": turn_result["player"],
                "roll": event["roll"],
                "outcome": event["outcome"],
                "reroll": event["reroll"],
                "won": turn_result["won"],
                "human_reasoning": event.get("human_reasoning"),
                "human_reasoning_non_optimal": event.get("human_reasoning_non_optimal"),
            })
            if settings.get("track_stats") and event.get("turn_detail") is not None:
                append_recording_entry(recording, snapshot, event["turn_detail"])
            write_recording(recording, recording_path)
        if turn_result["won"]:
            print(f"\n*** {player_label(turn_result['player'])} WINS! ***")
            if settings.get("track_stats"):
                try:
                    summary = compile_game_stats(recording)
                    print_game_report(summary)
                    append_stats_csv(summary, settings.get("stats_csv_path", DEFAULT_STATS_CSV_PATH))
                    print(f"Stats appended to {settings.get('stats_csv_path', DEFAULT_STATS_CSV_PATH)}")
                except ValueError as exc:
                    print(f"Stats unavailable: {exc}")
            sys.exit(0)


if __name__ == "__main__":
    main()
