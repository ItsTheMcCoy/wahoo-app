"""
Wahoo rules: legal_moves() and apply_move().

A Move is a dict:
  {
    "marble": int,            # marble id 0..3 of current player
    "dest": Location tuple,   # where the marble ends up
    "kind": str,              # "exit_base" | "advance" | "enter_center"
                              # | "exit_center" | "enter_home" | "advance_home"
    "captures": tuple | None, # (player, marble_id) bumped to base, if any
  }
"""

from .game_state import (
    GameState, LOOP_SIZE, SEGMENT_LEN, HOME_SLOTS, MARBLES_PER_PLAYER,
    NUM_PLAYERS, base_exit, home_entry, center_exit_dest, segment_offset,
    loc_base, loc_track, loc_home, loc_center,
)


def legal_moves(state: GameState, player: int, roll: int) -> list:
    """Return all legal moves for `player` with the given die `roll`.
    Empty list means no legal move (turn passes; re-roll if roll was 6)."""
    moves = []
    for marble_id in range(MARBLES_PER_PLAYER):
        loc = state.marbles[player][marble_id]
        if loc[0] == "BASE":
            moves.extend(_moves_from_base(state, player, marble_id, roll))
        elif loc[0] == "TRACK":
            moves.extend(_moves_from_track(state, player, marble_id, roll, loc[1]))
        elif loc[0] == "HOME":
            moves.extend(_moves_from_home(state, player, marble_id, roll, loc[1]))
        elif loc[0] == "CENTER":
            moves.extend(_moves_from_center(state, player, marble_id, roll))
    return moves


def _moves_from_base(state, player, marble_id, roll):
    """Exit base on a 1 or 6, landing on base-exit square."""
    if roll not in (1, 6):
        return []
    dest_idx = base_exit(player)
    occupant = state.marble_at_track(dest_idx)
    if occupant is not None and occupant[0] == player:
        return []  # blocked by own marble
    return [{
        "marble": marble_id,
        "dest": loc_track(dest_idx),
        "kind": "exit_base",
        "captures": occupant if occupant else None,
    }]


def _moves_from_track(state, player, marble_id, roll, current_idx):
    """Advance along the loop; possibly turn into home; possibly enter center."""
    moves = []

    # --- Option 1: enter center, if eligible ---
    # Center is reachable only from this player's own first 6 track squares
    # (offsets 0..5), with exact roll (6 - offset).
    own_offset = segment_offset(player, current_idx)
    if own_offset <= 5 and roll == (6 - own_offset):
        # Entering center cannot jump over your own marbles on the inward spoke.
        if _path_to_center_blocked_by_own_marble(state, player, current_idx):
            pass
        else:
        # Center can hold only one marble; entering captures occupant.
            capture = state.center_occupant
            # Cannot enter center if own marble already there (can't capture self).
            if capture is None or capture[0] != player:
                moves.append({
                    "marble": marble_id,
                    "dest": loc_center(),
                    "kind": "enter_center",
                    "captures": capture,
                })

    # --- Option 2: advance along the loop / into home ---
    move = _walk_forward(state, player, marble_id, current_idx, roll)
    if move is not None:
        moves.append(move)

    return moves


def _path_to_center_blocked_by_own_marble(state, player, current_idx):
    """Return True if entering center would pass over one of player's marbles."""
    own_offset = segment_offset(player, current_idx)
    for offset in range(own_offset + 1, 6):
        idx = (base_exit(player) + offset) % LOOP_SIZE
        occupant = state.marble_at_track(idx)
        if occupant is not None and occupant[0] == player:
            return True
    return False


def _walk_forward(state, player, marble_id, start_idx, steps):
    """Walk `steps` squares from start_idx. Handle home turn-in and blocking.
    Returns a move dict or None if illegal."""
    own_home_entry = home_entry(player)
    idx = start_idx
    remaining = steps
    entered_home = False
    home_slot = -1

    # Are we already past our home_entry? We need to know whether the
    # *next step forward* would cross the home_entry square.
    # Track-mode walking:
    while remaining > 0 and not entered_home:
        next_idx = (idx + 1) % LOOP_SIZE

        # If we are AT home_entry, next step turns into home (slot 0).
        if idx == own_home_entry:
            entered_home = True
            home_slot = 0
            remaining -= 1
            if remaining == 0:
                # Landed in home slot 0.
                if state.marble_at_home(player, 0) is not None:
                    return None
                return {
                    "marble": marble_id, "dest": loc_home(0),
                    "kind": "enter_home", "captures": None,
                }
            # Otherwise, continue walking up the home column below.
            break

        # Otherwise advance one square on the loop.
        # Check blocking: cannot land on or pass own marble.
        occupant = state.marble_at_track(next_idx)
        if occupant is not None and occupant[0] == player:
            # Own marble at next_idx: blocks both pass and land.
            return None

        idx = next_idx
        remaining -= 1

        if remaining == 0:
            # Final landing square — capture opponent if present.
            return {
                "marble": marble_id, "dest": loc_track(idx),
                "kind": "advance",
                "captures": occupant if occupant else None,
            }

    # We entered home. Walk remaining steps up the home column.
    # Constraints: cannot land on own marble in home; cannot overshoot
    # past slot 3.
    while remaining > 0:
        next_slot = home_slot + 1
        if next_slot > HOME_SLOTS - 1:
            return None  # overshoot — illegal
        if state.marble_at_home(player, next_slot) is not None:
            return None  # blocked by own marble
        home_slot = next_slot
        remaining -= 1

    return {
        "marble": marble_id, "dest": loc_home(home_slot),
        "kind": "advance_home", "captures": None,
    }


def _moves_from_home(state, player, marble_id, roll, current_slot):
    """Advance within home stretch; exact roll required, no overshoot,
    no landing on own marble."""
    new_slot = current_slot + roll
    if new_slot > HOME_SLOTS - 1:
        return []
    # Check no own marble in between or at destination.
    for s in range(current_slot + 1, new_slot + 1):
        if state.marble_at_home(player, s) is not None:
            return []
    return [{
        "marble": marble_id,
        "dest": loc_home(new_slot),
        "kind": "advance_home",
        "captures": None,
    }]


def _moves_from_center(state, player, marble_id, roll):
    """Exit center on a 1; destination is offset 5 of previous segment."""
    if roll != 1:
        return []
    dest_idx = center_exit_dest(player)
    occupant = state.marble_at_track(dest_idx)
    if occupant is not None and occupant[0] == player:
        return []  # blocked by own marble
    return [{
        "marble": marble_id,
        "dest": loc_track(dest_idx),
        "kind": "exit_center",
        "captures": occupant if occupant else None,
    }]


def apply_move(state: GameState, move: dict) -> GameState:
    """Mutate state in-place applying the move. Returns the state.
    Caller is responsible for turn/re-roll bookkeeping."""
    player = state.current_player
    marble_id = move["marble"]

    # Resolve capture first (so we don't overwrite the moving marble's slot).
    if move["captures"] is not None:
        cap_p, cap_m = move["captures"]
        state.marbles[cap_p][cap_m] = loc_base()
        if state.center_occupant == (cap_p, cap_m):
            state.center_occupant = None

    # Move the marble.
    state.marbles[player][marble_id] = move["dest"]

    # Update center_occupant.
    if move["dest"][0] == "CENTER":
        state.center_occupant = (player, marble_id)
    elif move["kind"] == "exit_center":
        state.center_occupant = None

    return state
