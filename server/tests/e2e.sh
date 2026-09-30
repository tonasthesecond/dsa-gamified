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

# Checks the move-related shape of every event in a response, and that every
# drain is a damage followed by a heal on its user. Prints the first problem, or
# nothing: event_problems <file>
event_problems() {
    python3 - "$1" <<'PY'
import json, sys
for s in json.load(open(sys.argv[1]))['result']['scenarios']:
    events = s['events']
    for i, e in enumerate(events):
        t = e['type']
        if t in ('intent', 'action') and e.get('move') != e['action']:
            sys.exit(print('%s without move == action: %s' % (t, e)))
        if t in ('damage', 'heal', 'blocked') and 'move' not in e:
            sys.exit(print('%s without move: %s' % (t, e)))
        if t in ('spawn', 'death', 'end') and 'move' in e:
            sys.exit(print('%s with move: %s' % (t, e)))
        if t == 'damage' and e['move'] == 'drain':
            user = [a for a in events[:i] if a['type'] == 'action'][-1]['unit']
            rest = [n for n in events[i + 1:] if n['type'] != 'death']
            if not rest or rest[0]['type'] != 'heal' or rest[0]['move'] != 'drain' or rest[0]['unit'] != user:
                sys.exit(print('drain damage not followed by a drain heal on %s: %s' % (user, e)))
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

post demo_win "level=demo&student=alice"
expect "demo, winning party: status" "$(get "$TMP/demo_win.json" status)" "ok"
expect "demo, winning party: passed" "$(get "$TMP/demo_win.json" result.passed)" "True"
expect "demo, winning party: every move event names its move, drain heals its user" \
    "$(event_problems "$TMP/demo_win.json")" ""
cp "$TMP/demo_win.json" "$TMP/demo_win_first.json"
post demo_win "level=demo&student=alice"
if cmp -s "$TMP/demo_win.json" "$TMP/demo_win_first.json"; then
    ok "demo, winning party: same student and level give a byte-identical response"
else
    bad "demo, winning party: two identical requests gave different responses"
fi

post demo_lose "level=demo&student=alice"
expect "demo, losing party: status" "$(get "$TMP/demo_lose.json" status)" "ok"
expect "demo, losing party: passed" "$(get "$TMP/demo_lose.json" result.passed)" "False"
expect "demo, losing party: reason" "$(get "$TMP/demo_lose.json" result.scenarios.0.reason)" "Party defeated"

post demo_invalid "level=demo&student=alice"
expect "invalid move: status" "$(get "$TMP/demo_invalid.json" status)" "ok"
expect "invalid move: passed" "$(get "$TMP/demo_invalid.json" result.passed)" "False"
expect_contains "invalid move: error names the hero" \
    "$(get "$TMP/demo_invalid.json" result.scenarios.0.error)" "Knight"
expect_contains "invalid move: error names the move" \
    "$(get "$TMP/demo_invalid.json" result.scenarios.0.error)" "heal"

post demo_wrong_target "level=demo&student=alice"
expect "wrong target kind: status" "$(get "$TMP/demo_wrong_target.json" status)" "ok"
expect "wrong target kind: passed" "$(get "$TMP/demo_wrong_target.json" result.passed)" "False"
expect "wrong target kind: error names the hero, the move and the target" \
    "$(get "$TMP/demo_wrong_target.json" result.scenarios.0.error)" \
    "Cleric tried to use Heal on Goblin, which is not an ally."

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
