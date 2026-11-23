# Draughts

A full-stack game of English draughts (checkers) written in XTC (Ecstasy) with a React client. Two
people take turns at the same screen; the server holds the game, enforces every rule and keeps a
daily scoreboard.

It is a port of the [Compator draughts course demo](https://draughts.courses.compator.com/course1/play/),
built the same way as [`chess-game`](../chess-game) — same project layout, same web client stack and
look — **without a computer opponent**: every move is made by a person.

## Overview

- **Server** — an XTC `@WebApp` module hosted by the [XQIZ.IT platform](https://github.com/xtclang/platform):
  REST services and a jsondb database.
- **Client** — React with TanStack Query, built with Vite and compiled into the server module. The
  client has no rules of its own: it asks the server which moves are legal and follows the paths
  it is given.
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
│   ├── draughtsDB.x           # database schema (@oodb.Database): games, scores
│   └── draughtsDB/models/     # Color, GameStatus, GameRecord, MoveEntry, ScoreEntry
└── app/
    ├── src/main/x/
    │   ├── draughts.x         # the @WebApp module: Database, static content
    │   └── draughts/
    │       ├── api/           # web services: DraughtsApi (/api), ScoresApi (/api/scores)
    │       └── core/          # DraughtsRules (the rules), DraughtsGame (game state)
    ├── src/test/x/            # xunit suites
    └── webapp/                # React client (Vite)
        └── src/
            ├── lib/           # play state (TanStack Query)
            └── components/    # board, play view, scoreboard
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

## How to Play

1. The first visit asks for two nicknames (Black moves first). Use nicknames, not real names —
   they are saved on the server and shown on the public scoreboard. **New game** asks again.
2. Click a piece, then a highlighted square. When a capture is available the pieces that can
   capture are ringed, and nothing else can move.
3. A multi-jump is chosen square by square: the piece stays where it has got to until the chain
   is finished.
4. Click any move in the score sheet to look at that position; **Back to the game** returns.

## API

Every endpoint is `@HttpsRequired`. `{sessionId}` is a per-browser id kept in `localStorage`; each
session has its own game. A move is the path the piece takes, squares named like chess
(`a8` top-left … `h1` bottom-right) joined by `-`: `c3-d4`, or `c3-e5-g7` for a double jump.

| Method | Path | Purpose |
| --- | --- | --- |
| `GET` | `/api/state/{sessionId}` | the game: board, turn, status, message, history, piece counts |
| `POST` | `/api/new/{sessionId}` | start a new game; body `{ "black": "...", "white": "..." }` |
| `GET` | `/api/moves/{sessionId}` | every legal move for the player to move, as paths |
| `POST` | `/api/move/{sessionId}/{path}` | play a move; an illegal one leaves the game unchanged with a message |
| `GET` | `/api/scores` | today's scoreboard, best first |

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
| `DraughtsApiTest` | `/api` — state, legal moves, turn order, illegal moves, forced captures, session isolation, nicknames, and a finished game reaching the scoreboard |

## Differences from the original

- The Compator page runs its rules in the browser; here the XTC server is the authority.
- There is no computer opponent (no Low/Medium/High), only two players at one screen.
- The scoreboard is kept by the server when a game ends, instead of being posted by the client.
  Old rows are not purged after 90 days.
