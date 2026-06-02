"use strict";

const crypto = require("node:crypto");
const {
  NUM_PLAYERS,
  applyMove,
  cloneState,
  legalMoves,
  newGameState,
  playerWon,
  sameMove,
} = require("./wahoo_rules");

const SAFE_ALPHABET = "BCDFGHJKMNPQRSTVWXYZ23456789";
const ROOM_IDLE_MS = 2 * 60 * 60 * 1000;
const ROOM_FINISHED_MS = 30 * 60 * 1000;
const CHAT_LIMIT = 140;

class RoomManager {
  constructor({ now = () => Date.now(), rng = () => Math.random() } = {}) {
    this.rooms = new Map();
    this.clientRooms = new Map();
    this.now = now;
    this.rng = rng;
  }

  createRoom(ws, hostName) {
    const gameId = this.generateGameId();
    const room = new Room(gameId, this.now, this.rng);
    this.rooms.set(gameId, room);
    room.attachHost(ws, cleanName(hostName, "Host"));
    this.clientRooms.set(ws.clientId, gameId);
    room.send(ws, "room_created", { gameId, seat: 0 });
    room.broadcastSeatUpdate();
    return room;
  }

  joinRoom(ws, gameId, playerName, { spectatorOnly = false } = {}) {
    const room = this.rooms.get(String(gameId || "").toUpperCase());
    if (!room) {
      send(ws, "join_error", { code: "ROOM_NOT_FOUND", message: "Room not found." });
      return null;
    }

    const name = cleanName(playerName, spectatorOnly ? "Spectator" : "Player");
    const result = spectatorOnly ? room.attachSpectator(ws, name) : room.attachPlayerOrSpectator(ws, name);
    this.clientRooms.set(ws.clientId, room.gameId);

    if (result.role === "spectator") {
      room.send(ws, "spectator_joined_ok", {
        gameId: room.gameId,
        spectatorCount: room.spectatorCount(),
        status: room.status,
        gameState: room.gameState,
        currentPlayer: room.gameState?.current_player ?? room.currentPlayer,
      });
      room.broadcastSpectatorCount();
    } else {
      room.send(ws, "room_joined", {
        gameId: room.gameId,
        seat: result.seat,
        seats: room.publicSeats(),
        spectatorCount: room.spectatorCount(),
        status: room.status,
        gameState: room.gameState,
        currentPlayer: room.gameState?.current_player ?? room.currentPlayer,
      });
      room.broadcastSeatUpdate();
    }
    return room;
  }

  handleMessage(ws, raw) {
    let message;
    try {
      message = JSON.parse(raw);
    } catch {
      send(ws, "error", { code: "BAD_JSON", message: "Message must be valid JSON." });
      return;
    }

    const type = String(message.type || "");
    if (type === "create_room") {
      this.createRoom(ws, message.hostName);
      return;
    }
    if (type === "join_room") {
      this.joinRoom(ws, message.gameId, message.playerName);
      return;
    }
    if (type === "join_as_spectator") {
      this.joinRoom(ws, message.gameId, message.spectatorName, { spectatorOnly: true });
      return;
    }
    if (type === "ping") {
      send(ws, "pong", {});
      return;
    }

    const room = this.roomForClient(ws);
    if (!room) {
      send(ws, "error", { code: "NOT_IN_ROOM", message: "Join or create a room first." });
      return;
    }

    room.handleClientMessage(ws, message);
  }

  handleClose(ws) {
    const room = this.roomForClient(ws);
    if (!room) {
      return;
    }
    room.detach(ws);
    this.clientRooms.delete(ws.clientId);
  }

  roomForClient(ws) {
    const gameId = this.clientRooms.get(ws.clientId);
    return gameId ? this.rooms.get(gameId) : null;
  }

  purgeExpiredRooms() {
    const now = this.now();
    for (const [gameId, room] of this.rooms.entries()) {
      const maxAge = room.status === "finished" ? ROOM_FINISHED_MS : ROOM_IDLE_MS;
      if (now - room.lastActivityAt > maxAge || !room.hasConnections()) {
        this.rooms.delete(gameId);
      }
    }
  }

  generateGameId() {
    for (let attempt = 0; attempt < 100; attempt += 1) {
      let code = "";
      for (let i = 0; i < 6; i += 1) {
        code += SAFE_ALPHABET[Math.floor(this.rng() * SAFE_ALPHABET.length)];
      }
      if (!this.rooms.has(code)) {
        return code;
      }
    }
    throw new Error("Unable to generate unique room code.");
  }
}

class Room {
  constructor(gameId, now = () => Date.now(), rng = () => Math.random()) {
    this.gameId = gameId;
    this.status = "waiting";
    this.hostClientId = null;
    this.seats = Array.from({ length: NUM_PLAYERS }, (_, index) => ({
      index,
      type: "empty",
      clientId: null,
      name: null,
      aiProfile: null,
      connected: false,
      ws: null,
    }));
    this.spectators = new Map();
    this.gameState = null;
    this.currentPlayer = 0;
    this.pendingRoll = null;
    this.awaitingOpeningRoll = false;
    this.createdAt = now();
    this.lastActivityAt = this.createdAt;
    this.now = now;
    this.rng = rng;
    this.lastRollLegalMoves = [];
  }

  attachHost(ws, hostName) {
    this.hostClientId = ws.clientId;
    this.attachSeat(ws, 0, hostName);
  }

  attachPlayerOrSpectator(ws, name) {
    const reconnectSeat = this.findReconnectSeat(name);
    if (reconnectSeat !== -1) {
      this.attachSeat(ws, reconnectSeat, name);
      this.broadcast("player_reconnected", { seat: reconnectSeat, name });
      return { role: "player", seat: reconnectSeat };
    }

    if (this.status !== "waiting") {
      this.attachSpectator(ws, name);
      return { role: "spectator" };
    }

    const openSeat = this.seats.find((seat) => seat.type === "empty");
    if (!openSeat) {
      this.attachSpectator(ws, name);
      return { role: "spectator" };
    }
    this.attachSeat(ws, openSeat.index, name);
    return { role: "player", seat: openSeat.index };
  }

  attachSpectator(ws, name) {
    this.touch();
    this.spectators.set(ws.clientId, {
      clientId: ws.clientId,
      name,
      connected: true,
      ws,
    });
    return { role: "spectator" };
  }

  attachSeat(ws, seatIndex, name) {
    this.touch();
    const seat = this.seats[seatIndex];
    seat.type = "human";
    seat.clientId = ws.clientId;
    seat.name = name;
    seat.aiProfile = null;
    seat.connected = true;
    seat.ws = ws;
  }

  findReconnectSeat(name) {
    if (this.status === "waiting") {
      return -1;
    }
    return this.seats.findIndex((seat) =>
      seat.type === "human" &&
      !seat.connected &&
      seat.name &&
      seat.name.toLowerCase() === name.toLowerCase()
    );
  }

  handleClientMessage(ws, message) {
    this.touch();
    switch (String(message.type || "")) {
      case "configure_seat":
        this.configureSeat(ws, message);
        break;
      case "start_game":
        this.startGame(ws);
        break;
      case "roll_request":
        this.rollRequest(ws);
        break;
      case "submit_move":
        this.submitMove(ws, message);
        break;
      case "chat_message":
        this.chatMessage(ws, message.text);
        break;
      default:
        this.send(ws, "error", { code: "UNKNOWN_MESSAGE", message: "Unknown message type." });
    }
  }

  configureSeat(ws, message) {
    if (!this.isHost(ws)) {
      this.send(ws, "error", { code: "HOST_ONLY", message: "Only the host can configure seats." });
      return;
    }
    if (this.status !== "waiting") {
      this.send(ws, "error", { code: "GAME_STARTED", message: "Seats cannot be changed after start." });
      return;
    }

    const seatIndex = Number(message.seat);
    if (!Number.isInteger(seatIndex) || seatIndex < 0 || seatIndex >= NUM_PLAYERS || seatIndex === 0) {
      this.send(ws, "error", { code: "BAD_SEAT", message: "Invalid seat." });
      return;
    }

    const seat = this.seats[seatIndex];
    if (seat.type === "human" && seat.connected) {
      this.send(ws, "error", { code: "SEAT_OCCUPIED", message: "Connected player seats cannot be overwritten." });
      return;
    }

    const type = String(message.seatType || "empty");
    if (type === "ai") {
      seat.type = "ai";
      seat.clientId = null;
      seat.name = aiLabel(message.aiProfile);
      seat.aiProfile = cleanKey(message.aiProfile || "random");
      seat.connected = true;
      seat.ws = null;
    } else if (type === "empty") {
      seat.type = "empty";
      seat.clientId = null;
      seat.name = null;
      seat.aiProfile = null;
      seat.connected = false;
      seat.ws = null;
    } else {
      this.send(ws, "error", { code: "BAD_SEAT_TYPE", message: "Seat type must be empty or ai." });
      return;
    }
    this.broadcastSeatUpdate();
  }

  startGame(ws) {
    if (!this.isHost(ws)) {
      this.send(ws, "error", { code: "HOST_ONLY", message: "Only the host can start the game." });
      return;
    }
    if (this.status !== "waiting") {
      this.send(ws, "error", { code: "GAME_STARTED", message: "Game already started." });
      return;
    }
    if (this.seats.some((seat) => seat.type === "empty")) {
      this.send(ws, "error", { code: "EMPTY_SEATS", message: "Fill every seat before starting." });
      return;
    }

    this.status = "playing";
    this.currentPlayer = 0;
    this.pendingRoll = null;
    this.awaitingOpeningRoll = true;
    this.lastRollLegalMoves = [];
    this.gameState = newGameState(this.currentPlayer);
    this.broadcast("game_started", {
      gameState: cloneState(this.gameState),
      currentPlayer: this.currentPlayer,
      awaitingOpeningRoll: true,
      openingRollRounds: [],
      seats: this.publicSeats(),
      spectatorCount: this.spectatorCount(),
    });
  }

  rollDie() {
    return Math.floor(this.rng() * 6) + 1;
  }

  resolveOpeningPlayer() {
    let contenders = [0, 1, 2, 3];
    const rounds = [];
    let safety = 0;

    while (contenders.length > 1) {
      let highest = 0;
      const rolls = contenders.map((player) => {
        const roll = this.rollDie();
        highest = Math.max(highest, roll);
        return { player, roll };
      });
      contenders = rolls.filter((entry) => entry.roll === highest).map((entry) => entry.player);
      rounds.push({
        rolls,
        leaders: [...contenders],
      });

      safety += 1;
      if (safety >= 20 && contenders.length > 1) {
        contenders = [contenders[0]];
      }
    }

    return {
      player: contenders[0],
      rounds,
    };
  }

  rollRequest(ws) {
    if (this.status !== "playing") {
      this.send(ws, "error", { code: "NOT_PLAYING", message: "Game is not in progress." });
      return;
    }

    if (this.awaitingOpeningRoll) {
      if (!this.isHost(ws)) {
        this.send(ws, "error", { code: "HOST_ONLY", message: "Host rolls to determine first player." });
        return;
      }
      const opening = this.resolveOpeningPlayer();
      this.awaitingOpeningRoll = false;
      this.currentPlayer = opening.player;
      this.gameState.current_player = this.currentPlayer;
      this.broadcast("state_update", {
        gameState: cloneState(this.gameState),
        currentPlayer: this.currentPlayer,
        lastMove: null,
        openingResolved: true,
        openingRollRounds: opening.rounds,
      });
      return;
    }

    if (this.pendingRoll !== null) {
      this.send(ws, "error", { code: "ROLL_PENDING", message: "A roll is already pending." });
      return;
    }
    if (!this.canActForCurrentSeat(ws)) {
      this.send(ws, "error", { code: "NOT_YOUR_TURN", message: "It is not your turn." });
      return;
    }

    const player = this.currentPlayer;
    const roll = crypto.randomInt(1, 7);
    const legal = legalMoves(this.gameState, player, roll);
    this.pendingRoll = roll;
    this.gameState.pending_roll = roll;
    this.lastRollLegalMoves = legal.map((move) => ({ ...move, dest: [...move.dest], captures: move.captures ? [...move.captures] : null }));

    this.broadcast("roll_result", {
      player,
      roll,
      legalMoves: this.lastRollLegalMoves,
      isAI: this.seats[player].type === "ai",
    });

    if (legal.length === 0) {
      this.pendingRoll = null;
      this.gameState.pending_roll = null;
      if (roll !== 6) {
        this.advancePlayer();
      }
      this.broadcast("state_update", {
        gameState: cloneState(this.gameState),
        currentPlayer: this.currentPlayer,
        lastMove: null,
        noLegalMoves: true,
      });
    }
  }

  submitMove(ws, message) {
    if (this.status !== "playing") {
      this.send(ws, "error", { code: "NOT_PLAYING", message: "Game is not in progress." });
      return;
    }
    if (this.awaitingOpeningRoll) {
      this.send(ws, "error", { code: "OPENING_PENDING", message: "Determine first player before moving." });
      return;
    }
    if (this.pendingRoll === null) {
      this.send(ws, "error", { code: "NO_PENDING_ROLL", message: "Roll before moving." });
      return;
    }
    if (!this.canActForCurrentSeat(ws)) {
      this.send(ws, "error", { code: "NOT_YOUR_TURN", message: "It is not your turn." });
      return;
    }

    const submitted = {
      marble: message.marble,
      dest: message.dest,
      kind: message.kind,
      captures: message.captures ?? null,
    };
    const valid = this.lastRollLegalMoves.find((move) => sameMove(move, submitted));
    if (!valid) {
      this.send(ws, "error", { code: "ILLEGAL_MOVE", message: "That move is not legal." });
      return;
    }

    const player = this.currentPlayer;
    const roll = this.pendingRoll;
    this.gameState.current_player = player;
    applyMove(this.gameState, valid);
    this.pendingRoll = null;
    this.gameState.pending_roll = null;
    this.lastRollLegalMoves = [];

    if (playerWon(this.gameState, player)) {
      this.status = "finished";
      this.broadcast("game_over", {
        winner: player,
        winnerName: this.seats[player].name,
        finalState: cloneState(this.gameState),
      });
      return;
    }

    if (roll !== 6) {
      this.advancePlayer();
    }

    this.broadcast("state_update", {
      gameState: cloneState(this.gameState),
      currentPlayer: this.currentPlayer,
      lastMove: valid,
    });
  }

  chatMessage(ws, text) {
    const trimmed = String(text || "").trim();
    if (!trimmed) {
      return;
    }
    const sender = this.senderInfo(ws);
    this.broadcast("chat_received", {
      text: trimmed.slice(0, CHAT_LIMIT),
      senderName: sender.name,
      senderType: sender.type,
      seatIndex: sender.seatIndex,
    });
  }

  detach(ws) {
    const seat = this.seats.find((candidate) => candidate.clientId === ws.clientId);
    if (seat) {
      seat.connected = false;
      seat.ws = null;
      if (this.status === "waiting") {
        seat.type = "empty";
        seat.clientId = null;
        seat.name = null;
        this.broadcastSeatUpdate();
      } else {
        this.broadcast("player_disconnected", { seat: seat.index, name: seat.name });
        this.promoteHostIfNeeded();
      }
      return;
    }

    if (this.spectators.delete(ws.clientId)) {
      this.broadcastSpectatorCount();
    }
  }

  promoteHostIfNeeded() {
    if (this.seats.some((seat) => seat.clientId === this.hostClientId && seat.connected)) {
      return;
    }
    const nextHost = this.seats.find((seat) => seat.type === "human" && seat.connected);
    this.hostClientId = nextHost ? nextHost.clientId : this.hostClientId;
  }

  advancePlayer() {
    this.currentPlayer = (this.currentPlayer + 1) % NUM_PLAYERS;
    this.gameState.current_player = this.currentPlayer;
  }

  canActForCurrentSeat(ws) {
    const seat = this.seats[this.currentPlayer];
    if (seat.type === "human") {
      return seat.clientId === ws.clientId && seat.connected;
    }
    return seat.type === "ai" && this.isHost(ws);
  }

  isHost(ws) {
    return this.hostClientId === ws.clientId;
  }

  senderInfo(ws) {
    const seat = this.seats.find((candidate) => candidate.clientId === ws.clientId);
    if (seat) {
      return { type: "player", name: seat.name, seatIndex: seat.index };
    }
    const spectator = this.spectators.get(ws.clientId);
    return {
      type: "spectator",
      name: spectator?.name || "Spectator",
      seatIndex: null,
    };
  }

  publicSeats() {
    return this.seats.map(({ index, type, clientId, name, aiProfile, connected }) => ({
      index,
      type,
      clientId,
      name,
      aiProfile,
      connected,
    }));
  }

  spectatorCount() {
    return [...this.spectators.values()].filter((spectator) => spectator.connected).length;
  }

  hasConnections() {
    return this.seats.some((seat) => seat.connected) || this.spectatorCount() > 0;
  }

  broadcastSeatUpdate() {
    this.broadcast("seat_updated", {
      seats: this.publicSeats(),
      spectatorCount: this.spectatorCount(),
    });
  }

  broadcastSpectatorCount() {
    const count = this.spectatorCount();
    this.broadcast("spectator_count", { count });
    this.broadcastSeatUpdate();
  }

  broadcast(type, payload) {
    for (const seat of this.seats) {
      if (seat.connected && seat.ws) {
        this.send(seat.ws, type, payload);
      }
    }
    for (const spectator of this.spectators.values()) {
      if (spectator.connected && spectator.ws) {
        this.send(spectator.ws, type, payload);
      }
    }
  }

  send(ws, type, payload) {
    send(ws, type, payload);
  }

  touch() {
    this.lastActivityAt = this.now();
  }
}

function send(ws, type, payload) {
  if (!ws || ws.readyState !== 1) {
    return;
  }
  ws.send(JSON.stringify({ type, ...payload }));
}

function cleanName(value, fallback) {
  const name = String(value || "").trim().slice(0, 24);
  return name || fallback;
}

function cleanKey(value) {
  return String(value || "").trim().toLowerCase().replace(/[^a-z0-9_ -]/g, "").slice(0, 32) || "random";
}

function aiLabel(profile) {
  const key = cleanKey(profile);
  return key.replace(/(^|[_ -])([a-z])/g, (_match, sep, char) => `${sep ? " " : ""}${char.toUpperCase()}`).trim() || "AI";
}

module.exports = {
  Room,
  RoomManager,
  SAFE_ALPHABET,
};
