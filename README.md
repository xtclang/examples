# XTC Examples

Example applications built with [Ecstasy](https://xtclang.org/) for deployment
on the XQIZ.IT hosting platform.

## Project Structure

This is a Gradle composite build. All examples are built together from the
repository root using the [XTC Gradle plugin](https://github.com/xtclang/xvm).

```
examples/
├── build.gradle.kts              # Root build — declares all example modules
├── settings.gradle.kts           # Composite build settings
├── gradle.properties             # Shared build properties
├── gradle/
│   └── libs.versions.toml        # Version catalog (XTC, Node.js versions)
├── build-logic/                  # Convention plugins (webapp integration)
│
├── welcome/                      # Web app with React frontend
│   ├── build.gradle.kts
│   ├── src/main/x/               # XTC source modules
│   │   ├── welcome.x             # Main @WebApp module
│   │   ├── welcomeDB.x           # Database schema
│   │   └── welcomeCLI.x          # CLI tool
│   ├── src/test/x/
│   │   └── welcomeTest.x         # Tests
│   └── webapp/                   # React app (npm build)
│
├── banking/                      # Bank stress test demo
│   ├── build.gradle.kts
│   ├── src/main/x/
│   │   ├── Bank.x                # @Database module
│   │   └── BankStressTest.x      # @WebApp stress test
│   ├── src/test/x/
│   │   └── BankTest.x            # Tests
│   └── webapp/public/            # Static web content
│
├── counter/                      # Authenticated counter app
│   ├── build.gradle.kts
│   ├── src/main/x/
│   │   ├── count.x               # @WebApp module (uses webauth)
│   │   └── countDB.x             # Database schema
│   └── webapp/public/            # Static web content
│
└── chess-game/                   # Chess game with AI opponent
    ├── build.gradle.kts
    ├── src/main/x/
    │   ├── chess.x               # @WebApp server module
    │   ├── chessDB.x             # Database schema
    │   └── chessLogic.x          # Game logic and AI
    └── webapp/public/            # Static web content (HTML client)
```

## Prerequisites

- **Java 25** (auto-downloaded via Gradle toolchain if not present)
- **XDK** — resolved automatically from Maven repositories
- **Node.js** — only needed for the `welcome` example (auto-downloaded by default)

Alternatively, if you have **Docker** installed, you don't need any of the
above — see [Building with Docker](#building-with-docker) below.

## Building

Build all examples from the repository root:

```bash
./gradlew build
```

Build a single example:

```bash
./gradlew :chess-game:build
```

Install all compiled modules to a single directory:

```bash
./gradlew installDist
# Output: build/install/examples/lib/
```

## Running

Most examples are `@WebApp` modules that require the
[XQIZ.IT platform](https://github.com/xtclang/platform) to run. The
`welcomeTest` module is a standalone console app that can be run directly:

```bash
./gradlew :welcome:runXtc
```

After building, you can also run any module directly with `xtc run`:

```bash
./gradlew installDist
xtc run -L build/install/examples/lib welcomeTest
```

## Testing

Run all tests:

```bash
./gradlew build
```

The `banking` example includes xunit database tests (`BankTest.x` in `src/test/x/`)
that run automatically as part of the build.

## Building Without Gradle

If you have the XDK installed and on your PATH, you can compile and run
individual examples directly with `xtc build` and `xtc run`:

```bash
# Chess game
xtc build -o out -r chess-game/webapp chess-game/src/main/x/*.x
xtc run -L out chess.examples.org

# Welcome (requires npm build in welcome/webapp/ first)
xtc build -o out -r welcome/webapp welcome/src/main/x/*.x
xtc run -L out welcome.examples.org        # run the web app
xtc run -L out welcomeTest                 # run the DB test
xtc run -L out welcomeCLI.examples.org     # interactive CLI (requires web app running)

# Counter
xtc build -o out -r counter/webapp counter/src/main/x/*.x
xtc run -L out count.examples.org

# Banking
xtc build -o out -r banking/webapp banking/src/main/x/*.x
xtc run -L out BankStressTest
```

## Building with Docker

### Full Gradle build in Docker

The included `Dockerfile` is a multi-stage build that:
1. Compiles all examples using `gradle:jdk25` (with dependency layer caching)
2. Copies the XVM runtime from `ghcr.io/xtclang/xvm:latest`
3. Runs `welcomeTest` as a build-time verification
4. Produces a slim JRE image with compiled modules and the `xtc` CLI

```bash
# Build the image (compiles all examples, runs welcomeTest to verify)
docker build -t xtc-examples .

# Run the welcomeTest (default entrypoint)
docker run --rm xtc-examples

# Run any module using xtc
docker run --rm xtc-examples run -L /opt/examples/lib welcomeTest

# Copy the compiled modules to your local machine
docker run --rm -v $(pwd)/out:/out --entrypoint cp xtc-examples -r /opt/examples/lib/. /out/
ls out/*.xtc
```

If you don't have Java or Gradle installed, you can build directly from source
and get the compiled modules on your local filesystem in one command:

```bash
docker run --rm -v $(pwd):/workspace -w /workspace gradle:jdk25 gradle build installDist
ls build/install/examples/lib/*.xtc
```

The output lands in `build/install/examples/lib/` on your host machine via the
volume mount — no JDK, Gradle, or Node.js installation required.

### Using the XDK Docker image

To compile and run individual examples without Gradle, use the official XDK
Docker image:

```bash
# Build and run the chess game
docker run --rm -v $(pwd):/workspace ghcr.io/xtclang/xvm:latest \
  xtc build -o /workspace/out -r /workspace/chess-game/webapp \
  /workspace/chess-game/src/main/x/chessDB.x \
  /workspace/chess-game/src/main/x/chessLogic.x \
  /workspace/chess-game/src/main/x/chess.x

# Interactive shell
docker run -it --rm -v $(pwd):/workspace ghcr.io/xtclang/xvm:latest bash
cd /workspace
xtc build -o out -r chess-game/webapp chess-game/src/main/x/*.x
```

## Example Descriptions

### welcome
A "hello world" web application with a React frontend. Demonstrates `@WebApp`,
database integration (`oodb`), static content serving, and a CLI management tool.

The `welcomeTest` module is a standalone console app that exercises the database
layer directly. It opens a `jsondb` connection to the `welcomeDB` schema, looks
up a guest entry in the `counters` map, increments it, and prints the visit count:

```
$ ./gradlew runXtc -PmoduleName=welcomeTest
Welcome! You are guest #test-guest, visit #1
$ ./gradlew runXtc -PmoduleName=welcomeTest
Welcome! You are guest #test-guest, visit #2
```

The counter persists across runs because `jsondb` stores the database as JSON
files on disk. The data lives under `data/` at the repository root (gitignored),
with the transaction log in `data/sys/txlog.json` and the counter values in
`data/counters/`. Delete the `data/` directory to reset the database.

### banking
A bank database with concurrent transaction stress testing. Demonstrates
`@Database`, `DBMap`, `DBCounter`, and web-based stress test visualization.

### counter
An authenticated web application using the `webauth` module. Demonstrates
login/logout, session management, and per-user persistent counters.

### chess-game
A chess game server with an AI opponent. Demonstrates a larger multi-module
application with game logic, database persistence, and a web client interface.

## Development

To use local (unpublished) XDK builds, ensure they are installed to Maven Local:

```bash
# In your xvm/xdk checkout:
./gradlew publishLocal

# Then build examples against the local snapshot:
./gradlew build
```

The XTC version is configured in `gradle/libs.versions.toml`.
