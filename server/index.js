"use strict";

const http = require("node:http");
const crypto = require("node:crypto");
const { WebSocketServer } = require("ws");
const { RoomManager } = require("./rooms");

const PORT = Number(process.env.PORT || 8080);
const manager = new RoomManager();

const server = http.createServer((req, res) => {
  if (req.url === "/healthz") {
    res.writeHead(200, { "content-type": "application/json" });
    res.end(JSON.stringify({ ok: true, rooms: manager.rooms.size }));
    return;
  }

  res.writeHead(200, { "content-type": "text/plain; charset=utf-8" });
  res.end("Wahulo relay server is running.\n");
});

const wss = new WebSocketServer({ server });

wss.on("connection", (ws) => {
  ws.clientId = crypto.randomUUID();

  ws.on("message", (data) => {
    manager.handleMessage(ws, data.toString());
  });

  ws.on("close", () => {
    manager.handleClose(ws);
  });

  ws.on("error", () => {
    manager.handleClose(ws);
  });
});

setInterval(() => {
  manager.purgeExpiredRooms();
}, 60_000).unref();

server.listen(PORT, () => {
  console.log(`Wahulo relay listening on ${PORT}`);
});
