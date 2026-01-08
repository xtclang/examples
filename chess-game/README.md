# Chess Game Example

A full-stack web-based chess game built with the XTC language, featuring a turn-based gameplay system with an automated AI opponent.

## Overview

This project demonstrates a complete web application using the XTC platform:
- **Server**: RESTful API built with XTC web framework and OODB (Object-Oriented Database)
- **Client**: Single-page application with vanilla JavaScript and modern CSS
- **Game Logic**: Complete chess rule implementation with simplified mechanics
- **AI Opponent**: Heuristic-based move selection for automated gameplay

### Key Features

- ♟️ **Turn-based Gameplay**: Play as White against an automated Black opponent
- 🎮 **Simplified Chess Rules**: No castling, en passant, or explicit check detection
- 🤖 **AI Opponent**: Smart move selection based on piece values and positional strategy
- 💾 **Persistent State**: Game state saved in OODB database
- 🎨 **Modern UI**: Responsive design with smooth animations
- ⚡ **Real-time Updates**: Auto-refresh during opponent's turn

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
│   ├── main/x/                 # XTC source code
│   │   ├── chess.x             # Main server and API endpoints
│   │   ├── chessDB.x           # Database schema and data models
│   │   └── chessLogic.x        # Chess game logic and move validation
│   └── build/
│       └── chessDB.xtc         # Compiled database file
└── webapp/                     # Frontend module
    ├── build.gradle.kts        # Webapp build configuration
    └── public/
        └── index.html          # Single-page web client
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

### 4. Open the Game

Open your web browser and navigate to:

```
http://localhost:8080
```

You should see the chess board and be ready to play!

## How to Play

### Game Rules

This implementation uses **simplified chess rules**:

- ✅ **Standard piece movement**: Pawns, Knights, Bishops, Rooks, Queens, and Kings move according to traditional rules
- ✅ **Pawn promotion**: Pawns automatically promote to Queens when reaching the opposite end
- ✅ **Capture pieces**: Capture opponent pieces to increase your score
- ❌ **No castling**: Special king-rook move is not implemented
- ❌ **No en passant**: Special pawn capture is not implemented
- ❌ **Simplified game ending**:
  - **Checkmate**: When one player has no pieces left (all captured)
  - **Stalemate**: When only kings remain on the board

### Making Moves

1. **Click a square** with your piece (White pieces)
2. **Click the destination** square where you want to move
3. The move will be validated by the server
4. If legal, the opponent (Black) will automatically respond after a 3-second delay
5. Continue playing until the game ends

### Game Controls

- **Reset Game**: Start a new game with fresh board setup
- **Refresh State**: Manually sync with the server (useful if connection is lost)

## API Documentation

The server exposes a RESTful API at `/api`:

### Get Game State

```http
GET /api/state
```

**Response:**
```json
{
  "board": ["rnbqkbnr", "pppppppp", "........", ...],
  "turn": "White",
  "status": "Ongoing",
  "message": "Your move.",
  "lastMove": "e2e4",
  "playerScore": 0,
  "opponentScore": 0,
  "opponentPending": false
}
```

### Make a Move

```http
POST /api/move/{from}/{to}
```

**Parameters:**
- `from`: Source square in algebraic notation (e.g., `e2`)
- `to`: Destination square in algebraic notation (e.g., `e4`)

**Example:**
```http
POST /api/move/e2/e4
```

### Reset Game

```http
POST /api/reset
```

Resets the game to the initial board position.

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

The automated opponent uses a simple heuristic evaluation function:

1. **Piece Values**: Pawn=1, Knight/Bishop=3, Rook=5, Queen=9, King=100
2. **Position Bonus**: Pieces closer to center score higher
3. **Special Bonuses**:
   - Pawn promotion: +8 points
   - Checkmate: +1000 points

The AI evaluates all legal moves and selects the one with the highest score.

## Development

### Running in Development Mode

The XTC platform supports hot-reloading. After making changes to `.x` files:

```bash
./gradlew :server:run --continuous
```

This will automatically rebuild and restart the server when files change.

### Building for Production

```bash
./gradlew build -Pproduction
```

### Testing

Currently, the project focuses on functional gameplay. To test manually:

1. Start the server
2. Open the web interface
3. Make moves and verify:
   - Legal moves are accepted
   - Illegal moves are rejected with appropriate messages
   - Opponent responds after delay
   - Game state persists across refreshes
   - Scores update correctly

## Database

The game uses XTC's OODB (Object-Oriented Database) for state persistence:

- **Database file**: `server/build/chessDB.xtc`
- **Schema**: Defined in `server/main/x/chessDB.x`
- **Storage**: Games are stored in a map indexed by game ID (currently using ID=1 for single-game support)

The database automatically persists game state, allowing you to close and restart the server without losing your game progress.

## Troubleshooting

### Port Already in Use

If port 8080 is already in use, you can change it by modifying the server configuration or killing the process using that port:

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

If the game gets into a bad state, you can:

1. Click the **Reset Game** button in the UI
2. Delete the database file: `rm server/build/chessDB.xtc`
3. Restart the server

## Contributing

This is an example project demonstrating XTC capabilities. Contributions are welcome!

Potential improvements:
- Add castling and en passant moves
- Implement proper check/checkmate detection
- Add move history and undo functionality
- Support multiple simultaneous games
- Add player authentication
- Implement time controls
- Add game replay feature


## Learn More

- **XTC Language**: [Link to XTC documentation]
- **Chess Rules**: [Wikipedia - Chess](https://en.wikipedia.org/wiki/Chess)
- **Algebraic Notation**: [Wikipedia - Algebraic notation (chess)](https://en.wikipedia.org/wiki/Algebraic_notation_(chess))
