# Chess Game Example

A full-stack web-based chess game built with the XTC language, featuring both single-player mode with an intelligent AI opponent and online multiplayer with real-time chat.

## Overview

This project demonstrates a complete web application using the XTC platform:
- **Server**: RESTful API built with XTC web framework and OODB (Object-Oriented Database)
- **Client**: Single-page application with vanilla JavaScript and modern CSS
- **Game Logic**: Complete chess rule implementation including castling and en passant
- **AI Opponent**: Diverse, randomized AI with opening book and heuristic evaluation
- **Online Multiplayer**: Play against others with game codes and real-time chat

### Key Features

- ♟️ **Two Game Modes**: Single-player vs AI or online multiplayer
- 🎮 **Complete Chess Rules**: Full implementation including castling, en passant, and pawn promotion
- 🤖 **Intelligent & Diverse AI**: Randomized move selection with opening book for varied gameplay
- 🌐 **Online Multiplayer**: Create or join games with unique game codes
- 💬 **Real-time Chat**: Modern chat interface for online games
- 💾 **Session Isolation**: Each browser tab has its own independent game
- 🎨 **Modern UI**: Responsive design with smooth animations and gradients
- ⚡ **Real-time Updates**: Auto-refresh during opponent's turn
- ⏱️ **Time Controls**: Optional chess clocks for competitive play

## Prerequisites

- A JDK on your PATH new enough to run Gradle 9 (JDK 17+) — only used to
  bootstrap `./gradlew`. The actual XTC compile toolchain (JDK 25, per
  `gradle/libs.versions.toml`) is auto-downloaded by Gradle via Foojay.
- **XDK** is resolved automatically from Maven repositories.

This project is part of the outer `examples` composite build — see the
top-level [README](../README.md) for full prerequisites and setup.

## Project Structure

`chess-game/` is itself a Gradle composite build that produces two XTC
modules: `chess.xtc` (the `@WebApp` server) and `chessDB.xtc` (the OODB
schema). The `app` subproject depends on `db`.

```
chess-game/
├── build.gradle.kts            # Composite root (lifecycle aggregator)
├── settings.gradle.kts
│
├── app/                        # :app subproject — produces chess.xtc
│   ├── build.gradle.kts
│   ├── src/main/x/
│   │   ├── chess.x             # @WebApp module entry point
│   │   └── chess/
│   │       ├── ai/             # AIMoveSelector, AIOpeningBook, ChessAI, …
│   │       ├── api/            # ChessApi, OnlineChessApi, ChatApi
│   │       ├── config/         # CastlingManager, MoveContext, MoveStrategy
│   │       ├── core/           # ChessGame, ChessLogic, OnlineChessLogic
│   │       ├── services/       # TimeControlService
│   │       ├── utils/          # BoardOperations, BoardUtils, …
│   │       └── validation/     # CheckDetection, MoveValidator, PieceValidator, …
│   ├── src/test/x/             # 16 xunit test modules
│   ├── cli/                    # @TerminalApp REST-API CLI (not yet on a source set)
│   └── webapp/public/          # Static client (HTML / JS / CSS)
│
└── db/                         # :db subproject — produces chessDB.xtc
    ├── build.gradle.kts
    └── src/main/x/
        ├── chessDB.x           # @Database schema entry point
        └── chessDB/
            ├── base/           # Piece base type
            ├── factory/        # PieceFactory
            ├── models/         # CastlingRights, GameRecord, OnlineGame, …
            ├── pieces/         # Bishop, King, Knight, Pawn, Queen, Rook
            └── types/          # PieceType
```

## Quick Start

Build and run from the `examples/` root (one level up):

```bash
# Compile chess.xtc and chessDB.xtc, run all 16 chess test modules
./gradlew :chess-game:build

# Stage all examples (including chess.xtc + chessDB.xtc) into one lib dir
./gradlew installDist
ls build/install/examples/lib/   # → chess.xtc, chessDB.xtc, …
```

`chess.examples.org` is an `@WebApp` and currently requires the XQIZ.IT
platform to be hosted (a standalone `xtc run` of an `@WebApp` is not
supported — `xenia.createServer(...)` from a `void run()` would be needed
to bootstrap one without the platform). Once hosted, the static client
served at `/` provides the UI in a browser.

## Game Modes

### Single Player (vs AI)

Play against an intelligent AI opponent that uses:
- **Opening Book**: Recognizes common chess openings and responds with strong moves
- **Randomized Selection**: Chooses from top-scoring moves for unpredictable gameplay
- **Positional Evaluation**: Uses piece-square tables for strategic positioning
- **Tactical Awareness**: Evaluates captures, checks, and material balance

The AI adds variety by:
- Randomly selecting from multiple strong opening responses
- Choosing from top moves within a score threshold (not always the "best" move)
- Different play styles in opening, middle, and endgame phases

**Session Isolation**: Each browser tab gets its own independent game. You can play multiple games simultaneously in different tabs without interference.

### Online Multiplayer

1. Click the **Online** tab
2. Choose to **Create Game** (generates a unique code) or **Join Game** (enter a code)
3. Share the game code with your opponent
4. Play in real-time with automatic turn synchronization
5. Use the **Chat** feature to communicate during the game

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

1. **Click a square** with your piece (you play as White in single-player)
2. **Click the destination** square where you want to move
3. The move will be validated by the server
4. If legal, the opponent responds (AI instantly picks from good moves, online opponent when they move)
5. Continue playing until the game ends

### Game Controls

- **Reset Game**: Start a new game with fresh board setup
- **Sync**: Manually refresh the game state from the server
- **Info**: View game status and rules
- **Chat**: Open chat panel (online mode)

## API Documentation

The server exposes a RESTful API at `/api`:

### Single Player Endpoints

All single-player endpoints include a session ID for game isolation:

#### Get Game State
```http
GET /api/state/{sessionId}
```

#### Make a Move
```http
POST /api/move/{sessionId}/{from}/{to}
```

#### Reset Game
```http
POST /api/reset/{sessionId}
```

#### Get Valid Moves
```http
GET /api/validmoves/{sessionId}/{square}
```

### Online Multiplayer Endpoints

#### Create Game
```http
POST /api/online/create
```

#### Join Game
```http
POST /api/online/join/{gameCode}?color={white|black}
```

#### Get Online Game State
```http
GET /api/online/state/{gameCode}?playerId={playerId}
```

#### Make Online Move
```http
POST /api/online/move/{gameCode}/{from}/{to}?playerId={playerId}
```

### Chat Endpoints

#### Send Message
```http
POST /api/chat/{gameCode}/send?playerId={playerId}&message={message}
```

#### Get Messages
```http
GET /api/chat/{gameCode}/messages?since={timestamp}
```

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

The AI opponent uses sophisticated move selection:

1. **Opening Book**: Collection of strong opening responses (Sicilian, French, Caro-Kann, etc.)
2. **Piece Values**: Pawn=100, Knight=320, Bishop=330, Rook=500, Queen=900
3. **Piece-Square Tables**: Positional bonuses for optimal piece placement
4. **Mobility**: Bonus for having more available moves
5. **Tactical Evaluation**: Check bonuses, development bonuses, center control
6. **Randomization**: Selects from top moves within 15% of best score for variety

### Session Management

- Single-player games use `sessionStorage` for browser tab isolation
- Each tab generates a unique session ID on first load
- Game state is persisted per-session in the database
- Refreshing the page restores your game; opening a new tab starts fresh

## Development

### Running in Development Mode

Use Gradle's `--continuous` flag to re-run a task whenever source files change:

```bash
./gradlew :chess-game:build --continuous
```

This recompiles the chess modules on every save. (The `chess.examples.org`
@WebApp itself still needs the XQIZ.IT platform to be hosted; `--continuous`
only handles the build/test loop.)

### Building for Production

There is no separate production build profile — the same `./gradlew build`
produces the deployable `chess.xtc` and `chessDB.xtc` modules.

### Project Architecture

The server uses a modular architecture:
- **ChessApi**: Routes HTTP requests to appropriate handlers
- **ChessGame**: Manages game state and coordinates logic
- **ChessAPIClient**: AI move selection via the Stockfish Online API
- **ChessLogic**: Executes moves and updates state
- **PieceValidator**: Validates move legality per piece type
- **CheckDetection**: Determines check, checkmate, and stalemate
- **OnlineChessApi/Logic**: Handles multiplayer game sessions
- **ChatApi**: Real-time chat for online games

## Database

The game uses XTC's OODB (Object-Oriented Database) for state persistence:

- **Compiled module**: `chess-game/db/build/xtc/main/lib/chessDB.xtc`
- **Schema**: Defined in `db/src/main/x/chessDB.x`
- **Storage**:
  - Single-player games in `singlePlayerGames` map (keyed by session ID)
  - Online games in `onlineGames` map (keyed by game code)

The database persists game state across server restarts.

## Troubleshooting

### Port Already in Use

If something is already listening on port 8080:

```bash
lsof -i :8080
kill -9 <PID>
```

### Build Failures

Ensure the JDK on your PATH is new enough to run Gradle 9 (JDK 17+):

```bash
java -version
```

The XTC toolchain itself runs on JDK 25 and is auto-downloaded by Gradle
the first time you build — you do **not** need to install JDK 25 yourself.

If you suspect a stale Gradle cache, clean and rebuild — but run `clean`
on its own (the outer `examples` build aggregator forbids combining it
with other tasks):

```bash
./gradlew clean
./gradlew build
```

### Game State Issues

If the game gets into a bad state:
1. Click **Reset Game** in the UI.
2. Open a new browser tab for a fresh single-player session.
3. Delete the on-disk database directory under the server's working dir
   (search for the `chessDB` jsondb folder created at runtime by the
   hosting platform) and restart the server.

## Learn More

- **XTC Language**: [Link to XTC documentation]
- **Chess Rules**: [Wikipedia - Chess](https://en.wikipedia.org/wiki/Chess)
- **Algebraic Notation**: [Wikipedia - Algebraic notation (chess)](https://en.wikipedia.org/wiki/Algebraic_notation_(chess))
