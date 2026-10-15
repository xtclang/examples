#!/usr/bin/env bash
#
# Builds the chess game and starts the server.
#
#   scripts/run.sh                                         # https://localhost:8090
#   scripts/run.sh localhost:3000/3001                     # other ports
#   scripts/run.sh my-laptop.local:8080/8090 0.0.0.0:8080/8090   # reachable on the network
#   scripts/run.sh --no-build ...                          # start the last build as is
#
# The first address is the one clients use (Host header and TLS certificate); the optional
# second is the socket to bind. See "Run the Server" in README.md.
#
# Environment:
#   XTC        the xtc launcher (default: `xtc` on the PATH)
#   JAVA_HOME  a JDK the XDK supports

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
XTC="${XTC:-xtc}"
LIB="$ROOT/build/xtc/main/lib"

build=true
args=()
for arg in "$@"; do
  case "$arg" in
    --no-build) build=false ;;
    -h|--help)  sed -n '2,14p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *)          args+=("$arg") ;;
  esac
done

if $build; then
  "$ROOT/scripts/build.sh"
fi

# The server keeps its database in data/ and its generated jsondb module in build/db/,
# relative to the working directory; both are git-ignored.
cd "$ROOT"
exec "$XTC" run -L "$LIB" "$LIB/chess.xtc" "${args[@]+"${args[@]}"}"
