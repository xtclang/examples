#!/usr/bin/env bash
#
# Runs the chess-game test suites with the XDK's `xtc test`, without Gradle.
#
#   scripts/test.sh                 # every suite except the live network suite
#   scripts/test.sh --live          # also run ChessLiveApiTest (needs internet; rate limited)
#   scripts/test.sh ChessApiTest    # just the named suite(s)
#   scripts/test.sh --no-build ...  # skip recompiling the modules first
#
# Each suite runs in its own fresh working directory, so the database a test creates never
# leaks into the next suite or into the repository.
#
# Environment:
#   XTC        the xtc launcher (default: `xtc` on the PATH)
#   JAVA_HOME  a JDK the XDK supports

set -uo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
XTC="${XTC:-xtc}"
LIB="$ROOT/build/xtc/main/lib"
LIVE_SUITE="ChessLiveApiTest"

live=false
build=true
only=()
for arg in "$@"; do
  case "$arg" in
    --live)     live=true ;;
    --no-build) build=false ;;
    -h|--help)  sed -n '2,17p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *)          only+=("$arg") ;;
  esac
done

if ! command -v "$XTC" >/dev/null 2>&1; then
  echo "error: '$XTC' not found. Put the XDK's bin directory on PATH, or set XTC=/path/to/xtc." >&2
  exit 2
fi

if $build; then
  "$ROOT/scripts/build.sh" || exit 1
fi

suites=()
if ((${#only[@]})); then
  suites=("${only[@]}")
else
  for file in "$ROOT"/app/src/test/x/*.x; do
    name="$(basename "$file" .x)"
    if [[ "$name" == "$LIVE_SUITE" && $live == false ]]; then
      continue
    fi
    suites+=("$name")
  done
fi

scratch="$(mktemp -d "${TMPDIR:-/tmp}/chess-tests.XXXXXX")"
trap 'rm -rf "$scratch"' EXIT

failed=0
total_passed=0
total_failed=0
printf '\n%-28s %8s %8s %8s %8s\n' "SUITE" "PASSED" "FAILED" "SKIPPED" "TIME"
printf '%-28s %8s %8s %8s %8s\n' "-----" "------" "------" "-------" "----"

for name in "${suites[@]}"; do
  source="$ROOT/app/src/test/x/$name.x"
  if [[ ! -f "$source" ]]; then
    echo "error: no test suite named $name" >&2
    failed=1
    continue
  fi

  workdir="$scratch/$name"
  mkdir -p "$workdir"
  log="$workdir/test.log"
  (cd "$workdir" && "$XTC" test -L "$LIB" -o "$workdir" -x "$workdir/xunit" "$source") >"$log" 2>&1

  summary="$(grep -E "^Finished:  $name (Successful|Failed)" "$log" | tail -1)"
  if [[ -z "$summary" ]]; then
    printf '%-28s %8s\n' "$name" "ERROR"
    sed -n '1,40p' "$log" | grep -v '^\s*at ' >&2
    failed=1
    continue
  fi

  passed="$(sed -E 's/.*passed=([0-9]+).*/\1/' <<<"$summary")"
  fails="$(sed -E 's/.*failed=([0-9]+).*/\1/' <<<"$summary")"
  errors="$(sed -E 's/.*errors=([0-9]+).*/\1/' <<<"$summary")"
  skipped="$(sed -E 's/.*skipped=([0-9]+).*/\1/' <<<"$summary")"
  seconds="$(sed -E 's/.* in ([0-9.]+) .*/\1/' <<<"$summary")"
  printf '%-28s %8s %8s %8s %7ss\n' "$name" "$passed" "$((fails + errors))" "$skipped" "$seconds"

  total_passed=$((total_passed + passed))
  total_failed=$((total_failed + fails + errors))
  if [[ "$summary" == *Failed* || $((fails + errors)) -gt 0 ]]; then
    failed=1
    grep -E "Failed in|Exception|assert" "$log" | grep -v '^\s*at ' | head -20 | sed 's/^/    /' >&2
  fi
done

printf '%-28s %8s %8s\n' "-----" "------" "------"
printf '%-28s %8s %8s\n\n' "TOTAL" "$total_passed" "$total_failed"

if ((failed)); then
  echo "Some tests failed." >&2
  exit 1
fi
echo "All tests passed."
