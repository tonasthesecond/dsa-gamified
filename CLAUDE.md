# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

A Zachtronics-style coding game for a data structures course. Students write Java
against a small API; the server compiles it, runs a turn-based battle with it, and
returns the whole battle as a JSON event log for a Godot client (not in this repo)
to replay. `server-brief.md` is the spec the server was built from.

Everything lives in `server/`. Run every command from there — the service reads
`api/` and `harness/` from its working directory.

## Commands

```bash
./gradlew run             # serve on :8080
tests/e2e.sh              # whole suite: builds, starts its own server, runs every example
tests/harness-test.sh     # determinism checks only, plain JVM, seconds not minutes
scripts/build-api-jar.sh  # dsagame-api.jar, what students compile against
```

There is no test framework and no per-test runner. Two ways to work on one case:

```bash
# Fast inner loop: no server, no TeaVM. Swap in any examples/<case>/Submission.java.
rm -rf build/check && mkdir -p build/check/dsagame/api
cp examples/attack/Submission.java harness/*.java build/check/
cp api/dsagame/api/*.java build/check/dsagame/api/
javac --release 17 -d build/check/out $(find build/check -name '*.java')
java -cp build/check/out Main smoke 1

# One case through the real pipeline, against a running server:
curl -s --data-binary @examples/demo_win/Submission.java \
  "http://localhost:8080/compile?level=demo&student=alice"
```

The JVM loop is only a smoke test: **a JVM accepts code TeaVM rejects**, so
anything touching `harness/` or `api/` has to be confirmed with `tests/e2e.sh`
before you believe it.

## Architecture

`Server.java` (package `compileservice`) per request: temp dir → write
`Submission.java` → copy `api/` + `harness/` in → `javac` in-process via
`ToolProvider` → TeaVM to `classes.js` → `node` → read the marked line → delete
the temp dir in a `finally`. Every expected failure is HTTP 200 with
`{"status","message","console","result"}`; the client reads `status`, never the
HTTP code.

`Main` (harness) is the TeaVM entry point: `<levelId> <seed>`, runs every scenario
of the level against a **fresh `new Submission()`**, prints a blank line then one
`@@DSAGAME_RESULT@@<json>` line. Student `System.out` shares that stdout.

### Rules that are load-bearing

**Default package.** `harness/` and the student's `Submission` are both in the
default package, because Java cannot reference the default package from a named
one — a packaged harness could not instantiate `Submission`. Only `dsagame.api`
is named. `harness/` must also stay **flat**: `Server.copySources` copies
recursively preserving directories, so a subfolder would land as a package dir.

**TeaVM subset.** `harness/`, `api/` and student code all cross-compile. Use
`StringBuilder`, `ArrayList`, `HashMap`, `java.util.Random`, `Math`, index loops.
No reflection, `String.format`, streams, records, `java.time`, files, threads,
network. JSON is built by hand (`Json.quote`) for this reason.

**Determinism is tested.** Server seed is `(student + ":" + level).hashCode() &
0x7fffffffL`; scenario `i` uses `seed + i * 7919L`; all randomness comes from
`Random(scenarioSeed)` or `battle.random`. Same inputs must give byte-identical
output, and nothing may depend on HashMap iteration order.

**The protocol is additive only.** `docs/protocol.md` is the contract with the
Godot client: new event types and new optional fields are fine, renames and
removals are not. The same goes for `dsagame.api` — old starter files must keep
compiling. Document every protocol change there.

**Student misbehaviour is game state, not a server error.** A throw (catch
`Throwable`), a null return, or an illegal move ends that scenario as a loss with
`error` set; the run continues to the next scenario and the status stays `ok`.

### The move system

Every action is a `Move` object a combatant owns — the basic attack and pass
included, so `Main` and `Battle` have no per-verb branches. Moves change the world
only through two primitives, `Battle.dealDamage` and `Battle.heal`, which log
their own events; **a move never builds an event**. Validation (ownership, target
kind, dead targets) is one method, `Battle.useError`. Turn order is one method,
`Battle.turnOrder`. `decide` is called once per living hero, in party order, with
a snapshot taken right then.

Adding a move, monster, hero or level should be a small additive change in one or
two files — a new `Move` subclass plus a line in `Moves`/`Heroes`/`Monsters`/`Levels`.
**If new content forces an edit to `Main`, `Battle` or `Server`, that is a design
flaw; say so rather than working around it.** The one legitimate exception is a
genuinely new primitive on `Battle`. `docs/adding-moves.md` is the how-to, with
the `drain` move as the worked example.

### Test fixtures

`smoke` and `demo` are the only levels, both marked TEST ONLY; there is no real
level content in the harness. Their numbers are pinned — `examples/attack` on
`smoke` must keep producing byte-identical output, which is how harness changes
are checked for regressions (diff against `git archive HEAD` of the old tree, do
not just trust the assertions). Each `examples/<case>/Submission.java` is one e2e
case; new content needs one submission that wins it and one that does not.
