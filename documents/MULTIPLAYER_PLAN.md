# Wahoo Multiplayer & Hosting Plan

This document covers the full plan for taking Wahoo from a local hot-seat game to a publicly hosted web game playable online with friends. It spans backend architecture, Godot client changes, room/lobby design, deployment, and domain setup including a step-by-step domain purchase guide.

## Confirmed Design Decisions

| Decision | Choice |
|----------|--------|
| Game mode structure | Two distinct modes: Play Solo / Host+Join |
| AI seat authority | Host client simulates AI turns and submits moves |
| Spectator mode | Included in v1 |
| In-game chat | Included in v1 |
| Room persistence | In-memory only; rooms lost on server restart (acceptable for v1) |

---

## Game Mode Design

The home screen presents four clear actions:

- **Play Solo** — instant game vs AI; no room code, no network, no waiting
- **Host Game** — creates a room with a short Game ID; host waits for friends, fills empty seats with AI when ready, then starts
- **Join Game** — enter a Game ID to join a waiting room as a player (if seats are open) or spectator
- **Spectate** — enter a Game ID to watch without playing (also reachable through the Join flow if all seats are full)

**Why not a unified "Host Game" for everything?**
Solo play should be completely frictionless: pick AI profiles, play immediately. Multiplayer has inherent latency (sharing the code, waiting for others to connect). Mixing the two flows makes each worse.

**Implication for Godot:** The existing seat-configuration overlay becomes the "Play Solo" path with no changes. A new Lobby scene is added for the multiplayer path. The Game scene is largely shared — the only difference is whether moves come from local tap input or the network.

---

## Architecture Overview

### WebSocket Relay (not WebRTC)

The current development plan called for WebRTC. A **WebSocket relay server** is a better fit for a small hobby game:

| | WebRTC P2P | WebSocket Relay |
|---|---|---|
| NAT traversal | Requires STUN + TURN server | Not needed |
| Connection setup | Complex ICE negotiation | Simple WebSocket connect |
| Move validation | Host only (cheating possible) | Server is authoritative |
| Reconnect handling | Hard — P2P session must be re-established | Server holds state, client re-subscribes |
| Infrastructure | Signaling server + TURN server | One server |
| Debug difficulty | High | Low |

The relay server holds the authoritative game state and relays moves and chat to all connected clients. Clients send moves; the server validates them, applies them, and broadcasts the updated state to everyone including spectators.

### Component Diagram

```
[Browser: Player 1 (Host)]  ──┐
[Browser: Player 2]          ─┤
[Browser: Player 3]          ─┤── WebSocket ──► [Relay Server on Render]
[Browser: Player 4]          ─┤                  - Room management
[Browser: Spectator 1]       ─┤                  - Move validation
[Browser: Spectator 2]       ─┘                  - State broadcast
                                                  - Chat relay

[Static Files: Netlify]
  - index.html, index.pck, index.wasm
  - Served to all browsers at wahoogame.com
```

### Tech Stack

| Component | Technology | Hosting |
|-----------|-----------|---------|
| Game client | Godot 4 HTML5 export (existing) | Netlify free tier |
| Relay server | Node.js + `ws` WebSocket library | Render free tier |
| Custom domain | `wahoogame.com` or similar | Cloudflare Registrar |
| HTTPS / WSS | Automatic via Netlify + Render custom domain | Free |

---

## Game ID Design

**Format:** 6 uppercase characters from a safe alphabet — no vowels (avoids accidental offensive words), no visually confusable characters (0/O, 1/I/L).

Safe alphabet: `BCDFGHJKMNPQRSTVWXYZ23456789` (28 characters)

6-character codes give 28^6 ≈ 481 million combinations — far more than will ever be in use simultaneously.

**Examples:** `J7WKBC`, `MR5TNH`, `8FVKJG`

**Expiry:** Rooms are active while a game is in the lobby or in progress. The server purges rooms 30 minutes after a game ends, or after 2 hours of inactivity in the waiting lobby.

**Deep link sharing:** `wahoogame.com/join/J7WKBC` auto-populates the join code field when a guest navigates to it. This means the host can share a single link in a group chat — guests don't have to manually type the code. Implemented via `JavaScriptBridge.eval()` in Godot to read the URL on load.

---

## Phase 4a — Backend Relay Server

### Goal

A Node.js WebSocket server that:
1. Creates rooms with a unique Game ID on request
2. Accepts player and spectator connections and assigns them to the correct role
3. Relays game state to all connected clients (players + spectators)
4. Validates moves before applying them
5. Relays chat messages between all participants (players + spectators)
6. Handles player disconnect/reconnect

### Project Structure

```
server/
  index.js          — HTTP + WebSocket server entry point
  rooms.js          — Room class: state, seat management, message routing
  wahoo_rules.js    — Move validation (JS port of legal_moves / apply_move)
  package.json
  .render.yaml      — Render deployment config
```

The `server/` directory lives in the existing `wahoo-app` repo (no separate repo needed).

### Room State (Server-Side)

```js
{
  gameId: "J7WKBC",
  status: "waiting" | "playing" | "finished",
  hostClientId: "abc123",
  seats: [
    {
      index: 0,
      type: "human" | "ai" | "empty",
      clientId: "abc123" | null,
      name: "Alex" | null,
      aiProfile: null | "sprinter",
      connected: true | false,
    },
    // x4
  ],
  spectators: [
    { clientId: "xyz789", name: "Sam", connected: true },
    // any number
  ],
  gameState: { /* serialized WahooState — same JSON schema as save/load */ },
  currentPlayer: 0,
  pendingRoll: null | 1..6,
  createdAt: 1748600000000,
}
```

### WebSocket Message Protocol

All messages are JSON objects: `{ "type": "<type>", ...payload }`.

**Client → Server:**

| Message | Payload | Who can send |
|---------|---------|--------------|
| `create_room` | `{ hostName }` | Anyone |
| `join_room` | `{ gameId, playerName }` | Anyone (becomes player if seat available, else spectator) |
| `join_as_spectator` | `{ gameId, spectatorName }` | Anyone (skip seat assignment) |
| `configure_seat` | `{ seat, type, aiProfile }` | Host only |
| `start_game` | `{}` | Host only |
| `roll_request` | `{}` | Current player's client only |
| `submit_move` | `{ marble, dest, kind, captures }` | Current player's client only |
| `chat_message` | `{ text }` | Any connected client (players + spectators) |
| `ping` | `{}` | Any client (keepalive heartbeat every 30s) |

**Server → Client:**

| Message | Payload | When |
|---------|---------|------|
| `room_created` | `{ gameId, seat: 0 }` | Host's room is live |
| `room_joined` | `{ gameId, seat, seats[], spectatorCount }` | Player successfully joined |
| `spectator_joined_ok` | `{ gameId, spectatorCount }` | Spectator successfully joined |
| `seat_updated` | `{ seats[], spectatorCount }` | Any seat or spectator count change |
| `join_error` | `{ code, message }` | Room not found, game already started, etc. |
| `game_started` | `{ gameState, currentPlayer }` | Host started the game |
| `roll_result` | `{ player, roll, legalMoves[] }` | Die rolled; sent to all clients |
| `state_update` | `{ gameState, currentPlayer, lastMove }` | After any move is applied |
| `game_over` | `{ winner, winnerName, finalState }` | A player won |
| `chat_received` | `{ text, senderName, senderType: "player"\|"spectator", seatIndex: int\|null }` | After any chat message; broadcast to all in room |
| `spectator_count` | `{ count }` | When spectator list changes (join/leave) |
| `player_disconnected` | `{ seat, name }` | A player client dropped |
| `player_reconnected` | `{ seat, name }` | A player client came back |
| `error` | `{ code, message }` | Catchall error |

### Move Validation

The server needs a JS port of `legal_moves()` and `apply_move()` from `wahoo/rules.py`. The rules are ~200 lines of straightforward logic — a mechanical JS translation is the right approach. The server:

1. Receives `submit_move` from a client
2. Verifies the sender is the current player (rejects if not)
3. Calls `legalMoves(currentState, currentPlayer, pendingRoll)`
4. Checks if the submitted move appears in the legal move list
5. If valid: applies the move, broadcasts `state_update` to all clients in the room (players + spectators)
6. If invalid: sends `error { code: "ILLEGAL_MOVE" }` back to the submitting client only

### AI Seats — Host-Client Approach

When a seat is configured as AI, the **host's Godot client** plays that seat using the existing `WahooAI` GDScript code and submits moves to the server like any other move. The server routes `roll_result` to the host when it is an AI seat's turn.

This avoids porting the full AI engine to JavaScript in Phase 4a. Tradeoff: if the host disconnects, AI turns cannot be played until reconnect. Acceptable for v1.

### Chat Relay

When the server receives a `chat_message`:
1. Validates the text is non-empty and ≤ 140 characters (truncate silently or reject)
2. Looks up the sender's name and type (player or spectator)
3. Broadcasts `chat_received { text, senderName, senderType, seatIndex }` to **all** clients in the room, including spectators

No chat history is stored on the server — messages are fire-and-forget. A client that connects mid-game will not see prior chat history.

### Deployment to Render

1. Push the `server/` directory to the existing GitHub repo
2. Sign up at [render.com](https://render.com) (free account)
3. Dashboard → New → Web Service → connect GitHub repo
4. Set root directory: `server`; Build command: `npm install`; Start command: `node index.js`; Runtime: Node
5. Deploy. Render gives you a URL like `wahoo-relay.onrender.com`
6. Free tier sleeps after 15 minutes of inactivity; first request after sleep takes ~30 seconds to wake. Acceptable for a hobby game. Upgrade to the $7/month Starter tier if the wakeup delay becomes annoying.

---

## Phase 4b — Godot Client: Home Screen, Lobby & Game UI

### Home Screen Scene

A new `HomeScreen.tscn` replaces the current setup overlay as the entry point:

```
┌──────────────────────────────────┐
│            W A H O O             │
│       marble race board game     │
│                                  │
│  ┌──────────────────────────┐   │
│  │        PLAY SOLO         │   │
│  └──────────────────────────┘   │
│                                  │
│  ┌──────────────────────────┐   │
│  │        HOST GAME         │   │
│  └──────────────────────────┘   │
│                                  │
│  ┌──────────────────────────┐   │
│  │      JOIN / SPECTATE     │   │
│  └──────────────────────────┘   │
└──────────────────────────────────┘
```

### Play Solo Flow

Clicking "Play Solo" opens the existing seat-configuration overlay unchanged. The player picks profiles for any AI seats and starts immediately. No network connection is made.

### Host Game Flow

1. Home screen → "Host Game" → prompt: "Your display name:"
2. Client connects to relay server via WebSocket and sends `create_room { hostName }`
3. Server responds with `room_created { gameId, seat: 0 }`
4. Client transitions to the Lobby scene (Host view)

**Host Lobby Layout:**

```
┌────────────────────────────────────────┐
│  Game Code:  J7WKBC                    │
│  [Copy Code]  [Copy Link]              │
│  wahoogame.com/join/J7WKBC             │
│                                        │
│  Seat 1: Alex            (You — Host)  │
│  Seat 2: Jordan                        │
│  Seat 3: [Waiting...]                  │
│  Seat 4: [Waiting...]                  │
│                                        │
│  👁 2 spectators watching              │
│                                        │
│  Fill empty seats before starting:     │
│  Seat 3: ▼ [Sprinter AI  ]            │
│  Seat 4: ▼ [Wait for player]          │
│                                        │
│  ┌──────────────────────────────────┐  │
│  │ Alex: Anyone else joining?       │  │
│  │ Jordan: I'm ready!               │  │
│  │ [Type a message...        ] [→]  │  │
│  └──────────────────────────────────┘  │
│                                        │
│  [        START GAME         ]         │
│   (enabled when all seats filled)      │
└────────────────────────────────────────┘
```

- Seat dropdown options: "Wait for player" | "Random AI" | each named profile (easiest → hardest)
- "START GAME" is enabled only when no seat is set to "Wait for player"
- Game code and shareable link displayed prominently with copy buttons
- Spectator count shown below the seat list
- Chat available in the lobby; spectators can participate

### Join / Spectate Flow

**Via home screen "Join / Spectate" button:**
1. Prompt: "Game code:" and "Your name:"
2. Client sends `join_room { gameId, playerName }` to server
3. If a seat is available → assigned as a player; transitions to Lobby (Guest view)
4. If no seats are available (room full or game started) → server redirects them as a spectator; transitions to Lobby or Game (Spectator view) with a message "No open seats — joining as a spectator"
5. On hard error (room not found, etc.): show error message

**Via deep link `wahoogame.com/join/J7WKBC`:**
1. Godot reads URL path via `JavaScriptBridge.eval("window.location.pathname")`
2. If path matches `/join/<code>`, skip the code field; only prompt for name
3. Same join logic as above

**Explicit spectator entry:**
1. User enters code and name; sees a "Join as Spectator" option (skip seat assignment)
2. Client sends `join_as_spectator { gameId, spectatorName }`
3. If game is in progress: transitions directly to Game scene (Spectator view) with current state
4. If game is in lobby: transitions to Lobby (Spectator view)

**Guest Lobby Layout:**

```
┌────────────────────────────────────────┐
│  Game Code:  J7WKBC                    │
│                                        │
│  Seat 1: Alex            (Host)        │
│  Seat 2: Jordan          (You)         │
│  Seat 3: Sprinter AI                   │
│  Seat 4: [Waiting...]                  │
│                                        │
│  👁 2 spectators watching              │
│                                        │
│  Waiting for host to start the game... │
│                                        │
│  ┌──────────────────────────────────┐  │
│  │ Alex: Anyone else joining?       │  │
│  │ Jordan: I'm ready!               │  │
│  │ [Type a message...        ] [→]  │  │
│  └──────────────────────────────────┘  │
└────────────────────────────────────────┘
```

**Spectator Lobby Layout:** Same as Guest view but "You" label replaced with "👁 Watching" and no seat-related controls.

### Lobby → Game Transition

1. Host clicks "START GAME" → client sends `start_game` to server
2. Server initializes game state, sends `game_started { gameState, currentPlayer }` to all clients (players + spectators)
3. All clients transition from Lobby scene to Game scene simultaneously
4. The Game scene runs from that point, with moves traveling through the server

### In-Game Chat UI

Chat is visible in both the lobby and the game. In the Game scene, it lives at the bottom of the right-side panel, below the existing controls:

```
┌──────────────────────────────┐
│ GameMenuButton               │
│ [Spacer]                     │
│ Status log                   │
│ DieFrame / DieLabel          │
│ TurnLabel                    │
│ RollButton                   │
│ EndTurnButton                │
├──────────────────────────────┤
│ ┌────────────────────────┐   │
│ │ Jordan: Nice move!     │   │
│ │ 👁 Sam: go Alex!       │   │
│ │ [Type...       ]  [→]  │   │
│ └────────────────────────┘   │
└──────────────────────────────┘
```

- Chat log shows the last ~5 messages; scrollable if needed
- Spectator messages prefixed with 👁 to distinguish them from player messages
- Send on Enter key or the [→] button
- 140-character limit enforced client-side (character counter optional)
- Chat is hidden in solo play (no network = no chat)

### Spectator View in the Game Scene

Spectators see the full board and side panel but with these differences:
- Roll button and End Turn button are hidden (or replaced with a "Spectating" label)
- Marble taps are ignored (no move submission)
- Chat is visible and they can send messages (prefixed with 👁)
- A "Spectating" indicator appears in the TurnLabel area when it is not the spectator's turn (always)
- Spectator count shown somewhere in the panel (e.g., "👁 3 watching")

---

## Phase 4c — Online Game Flow

### Turn Structure (Server-Driven)

The server tracks `currentPlayer` and `pendingRoll`. The sequence for each turn:

1. Server sends the current turn context to all clients; the current player's Roll button enables; others see "Waiting for [Name] to roll..."
2. Current player (or host for AI seats) clicks Roll → sends `roll_request` to server
3. Server rolls the die, computes legal moves, broadcasts `roll_result { player, roll, legalMoves[] }` to **all clients including spectators**
4. Current player's marble tap input enables; all other clients see the die result and a status message
5. Current player taps a marble → sends `submit_move` to server
6. Server validates, applies move, broadcasts `state_update` to all (players + spectators)
7. All clients update their board from the `state_update` (clients never apply moves locally)
8. If win: server broadcasts `game_over`; otherwise server advances `currentPlayer` and starts next turn

Spectators receive all broadcasts (roll_result, state_update, game_over) and update their displayed board accordingly. They have no interactive controls for the game.

### AI Seat Turns

When `currentPlayer` is an AI seat, the server flags this in its broadcast. The host client:
1. Receives `roll_result { player: <ai_seat>, roll, legalMoves[], isAI: true }`
2. Calls `WahooAI.choose_move()` locally (same as hot-seat mode)
3. After the standard AI delay (so spectators and guests can follow the action), sends `submit_move`
4. All clients (players + spectators) see the resulting `state_update`

### Disconnect Handling

**Player disconnects mid-game:**
1. Server marks seat `connected: false`, broadcasts `player_disconnected { seat, name }` to all
2. Game pauses; all clients show: "[Name] disconnected. Waiting for reconnect (60s)..."
3. If player reconnects within 60 seconds: server sends current `gameState`, broadcasts `player_reconnected`, game resumes
4. If timeout: host is prompted — convert seat to AI, or end the game

**Host disconnects:**
- Same handling; a remaining connected player is promoted to host
- AI seat management passes to the new host client

**Spectator disconnects:**
- Server removes from spectator list, broadcasts updated `spectator_count`
- No effect on game state; no pause

**Lobby disconnect (player):**
- Seat opens back up; server broadcasts `seat_updated` to remaining lobby members

### State Synchronization

The server is the single source of truth. **Clients never apply moves to their local game state directly.** Every state change originates from a `state_update` broadcast from the server. This applies equally to players and spectators.

The full `WahooState` is included in every `state_update`. For a 4-player marble game the serialized state is under 1 KB — broadcasting the full state every turn is simpler than delta-patching and eliminates desync risk.

---

## Phase 4d — Domain Purchase & Public Deployment

### Domain Name Suggestions

Before purchasing, search availability at [porkbun.com](https://porkbun.com) or [cloudflare.com/products/registrar](https://cloudflare.com/products/registrar). Do not buy until you find one that's available and you like it.

Candidates (short, memorable, mobile-friendly):
- `wahoogame.com` — direct; check availability first
- `playwahoo.com` — verb-first, clear intent
- `wahooboard.com` — references the board game
- `wahoo.gg` — `.gg` is the standard gamer TLD; widely recognized; often available when `.com` is not
- `wahoo-game.com` — fallback if bare `wahoogame.com` is taken

The `.gg` TLD costs roughly the same as `.com` and signals "this is a game" without extra explanation.

---

### Domain Purchase Guide (Step by Step)

#### Step 1: Choose a Registrar

**Recommended: Cloudflare Registrar**
- Charges domains at wholesale cost — no markup, no promotional pricing tricks
- Renewal price is the same as the first-year price (unusual in the industry)
- Free WHOIS privacy included (hides your personal information from public lookup)
- DNS management built into Cloudflare, which you'll want for the CDN/proxy
- URL: cloudflare.com → Products → Domain Registration

**Alternative: Porkbun**
- Similarly clean pricing (~$9–11/year for `.com`)
- Free WHOIS privacy included
- Simple, beginner-friendly interface
- URL: porkbun.com

**Avoid for first purchase:** GoDaddy (aggressive upsells, renewal price hikes), Web.com (same issues).

#### Step 2: Create an Account

Sign up at Cloudflare or Porkbun. Use an email address you check regularly — domain renewal notices go here, and a missed renewal means losing your domain.

#### Step 3: Search and Purchase

1. Use the search bar to check your preferred name (e.g., `wahoogame.com`)
2. If taken, try alternatives from the list above
3. Add to cart
4. **Before confirming, verify:**
   - The renewal price matches the first-year price
   - WHOIS privacy / domain privacy is enabled (checkbox during checkout — free at Cloudflare/Porkbun)
   - Auto-renew is turned on
5. Complete purchase with a credit card
6. **Expected cost:** $9–15/year for `.com`; $8–12/year for `.gg`
7. You'll receive a confirmation email — keep it.

#### Step 4: Understand the DNS Dashboard

After purchase you manage your domain through a DNS dashboard. You'll add records here to point the domain at your hosting services.

DNS record types you'll use:

| Record Type | What it does |
|-------------|-------------|
| `A` | Points domain to an IP address |
| `CNAME` | Points domain to another domain name (e.g., your Netlify URL) |
| `TXT` | Ownership verification — various services ask you to add one |

Changes to DNS records can take 1–60 minutes to propagate globally. Cloudflare's is usually under 5 minutes.

#### Step 5: Set Up Static Hosting for the Game Client (Netlify)

The Godot HTML5 export is a set of static files served from `godot/build/web/`. Netlify hosts these for free and auto-deploys on every GitHub push.

1. Sign up at netlify.com (free)
2. "Add new site" → "Import from Git" → connect GitHub → select `wahoo-app` repo
3. Build settings:
   - Build command: *(leave blank — exported files are already committed)*
   - Publish directory: `godot/build/web`
4. Click Deploy. Netlify gives a URL like `wahoo-abc123.netlify.app`
5. Test: open that URL and confirm the game loads

**Connect your custom domain to Netlify:**
1. Netlify: Site configuration → Domain management → "Add a domain" → type `wahoogame.com`
2. Netlify shows DNS records to add:
   ```
   CNAME  www  →  wahoo-abc123.netlify.app
   A      @    →  75.2.60.5   (Netlify's load balancer IP)
   ```
3. Add those records in your DNS dashboard
4. Wait up to 30 minutes (usually faster on Cloudflare)
5. Netlify automatically provisions HTTPS via Let's Encrypt
6. Navigate to `https://wahoogame.com` — game loads over HTTPS

#### Step 6: Set Up the Relay Server on Render

1. Sign up at render.com (free)
2. Dashboard → New → Web Service → connect GitHub → select `wahoo-app` repo
3. Root Directory: `server`; Build Command: `npm install`; Start Command: `node index.js`; Runtime: Node
4. Deploy. Render gives a URL like `wahoo-relay.onrender.com`
5. Test: open `https://wahoo-relay.onrender.com` — should show a status message

**Connect a subdomain to the relay server:**
1. In your DNS dashboard, add:
   ```
   CNAME  relay  →  wahoo-relay.onrender.com
   ```
2. In Render: your service → Settings → Custom Domains → add `relay.wahoogame.com`
3. Render automatically provisions HTTPS for the custom domain
4. Update the WebSocket URL constant in the Godot client to `wss://relay.wahoogame.com`

#### Step 7: Configure the Godot Client's Server URL

In `godot/scripts/main.gd` (or a new `godot/scripts/network.gd`):

```gdscript
const RELAY_URL = "wss://relay.wahoogame.com"
# During local development, use: "ws://localhost:8080"
```

#### Step 8: Verify the Full Stack

1. Open `https://wahoogame.com` on a computer → game loads
2. Click "Host Game" → connects to relay, shows a 6-character game code
3. On a phone, navigate to `https://wahoogame.com/join/<code>` → joins lobby as a player
4. On a second phone, navigate to the same link → joins as spectator (seat taken)
5. Host starts game; all three clients see the opening roll
6. Players take turns; spectator sees all state updates and can chat

#### Cost Summary

| Item | Cost | Notes |
|------|------|-------|
| `.com` domain | ~$10/year | Cloudflare Registrar or Porkbun |
| `.gg` domain | ~$10/year | Often available when `.com` is not |
| Game client hosting | Free | Netlify free tier: 100 GB bandwidth/month |
| Relay server | Free | Render free tier (sleeps after 15 min inactivity) |
| Relay server (no sleep) | $7/month | Render Starter — eliminates 30s cold-start |
| **Total (free tier)** | **~$10/year** | Just the domain |
| **Total (paid relay)** | **~$94/year** | Domain + no-sleep relay server |

---

## Phase 4e — Polish

Lower-priority items that are not required for v1 launch but worth building soon after:

**URL-based join deep link:** `wahoogame.com/join/J7WKBC` auto-populates the join code when a guest navigates to the URL. Implemented via `JavaScriptBridge.eval("window.location.pathname")` in Godot. Low effort, high shareability value.

**Game recap page:** After a game ends, show a summary screen (winner, total turns, captures per player). Optional: store briefly on the server for a shareable URL.

**Spectator join mid-game:** If a spectator navigates to `wahoogame.com/join/<code>` while a game is already in progress, the server sends the current full state immediately so they can catch up. The lobby handles the in-progress case by routing them directly to the Game scene (Spectator view).
