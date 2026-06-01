"use strict";

const LOOP_SIZE = 56;
const SEGMENT_LEN = 14;
const HOME_SLOTS = 4;
const MARBLES_PER_PLAYER = 4;
const NUM_PLAYERS = 4;

function baseExit(player) {
  return player * SEGMENT_LEN;
}

function homeEntry(player) {
  return mod(player * SEGMENT_LEN - 2, LOOP_SIZE);
}

function centerExitDest(player) {
  const prevPlayer = mod(player - 1, NUM_PLAYERS);
  return prevPlayer * SEGMENT_LEN + 5;
}

function segmentOffset(player, loopIdx) {
  return mod(loopIdx - baseExit(player), LOOP_SIZE);
}

function locBase() {
  return ["BASE"];
}

function locTrack(loopIdx) {
  return ["TRACK", loopIdx];
}

function locHome(slot) {
  return ["HOME", slot];
}

function locCenter() {
  return ["CENTER"];
}

function newGameState(currentPlayer = 0) {
  return {
    marbles: Array.from({ length: NUM_PLAYERS }, () =>
      Array.from({ length: MARBLES_PER_PLAYER }, () => locBase())
    ),
    current_player: currentPlayer,
    pending_roll: null,
    center_occupant: null,
    next_base_exit_marble: [0, 0, 0, 0],
  };
}

function cloneState(state) {
  return {
    marbles: state.marbles.map((row) => row.map((loc) => [...loc])),
    current_player: Number(state.current_player ?? 0),
    pending_roll: state.pending_roll ?? null,
    center_occupant: state.center_occupant ? [...state.center_occupant] : null,
    next_base_exit_marble: Array.isArray(state.next_base_exit_marble)
      ? [...state.next_base_exit_marble]
      : [0, 0, 0, 0],
  };
}

function legalMoves(state, player, roll) {
  const moves = [];
  for (let marbleId = 0; marbleId < MARBLES_PER_PLAYER; marbleId += 1) {
    const loc = state.marbles[player][marbleId];
    if (loc[0] === "BASE") {
      moves.push(...movesFromBase(state, player, marbleId, roll));
    } else if (loc[0] === "TRACK") {
      moves.push(...movesFromTrack(state, player, marbleId, roll, Number(loc[1])));
    } else if (loc[0] === "HOME") {
      moves.push(...movesFromHome(state, player, marbleId, roll, Number(loc[1])));
    } else if (loc[0] === "CENTER") {
      moves.push(...movesFromCenter(state, player, marbleId, roll));
    }
  }
  return moves;
}

function applyMove(state, move) {
  const player = Number(state.current_player);
  const marbleId = Number(move.marble);
  const captures = move.captures ?? null;

  if (captures !== null) {
    const capPlayer = Number(captures[0]);
    const capMarble = Number(captures[1]);
    state.marbles[capPlayer][capMarble] = locBase();
    if (
      state.center_occupant !== null &&
      Number(state.center_occupant[0]) === capPlayer &&
      Number(state.center_occupant[1]) === capMarble
    ) {
      state.center_occupant = null;
    }
  }

  state.marbles[player][marbleId] = [...move.dest];

  if (move.dest[0] === "CENTER") {
    state.center_occupant = [player, marbleId];
  } else if (move.kind === "exit_center") {
    state.center_occupant = null;
  }

  return state;
}

function playerWon(state, player) {
  return state.marbles[player].every((loc) => loc[0] === "HOME");
}

function marbleAtTrack(state, loopIdx) {
  for (let player = 0; player < NUM_PLAYERS; player += 1) {
    for (let marbleId = 0; marbleId < MARBLES_PER_PLAYER; marbleId += 1) {
      const loc = state.marbles[player][marbleId];
      if (loc[0] === "TRACK" && Number(loc[1]) === loopIdx) {
        return [player, marbleId];
      }
    }
  }
  return null;
}

function marbleAtHome(state, player, slot) {
  for (let marbleId = 0; marbleId < MARBLES_PER_PLAYER; marbleId += 1) {
    const loc = state.marbles[player][marbleId];
    if (loc[0] === "HOME" && Number(loc[1]) === slot) {
      return marbleId;
    }
  }
  return null;
}

function movesFromBase(state, player, marbleId, roll) {
  if (roll !== 1 && roll !== 6) {
    return [];
  }
  const destIdx = baseExit(player);
  const occupant = marbleAtTrack(state, destIdx);
  if (occupant !== null && occupant[0] === player) {
    return [];
  }
  return [{
    marble: marbleId,
    dest: locTrack(destIdx),
    kind: "exit_base",
    captures: occupant,
  }];
}

function movesFromTrack(state, player, marbleId, roll, currentIdx) {
  const moves = [];
  const ownOffset = segmentOffset(player, currentIdx);

  if (ownOffset <= 5 && roll === 6 - ownOffset) {
    if (!pathToCenterBlockedByOwnMarble(state, player, currentIdx)) {
      const capture = state.center_occupant;
      if (capture === null || Number(capture[0]) !== player) {
        moves.push({
          marble: marbleId,
          dest: locCenter(),
          kind: "enter_center",
          captures: capture,
        });
      }
    }
  }

  const move = walkForward(state, player, marbleId, currentIdx, roll);
  if (move !== null) {
    moves.push(move);
  }
  return moves;
}

function pathToCenterBlockedByOwnMarble(state, player, currentIdx) {
  const ownOffset = segmentOffset(player, currentIdx);
  for (let offset = ownOffset + 1; offset < 6; offset += 1) {
    const idx = mod(baseExit(player) + offset, LOOP_SIZE);
    const occupant = marbleAtTrack(state, idx);
    if (occupant !== null && occupant[0] === player) {
      return true;
    }
  }
  return false;
}

function walkForward(state, player, marbleId, startIdx, steps) {
  const ownHomeEntry = homeEntry(player);
  let idx = startIdx;
  let remaining = steps;
  let enteredHome = false;
  let homeSlot = -1;

  while (remaining > 0 && !enteredHome) {
    const nextIdx = mod(idx + 1, LOOP_SIZE);

    if (idx === ownHomeEntry) {
      enteredHome = true;
      homeSlot = 0;
      remaining -= 1;
      if (remaining === 0) {
        if (marbleAtHome(state, player, 0) !== null) {
          return null;
        }
        return {
          marble: marbleId,
          dest: locHome(0),
          kind: "enter_home",
          captures: null,
        };
      }
      break;
    }

    const occupant = marbleAtTrack(state, nextIdx);
    if (occupant !== null && occupant[0] === player) {
      return null;
    }

    idx = nextIdx;
    remaining -= 1;

    if (remaining === 0) {
      return {
        marble: marbleId,
        dest: locTrack(idx),
        kind: "advance",
        captures: occupant,
      };
    }
  }

  while (remaining > 0) {
    const nextSlot = homeSlot + 1;
    if (nextSlot > HOME_SLOTS - 1) {
      return null;
    }
    if (marbleAtHome(state, player, nextSlot) !== null) {
      return null;
    }
    homeSlot = nextSlot;
    remaining -= 1;
  }

  return {
    marble: marbleId,
    dest: locHome(homeSlot),
    kind: "advance_home",
    captures: null,
  };
}

function movesFromHome(state, player, marbleId, roll, currentSlot) {
  const newSlot = currentSlot + roll;
  if (newSlot > HOME_SLOTS - 1) {
    return [];
  }
  for (let slot = currentSlot + 1; slot <= newSlot; slot += 1) {
    if (marbleAtHome(state, player, slot) !== null) {
      return [];
    }
  }
  return [{
    marble: marbleId,
    dest: locHome(newSlot),
    kind: "advance_home",
    captures: null,
  }];
}

function movesFromCenter(state, player, marbleId, roll) {
  if (roll !== 1) {
    return [];
  }
  const destIdx = centerExitDest(player);
  const occupant = marbleAtTrack(state, destIdx);
  if (occupant !== null && occupant[0] === player) {
    return [];
  }
  return [{
    marble: marbleId,
    dest: locTrack(destIdx),
    kind: "exit_center",
    captures: occupant,
  }];
}

function sameMove(left, right) {
  return JSON.stringify(normalizeMove(left)) === JSON.stringify(normalizeMove(right));
}

function normalizeMove(move) {
  return {
    marble: Number(move.marble),
    dest: Array.isArray(move.dest) ? [...move.dest] : move.dest,
    kind: String(move.kind),
    captures: move.captures === undefined || move.captures === null
      ? null
      : [Number(move.captures[0]), Number(move.captures[1])],
  };
}

function mod(value, by) {
  return ((value % by) + by) % by;
}

module.exports = {
  LOOP_SIZE,
  SEGMENT_LEN,
  HOME_SLOTS,
  MARBLES_PER_PLAYER,
  NUM_PLAYERS,
  applyMove,
  baseExit,
  centerExitDest,
  cloneState,
  homeEntry,
  legalMoves,
  locBase,
  locCenter,
  locHome,
  locTrack,
  newGameState,
  playerWon,
  sameMove,
  segmentOffset,
};
