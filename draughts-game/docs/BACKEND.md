# Draughts backend

How the server side of `draughts-game` works: the modules, the data, the rules engine, the computer opponent, rooms and clocks, scoreboards, and every HTTP endpoint. It is written for someone who has to change or operate the backend.

Everything here is in XTC/Ecstasy. The React client (`app/webapp`) is covered only where it shapes the API.

---

## 1. The big picture

```
 browser (React)
     │  HTTPS + JSON
     ▼
 ┌──────────────────────── draughts.examples.org (@WebApp) ────────────────────────┐
 │                                                                                  │
 │  Home (@StaticContent "/")      serves the built client                          │
 │                                                                                  │
 │  DraughtsApi  /api          single-player + per-session scoreboard               │
 │  OnlineApi    /api/online   rooms, clocks, per-room scoreboard                   │
 │        │                                                                         │
 │        ▼  (no HTTP knowledge below this line)                                    │
 │  DraughtsGame   start games, apply a move to a GameRecord                        │
 │  DraughtsAi     minimax + alpha-beta, iterative deepening                        │
 │  DraughtsRules  legal moves, applying moves, win/draw detection                  │
 │  GameClock      clock arithmetic        Scoreboard   tallies, reset              │
 │                                                                                  │
 │  Database (service)   gets a DraughtsSchema: injected by the host, or jsondb     │
 └───────────────────────────────────────┬──────────────────────────────────────────┘
                                         ▼
                          draughtsDB.examples.org (@oodb.Database)
                          games · rooms · scores   (DBMap each)
```

Two Ecstasy modules are built and deployed together:

| Module | Source | Role |
|---|---|---|
| `draughtsDB.examples.org` | `db/src/main/x/draughtsDB.x` + `draughtsDB/models/*.x` | The schema and the immutable record types |
| `draughts.examples.org` | `app/src/main/x/draughts.x` + `draughts/{api,core}/*.x` | The web app. It imports the DB module as the package `db` |

The layering is deliberate. `core/*` knows nothing about HTTP or transactions, so it is unit-tested directly. `api/*` owns transactions, request parsing and response shapes, and calls into `core`.

**The platform allows only one web service per path.** That is why single-player and its scoreboard share `DraughtsApi` at `/api`, and rooms live in a separate service at `/api/online`. Registering a second service on `/api` fails at container creation with `path "/api" is already in use`.

---

## 2. Data model (`db/`)

All record types are immutable `const` classes. A "change" builds a new record and `put`s it over the old one. Nothing is mutated in place.

### 2.1 Schema

```ecstasy
interface DraughtsSchema extends oodb.RootSchema {
    @RO oodb.DBMap<String, GameRecord> games;   // key: browser session id
    @RO oodb.DBMap<String, RoomRecord> rooms;   // key: room code
    @RO oodb.DBMap<String, ScoreEntry> scores;  // key: "{scope}|{nickname}"
}
```

All access happens inside `using (schema.createTransaction()) { ... }`.

### 2.2 Records

**`GameRecord`**: one game.

| Field | Meaning |
|---|---|
| `board` | 64-char string, row-major, row 0 on top (see 3.1) |
| `turn` | `Color`: whose move it is. Black moves first |
| `status` | `Ongoing`, `BlackWins`, `WhiteWins`, `Draw` |
| `blackName`, `whiteName` | Nicknames, cleaned (trimmed, max 20 chars) |
| `quietPlies` | Half-moves since the last capture or man move (draw counter) |
| `lastMove` | Path of the last move, e.g. `c3-e5`; `Null` before the first |
| `history` | `MoveEntry[]`, every move so far |
| `level` | `""` = two humans; `easy`/`medium`/`hard` = White is the computer |

**`MoveEntry`**: `moveNumber`, `color`, `path`, `captures`, `crowned`, `notation` (`c3-d4` or `c3xe5xg7`) and `boardAfter` (the full board after the move, so the client can step back through a game).

**`RoomRecord`**: a room.

| Field | Meaning |
|---|---|
| `code` | 6 chars from `ABCDEFGHJKLMNPQRSTUVWXYZ23456789` (no `I`, `O`, `0`, `1`) |
| `game` | The `GameRecord` being played |
| `blackId` | Creator's private player id |
| `whiteId` | Joiner's id, `Null` while waiting |
| `leftId` | Id of a player who left, or `Null` |
| `timeControl` | `TimeControl?`: `Null` means an untimed room |
| `timedOut` | True if the game ended on time (it drives the status text) |

**`TimeControl`**: `initialMs` (kept for rematches), `incrementMs`, `blackMs`, `whiteMs`, `lastMoveTime`. The two bank figures are *as of `lastMoveTime`*. They are not live values. See section 6.

**`ScoreEntry`**: `name`, `played`, `won`, `drawn`, `lost`, with `points = won*3 + drawn`. `record(win, draw)` returns a copy with one more result.

### 2.3 Where each record lives

| Mode | Game stored in | Scoreboard scope |
|---|---|---|
| Single-player / same-screen | `games[sessionId]` | `game:{sessionId}` |
| Room | `rooms[code].game` | `room:{code}` |

---

## 3. The rules engine (`core/DraughtsRules.x`)

Pure functions over a board. No HTTP, no database, no clock.

### 3.1 Board and squares

The board is a 64-character `String`:

```
'.' empty   'b' Black man   'B' Black king   'w' White man   'W' White king
```

Index = `row*8 + col`. **Row 0 is the top of the screen.** Black starts at the bottom (rows 5–7) and moves *up*; White starts at the top (rows 0–2) and moves *down*. Only dark squares, where `(row + col)` is odd, are used.

Squares are named like chess: column `a`–`h`, rank `8` down to `1`. Index 0 is `a8`, index 56 is `a1`. `parseSquare`, `toAlgebraic` and `parsePath` convert between names and indices. `parsePath("c3-e5-g7")` gives the index list, or `[]` if any part isn't a square.

### 3.2 `Move`

```ecstasy
static const Move(Int[] path, Int[] captures)
```

`path` is every square the piece visits, start first and end last. `captures` is the squares of the pieces taken. A multi-jump is **one** `Move` with a long path. `pathText` gives `c3-e5-g7`, which is what goes over the wire. `notation` gives `c3-d4` for a step and `c3xe5xg7` for a capture.

### 3.3 The rules as implemented

- Men step one square diagonally forward. Kings go diagonally both ways, one square at a time (English draughts has no flying kings).
- A capture jumps an adjacent enemy onto the empty square beyond.
- **Captures are compulsory.** If any capture exists, `legalMoves` returns *only* captures.
- A capturing piece **must keep jumping**. Every returned capture is a maximal chain, and the chains for a given piece are all returned so the player picks a route.
- A man that reaches the far row mid-chain is crowned and **the move ends there**.
- Captured pieces leave the board as they are jumped. A piece can't be jumped twice in one chain, and the starting square can be landed on again.
- A player with **no legal move loses**.
- **Draw:** `DRAW_LIMIT = 80` half-moves (40 each) with no capture and no man moved.

### 3.4 Move generation

`legalMoves(Char[] board, Color turn)`:

1. For each of the mover's pieces, `captureSequences` explores jumps recursively.
2. It makes each jump **in place** on the `Char[]` (lift the piece, remove the victim, drop the piece), recurses, then **undoes** it. The board is restored before returning.
3. Plain steps are only generated while no capture has been found.
4. Result arrays are allocated lazily, only when something is found.

This is deliberately allocation-light because the AI calls it millions of times. The `String` overload copies into a fresh `Char[]` first, so callers holding a string don't have to care.

Other entry points:

| Function | Purpose |
|---|---|
| `findMove(board, turn, path)` | The legal move with exactly this path, if any. This is how client input is validated |
| `applyMove(board, move)` | New board plus a `crowned` flag. Never mutates the input |
| `countPieces(board, color)` | Men and kings |
| `statusOf(board, turn, quietPlies)` | `Draw` at the limit; the mover loses if they have no moves; otherwise `Ongoing` |

---

## 4. Game lifecycle (`core/DraughtsGame.x`)

Turns rules into stored game state.

- **`newGame(black, white, level)`**: the starting board, Black to move. A recognised `level` makes White "Computer (Low|Medium|High)" and ignores the supplied white name. An unrecognised non-empty level is treated as `medium`.
- **`cleanName`**: trim, cap at 20 characters, fall back to `Black`/`White`.
- **`computerToMove(game)`**: true when `level` is set, the game is `Ongoing` and it's White's turn. The human is always Black.
- **`applyMove(game, path)`**: refuses if the game is over or it's the computer's turn. Otherwise it calls `play`.
- **`applyComputerMove(game, random)`**: refuses unless it really is the computer's turn. It asks `DraughtsAi.chooseMove` and then calls `play`.
- **`play`** (private) is the one place a move is applied:
  1. `parsePath`. Fewer than 2 squares gives "Invalid square format".
  2. `findMove`. A miss gives "Illegal move", or "Illegal move: you must capture." if a capture was available.
  3. `applyMove` for the new board and the crowned flag.
  4. **Draw counter:** `quietPlies` resets to 0 if the move captured or moved a *man*, otherwise it increments.
  5. `statusOf` for the next player.
  6. Append a `MoveEntry`, build a new `GameRecord`.

Every method returns `MoveOutcome(ok, record, message)`. On refusal `record` is the game *unchanged*, so the API can always send back a valid state.

`winnerOf(status)` gives the winning `Color`, or `Null` for a draw. `boardRows` splits the 64-char board into 8 row strings for the client.

---

## 5. The computer (`core/DraughtsAi.x`)

Minimax with alpha-beta pruning, run **on the server inside a request**, so it must be time-bounded.

### 5.1 Levels

| Level | Label | Depth | Random move chance | Time budget |
|---|---|---|---|---|
| `easy` | Low | 2 | 35% | 1.5 s |
| `medium` | Medium | 4 | 10% | 2.5 s |
| `hard` | High | 7 | 0% | 4 s |

Measured on the dev machine, High takes about 3–4 s per move and Medium 0.3–0.7 s.

### 5.2 Algorithm

`chooseMove(board, turn, level, random)`:

1. Generate legal moves. None gives `False`. Exactly one is returned immediately.
2. With the level's `randomPercent` probability, return a random legal move. This is the "distracted human" effect.
3. **Iterative deepening:** search depth 1, then 2, up to the level's depth. A *finished* depth replaces the previous answer. A depth that hits the deadline is **discarded** (`ABORT`) and the last finished answer is used. A slow machine therefore plays shallower rather than late.
4. Each finished depth reorders the moves so the best are tried first next time, which makes pruning far more effective.
5. Ties for best are collected and one is picked at random, for variety.

`minimax` details:

- Leaves (`depth == 0`) are scored immediately with `evaluate`, with no move generation. That is the biggest cost saving, and the trade-off is that a stalemate right at the search horizon is noticed one ply late.
- The clock is only read at `depth >= 3`, so shallow nodes pay nothing for deadline checks.
- No legal moves means a loss for that side, scored `±(WIN_SCORE + depth)`, so quicker wins and slower losses are preferred.
- At the root, `bestScore - 1` is passed as alpha so equal-scoring moves aren't pruned away. Scores are integers, so this keeps the tie list complete.

### 5.3 Evaluation

From the mover's point of view: a king is 175; a man is `100 + 3 × advance`, plus 6 for staying on the back row; plus 4 for any piece on the central 4×4. Material difference dominates.

---

## 6. Rooms and clocks

### 6.1 Identity

Rooms are unauthenticated and rely on **capability ids**. `create` and `join` each return a random 16-character `playerId` (lowercase letters and digits). The browser stores it and sends it on every request. The server's `colorOf(room, playerId)` decides who you are: `blackId` is Black, `whiteId` is White, anything else is `Null`. A stranger who knows the room code can still call `state` and see the board (it is not secret), but can't move, rematch, leave or touch the scoreboard. The `playerId` is only ever sent to the player it belongs to, never to the opponent.

Single-player uses the browser-generated `sessionId` the same way, with no further auth.

### 6.2 Room lifecycle

```
create ──► waiting (whiteId = Null) ──join──► playing ──► finished ──rematch──► playing …
                │                                │
              leave (room deleted)             leave ⇒ forfeit (other player wins)
```

- **create:** picks a code not already in `rooms`, creates a game with the creator as Black, and sets clocks if requested.
- **join:** only possible while `whiteId` is `Null`, otherwise "This room is full." Joining rebuilds the `GameRecord` to carry the joiner's name, and keeps the clocks.
- **move:** see 6.4.
- **rematch:** only after the game ended, with both players still seated. It builds a fresh game with the same names, resets clocks to `initialMs` and clears `leftId` and `timedOut`. **The scoreboard is not touched.**
- **leave:** an unjoined room is deleted. Leaving a game in progress **forfeits** it: the opponent is recorded as the winner, and the result goes on the room's scoreboard. The room stays so the other player can read the result.

### 6.3 Clocks (`core/GameClock.x`)

Each player has a bank of time. It only runs on their own turn, and an increment is added after each of their moves.

Rules:

- `start(now, initialMs, incrementMs)` returns `Null` if `initialMs <= 0` (no clock). Otherwise it clamps: initial 30 s to 3 h, increment 0 to 60 s.
- **Clocks don't run until the first move is made**, and not while waiting for an opponent. That is `running = timed && !waiting && ongoing && history nonempty`.
- The first move deducts nothing from its mover, only adds the increment.

**Nothing ticks on the server.** There is no timer thread. The stored `blackMs`/`whiteMs` are values *at `lastMoveTime`*, and the live figure is computed on read:

```
remaining(player) = running && it's their turn
                      ? max(0, storedMs − (now − lastMoveTime))
                      : storedMs
```

Because it is wall-clock time kept in the record rather than process state, **clocks survive a server restart**.

**Lazy settlement.** Since no timer fires, `OnlineApi.settle(code, room)` runs at the start of **every** request that reads a room (`join`, `state`, `moves`, `move`, `rematch`, `leave`, `scores`, `scores/reset`). If the player to move has run out of time it:

1. Marks the game as won by the opponent.
2. Zeroes the loser's bank and sets `timedOut = true`.
3. Writes the room back.
4. Records the result on the room's scoreboard.

The practical consequence is that **a timeout is only recorded when somebody next asks**. Clients poll every 1.5 s, so in a live game that is near-instant. For an abandoned room it happens whenever someone next looks. Note also that `GET` endpoints can therefore write to the database.

### 6.4 `move` in detail

`POST move/{code}/{playerId}/{path}`, in order:

1. Room missing: `notFound`.
2. `settle` (may end the game on time).
3. Caller not seated: "You are not a player in this room."
4. No opponent yet: "Waiting for an opponent to join."
5. Game already over: return state with `success:false` (the message explains how it ended, e.g. on time).
6. Not the caller's turn: "It is not your turn."
7. `DraughtsGame.applyMove`. If refused, return the unchanged state with the reason.
8. Update the clocks with `GameClock.afterMove`, save the room.
9. If that move ended the game, record it on the room's scoreboard.
10. Return `stateFor(updated, playerId)`.

Any exception inside step 7–10 is caught and returned as `"Server error: …"` with the unchanged room.

### 6.5 Sync model

There is no push channel. Clients **poll** `state/{code}/{playerId}` (about every 1.5 s) and compare. Because the server computes `yourTurn`, `waiting`, `opponentLeft` and the clocks, the client holds almost no game logic. A client discovers the opponent's move by seeing a changed `history` or `board`. It then fetches `moves` only when `yourTurn` is true.

---

## 7. Scoreboards (`core/Scoreboard.x`)

A scoreboard belongs to **one match**: one room, or one single-player session. There is no global board.

- Rows are stored in `scores` under the key `"{scope}|{nickname}"`, where scope is `room:{CODE}` or `game:{sessionId}`.
- `record(schema, scope, game)` adds one result per player: win/loss, or a draw for both. It reads the existing row (or a fresh `ScoreEntry`) and writes back `entry.record(...)`.
- `table(schema, scope)` scans keys with the prefix `"{scope}|"` and sorts by **points, then wins, then name**.
- `reset(schema, scope)` collects the matching keys and removes them.
- **`canReset(game)`** is `status != Ongoing || history.empty`. A reset is allowed once the game has ended, or before a game has had a move. It is refused mid-game, because the in-progress game would then sit on a board that has forgotten the earlier games.

Scoring: **win 3, draw 1, loss 0.**

Results are recorded exactly once per game, at the moment it ends: on the deciding move, on the computer's deciding move, on a forfeit, or in `settle` for a timeout. A rematch starts a new game and the tally carries on until someone resets it.

**Limitations to know about:**

- Rows are keyed by *nickname*. If the same room has two players with the same name, they share one row. The client doesn't prevent that.
- `table` and `reset` scan every key in `scores`. That is fine at this scale, but it is O(total rows) per call.
- Old data from before scopes existed (date-keyed rows) is ignored and never cleaned up.

---

## 8. HTTP API

All endpoints are `@HttpsRequired` and `@Produces(Json)`.

**Error convention:** failures return **HTTP 200** with a body saying so, not an HTTP error code.

- Room and score responses carry `success: false` and a `message`.
- Single-player `ApiState` has no `success` field. A refused move returns the *unchanged* state with the reason in `message`. The client detects refusal by the state not changing, or it just shows the message.
- Unknown routes are the platform's 404.

### 8.1 Single-player: `DraughtsApi` at `/api`

`sessionId` is a client-chosen string identifying the browser tab's game.

| Method | Path | Body | Result |
|---|---|---|---|
| GET | `state/{sessionId}` | | `ApiState`. Creates a fresh game if none exists |
| POST | `new/{sessionId}` | `{black?, white?, level?}` | `ApiState`. Replaces any game in progress |
| GET | `moves/{sessionId}` | | `MovesResponse` |
| POST | `move/{sessionId}/{path}` | | `ApiState` |
| POST | `computer/{sessionId}` | | `ApiState`. The computer plays if it is its turn, else unchanged |
| GET | `scores/{sessionId}` | | `ScoreTable` |
| POST | `scores/{sessionId}/reset` | | `ScoreTable` (`success:false` if mid-game) |

**Why `computer` is a separate call.** `move` returns right after the human's move. The client animates it, then calls `computer` and shows the reply. This is why the AI's 0.3–4 s latency never freezes the human's own move. `ApiState.computerToMove` tells the client when to make that call.

`moves` returns `{success:false}` when the game is over or it is the computer's turn.

**`ApiState`**: `board` (8 row strings), `turn`, `status`, `message`, `lastMove`, `blackName`, `whiteName`, `blackPieces`, `whitePieces`, `mustCapture`, `history`, `sessionId`, `level`, `computerToMove`.

**`MovesResponse`**: `{success, error, moves: ["c3-d4", "a3-c5-e5", …]}`. If any capture exists, all entries are captures.

### 8.2 Rooms: `OnlineApi` at `/api/online`

| Method | Path | Body | Notes |
|---|---|---|---|
| POST | `create` | `{name?, timeControlMs?, incrementMs?}` | Creator becomes Black. `timeControlMs` 0 or omitted means no clock |
| POST | `join/{roomCode}` | `{name?}` | Becomes White. A timing in the body is ignored |
| GET | `state/{roomCode}/{playerId}` | | The room as this player sees it |
| GET | `moves/{roomCode}/{playerId}` | | Only non-empty on your turn |
| POST | `move/{roomCode}/{playerId}/{path}` | | |
| POST | `rematch/{roomCode}/{playerId}` | | Only after a game ended, both seated |
| POST | `leave/{roomCode}/{playerId}` | | Forfeits a game in progress |
| GET | `scores/{roomCode}/{playerId}` | | Players only |
| POST | `scores/{roomCode}/{playerId}/reset` | | Players only; only when `canReset` |

**`RoomState`** is the one response shape for everything room-related:

| Field | Meaning |
|---|---|
| `success`, `message` | Whether the request was accepted, and the text to show |
| `roomCode` | The room |
| `playerId` | Echoed back, or `""` if you aren't seated |
| `color` | `"Black"`, `"White"`, or `""` |
| `waiting` | No second player yet |
| `opponentLeft` | The other player has left |
| `yourTurn` | You are to move (and the game is live) |
| `board`, `turn`, `status`, `lastMove`, `history` | The game |
| `blackName`, `whiteName`, `blackPieces`, `whitePieces` | |
| `mustCapture` | You are to move and have a capture to make |
| `timed`, `blackMs`, `whiteMs`, `incrementMs`, `clockRunning` | Clocks. `blackMs`/`whiteMs` are the **live** values at response time |

The status `message` is chosen in priority order: an explicit message, waiting for an opponent, timed out, left the room, game over, "Your move" (with "you must capture" if so), then "{name} to move."

### 8.3 Paths and URL encoding

Paths contain `-` only (`c3-e5-g7`), so they are URL-safe as written. Room codes avoid ambiguous characters, and ids are `[a-z0-9]`.

### 8.4 Static content

`Home` is `@StaticContent("/", /)`. It serves the built client, which is compiled into `draughts.xtc` from `app/webapp/build` at build time (`-r app/webapp/build`). **Build the client first**, or the module has nothing to serve.

---

## 9. Database access (`Database` service in `draughts.x`)

`Database.connect()` returns a `DraughtsSchema`:

1. Try the **hosted** schema: `@Inject(resourceName="schema") DraughtsSchema? schema`. A platform that runs the app supplies this. Containers disagree on how to report a missing resource, since some yield `Null` and some throw, so both are treated as "not hosted".
2. Otherwise **open jsondb directly**: `jsondb.createCatalog("draughtsDB.examples.org", data/draughtsDB, build/db)` and `createConnection()`. The catalog is a `@Lazy` singleton, created once. Directories are relative to the working directory.

Each web service holds its own connection (`@Lazy schema.calc() = Database.connect()`), so two services never share a transaction.

Step 2 is what lets `xec`, the tests and a bare `xec draughts.xtc` work without a host. On a platform that injects the schema (the intended deployment), step 1 applies and the fallback is not used. This path has not been exercised on the real platform.

---

## 10. Concurrency and transactions

- Every endpoint body is one `using (schema.createTransaction())` block, so each request is atomic: read, decide, write.
- Updates are **read-modify-write of whole records** (`rooms.put(code, newRecord)`). Two near-simultaneous moves in one room are guarded by the turn check inside the transaction. The code relies on jsondb's transaction isolation for the rest and has no explicit retry logic. Concurrent writers to one room have not been load-tested.
- `settle` writes inside what looks like a read. It is idempotent: once the game is no longer `Ongoing` it returns early, so a second poller doesn't record the result twice.
- The AI runs **inside** the `computer` transaction, so a 4 s High search holds the session's transaction open for that long. That only blocks the same session.

---

## 11. Building, running and testing

**Build** (needs the XDK's `xtc` on `PATH`, plus Node for the client):

```bash
scripts/build.sh                    # client, then draughtsDB.xtc, then draughts.xtc
./gradlew :draughts-game:build      # the same through Gradle
```

Output is in `build/xtc/main/lib/`. The two files to deploy are `draughtsDB.xtc` and `draughts.xtc`.

**Test:**

```bash
scripts/test.sh                      # all suites (rebuilds first)
scripts/test.sh DraughtsApiTest      # one suite
scripts/test.sh --no-build ...       # skip the rebuild
```

Each suite runs in a throwaway working directory, so the jsondb files a test creates never leak.

| Suite | What it covers |
|---|---|
| `DraughtsRulesTest` | Move generation, compulsory capture, multi-jump, crowning, draw and loss |
| `DraughtsAiTest` | Levels, legality of chosen moves, time bounds |
| `DraughtsApiTest` | Single-player endpoints and per-session scoreboards |
| `DraughtsOnlineApiTest` | Rooms: create, join, turns, forfeit, rematch, scoreboard |
| `DraughtsClockTest` | Clock arithmetic and timeouts |

The suites call the services directly, with no HTTP.

---

## 12. Extending it: where to change what

| I want to… | Change |
|---|---|
| Add a rule variant (flying kings, men capturing backward) | `DraughtsRules.captureSequences` and the step loop in `legalMoves`. The AI follows automatically |
| Change AI strength | The `EASY`/`MEDIUM`/`HARD` constants in `DraughtsAi` |
| Improve the AI | `evaluate`. Move ordering is already done per depth |
| Change the draw rule | `DRAW_LIMIT`, and the text in `describeState` |
| Allow longer or shorter clocks | `MIN_MS`, `MAX_MS`, `MAX_INCREMENT` in `GameClock` |
| Add a field to a game | The `const` in `db/.../models/`. **Existing stored records will not match the new shape**, so plan a migration or a fresh database |
| Add an endpoint | `DraughtsApi` or `OnlineApi`. Do **not** add a new `@WebService` at an existing path |
| Make timeouts fire without a poll | Needs a scheduled task, which does not exist today. Settlement is lazy by design (6.3) |

**Schema changes and deployed data.** `draughtsDB.xtc` defines the stored shapes. When a record type or a key format changes, as it did when scoreboards moved from date keys to match scopes, old rows are not migrated. Deploy to a clean data directory, or accept that stale rows are ignored.

---

## 13. Known limits

- **The real platform (XQIZ.IT) has not been run against this code.** It was verified through the XDK's `xtc`, the unit tests and a browser against a mock of the API.
- Polling, not push. Latency is the poll interval, and load scales with open rooms.
- Nicknames are not unique and aren't authenticated. Scoreboard rows merge on equal names.
- Player ids are bearer secrets with no expiry. Rooms are never garbage-collected, except an unjoined room that its creator leaves.
- The AI's budget is wall-clock, so a heavily loaded server plays shallower.
- Timeouts are recorded lazily (6.3).
