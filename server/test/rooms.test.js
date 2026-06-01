"use strict";

const assert = require("node:assert/strict");
const test = require("node:test");
const { RoomManager } = require("../rooms");
const { locTrack } = require("../wahoo_rules");

function fakeClient(id) {
  return {
    clientId: id,
    readyState: 1,
    messages: [],
    send(raw) {
      this.messages.push(JSON.parse(raw));
    },
  };
}

test("create, join, configure AI seats, and start a room", () => {
  const manager = new RoomManager({ rng: () => 0 });
  const host = fakeClient("host");
  const guest = fakeClient("guest");

  const room = manager.createRoom(host, "Alex");
  manager.joinRoom(guest, room.gameId, "Jordan");
  room.configureSeat(host, { seat: 2, seatType: "ai", aiProfile: "sprinter" });
  room.configureSeat(host, { seat: 3, seatType: "ai", aiProfile: "random" });
  room.startGame(host);

  assert.equal(room.status, "playing");
  assert.equal(room.seats[0].name, "Alex");
  assert.equal(room.seats[1].name, "Jordan");
  assert.equal(room.seats[2].type, "ai");
  assert.equal(host.messages.some((message) => message.type === "game_started"), true);
  assert.equal(guest.messages.some((message) => message.type === "game_started"), true);
});

test("spectators receive chat but cannot roll", () => {
  const manager = new RoomManager({ rng: () => 0 });
  const host = fakeClient("host");
  const spectator = fakeClient("spec");

  const room = manager.createRoom(host, "Alex");
  manager.joinRoom(spectator, room.gameId, "Sam", { spectatorOnly: true });

  room.chatMessage(spectator, "hello table");
  assert.equal(host.messages.at(-1).type, "chat_received");
  assert.equal(host.messages.at(-1).senderType, "spectator");

  room.startGame(spectator);
  assert.equal(spectator.messages.at(-1).code, "HOST_ONLY");
});

test("configure_seat routes correctly through handleClientMessage", () => {
  const manager = new RoomManager({ rng: () => 0 });
  const host = fakeClient("host");
  manager.createRoom(host, "Alex");
  const room = manager.roomForClient(host);

  manager.handleMessage(host, JSON.stringify({ type: "configure_seat", seat: 1, seatType: "ai", aiProfile: "sprinter" }));
  assert.equal(room.seats[1].type, "ai");
  assert.equal(room.seats[1].aiProfile, "sprinter");

  manager.handleMessage(host, JSON.stringify({ type: "configure_seat", seat: 1, seatType: "empty" }));
  assert.equal(room.seats[1].type, "empty");
});

test("submitted moves must match legal moves", () => {
  const manager = new RoomManager({ rng: () => 0 });
  const host = fakeClient("host");
  const room = manager.createRoom(host, "Alex");
  room.configureSeat(host, { seat: 1, seatType: "ai", aiProfile: "random" });
  room.configureSeat(host, { seat: 2, seatType: "ai", aiProfile: "random" });
  room.configureSeat(host, { seat: 3, seatType: "ai", aiProfile: "random" });
  room.startGame(host);

  room.pendingRoll = 1;
  room.gameState.pending_roll = 1;
  room.lastRollLegalMoves = [
    { marble: 0, dest: locTrack(0), kind: "exit_base", captures: null },
  ];
  room.submitMove(host, { marble: 1, dest: locTrack(0), kind: "exit_base", captures: null });
  assert.equal(host.messages.at(-1).code, "ILLEGAL_MOVE");

  room.submitMove(host, { marble: 0, dest: locTrack(0), kind: "exit_base", captures: null });
  assert.deepEqual(room.gameState.marbles[0][0], locTrack(0));
});
