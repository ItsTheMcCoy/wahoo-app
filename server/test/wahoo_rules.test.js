"use strict";

const assert = require("node:assert/strict");
const test = require("node:test");
const {
  applyMove,
  legalMoves,
  locBase,
  locCenter,
  locHome,
  locTrack,
  newGameState,
  playerWon,
} = require("../wahoo_rules");

test("base marbles can exit on 1 or 6 only", () => {
  const state = newGameState();
  assert.equal(legalMoves(state, 0, 2).length, 0);
  assert.deepEqual(legalMoves(state, 0, 1), [
    { marble: 0, dest: locTrack(0), kind: "exit_base", captures: null },
    { marble: 1, dest: locTrack(0), kind: "exit_base", captures: null },
    { marble: 2, dest: locTrack(0), kind: "exit_base", captures: null },
    { marble: 3, dest: locTrack(0), kind: "exit_base", captures: null },
  ]);
});

test("own marble blocks track movement", () => {
  const state = newGameState();
  state.marbles[0][0] = locTrack(0);
  state.marbles[0][1] = locTrack(2);
  const moves = legalMoves(state, 0, 3);
  assert.equal(moves.some((move) => move.marble === 0), false);
  assert.equal(moves.some((move) => move.marble === 1 && move.dest[1] === 5), true);
});

test("track movement can capture opponent", () => {
  const state = newGameState();
  state.marbles[0][0] = locTrack(0);
  state.marbles[1][0] = locTrack(3);
  const moves = legalMoves(state, 0, 3);
  assert.deepEqual(moves, [
    { marble: 0, dest: locTrack(3), kind: "advance", captures: [1, 0] },
  ]);
  state.current_player = 0;
  applyMove(state, moves[0]);
  assert.deepEqual(state.marbles[1][0], locBase());
  assert.deepEqual(state.marbles[0][0], locTrack(3));
});

test("center entry and exit follow Wahoo rules", () => {
  const state = newGameState();
  state.marbles[0][0] = locTrack(4);
  assert.deepEqual(legalMoves(state, 0, 2)[0], {
    marble: 0,
    dest: locCenter(),
    kind: "enter_center",
    captures: null,
  });

  state.current_player = 0;
  applyMove(state, legalMoves(state, 0, 2)[0]);
  assert.deepEqual(state.center_occupant, [0, 0]);
  assert.deepEqual(
    legalMoves(state, 0, 1).find((move) => move.kind === "exit_center"),
    { marble: 0, dest: locTrack(47), kind: "exit_center", captures: null },
  );
});

test("home entry and win detection work", () => {
  const state = newGameState();
  state.marbles[0][0] = locTrack(54);
  assert.deepEqual(
    legalMoves(state, 0, 1).find((move) => move.kind === "enter_home"),
    { marble: 0, dest: locHome(0), kind: "enter_home", captures: null },
  );

  state.marbles[0] = [locHome(0), locHome(1), locHome(2), locHome(3)];
  assert.equal(playerWon(state, 0), true);
});
