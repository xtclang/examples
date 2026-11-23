#!/usr/bin/env bash
#
# Builds the draughts game without Gradle: the React client, then the draughtsDB and draughts modules.
#
#   scripts/build.sh
#
# Output lands in build/xtc/main/lib (draughtsDB.xtc and draughts.xtc). The client build in
# app/webapp/build is compiled into draughts.xtc, so it must exist first.
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

echo "==> draughtsDB"
"$XTC" build -L "$LIB" -o "$LIB" "$ROOT/db/src/main/x/draughtsDB.x"

echo "==> draughts"
"$XTC" build -L "$LIB" -r "$ROOT/app/webapp/build" -o "$LIB" "$ROOT/app/src/main/x/draughts.x"

echo "==> built into ${LIB#"$ROOT"/}"
