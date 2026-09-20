#!/usr/bin/env bash
# End-to-end: starts the compile service, posts every example against the smoke
# level, and asserts on the response. Runs the real javac -> TeaVM -> node
# pipeline, because a plain JVM accepts code that TeaVM rejects.
set -uo pipefail

cd "$(dirname "$0")/.."

command -v node >/dev/null || { echo "node is required"; exit 1; }
command -v python3 >/dev/null || { echo "python3 is required (used to read the responses)"; exit 1; }

BASE="http://localhost:8080/compile"
TMP=$(mktemp -d)
SERVER_PID=""
fails=0

cleanup() {
    [ -n "$SERVER_PID" ] && kill "$SERVER_PID" 2>/dev/null
    rm -rf "$TMP"
}
trap cleanup EXIT

# Read one field out of a response: get <file> <dotted.path>
get() {
    python3 - "$1" "$2" <<'PY'
import json, sys
cur = json.load(open(sys.argv[1]))
for part in sys.argv[2].split('.'):
    cur = cur[int(part)] if part.isdigit() else cur[part]
print('' if cur is None else cur)
PY
}

ok() { echo "ok: $1"; }
bad() { echo "FAIL: $1"; fails=$((fails + 1)); }

expect() { # expect <label> <actual> <expected>
    if [ "$2" = "$3" ]; then ok "$1"; else bad "$1 (got '$2', want '$3')"; fi
}

expect_contains() { # expect_contains <label> <haystack> <needle>
    case "$2" in *"$3"*) ok "$1";; *) bad "$1 (got '$2', want something containing '$3')";; esac
}

expect_matches() { # expect_matches <label> <haystack> <regex>
    if echo "$2" | grep -Eq "$3"; then ok "$1"; else bad "$1 (got '$2', want /$3/)"; fi
}

post() { # post <case> <query>
    curl -s --data-binary @"examples/$1/Submission.java" "$BASE?$2" -o "$TMP/$1.json"
}

echo "== building and starting the server"
./gradlew -q installDist || { echo "build failed"; exit 1; }
build/install/server/bin/server > "$TMP/server.log" 2>&1 &
SERVER_PID=$!
for _ in $(seq 1 60); do
    curl -s -o /dev/null "$BASE?level=smoke" && break
    sleep 1
done

echo "== cases"

post attack "level=smoke&student=alice"
expect "attacks the first enemy: status" "$(get "$TMP/attack.json" status)" "ok"
expect "attacks the first enemy: passed" "$(get "$TMP/attack.json" result.passed)" "True"

post pass "level=smoke&student=alice"
expect "always passes: status" "$(get "$TMP/pass.json" status)" "ok"
expect "always passes: passed" "$(get "$TMP/pass.json" result.passed)" "False"
expect "always passes: reason" "$(get "$TMP/pass.json" result.scenarios.0.reason)" "Turn limit reached"

post missing_semicolon "level=smoke"
expect "missing semicolon: status" "$(get "$TMP/missing_semicolon.json" status)" "compile_error"
expect_matches "missing semicolon: message points at a line" \
    "$(get "$TMP/missing_semicolon.json" message)" "Submission\.java:[0-9]+"

started=$SECONDS
post infinite_loop "level=smoke"
elapsed=$((SECONDS - started))
expect "infinite loop: status" "$(get "$TMP/infinite_loop.json" status)" "timeout"
if [ "$elapsed" -ge 4 ] && [ "$elapsed" -le 20 ]; then
    ok "infinite loop: took ${elapsed}s (5s timeout plus startup)"
else
    bad "infinite loop: took ${elapsed}s, expected about 5s"
fi

post package_line "level=smoke"
expect "package line: status" "$(get "$TMP/package_line.json" status)" "compile_error"

post throws "level=smoke"
expect "throws: status" "$(get "$TMP/throws.json" status)" "ok"
expect_contains "throws: error is set" "$(get "$TMP/throws.json" result.scenarios.0.error)" "boom"
# get parsed the file, so the response with a quote and a newline in it is valid JSON.
ok "throws: response is valid JSON"

post returns_null "level=smoke"
expect "returns null: status" "$(get "$TMP/returns_null.json" status)" "ok"
expect_contains "returns null: error mentions null" \
    "$(get "$TMP/returns_null.json" result.scenarios.0.error)" "null"

post fake_marker "level=smoke"
expect "fake marker: status" "$(get "$TMP/fake_marker.json" status)" "ok"
expect "fake marker: real result wins" "$(get "$TMP/fake_marker.json" result.passed)" "True"
expect_contains "fake marker: console has the printed text" \
    "$(get "$TMP/fake_marker.json" console)" "thinking about my move"

post attack "level=Bad%20Level!"
expect "invalid level id: status" "$(get "$TMP/attack.json" status)" "bad_request"

leftovers=$(ls -d /tmp/submission* 2>/dev/null | wc -l)
expect "no temp dirs left behind" "$leftovers" "0"

echo "== harness tests"
tests/harness-test.sh || fails=$((fails + 1))

if [ "$fails" -eq 0 ]; then
    echo "ALL TESTS PASSED"
else
    echo "$fails CHECK(S) FAILED"
fi
exit "$fails"
