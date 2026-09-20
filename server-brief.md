# DSA Game: server + student API implementation brief

Read this whole file, then read the repo, then reply with a plan of 10 lines or fewer before writing any code. If the repo layout or build tool makes something here ambiguous, ask instead of guessing.

## Context

This is a Zachtronics-style coding game for a data structures course. Students write Java against a small API. The server compiles their code, runs a turn-based battle simulation with it, and returns the full battle as a JSON event log. A Godot client (not part of this task) replays the log.

The server owns every rule. The client only animates events. Nothing in this task knows about any specific level.

Pipeline: `javac` -> TeaVM (JavaScript target) -> `node` -> one marked JSON line on stdout -> HTTP response.

## Your task

Build three things. All of them are level-agnostic.

1. **Compile service**: the HTTP server that runs the pipeline above.
2. **Student API**: the `dsagame.api` package students code against, plus a script that packages it as a jar.
3. **Harness skeleton**: the battle loop, event log, and a seam where levels plug in. It ships with one test-only level and no real ones.

Out of scope, do not build: the Godot client, any real level or level content (briefings, starter code per level, art), bytecode instrumentation, auth or accounts, a results store, Docker or Cloud Run deployment, rate limiting, non-Java languages.

## Repo state

The repo may contain an older spike (a sorting harness with `BubbleSort`, `TrackedArray`, and an `EventLog.printToStdout`) and possibly a prototype with a concrete level. Neither is the target.

- The sorting spike is superseded. Remove what the new harness replaces.
- Any concrete level from a prototype should come out of the harness core and out of the registry. It stays in git history. The test-only level below replaces it for testing.
- The javac -> TeaVM -> node pipeline in the existing `Server.java` already works. Keep its shape and the `compileservice` package.

## Layout

Follow the existing build tool. Do not add a new one. The service runs from a working directory that contains `api/` and `harness/`, which it copies into each submission's temp dir.

```
Server.java                       package compileservice
api/dsagame/api/*.java            student-facing, named package
harness/*.java                    default package (see rule below)
starter/Submission.java           generic skeleton students copy
examples/<case>/Submission.java   one dir per test case (see Tests)
scripts/build-api-jar.sh          builds dsagame-api.jar
tests/                            end-to-end script + harness unit tests
docs/protocol.md                  the contract with the Godot client
```

**Default-package rule.** The harness and the student's `Submission` both live in the default package. Java cannot reference the default package from a named one, so if the harness were in a package it could not instantiate `Submission`. Only `dsagame.api` is a named package. Do not "clean this up" by adding packages.

## 1. Student API (`dsagame.api`)

Students implement one interface in a class named `Submission` (default package, public, public no-arg constructor).

```java
public interface Strategy { Action decide(GameState state); }

public final class Action {
    public enum Type { ATTACK, PASS }
    public static Action attack(Unit target);   // IllegalArgumentException if null
    public static Action pass();
    public Type getType();
    public String getTargetId();                // null for PASS
}

public final class Unit {                       // immutable snapshot
    public Unit(String id, String name, int hp, int maxHp, int attack,
                boolean enemy, Action intent);
    // getId getName getHp getMaxHp getAttack isEnemy isAlive
    // getIntent(): what this unit will do after you act; null for non-enemies
}

public final class GameState {
    public GameState(int turn, Unit self, List<Unit> enemies);  // copies the list
    public int getTurn();                       // starts at 1
    public Unit getSelf();
    public List<Unit> getEnemies();             // living only; a fresh mutable list every call
}
```

Rules for this package:

- Immutable value classes with **public constructors**. Students must be able to build a fake `GameState` and unit-test their own `decide` locally.
- `getEnemies()` returns a fresh mutable list on every call. Students will sort it, and that must not corrupt anything.
- No dependency on the harness. No I/O, threads, reflection, or clock.
- Later changes are additive only: new methods and classes are fine, renames and removals are not, so old starter files keep compiling.
- Must compile with `--release 17` and under TeaVM.

`scripts/build-api-jar.sh` builds `dsagame-api.jar` from `api/`. Equivalent to: `javac -d build $(find api -name '*.java') && jar cf dsagame-api.jar -C build .`

`starter/Submission.java` is a skeleton whose `decide` returns `Action.pass()` with a one-line comment. It must compile against the jar as-is.

## 2. Harness skeleton (default package)

### Entry point

`Main` is the TeaVM main class. Args: `<levelId> <seed>`. For each scenario of the level it builds a battle from `level.setup(scenarioSeed)` and runs it against a **fresh `new Submission()`** (instance fields persist across turns within a scenario, never across scenarios). Scenario `i` uses `seed + i * 7919L`. All randomness comes from `java.util.Random` seeded that way. Same inputs must give byte-identical output.

It then prints two things: an empty line, then one line that is `@@DSAGAME_RESULT@@` immediately followed by the result JSON. Student `System.out` output shares stdout, which is why the result gets its own marked line.

### Battle loop (per scenario)

Repeat for turn = 1 .. `level.maxTurns()`:

1. Every living enemy gets an intent from `level.chooseIntent(...)`; emit `intent` events. Intents are visible to the student before they act.
2. Build a `GameState` snapshot and call `decide`. Catch **`Throwable`** (not just `Exception`). On a throw, a `null` return, or an attack on a nonexistent or dead target: the scenario ends as a loss with `error` set to a readable message, events so far are kept, and the run continues to the next scenario.
3. Emit `action`, then resolve it. `PASS` does nothing. `ATTACK` first asks `level.blockReason(target, battle)`: a non-null reason means the hit bounces (emit `blocked` with the reason), otherwise apply damage, emit `damage`, and emit `death` at 0 HP.
4. If no enemies are alive: win, emit `end`.
5. Each living enemy carries out its telegraphed intent (emit `action`, then resolve). If the hero reaches 0 HP: loss, emit `end`.

If the loop ends without a winner: loss, reason "Turn limit reached", emit `end`.

### The level seam

```
abstract class Level
    String id()
    List<Combatant> setup(long seed)                      // hero first, then enemies; deterministic
    int scenarioCount()                                   // default 3
    int maxTurns()                                        // default 20
    Action chooseIntent(Combatant enemy, Battle battle)   // default: attack the hero
    String blockReason(Combatant target, Battle battle)   // default: null (the hit lands)
```

The defaults are a plain fight, so a level overrides only what makes it special. Add a new hook only when a real level needs one. Do not pre-build hooks on speculation.

`Levels.get(String id)` is the registry: one line per level, returns null for unknown ids. Unknown level ids surface as a `runtime_error` with the exception message; no extra plumbing.

**Test-only level `smoke`.** One hero (30 HP, attack 6), one enemy (6 HP, attack 1), `maxTurns` 5. Any attack wins on turn 1. Passing every turn loses with "Turn limit reached". Mark it clearly `TEST ONLY` in a comment. It exists so the pipeline can be tested end to end without any real level.

Also write a short "how to add a level" section in `docs/protocol.md`: subclass `Level`, register it in `Levels`, add a reference solution and a deliberately wrong one to the tests.

### Event and result schema

Build JSON by hand with `StringBuilder`. No JSON library, because this code runs under TeaVM. Write one `quote()` helper that escapes `"`, `\`, `\n`, `\r`, `\t`, and other control characters as `\u00XX`, and treats null as an empty string.

Every event has `turn` and `type`. Core types:

| type | extra fields | notes |
|---|---|---|
| `spawn` | `unit`, `name`, `team` ("hero" or "enemy"), `hp`, `maxHp` | turn 0, one per unit |
| `intent` | `unit`, `action`, `target?` | telegraphed before the student acts |
| `action` | `unit`, `action` ("attack" or "pass"), `target?` | |
| `blocked` | `unit` (the target), `reason` | the action had no effect |
| `damage` | `unit`, `amount`, `hp` | `hp` is after damage |
| `death` | `unit` | |
| `end` | `won`, `reason` | last event of a scenario |

The schema is the contract with the Godot client. It can grow (new types, new optional fields) but never rename or remove. The type `probe` is reserved for future instrumentation; do not implement it.

Result object printed by `Main`:

```json
{"levelId":"...","passed":true,
 "scenarios":[{"seed":1,"won":true,"reason":"...","error":"","events":[...]}]}
```

`passed` is true only if every scenario was won. `error` is non-empty only when the student's code threw or returned something invalid.

Write all of this into `docs/protocol.md`, because the Godot side is built from it.

### TeaVM-safe subset

Harness and API code must stay inside what TeaVM's class library supports. Use `StringBuilder`, `ArrayList`, `HashMap`, `java.util.Random`, `Math`, and plain loops. Avoid reflection, `String.format`, streams, records, `java.time`, and anything touching files, threads, or the network. If you need something outside this list, stop and say so.

## 3. Compile service

Keep the existing HTTP server (`com.sun.net.httpserver`), port 8080, no framework.

**Request:** `POST /compile?level=<id>&student=<id>`. The body is the raw UTF-8 source of `Submission.java`. Ignore the request's `Content-Type`.
- `level` must match `[a-z0-9_]{1,40}`. It gets interpolated into the `node` command line, so this check is a security boundary. Nothing else from the request goes into a command.
- `student` is any string, default `anonymous`. It is only used to derive the seed: `(student + ":" + level).hashCode() & 0x7fffffffL`. Same student and level always give the same scenarios.
- Body limit is 50,000 bytes. Read at most limit+1 bytes and reject if over.

**Response:** always HTTP 200 for expected failures, always this envelope, always with `Access-Control-Allow-Origin: *` (including error paths; scope it after deploy) and `Content-Type: application/json`:

```json
{"status":"...","message":"...","console":"...","result":null}
```

| status | when |
|---|---|
| `ok` | the harness ran and produced a result; `result` is the harness JSON |
| `compile_error` | javac failed, TeaVM reported problems, or the source has a `package` line; `message` holds the text |
| `timeout` | `node` did not finish in 5 seconds |
| `runtime_error` | `node` exited non-zero, printed over 2 MB, or printed no result line; also unexpected server errors |
| `bad_request` | invalid `level`, oversized body |

**Pipeline**, in order:

1. Reject a `package` line at the start of any line (regex `(?m)^\s*package\s`) with a message telling them to remove it. Otherwise the failure shows up later as a confusing "cannot find symbol".
2. Create a temp dir. Write `Submission.java`. Copy every `.java` under `api/` and `harness/` into it, **preserving package directories** so class files land where the class loader expects them.
3. `javac` in-process via `ToolProvider`. On failure return `compile_error` with javac's output, with the temp-dir prefix stripped so students see `Submission.java:5: error: ...`.
4. TeaVM, same configuration as today, main class `Main`, JavaScript target, output `classes.js`. Any TeaVM problems become `compile_error`.
5. Run `node --max-old-space-size=256 -e "require('<path>').main(['<level>','<seed>'], cb)"` with the same callback shape as the existing code. Wait at most 5 seconds; on expiry kill the process and return `timeout` with the existing message.
6. **Redirect stdout and stderr to a file, not a pipe.** An unread pipe fills at about 64 KB and blocks `node`, which then looks exactly like a timeout. Event logs will exceed that once levels get bigger. If the file is over 2,000,000 bytes, return `runtime_error`.
7. Read the file. The **last** line starting with `@@DSAGAME_RESULT@@` is the result. Take the last one so a student who prints a fake marker line cannot override the harness, which prints last. Everything else is `console`: trimmed and truncated to 4,000 characters with a truncation note. No marker line means `runtime_error` with the raw output.
8. Delete the temp dir in a `finally`, on every path.

Do not add concurrency handling, sandboxing beyond the limits above, or caching. Those are deliberate later work.

## Tests

Write `examples/<case>/Submission.java` for each case below, and a script (`tests/e2e.sh` or your build tool's integration-test mechanism) that starts the server, posts each one against level `smoke`, and asserts on the response. **Run it against real TeaVM, not a JVM stand-in.** A JVM can pass code that TeaVM rejects.

| case | expected |
|---|---|
| attacks the first enemy | `ok`, `passed: true` |
| always returns `Action.pass()` | `ok`, `passed: false`, reason "Turn limit reached" |
| missing semicolon | `compile_error`, message contains `Submission.java:` and a line number |
| `while (true) {}` in `decide` | `timeout` in about 5s |
| has a `package foo;` line | `compile_error` |
| throws an exception with quotes and a newline in its message | `ok`, `error` non-empty, response is still valid JSON |
| returns `null` | `ok`, `error` mentions null |
| prints text and a fake `@@DSAGAME_RESULT@@` line, then plays normally | `ok`, real result wins, `console` has the printed text |
| `level=Bad Level!` | `bad_request` |

Plus two harness-level checks that do not need the server: the same seed twice gives byte-identical output, and different seeds give different scenarios.

## Definition of done

- Every row in the test table passes against real TeaVM.
- `dsagame-api.jar` builds, and `starter/Submission.java` compiles against it with `--release 17`.
- `docs/protocol.md` documents the envelope, statuses, event schema, result shape, and how to add a level.
- No temp dirs are left behind after a run.
- The harness contains no concrete level except `smoke`.

## Working rules

- When editing an existing file, preserve every existing comment exactly.
- Smallest change that works. No speculative features, no abstraction for a second use that does not exist yet.
- If something that used to work breaks, find the minimal delta from the last working state. Do not chain guesses. Verify each fix before trying the next, and ask or search if you are unsure.
- Commit in small steps, one per component, so any step can be reverted alone.
