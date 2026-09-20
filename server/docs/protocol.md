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
| `scenarios[].won` | whether the party won this scenario |
| `scenarios[].reason` | why the scenario ended, shown to the player |
| `scenarios[].error` | non-empty only when the student's code threw or returned something invalid |
| `scenarios[].events` | the full battle, in order |

A scenario that ends in an error keeps the events it got through, so the client
can still replay up to the point where the code broke.

`reason` is free text meant for the player. The usual values are
"All enemies defeated", "Party defeated" and "Turn limit reached"; when `error`
is set, `reason` repeats it.

## Events

Every event has `turn` and `type`. Spawns are turn 0; the first turn is 1.

| type | extra fields | notes |
|---|---|---|
| `spawn` | `unit`, `name`, `team` (`hero` or `enemy`), `hp`, `maxHp` | turn 0, one per unit |
| `intent` | `unit`, `action`, `target?` | telegraphed before the party acts |
| `action` | `unit`, `action` (a move id), `target?` | |
| `blocked` | `unit` (the target), `reason` | the action had no effect |
| `damage` | `unit`, `amount`, `hp` | `hp` is after the damage |
| `heal` | `unit`, `amount`, `hp` | `hp` is after the healing; `amount` is what it actually got, so it is 0 on a unit already at full health |
| `death` | `unit` | |
| `end` | `won`, `reason` | the last event of a scenario |

`unit` and `target` are unit ids, matching the `unit` of a `spawn`.

The `action` field on `action` and `intent` is the id of the move being used.
`attack` and `pass` are the two every combatant has, so they read exactly as
they always did; a level's own moves use their own ids, such as `heal` or
`drain`. A move aimed at whoever is using it, like `pass`, has no `target`.

### Compatibility notes

Everything above is a superset of the first version of this protocol:

- `heal` is a new event type. A client that ignores unknown types still replays
  correctly, it just misses the healing.
- `action` on the `action` and `intent` events used to be only `attack` or
  `pass`. It is now any move id; those two keep their spelling and meaning.
- There can now be more than one unit with `team: hero`, and the party acts in
  spawn order within a turn.

No field has been renamed or removed.

### Turn order

1. Every living enemy telegraphs an intent (`intent`): the move it will use and
   who it will use it on.
2. Everyone acts, the party first in spawn order, then the enemies in spawn
   order. Anyone who died earlier in the turn is skipped.
   - For a hero, the student's `decide` is called with a snapshot taken right
     then, so a later hero sees what the earlier ones already did.
   - An enemy carries out what it telegraphed. If its target died first, it
     still emits its `action` and nothing happens.
3. Each action resolves: `action`, then `blocked`, or the move's own events —
   `damage` and possibly `death`, `heal`, or both for something like `drain`.
4. After every single action: if no enemy is left alive the scenario is won, and
   if no hero is left alive it is lost (`end`).

If the turn limit runs out, the scenario is lost with the reason
"Turn limit reached".

A scenario that ends because the student's code misbehaved — it threw, returned
null, or used a move its hero does not know — ends on an `end` event whose
`reason` is the error message.

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
           units.add(Heroes.knight("knight"));
           units.add(Monsters.goblin("e1", 12));
           return units;
       }
   }
   ```

   `setup` returns the party first, then the enemies, and must be deterministic
   for a given seed. Override `scenarioCount` (default 3), `maxTurns`
   (default 20), `chooseIntent` (default: the enemy's first move on the first
   living hero) and `blockReason` (default: the hit lands) only where the level
   differs from a plain fight. Use `battle.random` for anything random, so
   replays stay identical. See `docs/adding-moves.md` for the moves themselves.

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
