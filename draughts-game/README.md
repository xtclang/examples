# Draughts

A full-stack game of English draughts (checkers) written in XTC (Ecstasy) with a React client. Play
the computer at Low, Medium or High strength, a second person at the same screen, or a friend on
their own device in a shared room. The server
holds the game, enforces every rule, chooses the computer's moves and keeps a daily scoreboard.

It is a port of the [Compator draughts course demo](https://draughts.courses.compator.com/course1/play/),
built the same way as [`chess-game`](../chess-game) — same project layout, same web client stack and
look.

## Overview

- **Server** — an XTC `@WebApp` module hosted by the [XQIZ.IT platform](https://github.com/xtclang/platform):
  REST services and a jsondb database.
- **Client** — React with TanStack Query, built with Vite and compiled into the server module. The
  client has no rules of its own: it asks the server which moves are legal and follows the paths
  it is given.
- **Computer opponent** — the computer plays White; you play Black and move first. See
  [The computer](#the-computer).
- **Rooms** — open a room, send the code or an invite link, and play a friend live from your own
  devices. See [Rooms](#rooms).
- **The board** — drawn as a wooden board in a frame, with coordinates on the rails, and layered
  pieces; a king wears a gold crown. The page's own pieces — the header, the dialogs, the favicon — are
  drawn the same way as the pieces on the board.
- **Rules** — English draughts on an 8×8 board, in `DraughtsRules.x`:
  - Black moves first; men move one square diagonally forward, kings move both ways.
  - A capture jumps an adjacent enemy piece onto the empty square beyond it.
  - **Captures are compulsory**, and a capturing piece must keep jumping while it can.
  - A man reaching the far row is crowned, and its move ends there.
  - A player with no legal move loses.
  - House rule (from the original): 40 moves each with no capture and no man moved is a draw.
- **Scoreboard** — when a game ends the server adds each player's result to today's board
  (win 3 points, draw 1). It starts afresh every day (UTC).

## Prerequisites

| Tool | Why |
| --- | --- |
| **JDK** supported by your XDK (21+) | runs the XTC toolchain; set `JAVA_HOME` |
| **XDK** with `xtc` on your `PATH` | compiles, runs and tests the modules |
| **Node.js 18+** and npm | builds the React client |

Gradle (`./gradlew :draughts-game:build`) works too where the XTC Gradle plugin resolves.

## Project Structure

```
draughts-game/
├── scripts/
│   ├── build.sh               # web client + draughtsDB + draughts, into build/xtc/main/lib
│   └── test.sh                # run every test suite, each in a fresh directory
├── db/src/main/x/
│   ├── draughtsDB.x           # database schema (@oodb.Database): games, rooms, scores
│   └── draughtsDB/models/     # Color, GameStatus, GameRecord, MoveEntry, RoomRecord, ScoreEntry
└── app/
    ├── src/main/x/
    │   ├── draughts.x         # the @WebApp module: Database, static content
    │   └── draughts/
    │       ├── api/           # web services: DraughtsApi (/api) — game and scoreboard,
    │       │                  #   OnlineApi (/api/online) — rooms
    │       └── core/          # DraughtsRules (the rules), DraughtsAi (the computer),
    │                          #   DraughtsGame (game state), Scoreboard
    ├── src/test/x/            # xunit suites
    └── webapp/                # React client (Vite)
        └── src/
            ├── lib/           # play and room state (TanStack Query)
            └── components/    # board, pieces, game view, dialogs, room, scoreboard
```

## Quick Start

```bash
scripts/build.sh      # builds the web client and both modules into build/xtc/main/lib
scripts/test.sh       # runs the test suites
```

`draughts.examples.org` is `@WebApp` — it has no standalone server of its own and needs the
XQIZ.IT platform to host it (it supplies the `DraughtsSchema` by injection and serves the
HTTPS endpoints). Deploy `draughtsDB.xtc` and `draughts.xtc` to a running platform instance.

Without a host — e.g. in the tests — `Database` in `draughts.x` opens the `draughtsDB` module over
`jsondb` instead, writing to `data/draughtsDB/` and `build/db/` (both git-ignored).

To work on the client with hot reload, host the backend, then:

```bash
cd app/webapp
npm install
npm run dev           # proxies /api to https://localhost:8090 — see vite.config.js
```

## Rooms

Play a friend from your own devices (`OnlineApi.x`, `/api/online`):

1. On the **Room** page, **Create a room**. You play Black and move first, and get a six-character
   room code and an invite link (`?room=CODE`).
2. Send your friend the code, or **Copy invite link**. Opening the link lands them on the Room page
   with the code filled in; they enter a nickname and **Join**, and play White. Their board is
   turned round so White sits at the bottom.
3. Once both are seated, each browser polls the room for the other's moves, so a move appears
   within a second or two. Only the player whose turn it is can move; the server checks it.
4. **Leave** at any time. Leaving a game in progress forfeits it (the other player wins, and the
   result goes on the scoreboard); closing a room nobody has joined just removes it. When a game
   ends, **Rematch** starts a new one in the same room while both players are still there.

Each player is known by a private id handed out when they create or join, which the browser keeps in
`localStorage` with the room code, so reloading the page returns you to the same seat. The id is
only ever sent to its owner.

### Clocks

A room can be timed. When creating one, pick **No clock**, **3 min**, **5 min**, **10 min**, **5 + 3**
or **10 + 5** (minutes each, plus seconds added after each of your moves).

- Each player has a bank of time that runs down **only on their turn**. Neither clock runs before the
  first move, and the first move costs nothing.
- Each move takes the time it used off the mover's clock and adds the increment.
- A clock turns red in its last 30 seconds. The page counts down between polls, so it moves smoothly,
  and every poll puts it right.
- When a player's time runs out they lose. Nothing ticks on the server: the first request that
  reads the room afterwards (the other player's poll, usually) ends the game, records it on the
  scoreboard once, and says "X ran out of time, so Y wins." A rematch starts the clocks afresh.
- The clocks are wall-clock times kept in the room record (`GameClock.x`, `TimeControl`), not a timer
  belonging to one process, so they survive a server restart. Time controls are clamped to between
  30 seconds and 3 hours, with an increment of up to a minute.

## Sounds

The page makes its own sounds with the Web Audio API — no audio files — in `lib/sound.js`:

| Sound | When |
| --- | --- |
| a soft tick | a piece is picked up |
| a wooden "tok" | a piece is set down, yours or the other player's |
| a sharper double knock | a capture |
| the "tok" and a rising chime | a man is crowned |
| two rising notes | a friend joins your room |
| a short jingle: up, down, or even | you win, you lose, or it is a draw |
| a quick tick, once a second | your own clock is in its last ten seconds |

Moves sound the same whoever made them, so the computer's reply and a friend's move are heard.
Nothing sounds on first load or when a new game replaces the old one. The speaker button in the
header mutes everything, and the choice is remembered. Browsers only allow sound after you have
touched the page, so anything before your first click or tap is silent.

## The computer

`DraughtsAi.x` is a port of the course demo's opponent: **minimax search with alpha-beta pruning**.
It imagines each legal move, the opponent's best reply, its own best reply to that, and so on to a
fixed depth, scores the position at the end of each line (pieces, kings, how far men have
advanced, the centre of the board), and plays the move with the best guaranteed score.

| Level | Looks ahead | Plays a random move |
| --- | --- | --- |
| Low | 2 moves | 35% of the time |
| Medium | 4 moves | 10% of the time |
| High | up to 7 moves | never |

The search runs on the server inside a web request, so it is **iterative**: it searches 1 move
ahead, then 2, and so on up to the level's depth, and plays the best move of the deepest search
that finished inside the level's time budget (Low 1.5 s, Medium 2.5 s, High 4 s). On a fast machine
every level reaches its full depth; on a slow one the computer just plays a little shallower.
Measured on a laptop, Medium answers in well under a second and High in about three or four.

After you move, the server returns the game with `computerToMove: true`; the client then calls
`POST /api/computer/{sessionId}`, so the reply is something you see happen. Nobody can move for the
computer, and it cannot move out of turn.

## API

Every endpoint is `@HttpsRequired`. `{sessionId}` is a per-browser id kept in `localStorage`; each
session has its own game. A move is the path the piece takes, squares named like chess
(`a8` top-left … `h1` bottom-right) joined by `-`: `c3-d4`, or `c3-e5-g7` for a double jump.

| Method | Path | Purpose |
| --- | --- | --- |
| `GET` | `/api/state/{sessionId}` | the game: board, turn, status, message, history, piece counts |
| `POST` | `/api/new/{sessionId}` | start a new game; body `{ "black": "...", "white": "...", "level": "" }` — `level` is `easy`, `medium` or `hard` to play the computer (the second nickname is then ignored), or `""` for two players |
| `GET` | `/api/moves/{sessionId}` | every legal move for the player to move, as paths |
| `POST` | `/api/move/{sessionId}/{path}` | play a move; an illegal one leaves the game unchanged with a message |
| `POST` | `/api/computer/{sessionId}` | the computer plays its move, if it is its turn (otherwise the game comes back unchanged) |
| `GET` | `/api/scores` | today's scoreboard, best first |

Rooms live under `/api/online`. `{playerId}` is the private id from `create` or `join`:

| Method | Path | Purpose |
| --- | --- | --- |
| `POST` | `/api/online/create` | open a room; body `{ "name": "...", "timeControlMs": 0, "incrementMs": 0 }` (0 for no clock); returns the room code and your player id |
| `POST` | `/api/online/join/{roomCode}` | take the second seat; body `{ "name": "..." }` |
| `GET` | `/api/online/state/{roomCode}/{playerId}` | the room: game, your side, whether it is your turn, whether the other player has left, and the clocks (`timed`, `blackMs`, `whiteMs`, `incrementMs`, `clockRunning`) |
| `GET` | `/api/online/moves/{roomCode}/{playerId}` | your legal moves, as paths; none unless it is your turn |
| `POST` | `/api/online/move/{roomCode}/{playerId}/{path}` | play a move |
| `POST` | `/api/online/rematch/{roomCode}/{playerId}` | a new game in the same room, once one has ended |
| `POST` | `/api/online/leave/{roomCode}/{playerId}` | leave; forfeits a game in progress |

Each web service needs its own path on the platform, which is why rooms are not under `/api`.

The board is 8 strings, top row first: `b`/`B` Black man/king, `w`/`W` White man/king, `.` empty.

## Tests

```bash
scripts/test.sh                      # all suites
scripts/test.sh DraughtsRulesTest    # one suite
scripts/test.sh --no-build           # skip recompiling first
```

| Suite | Covers |
| --- | --- |
| `DraughtsRulesTest` | squares, the starting position, steps, compulsory and multiple captures, crowning, kings jumping backwards, losing, the draw rule |
| `DraughtsAiTest` | the levels, how a position is valued, the computer always playing a legal move at every level, taking a compulsory capture, not hanging a piece at High, and a whole game between two computers |
| `DraughtsClockTest` | the clocks' arithmetic: starting times and their limits, running only on the player to move, not before the first move, increments, never below zero, timing out |
| `DraughtsOnlineApiTest` | `/api/online` — creating and joining, a full room, turn order, refusing strangers and out-of-turn moves, legal moves, forfeiting by leaving, closing an empty room, a finished game scoring and offering a rematch, and timed rooms: clocks that start at the first move, and losing on time (scored once, rematch resets the clocks) |
| `DraughtsApiTest` | `/api` — state, legal moves, turn order, illegal moves, forced captures, session isolation, nicknames, playing the computer (its turn, refusing moves for it), and a finished game reaching the scoreboard |

## Differences from the original

- The Compator page runs its rules and its AI in the browser; here the XTC server is the authority
  for both, so a client cannot cheat and every move is checked.
- The computer's search has a time budget (see [The computer](#the-computer)); the original's has
  none. The search also scores positions at its depth limit without listing moves there, which
  makes it several times faster at the cost of noticing a stalemate one move later.
- The scoreboard is kept by the server when a game ends, instead of being posted by the client.
  Old rows are not purged after 90 days.
