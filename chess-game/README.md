# Chess Playground

A full-stack chess game written in XTC (Ecstasy) with a React client. Play Stockfish, play a
friend over a shared room link, solve the chess.com daily puzzle, or review a chess.com game —
then see how you played and how you think: live engine evaluations, accuracy, mistakes, and a
fitted model of your decision-making, all drawn as interactive charts.

## Contents

- [Overview](#overview)
- [Prerequisites](#prerequisites)
- [Project Structure](#project-structure)
- [Quick Start](#quick-start)
- [Game Modes](#game-modes)
  - [Single Player (vs AI)](#single-player-vs-ai)
  - [Play a Friend (Rooms)](#play-a-friend-rooms)
  - [Daily Puzzle](#daily-puzzle)
  - [Review](#review)
- [How to Play](#how-to-play)
- [API](#api)
  - [Single-Player Endpoints](#single-player-endpoints)
  - [Room Endpoints](#room-endpoints)
  - [Engine and chess.com Endpoints](#engine-and-chesscom-endpoints)
- [Technical Details](#technical-details)
- [Development](#development)
- [Database](#database)
- [Troubleshooting](#troubleshooting)
- [Learn More](#learn-more)

## Overview

- **Server** — an XTC `@WebApp` module hosted by the [XQIZ.IT platform](https://github.com/xtclang/platform):
  REST services, a jsondb database, and proxies for the Stockfish Online engine and chess.com.
- **Client** — React with TanStack Query (live data), TanStack Charts (charts) and TanStack Table
  (the sortable move list), built with Vite and compiled into the server module.
- **Computer opponent** — every move comes from Stockfish Online; nothing picks moves locally.
- **Rooms** — play a friend over a shared link, with an optional clock. See
  [Play a Friend (Rooms)](#play-a-friend-rooms).
- **Daily puzzle** — the chess.com puzzle of the day, playable move by move with right/wrong
  feedback, not just a static diagram. See [Daily Puzzle](#daily-puzzle).
- **Insights** — engine evaluation, win chance, accuracy, centipawn loss, mistake counts, and a
  softmax model of your choices fitted to the moves you play. The in-app **Guide** explains each.

## Prerequisites

| Tool | Why |
| --- | --- |
| **JDK** supported by your XDK (21+) | runs the XTC toolchain; set `JAVA_HOME` |
| **XDK** with `xtc` on your `PATH` | compiles, runs and tests the modules |
| **Node.js 18+** and npm | builds the React client |

Gradle (`./gradlew build`, `./gradlew run`) works too where the XTC Gradle plugin resolves; the
scripts below need only the three tools above.

## Project Structure

`chess-game/` is itself a Gradle composite build that produces two XTC
modules: `chess.xtc` (the `@WebApp` server) and `chessDB.xtc` (the OODB
schema). The `app` subproject depends on `db`. Being `@WebApp`, `chess.xtc`
needs the XQIZ.IT platform to host it — it has no standalone server of its own.

```
chess-game/
├── scripts/
│   ├── build.sh               # web client + chessDB + chess, into build/xtc/main/lib
│   └── test.sh                # run every test suite, each in a fresh directory
├── db/src/main/x/
│   └── chessDB.x              # database schema (@oodb.Database)
└── app/
    ├── src/main/x/
    │   ├── chess.x            # the @WebApp module: Database, static content
    │   └── chess/
    │       ├── api/           # web services: ChessApi, OnlineChessApi,
    │       │                  #   EngineApi (/api/engine), ChessComApi (/api/chesscom)
    │       ├── ai/            # StockfishApi (engine client), ChessAPIClient (computer moves)
    │       ├── core/          # game logic, single-player and online
    │       ├── validation/    # move legality, check detection
    │       └── services/      # time controls
    ├── src/test/x/            # one xunit suite per service, plus the logic suites
    └── webapp/                # React client (Vite)
        └── src/
            ├── lib/           # engine scheduler, local model, insights, play state
            └── components/    # board, charts, insights panel, guide, logo
```

## Quick Start

### Build

```bash
scripts/build.sh
```

This builds the web client and both modules into `build/xtc/main/lib`: `chessDB.xtc` and
`chess.xtc` (with the built web client bundled in as static content).

### Host it

`chess.examples.org` is `@WebApp` — it has no standalone server of its own and needs the
[XQIZ.IT platform](https://github.com/xtclang/platform) to host it (it supplies the `ChessSchema`
by injection and serves the HTTP/HTTPS endpoints). Deploy `chessDB.xtc` and `chess.xtc` to a
running platform instance per its own documentation.

**Files the database writes**, relative to the working directory (both git-ignored):
`data/chessDB/` holds the database and `build/db/` the generated jsondb host module. These are
only used as a fallback when nothing injects a schema (e.g. tests calling a service directly) —
see `Database` in `chess.x`.

### Run the tests

```bash
scripts/test.sh                 # all suites except the live network suite
scripts/test.sh ChessApiTest    # one or more named suites
scripts/test.sh --live          # also ChessLiveApiTest: real Stockfish and chess.com calls
scripts/test.sh --no-build      # skip recompiling first
```

Each suite runs from its own fresh temporary directory, so its database never leaks into another
suite or into the repository. The script prints a table of passed, failed and skipped tests per
suite and exits non-zero on any failure.

| Suite | Covers |
| --- | --- |
| `ChessApiTest` | `/api` — state, legal and illegal moves, valid moves, reset, clocks, session isolation |
| `OnlineChessApiTest` | `/api/online` — rooms, seating, turn order, moves, valid moves, reset, leaving |
| `EngineApiTest` | `/api/engine` — FEN validation before any upstream call, JSON encoding |
| `ChessComApiTest` | `/api/chesscom` — username and date validation before any upstream call |
| `ChessEngineApiTest` | `StockfishApi` — reading engine replies, UCI moves, URL encoding |
| `ChessLiveApiTest` | live: engine analysis, chess.com, and a real computer reply (opt-in) |
| the rest | game logic, validation, board utilities, time controls, the database models |

The live suite needs internet and respects the engine's rate limit (about one request per 1.5
seconds); expect it to take around half a minute. `ChessAIMoveSelectionTest` in the default run
also reaches the engine once, through the computer-move path.

A single suite can also be run by hand from any scratch directory:

```bash
xtc test -L build/xtc/main/lib app/src/test/x/ChessApiTest.x
```

### Work on the web client

With the backend hosted on the XQIZ.IT platform, start Vite with hot reload in another terminal:

```bash
cd app/webapp
npm install
npm run dev
```

Point Vite's dev proxy at wherever the platform is hosting `chess.examples.org`, so the client
talks to the real backend. `npm run build` writes the production client to `app/webapp/build`,
which `chess.x` serves as static content; rebuild the module afterwards (`scripts/build.sh`) to
ship it.

## Game Modes

### Single Player (vs AI)

Every move the computer plays comes from the [Stockfish Online](https://stockfish.online) engine
API, reached through `StockfishApi.x`. Nothing picks the computer's moves locally:

- **Real engine play**: the position is sent as FEN and the engine's `bestmove` is played back
- **Rule check**: the engine's move is validated against this game's simplified rules before it
  is applied, since a full engine can suggest moves the simplified rule set cannot play
- **Offline fallback**: if the engine cannot be reached, a random legal move is played so the
  game never stalls

The same engine is exposed to the web client at `/api/engine/analyse`, which is where the
analysis panel's evaluation graph and centipawn-loss figures come from.

**Session isolation**: each browser tab keeps its own game, under a session id in `localStorage`
(see [Session Management](#session-management)). Multiple tabs play independent games.

### Play a Friend (Rooms)

Two players share a room, identified by a 6-character code (`OnlineChessApi.x`, `/api/online`):

1. On the **Room** tab, **Create room** — optionally with a clock. The creator plays White and
   gets a room code plus an invite link (`?room=CODE`).
2. **Copy invite link** and send it to a friend. Opening the link lands them directly on the Room
   tab and attempts to join that room — no code to type. A code can also be entered by hand under
   **Join a room**.
3. The second player to join plays Black. Once both are seated, the room's state polls for each
   player's turn — board, clocks, and move history all come from the server, so either side's
   browser is simply a window onto the same `OnlineGame`.
4. Either player can **Leave** at any time, which marks the room as abandoned for the other side.
   When the game ends (checkmate, draw, or time out), **Rematch** resets the same room with both
   players still seated.

A room's seat (its room code and player id) is kept in `localStorage`, the same way a
single-player session is — reloading the page returns you to the same seat in the same room.

### Daily Puzzle

The **daily puzzle** button (on the Review tab) loads chess.com's puzzle of the day and plays it
out move by move, not as a static position: attempt the solving side's move, and the opponent's
reply plays itself after a short pause if it's correct. A wrong attempt is rejected on the spot,
with the board staying put and a prompt to try again. The solution comes from the puzzle's own
PGN (`/api/chesscom/puzzle`), checked entirely in the browser — no server round-trip while
solving. Solving the full sequence shows a "Solved!" state with a button to try it again.

### Review

Load any `chess.com` player's recent games (`/api/chesscom/*`) and step through them move by
move, with the same engine-evaluation and accuracy panel used in single-player — useful for
seeing how a finished game actually went, move by move, with the engine's own read on each
position.

## How to Play

### Game Rules

This implementation includes **complete chess rules**:

- ✅ **Standard piece movement**: All pieces move according to official chess rules
- ✅ **Castling**: Both kingside (O-O) and queenside (O-O-O) castling
- ✅ **En passant**: Special pawn capture available for one move after double pawn push
- ✅ **Pawn promotion**: Pawns promote to Queen when reaching the opposite end
- ✅ **Check detection**: Illegal to move into check or leave king in check
- ✅ **Checkmate**: Game ends when king is in check with no escape
- ✅ **Stalemate**: Game ends in draw when no legal moves but not in check

### Making Moves

1. **Click a square** with your piece (you play as White in single-player and as the room's
   creator; Black otherwise)
2. **Click a highlighted destination** square to move there
3. The server validates and applies the move
4. The opponent responds — the computer after a short pause, a room opponent whenever they move
5. Continue playing until the game ends

### Game Controls

- **Game** menu (single-player): pick a time control and start a **New game**
- **Leave** / **Rematch** (rooms): leave the room, or reset it with both players still seated
- **Insights** panel: collapse or reopen the engine-evaluation and accuracy panel beside the board

## API

### Single-Player Endpoints

`ChessApi.x`, under `/api`. Every endpoint includes the browser's session id for game isolation.

| Method | Path | Does |
| --- | --- | --- |
| GET | `/api/state/{sessionId}` | Current state of this session's game |
| POST | `/api/move/{sessionId}/{from}/{target}` | Play a move, e.g. `e2`/`e4` |
| POST | `/api/reset/{sessionId}` | Start a new game; JSON body `{timeControlMs, incrementMs}` for a clock |
| GET | `/api/validmoves/{sessionId}/{square}` | Legal destination squares for the piece on `square` |

### Room Endpoints

`OnlineChessApi.x`, under `/api/online`. The room code identifies the game; the player id
(returned by `create`/`join`) identifies which side of it this request is playing.

| Method | Path | Does |
| --- | --- | --- |
| POST | `/api/online/create` | New room; optional JSON body `{timeControlMs, incrementMs}`. Returns `{roomCode, playerId}` |
| POST | `/api/online/join/{roomCode}` | Join as the second player. Returns game state with a `playerId`, or an error message with none |
| GET | `/api/online/state/{roomCode}/{playerId}` | Current state, from this player's point of view |
| POST | `/api/online/move/{roomCode}/{playerId}/{from}/{target}` | Play a move |
| POST | `/api/online/reset/{roomCode}/{playerId}` | Rematch: reset the board, keep both players seated |
| POST | `/api/online/leave/{roomCode}/{playerId}` | Leave the room |
| GET | `/api/online/validmoves/{roomCode}/{playerId}/{square}` | Legal destination squares for the piece on `square` |

### Engine and chess.com Endpoints

| Method | Path | Does |
| --- | --- | --- |
| GET | `/api/engine/analyse?fen=&depth=` | Stockfish Online's evaluation of a position |
| GET | `/api/engine/bestmove?fen=&depth=` | The engine's move for a position |
| GET | `/api/chesscom/player/{username}` | A chess.com player's public profile |
| GET | `/api/chesscom/archives/{username}` | Monthly archive URLs for a player's games |
| GET | `/api/chesscom/games/{username}/{year}/{month}` | One month's games, with PGN |
| GET | `/api/chesscom/puzzle` | chess.com's daily puzzle: title, FEN, PGN solution |

## Technical Details

### Board Representation

The board is stored as a 64-character string in **row-major order** from `a8` to `h1`:

```
Index:  0-7    = Rank 8 (a8-h8) - Black's back rank
Index:  8-15   = Rank 7 (a7-h7) - Black pawns
Index: 16-23   = Rank 6 (a6-h6)
Index: 24-31   = Rank 5 (a5-h5)
Index: 32-39   = Rank 4 (a4-h4)
Index: 40-47   = Rank 3 (a3-h3)
Index: 48-55   = Rank 2 (a2-h2) - White pawns
Index: 56-63   = Rank 1 (a1-h1) - White's back rank
```

### Piece Notation

- **Uppercase** letters (`R`, `N`, `B`, `Q`, `K`, `P`) = White pieces
- **Lowercase** letters (`r`, `n`, `b`, `q`, `k`, `p`) = Black pieces
- **Period** (`.`) = Empty square

### AI Strategy

The computer plays whatever Stockfish Online returns for the position (depth 12), after checking
the move against this game's rules. If the engine cannot be reached, it plays a random legal move
so the game never stalls. See *Single Player (vs AI)* above.

### Session Management

- Each browser keeps one single-player game, under a session id stored in `localStorage`
- Reloading the page, or closing and reopening the browser, returns you to the same game
- Clearing the site's storage starts a fresh session
- Game state is persisted per session in the database

## Development

### Project Architecture

- **ChessApi** (`/api`): single-player games, one per browser session
- **OnlineChessApi** (`/api/online`): rooms for two players
- **EngineApi** (`/api/engine`): the web client's route to Stockfish Online
- **ChessComApi** (`/api/chesscom`): read-only proxy for chess.com's public data
- **StockfishApi**: the engine client; **ChessAPIClient** plays its moves for the computer
- **ChessLogic / ChessGame**: execute moves and update state
- **PieceValidator / CheckDetection**: legality, check, checkmate, stalemate
- **Database** (in `chess.x`): hands each service its own connection — injected by a host when
  there is one, otherwise opened over jsondb in the working directory

The client keeps two kinds of live data in TanStack Query. The game is one query per session,
polled only while the computer is thinking. Engine evaluations are one query per position, cached
for good (in memory and in local storage), and fed through a scheduler that sends one request
per 1.5 seconds, serves the position on the board first, and pauses while the computer chooses
its move so the two never compete for the engine's rate limit.

## Database

The game uses Ecstasy's OODB (Object-Oriented Database) for state persistence:

- **Data**: `data/chessDB/`, relative to the server's working directory
- **Schema**: defined in `db/src/main/x/chessDB.x`
- **Storage**:
  - Single-player games in `singlePlayerGames` map (keyed by session ID)
  - Online games in `onlineGames` map (keyed by game code)

The database persists game state across server restarts.

## Troubleshooting

### Build Failures

Check the toolchain the scripts use:
```bash
java -version      # a JDK your XDK supports
xtc --version      # the XDK is on PATH (or set XTC=/path/to/xtc)
node --version     # 18 or later
```

### Hosting Issues

`chess.examples.org` is `@WebApp` and has no server of its own — connectivity, TLS, and port
issues are a property of the XQIZ.IT platform instance hosting it, not of this module. See the
[platform's docs](https://github.com/xtclang/platform) for deploying and troubleshooting there.

### Game State Issues

If the game gets into a bad state:
1. Start a **New game** under the board
2. Clear the site's storage in the browser for a fresh session
3. On the hosting platform, clear `chessDB`'s persisted data and restart the module

## Learn More

- **Ecstasy Language**: [xtclang.org](https://xtclang.org/)
- **Chess Rules**: [Wikipedia - Chess](https://en.wikipedia.org/wiki/Chess)
- **Algebraic Notation**: [Wikipedia - Algebraic notation (chess)](https://en.wikipedia.org/wiki/Algebraic_notation_(chess))
