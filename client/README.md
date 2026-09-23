# dsa-rpg client

The Godot 4 client for the compile service in `../server`. You write a
`Submission.java`, press Submit, and it replays the battle the server sends
back. This is a scaffold: every system is wired up with real signals, but the
visuals are just `print` calls.

## How to run it

1. Start the server: `cd ../server && ./gradlew run` (serves on `:8080`).
2. Open `client/project.godot` in Godot 4.7 and press **F5**. The main scene is
   `main.tscn`.
3. The editor starts with a sample submission. Press **Submit**. The spinner
   shows while the server compiles, then Scenario, Step, Skip to end and Reset
   appear. Each event prints to the Godot output panel, for example
   `damaged: { "turn": 1, "type": "damage", "unit": "e1", "amount": 10, "hp": 6 }`.
4. Delete a `;` and submit again. The error label shows the javac message, and
   the editor selects the line it points at.

**With no server running**, Submit fails right away and the error label reads
`Could not reach the server: no server at http://localhost:8080/compile?...`.
A request that hangs gives up after `timeout_sec`.

You can check each system from the command line, no editor needed:

```bash
godot --headless --path client res://dev/smoke_submit.tscn        # SubmitClient (needs server)
godot --headless --path client res://dev/smoke_simulation.tscn    # Simulation, from fixtures
godot --headless --path client res://dev/smoke_content.tscn       # Content lookups
godot --headless --path client res://dev/smoke_presentation.tscn  # Presentation, from fixtures
godot --headless --path client res://dev/smoke_flow.tscn          # whole client (needs server)
```

`dev/fixtures/` has real envelopes the server returned: `smoke_win.json`,
`demo_win.json` and `compile_error.json`.

## How to point it at a real server

Edit **`config/server_config.tres`**, either in the Inspector or as text:

| value | meaning |
|---|---|
| `server_url` | base URL, no trailing slash. `http://localhost:8080` today |
| `timeout_sec` | how long a submit waits before `submit_failed` |
| `default_level` | the `level` query parameter sent on Submit |
| `student` | the `student` query parameter; it only seeds the scenarios |

These are the only settings. Scripts read them through the `Config` autoload
(`Config.settings.server_url`), and nothing else hardcodes a URL. The
defaults in `config/server_config.gd` only apply when the `.tres` leaves a
value out.

In a web export, the server already sends `Access-Control-Allow-Origin: *`.

## The JSON format

It is **defined** in `../server/docs/protocol.md`, which is the contract; read
that for the details. It is **consumed** in one place, `sim/simulation.gd`
(`load_battle` and `step`). `SubmitClient` only decodes the JSON.

### Envelope

Every response is HTTP 200 with this shape:

| field | meaning |
|---|---|
| `status` | `ok`, `compile_error`, `timeout`, `runtime_error` or `bad_request` |
| `message` | error text; empty when `ok` |
| `console` | what the student's code printed |
| `result` | `{levelId, passed, scenarios[]}` when `ok`, otherwise `null` |

Each scenario is `{seed, won, reason, error, events[]}`. `error` is non-empty
when the student's code threw or returned something illegal. That still has
status `ok`: the events stop where the code broke, and `end.reason` repeats the
error.

### Events

Every event has `turn` (0 for spawns) and `type`. `unit` and `target` are unit
ids, matching the `unit` of a `spawn`.

| `type` | extra fields | Simulation signal |
|---|---|---|
| `spawn` | `unit`, `name`, `team` (`hero`/`enemy`), `hp`, `maxHp` | `spawned(event)` |
| `intent` | `unit`, `action` (move id), `target?` | `intent(event)` |
| `action` | `unit`, `action` (move id), `target?` | `action(event)` |
| `blocked` | `unit` (the target), `reason` | `blocked(event)` |
| `damage` | `unit`, `amount`, `hp` (after) | `damaged(event)` |
| `heal` | `unit`, `amount`, `hp` (after) | `healed(event)` |
| `death` | `unit` | `died(event)` |
| `end` | `won`, `reason` | `ended(won, reason)` |
| anything else | | `unknown_event(event)`, and replay carries on |

Simulation also emits `battle_loaded(scenario_count)`,
`scenario_reset(index)`, and `submission_failed(message, line)` when
`status != "ok"`. `line` is the `Submission.java:N:` line from javac, or -1.
Simulation converts every JSON number to `int` on load, so listeners get
`hp: 30`, not `30.0`.

A lost battle (`passed: false`) is still a battle. It replays normally, and
`ended(false, reason)` reports the loss. Only a non-`ok` status is kept away
from Presentation.

### Example: a win

`POST /compile?level=smoke&student=alice`, with `scenarios` trimmed to the
first of three:

```json
{"status": "ok", "message": "", "console": "",
 "result": {"levelId": "smoke", "passed": true, "scenarios": [
  {"seed": 1042256885, "won": true, "reason": "All enemies defeated", "error": "",
   "events": [
    {"turn": 0, "type": "spawn", "unit": "hero", "name": "Hero", "team": "hero", "hp": 30, "maxHp": 30},
    {"turn": 0, "type": "spawn", "unit": "e1", "name": "Slime", "team": "enemy", "hp": 6, "maxHp": 6},
    {"turn": 1, "type": "intent", "unit": "e1", "action": "attack", "target": "hero"},
    {"turn": 1, "type": "action", "unit": "hero", "action": "attack", "target": "e1"},
    {"turn": 1, "type": "damage", "unit": "e1", "amount": 6, "hp": 0},
    {"turn": 1, "type": "death", "unit": "e1"},
    {"turn": 1, "type": "end", "won": true, "reason": "All enemies defeated"}]}]}}
```

`dev/fixtures/demo_win.json` is a longer one, with a party, `heal` and `drain`.

### Example: a compile error

```json
{"status": "compile_error",
 "message": "Submission.java:6: error: ';' expected\n        return Action.pass()\n                            ^\n1 error\n",
 "console": "", "result": null}
```

Simulation turns this into `submission_failed("Submission.java:6: error: ...", 6)`.

## How to change the format

The server only ever adds to the protocol: new event types and new optional
fields, never renames. Here is what to change in Godot for each kind of
server change:

| server change | files to change in Godot |
|---|---|
| **new event type** | `sim/simulation.gd`: add a `signal`, add a `match` branch in `step()` that updates state (if it affects HP or alive) and emits it. `presentation/presentation.gd`: connect the new signal in `listen_to()`. Until you do, it arrives as `unknown_event` and nothing breaks. |
| **new field on an existing event** | Nothing, if it is just for display: it is already in the `event` Dictionary Presentation receives. If it changes unit state, `sim/simulation.gd` (`step()`, plus the state dict in the `spawn` branch). |
| **new field on the envelope or a scenario** | `sim/simulation.gd`: expose it next to `current_scenario()`. If the UI shows it, `ui/flow.gd` plus one connection in `battle_controller.gd`. |
| **new status** | Nothing: any status other than `ok` already becomes `submission_failed`. |
| **new move or unit on the server** | `autoload/content.gd`: register a row for it. |
| **new request parameter** | `config/server_config.gd` + `.tres` if it is a setting, and `autoload/submit_client.gd` where the URL is built. |

Also update the event table above.

## The five systems

| system | where | signals across the boundary |
|---|---|---|
| Network/Submit | `autoload/submit_client.gd` (autoload `SubmitClient`), with `autoload/config.gd` + `config/server_config.tres` | out: `result_ready(envelope)`, `submit_failed(reason)` |
| Simulation | `sim/simulation.gd`, a node in `main.tscn` | in: `load_battle`, `step`, `skip_to_end`, `reset`, `select_scenario`. Out: the event signals above, plus `battle_loaded`, `scenario_reset`, `submission_failed` |
| Content | `autoload/content.gd` (autoload `Content`), with `content/unit_data.gd` and `content/move_data.gd` | none. `get_unit` / `get_move` lookups |
| Presentation | `presentation/presentation.tscn` + `.gd` | in: every Simulation signal, through `listen_to(sim)`. Reads Content |
| Flow/UI | `ui/flow.tscn` + `.gd` | out: `submit_pressed(source)`, `step_pressed`, `skip_pressed`, `reset_pressed`, `scenario_selected(index)`. In: `show_transport_error`, `show_submission_error`, `show_battle` |

`battle_controller.gd` (the root of `main.tscn`) makes every cross-system
connection, all in its `_ready()`. Two things are not in that function:
Presentation looks names up in Content, and SubmitClient reads Config. No
autoload references a scene node.

`submit_failed` and `submission_failed` both put Flow in its `ERROR` state, as
two separate connections to two methods. One means the server could not be
reached, the other means your code did not compile.

## Where you add content

Both call sites are in `autoload/content.gd`, in `_ready()`:

```gdscript
register_unit("Goblin", placeholder_unit)   # PLACEHOLDER: delete me
register_move("attack", placeholder_move)   # PLACEHOLDER: delete me
```

The whole placeholder block is marked `--- PLACEHOLDER ---`. Replace it with
your own rows:

- **Units** are keyed by the spawn event's **`name`** (`"Goblin"`, `"Knight"`),
  not by its `unit` id. `unit` is per battle (`e1`, `e2`), and there are two
  `Goblin`s in `demo`. The protocol has no separate unit-kind id, so `name`
  is the only one available. If display names and kinds ever need to differ,
  the fix is a new optional `kind` field on `spawn`, server-side.
- **Moves** are keyed by move id, the `action` field of `action`/`intent`
  events: `attack`, `pass`, `heal`, `smite`, `drain`, ...

`get_unit` and `get_move` return `null` for a missing row, and Presentation
prints `(no Content row for ...)` instead of failing.
