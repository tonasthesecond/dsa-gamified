# DSA Game protocol

The contract between the compile service, the harness, and the Godot client.
The client only animates events; every rule lives on the server.

The schema can grow — new event types, new optional fields — but a field is
never renamed or removed, so an old client keeps working. The event type
`probe` is reserved for future instrumentation and is not implemented.

## Request

```
POST /compile?level=<id>&student=<id>
```

The body is the raw UTF-8 source of `Submission.java`. The request's
`Content-Type` is ignored.

| parameter | rule |
|---|---|
| `level` | must match `[a-z0-9_]{1,40}` |
| `student` | any string, default `anonymous` |

The body is limited to 50,000 bytes.

`student` only derives the seed: `(student + ":" + level).hashCode() & 0x7fffffffL`.
The same student and level always get the same scenarios.

## Response

Always HTTP 200 with `Content-Type: application/json` and
`Access-Control-Allow-Origin: *`, including on every error path, and always this
envelope:

```json
{"status":"...","message":"...","console":"...","result":null}
```

| field | meaning |
|---|---|
| `status` | one of the statuses below |
| `message` | the error text; empty when `status` is `ok` |
| `console` | whatever the student printed, trimmed and truncated to 4,000 characters |
| `result` | the harness result object when `status` is `ok`, otherwise `null` |

| status | when |
|---|---|
| `ok` | the harness ran and produced a result |
| `compile_error` | javac failed, TeaVM reported problems, or the source has a `package` line |
| `timeout` | the run did not finish in 5 seconds |
| `runtime_error` | the run exited non-zero, printed over 2 MB, or printed no result line; also unexpected server errors |
| `bad_request` | invalid `level`, oversized body |

A failing status is not an HTTP error: expected failures are part of playing the
game, so the client reads `status`, not the HTTP code.

## Result

```json
{"levelId":"smoke","passed":true,
 "scenarios":[{"seed":1,"won":true,"reason":"All enemies defeated","error":"","events":[]}]}
```

| field | meaning |
|---|---|
| `levelId` | the level that was played |
| `passed` | true only if every scenario was won |
| `scenarios` | one entry per scenario, in order |
| `scenarios[].seed` | the scenario's seed; scenario `i` uses `seed + i * 7919` |
| `scenarios[].won` | whether the hero won this scenario |
| `scenarios[].reason` | why the scenario ended, shown to the player |
| `scenarios[].error` | non-empty only when the student's code threw or returned something invalid |
| `scenarios[].events` | the full battle, in order |

A scenario that ends in an error keeps the events it got through, so the client
can still replay up to the point where the code broke.

## Events

Every event has `turn` and `type`. Spawns are turn 0; the first turn is 1.

| type | extra fields | notes |
|---|---|---|
| `spawn` | `unit`, `name`, `team` (`hero` or `enemy`), `hp`, `maxHp` | turn 0, one per unit |
| `intent` | `unit`, `action`, `target?` | telegraphed before the student acts |
| `action` | `unit`, `action` (`attack` or `pass`), `target?` | |
| `blocked` | `unit` (the target), `reason` | the action had no effect |
| `damage` | `unit`, `amount`, `hp` | `hp` is after the damage |
| `death` | `unit` | |
| `end` | `won`, `reason` | the last event of a scenario |

`unit` and `target` are unit ids, matching the `unit` of a `spawn`. `target` is
absent on a pass.

### Turn order

1. Every living enemy telegraphs an intent (`intent`).
2. The student's `decide` is called with a snapshot of the battle.
3. The student's action resolves: `action`, then `blocked` or `damage` and
   possibly `death`.
4. If no enemy is left alive, the scenario is won (`end`).
5. Every living enemy carries out its telegraphed intent, in spawn order. If the
   hero reaches 0 HP the scenario is lost (`end`).

If the turn limit runs out, the scenario is lost with the reason
"Turn limit reached".

## Output framing

The harness and the student share stdout, so the harness prints a blank line and
then one line that is `@@DSAGAME_RESULT@@` immediately followed by the result
JSON. The service takes the **last** such line — the harness prints last, so a
student who prints a fake marker line cannot override the real result. Every
other line becomes `console`.

## How to add a level

1. Subclass `Level` in `harness/`:

   ```java
   class ExampleLevel extends Level {
       String id() { return "example"; }

       List<Combatant> setup(long seed) {
           List<Combatant> units = new ArrayList<Combatant>();
           units.add(new Combatant("hero", "Hero", 30, 6, false));
           units.add(new Combatant("e1", "Goblin", 12, 3, true));
           return units;
       }
   }
   ```

   `setup` returns the hero first, then the enemies, and must be deterministic
   for a given seed. Override `scenarioCount` (default 3), `maxTurns`
   (default 20), `chooseIntent` (default: attack the hero) and `blockReason`
   (default: the hit lands) only where the level differs from a plain fight. Use
   `battle.random` for anything random, so replays stay identical.

2. Register it in `Levels.get` — one line.

3. Add tests: a reference solution that wins and a deliberately wrong one that
   loses, as `examples/<case>/Submission.java`, with assertions in
   `tests/e2e.sh`.

Add a new hook to `Level` only when a real level needs it.

## Harness and API limits

The harness and `dsagame.api` are cross-compiled by TeaVM, so they stay inside
what its class library supports: `StringBuilder`, `ArrayList`, `HashMap`,
`java.util.Random`, `Math` and plain loops. No reflection, `String.format`,
streams, records, `java.time`, files, threads or network. JSON is built by hand
with `StringBuilder` for the same reason.
