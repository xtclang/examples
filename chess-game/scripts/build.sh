#!/usr/bin/env bash
#
# Builds the chess game without Gradle: the React client, then the chessDB and chess modules.
#
#   scripts/build.sh
#
# Output lands in build/xtc/main/lib (chessDB.xtc and chess.xtc). The client build in
# app/webapp/build is compiled into chess.xtc, so it must exist first.
#
# Environment:
#   XTC        the xtc launcher (default: `xtc` on the PATH)
#   JAVA_HOME  a JDK the XDK supports

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
XTC="${XTC:-xtc}"
LIB="$ROOT/build/xtc/main/lib"

if ! command -v "$XTC" >/dev/null 2>&1; then
  echo "error: '$XTC' not found. Put the XDK's bin directory on PATH, or set XTC=/path/to/xtc." >&2
  exit 2
fi

mkdir -p "$LIB"

echo "==> web client"
(
  cd "$ROOT/app/webapp"
  [[ -d node_modules ]] || npm ci
  npm run build --silent
)

echo "==> chessDB"
"$XTC" build -L "$LIB" -o "$LIB" "$ROOT/db/src/main/x/chessDB.x"

echo "==> chess"
"$XTC" build -L "$LIB" -r "$ROOT/app/webapp" -o "$LIB" "$ROOT/app/src/main/x/chess.x"

echo "==> built into ${LIB#"$ROOT"/}"
