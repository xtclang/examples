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
│   │   ├── welcomeCLI.x          # CLI tool
│   │   └── welcomeTest.x         # Standalone DB console app (run via :welcome:runXtc)
│   └── webapp/                   # React app (npm build)
│
├── banking/                      # Bank stress test demo
│   ├── build.gradle.kts
│   ├── src/main/x/
│   │   ├── Bank.x                # @Database module
│   │   └── BankStressTest.x      # @WebApp stress test
│   ├── src/test/x/
│   │   └── BankTest.x            # xunit tests
│   └── webapp/public/            # Static web content
│
├── counter/                      # Authenticated counter app
│   ├── build.gradle.kts
│   ├── src/main/x/
│   │   ├── count.x               # @WebApp module (uses webauth)
│   │   └── countDB.x             # Database schema
│   └── webapp/public/            # Static web content
│
└── chess-game/                   # Composite build — chess game with AI opponent
    ├── build.gradle.kts          # Composite root (lifecycle aggregator)
    ├── settings.gradle.kts
    ├── app/                      # :app subproject — produces chess.xtc
    │   ├── build.gradle.kts
    │   ├── src/main/x/           # chess.x + chess/{ai,api,config,core,services,utils,validation}/
    │   ├── src/test/x/           # 16 xunit test modules
    │   └── webapp/public/        # Static web content (HTML/JS client)
    └── db/                       # :db subproject — produces chessDB.xtc
        ├── build.gradle.kts
        └── src/main/x/           # chessDB.x + chessDB/{base,factory,models,pieces,types}/
```

## Prerequisites

- **Java 21+** — needed to bootstrap the Gradle wrapper (`./gradlew`). Gradle
  will then auto-download JDK 25 via its toolchain support to compile XTC sources.
  Install via [SDKMAN](https://sdkman.io/) (`sdk install java`),
  [Adoptium](https://adoptium.net/), or your system package manager.
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

### Running detached (background) via Gradle

The XTC Gradle plugin's `runXtc`/`testXtc` tasks accept a `--mode` option
controlling how the XTC process is launched:

| Mode | Behaviour |
|------|-----------|
| `DIRECT`               | In-process, shares Gradle's JVM (fastest, no fork). |
| `ATTACHED` *(default)* | Forked JVM, stdout/stderr inherited; Gradle waits for the process to exit. |
| `DETACHED`             | Forked JVM in the background; Gradle returns immediately. The PID is logged; stdout/stderr are redirected to timestamped log files under `build/xtc/run_stdout_*.log` (and stderr equivalent). |

Example:

```bash
./gradlew :welcome:runXtc --mode=DETACHED
# → [plugin] Started detached process with PID: 12345
# Gradle exits; welcomeTest keeps running. Tail the log file under
# welcome/build/xtc/ to see its output, and `kill <PID>` to stop it.
```

DETACHED is intended for run/test tasks only; it has no effect on compile
tasks and disables interactive stdin (the child has no inherited terminal).

## Testing

Run all tests:

```bash
./gradlew build
```

xunit tests run automatically as part of the build. Test failures fail the
build (configured in `build-logic`'s `xtc-conventions` plugin):

- `banking/src/test/x/BankTest.x` — bank database operations.
- `chess-game/app/src/test/x/Chess*Test.x` — 16 modules covering chess
  logic, board operations, AI, validation, and time control.

## Continuous Integration

GitHub Actions runs `./gradlew build`, `./gradlew installDist`, and a
`welcomeTest` smoke run on every push and pull request. The Dockerfile is
also built in CI to catch context drift. See `.github/workflows/ci.yml`.

## Building Without Gradle

If you have the XDK installed and on your PATH, you can compile and run
individual examples directly with `xtc build` and `xtc run`:

```bash
# Chess game (db must be compiled first; chess.x depends on chessDB)
xtc build -o out chess-game/db/src/main/x/chessDB.x
xtc build -o out -L out -r chess-game/app/webapp chess-game/app/src/main/x/chess.x
# chess.examples.org is @WebApp — needs the XQIZ.IT platform to host

# Welcome (requires npm build in welcome/webapp/ first)
xtc build -o out -r welcome/webapp welcome/src/main/x/*.x
xtc run -L out welcomeTest                 # standalone DB console app
# welcome.examples.org / welcomeCLI.examples.org are @WebApp — need the XQIZ.IT platform

# Counter
xtc build -o out -r counter/webapp counter/src/main/x/*.x
# count.examples.org is @WebApp — needs the XQIZ.IT platform

# Banking
xtc build -o out -r banking/webapp banking/src/main/x/*.x
# BankStressTest is @WebApp — needs the XQIZ.IT platform
```

`@WebApp` modules (`chess`, `welcome`, `count`, `BankStressTest`) cannot be
run via plain `xtc run` — they require the XQIZ.IT platform to host them.
`welcomeTest` is a standalone `module ... { void run() {...} }` and is the
only example currently runnable directly with `xtc run`.

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
docker run --rm -v "$(pwd)/out:/out" --entrypoint cp xtc-examples -r /opt/examples/lib/. /out/
ls out/*.xtc
```

If you don't have Java or Gradle installed, you can build directly from source
and get the compiled modules on your local filesystem in one command:

```bash
docker run --rm -v "$(pwd):/workspace" -w /workspace gradle:jdk25 gradle build installDist
ls build/install/examples/lib/*.xtc
```

The output lands in `build/install/examples/lib/` on your host machine via the
volume mount — no JDK, Gradle, or Node.js installation required.

### Using the XDK Docker image

To compile individual examples without Gradle, use the official XDK Docker
image:

```bash
# Build the chess game modules (db first, then app — app depends on db)
docker run --rm -v "$(pwd):/workspace" ghcr.io/xtclang/xvm:latest \
  xtc build -o /workspace/out /workspace/chess-game/db/src/main/x/chessDB.x
docker run --rm -v "$(pwd):/workspace" ghcr.io/xtclang/xvm:latest \
  xtc build -o /workspace/out -L /workspace/out \
  -r /workspace/chess-game/app/webapp \
  /workspace/chess-game/app/src/main/x/chess.x

# Interactive shell
docker run -it --rm -v "$(pwd):/workspace" ghcr.io/xtclang/xvm:latest bash
cd /workspace
xtc build -o out chess-game/db/src/main/x/chessDB.x
xtc build -o out -L out -r chess-game/app/webapp chess-game/app/src/main/x/chess.x
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
