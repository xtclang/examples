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

- **Java JDK 11 or higher** - Required to run the Gradle build system and XTC runtime
- **XTC Platform** - The XTC language runtime and libraries (included via Gradle dependencies)

## Project Structure

```
chess-game/
├── build.gradle.kts           # Root project configuration
├── settings.gradle.kts         # Gradle settings and module definitions
├── gradlew / gradlew.bat       # Gradle wrapper scripts
├── server/                     # Backend module
│   ├── build.gradle.kts        # Server build configuration
│   └── chess/main/x/           # XTC source code
│       ├── chess.x             # Main module definition
│       └── chess/
│           ├── ChessApi.x      # REST API endpoints
│           ├── ChessGame.x     # Core game state management
│           ├── ChessLogic.x    # Move execution logic
│           ├── ChessAPIClient.x # AI opponent via Stockfish Online API
│           ├── PieceValidator.x # Move validation
│           ├── CheckDetection.x # Check/checkmate detection
│           ├── BoardUtils.x    # Board utilities
│           ├── ValidMovesHelper.x # Valid move calculation
│           ├── OnlineChessApi.x # Multiplayer API
│           ├── OnlineChessLogic.x # Multiplayer logic
│           ├── ChatApi.x       # Chat functionality
│           └── TimeControlService.x # Chess clock
├── chessDB/main/x/
│   └── chessDB.x               # Database schema
└── webapp/                     # Frontend module
    ├── build.gradle.kts        # Webapp build configuration
    └── public/
        ├── index.html          # Main HTML page
        └── static/
            ├── app.js          # JavaScript application
            └── styles.css      # Modern CSS styling
```

## Quick Start

### 1. Clone the Repository

```bash
cd chess-game
```

### 2. Build the Project

```bash
./gradlew build
```

This will compile the XTC code and prepare all dependencies.

### 3. Run the Server

```bash
./gradlew run
```

### 4. Open the Game

Open your web browser and navigate to:

```
http://localhost:8080
```

You should see the chess board and be ready to play!

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

```bash
./gradlew :server:run --continuous
```

This will automatically rebuild and restart the server when files change.

### Building for Production

```bash
./gradlew build -Pproduction
```

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

- **Database file**: `server/build/chessDB.xtc`
- **Schema**: Defined in `chessDB/main/x/chessDB.x`
- **Storage**: 
  - Single-player games in `singlePlayerGames` map (keyed by session ID)
  - Online games in `onlineGames` map (keyed by game code)

The database automatically persists game state, allowing you to close and restart the server without losing progress.

## Troubleshooting

### Port Already in Use

```bash
# Find the process
lsof -i :8080

# Kill it (replace PID with actual process ID)
kill -9 PID
```

### Build Failures

Ensure you have Java 11+ installed:
```bash
java -version
```

Clear the Gradle cache if needed:
```bash
./gradlew clean build
```

### Game State Issues

If the game gets into a bad state:
1. Click the **Reset Game** button in the UI
2. Open a new browser tab for a fresh game
3. Delete the database file: `rm server/build/chessDB.xtc`
4. Restart the server

## Learn More

- **XTC Language**: [Link to XTC documentation]
- **Chess Rules**: [Wikipedia - Chess](https://en.wikipedia.org/wiki/Chess)
- **Algebraic Notation**: [Wikipedia - Algebraic notation (chess)](https://en.wikipedia.org/wiki/Algebraic_notation_(chess))
