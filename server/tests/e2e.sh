#!/usr/bin/env bash
# End-to-end: starts the compile service, posts every example against the smoke
# level, and asserts on the response; then drives the runner endpoints with
# every next/examples case. Runs the real javac -> TeaVM -> node pipeline,
# because a plain JVM accepts code that TeaVM rejects.
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

echo "== runner: /build, /start, /decide, /close (docs/runner.md)"

ROOT="http://localhost:8080"
STATE=next/state.json

build() { # build <case>: writes $TMP/<case>.build.json, prints the build id
    curl -s --data-binary @"next/examples/$1/Submission.java" "$ROOT/build" -o "$TMP/$1.build.json"
    get "$TMP/$1.build.json" build
}

start() { # start <build> <out> [timeout_ms]: prints the instance id
    curl -s -X POST "$ROOT/start?build=$1${3:+&timeout_ms=$3}" -o "$TMP/$2"
    get "$TMP/$2" instance
}

decide() { # decide <instance> <out> [state file]
    curl -s --data-binary @"${3:-$STATE}" "$ROOT/decide?instance=$1" -o "$TMP/$2"
}

close_build() { # close_build <build> <out>
    curl -s -X POST "$ROOT/close?build=$1" -o "$TMP/$2"
}

b=$(build first_enemy)
expect "first enemy: build status" "$(get "$TMP/first_enemy.build.json" status)" "ok"
i=$(start "$b" first_enemy.start.json)
expect "first enemy: start status" "$(get "$TMP/first_enemy.start.json" status)" "ok"
expect "first enemy: start has no error" "$(get "$TMP/first_enemy.start.json" error)" ""
decide "$i" first_enemy.decide.json
expect "first enemy: decide status" "$(get "$TMP/first_enemy.decide.json" status)" "ok"
expect "first enemy: the command comes back as it is" "$(get "$TMP/first_enemy.decide.json" action)" "attack e3"
decide "$i" first_enemy.bad_state.json <(echo 'not json')
expect "a state that is not JSON: status" "$(get "$TMP/first_enemy.bad_state.json" status)" "bad_request"
expect_contains "a state that is not JSON: message" "$(get "$TMP/first_enemy.bad_state.json" message)" "not JSON"
decide "$i" first_enemy.after_bad.json
expect "a bad state does not end the battle" "$(get "$TMP/first_enemy.after_bad.json" action)" "attack e3"
close_build "$b" first_enemy.close.json
expect "close: status" "$(get "$TMP/first_enemy.close.json" status)" "ok"
close_build "$b" first_enemy.close_again.json
expect "close twice: status" "$(get "$TMP/first_enemy.close_again.json" status)" "unknown_build"
decide "$i" first_enemy.after_close.json
expect "decide after close: status" "$(get "$TMP/first_enemy.after_close.json" status)" "unknown_instance"

b=$(build persists)
i=$(start "$b" persists.start.json)
decide "$i" persists.1.json
decide "$i" persists.2.json
expect "fields persist within a battle: first call" "$(get "$TMP/persists.1.json" action)" "pass 1"
expect "fields persist within a battle: second call" "$(get "$TMP/persists.2.json" action)" "pass 2"
i2=$(start "$b" persists.restart.json)
decide "$i2" persists.3.json
expect "a new /start is a fresh Submission" "$(get "$TMP/persists.3.json" action)" "pass 1"
decide "$i" persists.old.json
expect "the replaced battle is gone" "$(get "$TMP/persists.old.json" status)" "unknown_instance"
close_build "$b" persists.close.json

build missing_semicolon > /dev/null
expect "missing semicolon: status" "$(get "$TMP/missing_semicolon.build.json" status)" "compile_error"
expect_matches "missing semicolon: message points at a line" \
    "$(get "$TMP/missing_semicolon.build.json" message)" "Submission\.java:[0-9]+"
expect "missing semicolon: no build" "$(get "$TMP/missing_semicolon.build.json" build)" ""

build package_line > /dev/null
expect "package line: status" "$(get "$TMP/package_line.build.json" status)" "compile_error"

b=$(build infinite_loop)
i=$(start "$b" infinite_loop.start.json 700)
started=$(date +%s%N)
decide "$i" infinite_loop.decide.json
elapsed_ms=$((($(date +%s%N) - started) / 1000000))
expect "infinite loop: status" "$(get "$TMP/infinite_loop.decide.json" status)" "ok"
expect "infinite loop: error kind" "$(get "$TMP/infinite_loop.decide.json" error.kind)" "timeout"
expect_contains "infinite loop: message has the timeout the client chose" \
    "$(get "$TMP/infinite_loop.decide.json" error.message)" "700 ms"
if [ "$elapsed_ms" -ge 600 ] && [ "$elapsed_ms" -le 3000 ]; then
    ok "infinite loop: took ${elapsed_ms} ms (700 ms timeout)"
else
    bad "infinite loop: took ${elapsed_ms} ms, expected about 700"
fi
decide "$i" infinite_loop.again.json
expect "infinite loop: the battle is over after a timeout" \
    "$(get "$TMP/infinite_loop.again.json" status)" "unknown_instance"
start "$b" infinite_loop.restart.json > /dev/null
expect "infinite loop: the same build can start again" "$(get "$TMP/infinite_loop.restart.json" status)" "ok"
curl -s -X POST "$ROOT/start?build=$b&timeout_ms=0" -o "$TMP/timeout_zero.json"
expect "timeout_ms=0: status" "$(get "$TMP/timeout_zero.json" status)" "bad_request"
close_build "$b" infinite_loop.close.json

b=$(build throws)
i=$(start "$b" throws.start.json)
decide "$i" throws.decide.json
expect "throws: status" "$(get "$TMP/throws.decide.json" status)" "ok"
expect "throws: error kind" "$(get "$TMP/throws.decide.json" error.kind)" "threw"
expect "throws: exception class" "$(get "$TMP/throws.decide.json" error.exception)" "java.lang.IllegalStateException"
expect "throws: message, quote and newline intact" "$(get "$TMP/throws.decide.json" error.message)" \
    "$(printf 'he said "boom"\nand then it broke')"
close_build "$b" throws.close.json

b=$(build throws_in_constructor)
start "$b" throws_in_constructor.start.json > /dev/null
expect "constructor throws: status" "$(get "$TMP/throws_in_constructor.start.json" status)" "ok"
expect "constructor throws: error kind" "$(get "$TMP/throws_in_constructor.start.json" error.kind)" "threw"
expect "constructor throws: where" "$(get "$TMP/throws_in_constructor.start.json" error.in)" "constructor"
expect "constructor throws: message" "$(get "$TMP/throws_in_constructor.start.json" error.message)" "not ready"
close_build "$b" throws_in_constructor.close.json

b=$(build returns_null)
i=$(start "$b" returns_null.start.json)
decide "$i" returns_null.decide.json
expect "returns null: error kind" "$(get "$TMP/returns_null.decide.json" error.kind)" "returned_null"
close_build "$b" returns_null.close.json

b=$(build missing_key)
i=$(start "$b" missing_key.start.json)
decide "$i" missing_key.decide.json
expect "missing key: error kind" "$(get "$TMP/missing_key.decide.json" error.kind)" "threw"
expect_contains "missing key: message names the key" "$(get "$TMP/missing_key.decide.json" error.message)" '"hpp"'
close_build "$b" missing_key.close.json

b=$(build fake_marker)
i=$(start "$b" fake_marker.start.json)
decide "$i" fake_marker.decide.json
expect "fake reply line: the real action wins" "$(get "$TMP/fake_marker.decide.json" action)" "pass"
expect_contains "fake reply line: console has the printed text" \
    "$(get "$TMP/fake_marker.decide.json" console)" "thinking about my move"
expect_contains "fake reply line: console has the fake line" \
    "$(get "$TMP/fake_marker.decide.json" console)" '"action":"win"'
expect_contains "fake reply line: console has an unfinished line" \
    "$(get "$TMP/fake_marker.decide.json" console)" "no newline at the end"
close_build "$b" fake_marker.close.json

b=$(build floods_output)
i=$(start "$b" floods_output.start.json 10000)
decide "$i" floods_output.decide.json
expect "floods output: error kind" "$(get "$TMP/floods_output.decide.json" error.kind)" "output_limit"
close_build "$b" floods_output.close.json

curl -s -X POST "$ROOT/start?build=nope" -o "$TMP/unknown_build.json"
expect "start an unknown build: status" "$(get "$TMP/unknown_build.json" status)" "unknown_build"

expect "runner: no build dirs left behind" "$(ls -d /tmp/dsagame-build* 2>/dev/null | wc -l)" "0"
expect "runner: no node hosts left running" "$(pgrep -fc 'runner/host.js')" "0"

echo "== harness tests"
tests/harness-test.sh || fails=$((fails + 1))

if [ "$fails" -eq 0 ]; then
    echo "ALL TESTS PASSED"
else
    echo "$fails CHECK(S) FAILED"
fi
exit "$fails"
