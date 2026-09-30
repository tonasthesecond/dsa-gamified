# Development guide

How the whole thing fits together, what each piece is called and where it
lives, and step-by-step recipes for adding moves, enemies, heroes and levels on
both the Java side and the Godot side.

The detailed references are still:

- `server/docs/protocol.md`: the JSON contract between server and client.
- `client/README.md`: the client's event table and "how to change the format".

This file is the map. Start here.

---

## 1. The big picture

```
 ┌──────────── Godot client (client/) ────────────┐        ┌──────── Java server (server/) ────────┐
 │                                                │  HTTP  │                                       │
 │  Flow (UI) ──submit_pressed──► SubmitClient ───┼──POST──┼─► Server.java                         │
 │                                                │        │     javac + TeaVM + node              │
 │                                                │        │        │                              │
 │                                                │        │        ▼                              │
 │                                                │        │     Main.java  (the harness)          │
 │                                                │        │       runs the battle with the        │
 │                                                │        │       student's Submission, writes    │
 │                                                │        │       every event to a JSON log       │
 │  Simulation ◄──result_ready(envelope)── SubmitClient ◄──┼── JSON event log                      │
 │     │  one signal per event, on Step           │        │                                       │
 │     ▼                                          │        └───────────────────────────────────────┘
 │  Presentation  (draws it: today, print calls)  │
 └────────────────────────────────────────────────┘
```

The important idea: **the server plays the whole battle, the client only
replays it.** All game rules (damage, healing, who acts when, win/loss) are in
Java. The client never computes damage. It receives a list of events like
"e1 took 6 damage, now has 0 hp" and animates them one at a time.

So:

- A new **rule or mechanic** is Java work.
- A new **visual** is Godot work.
- A new **move or enemy** is usually both: Java to make it exist, Godot to give
  it a name and an animation.

---

## 2. Java side (`server/`)

Run everything from `server/`.

```bash
./gradlew run             # serve on :8080
tests/e2e.sh              # full test suite (builds, starts its own server)
tests/harness-test.sh     # determinism checks only, fast
```

### 2.1 The pieces

| piece | file(s) | what it does |
|---|---|---|
| **Server** | `src/main/java/compileservice/Server.java` | The HTTP service. For each request it writes the student's code to a temp dir, copies `api/` and `harness/` next to it, compiles with `javac`, cross-compiles to JavaScript with TeaVM, runs it with `node`, and sends back the result line. You almost never touch this. |
| **Student API** | `api/dsagame/api/*.java` | What students code against: `Strategy` (the interface they implement), `GameState`, `Unit`, `MoveInfo`, `Action`, `TargetKind`. These are read-only snapshots, so students can't cheat by editing hp. |
| **Main** | `harness/Main.java` | The battle loop. Entry point of the compiled program. For each scenario of the level it creates the units, a fresh `Submission`, and runs turns until someone wins or the turn limit hits. Prints the JSON result. |
| **Battle** | `harness/Battle.java` | The state of one fight: the list of combatants, the RNG, the event log. Holds the **primitives** (`dealDamage`, `heal`, `block`), the one legality check (`useError`), turn order (`turnOrder`) and `use`, which runs a move. |
| **EventLog** | `harness/EventLog.java` | Builds the JSON events. Only `Battle` and `Main` call it. |
| **Combatant** | `harness/Combatant.java` | A fighter in a battle: id, name, hp, attack, which team, which moves. Mutable. Students see a `Unit` snapshot of it. |
| **Move** | `harness/Move.java` | An action a combatant can take: id, name, description, target kind, power, and a **list of effects**. |
| **Effect** | `harness/Effect.java` + `DamageEffect`, `HealEffect`, `BlockEffect` | One step of a move. A move runs its effects in order. |
| **MoveState** | `harness/MoveState.java` | Scratch notepad shared by the effects of one move use, so a later effect can read what an earlier one did (drain heals by the damage that landed). |
| **Moves** | `harness/Moves.java` | Catalogue of every move: one static factory each. |
| **Heroes / Monsters** | `harness/Heroes.java`, `harness/Monsters.java` | Catalogue of every fighter: one static factory each. |
| **Level** | `harness/Level.java` + `SmokeLevel`, `DemoLevel` | One exercise: who fights, how many scenarios, turn limit, what enemies do. |
| **Levels** | `harness/Levels.java` | Registry: level id string → `Level` object. |

### 2.2 What happens in one turn (`Main.runScenario`)

1. Every living enemy picks an **intent** (`level.chooseIntent`) and it is
   logged. The student can see intents through `Unit.getIntent()`.
2. Everyone acts in `battle.turnOrder()`: heroes first in party order, then
   enemies.
   - Hero: the student's `decide(state)` is called and returns an `Action`.
   - Enemy: it does what it telegraphed.
3. `battle.useError` checks the action is legal (move is known, target exists,
   is alive, is the right kind). If a hero's action is illegal, the scenario is
   lost with an error message. If an enemy's is (its target died), it's skipped.
4. `battle.use(move, user, target, ...)` runs the move's effects. The effects
   call the primitives, and the primitives log the events.
5. After every action, check win/loss.

### 2.3 Rules you must not break

- **Everything in `harness/` stays flat, in the default package.** No
  subfolders, no `package` line.
- **TeaVM subset only.** `ArrayList`, `HashMap`, `StringBuilder`,
  `java.util.Random`, `Math`, index `for` loops. No streams, lambdas-over-streams,
  `String.format`, records, reflection, `java.time`, threads.
- **Deterministic.** Randomness comes only from `new Random(seed)` in
  `Level.setup` or from `battle.random`. Never iterate a `HashMap` to decide
  anything.
- **A move/effect never builds an event.** It calls `battle.dealDamage`,
  `battle.heal` or `battle.block`, which log for it.
- **New content should not touch `Main`, `Battle` or `Server`.** The one
  exception is a genuinely new primitive on `Battle` (see 2.6).

### 2.4 Adding a move

Three cases, from easiest to hardest.

**(a) It's a plain hit or heal with different numbers.** One factory in
`Moves.java`, nothing else:

```java
static Move fireball() {
    int power = 7;
    return new Move("fireball", "Fireball", "Hit one enemy for your attack plus " + power + ".",
            TargetKind.ENEMY, power, new DamageEffect(power));
}
```

The first argument, `"fireball"`, is the **move id**. It's what students
pass back in `Action.use`, and it's the `move` field on every event the move
causes. The Godot side keys off it too. Pick it once and don't rename it.

`TargetKind` is `ENEMY`, `ALLY` (includes self) or `SELF`.

**(b) It combines existing effects.** Still one factory. Effects run in order
and share a `MoveState`:

```java
// Hit, then heal yourself by what landed (this is the real `drain`).
new Move("drain", ..., TargetKind.ENEMY, power,
        new DamageEffect(power), HealEffect.userFromState(MoveState.DAMAGE));
```

**(c) It needs a new mechanic.** Write a new `Effect` subclass in its own file
in `harness/`, then use it in a `Moves` factory. Example: a reckless hit where
the user takes half the damage it dealt as recoil.

`harness/RecoilEffect.java`:

```java
/** Hurts the user by a fraction of the damage an earlier effect of this move landed. */
class RecoilEffect extends Effect {
    private final int divisor;

    RecoilEffect(int divisor) {
        this.divisor = divisor;
    }

    void apply(Battle battle, Combatant user, Combatant target, MoveState state) {
        battle.dealDamage(user, state.get(MoveState.DAMAGE) / divisor);
    }
}
```

`harness/Moves.java`:

```java
static Move reckless() {
    int power = 6;
    return new Move("reckless", "Reckless Swing",
            "Hit one enemy for your attack plus " + power + ", and take half of it yourself.",
            TargetKind.ENEMY, power, new DamageEffect(power), new RecoilEffect(2));
}
```

On the wire that produces an `action`, then two `damage` events, both with
`"move":"reckless"`: one on the target, one on the user. No protocol change,
no client code change needed for it to replay.

For a move that should *refuse* under some condition (e.g. "can't hit flying
enemies"), subclass `BlockEffect`, implement `reason(...)` to return a message
or `null`, and put it **first** in the effects list. If it returns a reason it
logs a `blocked` event and the rest of the move is skipped.

**Giving the move to someone:** add it to a hero or monster's move list (next
section). A move nobody has does nothing.

### 2.5 Adding an enemy (or a hero)

One factory in `Monsters.java` (or `Heroes.java`):

```java
static Combatant orc(String id, int maxHp) {
    return new Combatant(id, "Orc", maxHp, 4, true, Moves.reckless(), Moves.attack());
}
```

Arguments: per-battle id (`"e1"`), **name** (`"Orc"`), max hp, attack,
`true` for enemy / `false` for hero, then its moves in order. `pass` is added
automatically.

- The **name** is what the Godot client uses to look up the unit's art, so
  treat it as an id too.
- **Order matters for enemies:** by default an enemy uses its **first** move on
  the first living hero every turn. If the first move is a heal, or you want
  smarter AI, override `chooseIntent` in the level (below).

Then put it in a level's `setup`.

### 2.6 Adding a level

Create `harness/ExampleLevel.java`:

```java
import java.util.ArrayList;
import java.util.List;
import java.util.Random;

class ExampleLevel extends Level {
    String id() { return "example"; }

    List<Combatant> setup(long seed) {
        Random random = new Random(seed);
        List<Combatant> units = new ArrayList<Combatant>();
        units.add(Heroes.knight("knight"));            // heroes first
        units.add(Monsters.orc("e1", 20 + random.nextInt(6)));  // then enemies
        return units;
    }
}
```

Register it with one line in `Levels.get`:

```java
if ("example".equals(id)) {
    return new ExampleLevel();
}
```

Optional overrides on `Level`:

| override | default | use it for |
|---|---|---|
| `scenarioCount()` | 3 | how many seeds the student's code is tested on |
| `maxTurns()` | 20 | turn limit before it's a loss |
| `chooseIntent(enemy, battle)` | first move on first living hero | enemy AI. Return `new Intent(move, target)`; use `battle.random` for randomness |
| `blockReason(target, battle)` | `null` | a level-wide rule like "this boss is shielded until X" |

**When you really do need to touch `Battle`:** only if a mechanic can't be
expressed as damage, heal or block. Things like status effects over time
(poison, stun), buffs to `attack`, or shields that persist between turns need
state on `Combatant` plus a new primitive on `Battle` that logs a new event
type. That's a protocol addition: document the new event in
`server/docs/protocol.md`, and give it a `move` field so the client picks it up
automatically.

### 2.7 Testing Java changes

1. Write two submissions under `server/examples/<case>/Submission.java`: one
   that wins your level and one that loses.
2. Add assertions for them in `server/tests/e2e.sh` (copy the `demo_win` /
   `demo_lose` blocks).
3. Run `tests/e2e.sh`. It goes through the real TeaVM, and **code the JVM
   accepts can still fail in TeaVM**, so don't trust the quick loop alone.

Quick inner loop, no server, plain JVM (a smoke test only):

```bash
rm -rf build/check && mkdir -p build/check/dsagame/api
cp examples/demo_win/Submission.java harness/*.java build/check/
cp api/dsagame/api/*.java build/check/dsagame/api/
javac --release 17 -d build/check/out $(find build/check -name '*.java')
java -cp build/check/out Main demo 1
```

Against a running server:

```bash
curl -s --data-binary @examples/demo_win/Submission.java \
  "http://localhost:8080/compile?level=example&student=alice"
```

Don't change `SmokeLevel` or the numbers it uses. Its output is pinned and
the tests use it to catch regressions.

---

## 3. Godot side (`client/`)

Open `client/project.godot` in Godot 4.7, start the server, press F5.

### 3.1 The pieces

`main.tscn` is the running game. Its tree:

```
BattleController   (battle_controller.gd)  ← wires everything together
├── Simulation     (sim/simulation.gd)
├── Presentation   (presentation/presentation.tscn)
└── Flow           (ui/flow.tscn)
```

Plus three **autoloads** (global singletons, see Project Settings → Autoload):
`Config`, `SubmitClient`, `Content`.

| system | file | in plain words |
|---|---|---|
| **Flow** | `ui/flow.gd`, `ui/flow.tscn` | **The UI screen**: the code editor, the Submit button, the spinner, the error label, and the replay buttons (Scenario dropdown, Step, Skip, Reset). It's a small state machine: `IDLE → SUBMITTING → REPLAYING` or `ERROR`. It knows nothing about battles. It only reports "the player clicked X" through signals, and shows whatever it's told to show. |
| **SubmitClient** | `autoload/submit_client.gd` | **The network layer.** `SubmitClient.submit(source, level)` POSTs the code to the server. Emits `result_ready(envelope)` with the decoded JSON, or `submit_failed(reason)` if the server couldn't be reached. |
| **Config** | `autoload/config.gd`, `config/server_config.tres` | **Settings**: server URL, timeout, level, student name. Edit the `.tres`. |
| **Simulation** | `sim/simulation.gd` | **The replay engine.** Takes the server's JSON and steps through its events one at a time, like a tape player. It keeps a tiny bit of state (each unit's hp, alive or dead) and emits **one signal per event**. No animation, no timers, no visuals. |
| **Presentation** | `presentation/presentation.gd`, `.tscn` | **What the player sees of the battle.** Listens to Simulation's signals and draws them. Right now it just `print`s each one. **This is the file you rebuild with sprites, tweens and health bars.** |
| **Content** | `autoload/content.gd`, `content/unit_data.gd`, `content/move_data.gd` | **The client's catalogue**: display name, description, scene and animation key for each unit and move id. Presentation looks things up here. |
| **BattleController** | `battle_controller.gd` | **The switchboard.** The only script that knows about more than one system. All the connections are in its `_ready()`: Flow's Submit → SubmitClient, SubmitClient's result → Simulation, Simulation → Presentation, Flow's Step/Skip/Reset → Simulation. |

"Main" on the Godot side is just `main.tscn`, the scene that holds the four
nodes above. On the Java side `Main.java` is the battle loop. They're
unrelated.

### 3.2 The flow of one submit

1. Player clicks **Submit** → `Flow.submit_pressed(source)`.
2. BattleController → `SubmitClient.submit(source, level)`. Flow shows the
   spinner.
3. Server responds → `SubmitClient.result_ready(envelope)` →
   `Simulation.load_battle(envelope)`.
4. If `status != "ok"` (compile error, timeout...) → `Simulation.submission_failed(message, line)`
   → `Flow.show_submission_error` highlights the line.
   Otherwise → `Simulation.battle_loaded(count)` → `Flow.show_battle` shows the
   replay controls, and scenario 0 is selected.
5. Player clicks **Step** → `Simulation.step()` applies one event and emits its
   signal → Presentation animates it. **Skip** → `skip_to_end()` steps until
   done. **Reset** → back to event 0, emits `scenario_reset`.

### 3.3 Simulation signals (what Presentation listens to)

Every event signal carries the raw event `Dictionary` from the server (see the
event table in `server/docs/protocol.md`). Numbers are already `int`.

| signal | fires for | useful fields | typical visual |
|---|---|---|---|
| `battle_loaded(scenario_count)` | a good envelope arrived | | clear the stage |
| `scenario_reset(index)` | Reset, or a scenario was picked | | remove all unit nodes, start over |
| `submission_failed(message, line)` | compile error etc. | | (Flow handles it) |
| `spawned(event)` | `spawn` | `unit` (id like `"e1"`), `name` (`"Goblin"`), `team` (`"hero"`/`"enemy"`), `hp`, `maxHp` | create the unit's sprite, look up `Content.get_unit(event.name)` |
| `intent(event)` | `intent` | `unit`, `move`, `target` | show an icon over the enemy of what it will do |
| `action(event)` | `action` | `unit`, `move`, `target` (missing for `pass`) | play the user's attack/cast animation, `Content.get_move(event.move)` |
| `effect_applied(event)` | **everything a move did**: `damage`, `heal`, `blocked`, and any future effect type | `type`, `unit` (who was affected), `move`, and `amount`, `hp` or `reason` | hit flash, damage number, health bar tween |
| `died(event)` | `death` | `unit` | death animation, remove sprite |
| `ended(won, reason)` | `end` | | victory/defeat banner |
| `unknown_event(event)` | a new structural event the client doesn't know yet | | ignore; replay continues |

Typical sequence for one knight attack that kills a goblin:

```
action          {unit: "knight", move: "smite", target: "e1"}
effect_applied  {type: "damage", unit: "e1", amount: 10, hp: 0, move: "smite"}
died            {unit: "e1"}
```

**Why `effect_applied` is one signal:** any event caused by a move carries a
`move` field, and they all go through `effect_applied`. A new effect on the
server (like the recoil above, or a future `poison` event) arrives in Godot
with **no change to Simulation**. Presentation decides what it looks like.

You can also ask Simulation for current state at any time:
`simulation.unit_ids()`, `simulation.unit_state("e1")` →
`{name, team, hp, max_hp, alive}`, `simulation.turn`, `simulation.current_scenario()`.

### 3.4 Presentation hooks

Presentation dispatches `effect_applied` through two dictionaries at the top of
`presentation/presentation.gd`:

```gdscript
# By event type. One entry per kind of effect.
var type_hooks: Dictionary[String, Callable] = {
	"damage": func(event): ...,
	"heal": func(event): ...,
	"blocked": func(event): ...,
}
# By move id. Extra flourish for one specific move, runs after the type hook.
var move_hooks: Dictionary[String, Callable] = {}
```

So the recoil from `reckless` is a `damage` event and already plays the normal
damage visual. If you want something special for it:

```gdscript
var move_hooks: Dictionary[String, Callable] = {
	"reckless": func(event: Dictionary) -> void: _screen_shake(),
}
```

A brand-new effect type from the server (say `"poison"`) is one more entry in
`type_hooks`. If you don't add one, it prints `effect_applied (no type hook
for poison)` and the replay carries on. `hp` is still applied in Simulation if
the event has it.

### 3.5 Adding a move or enemy in Godot

After adding it on the server, register it in `autoload/content.gd`, in
`_ready()`. Replace the `--- PLACEHOLDER ---` block with real rows:

```gdscript
func _ready() -> void:
	var orc := UnitData.new()
	orc.display_name = "Orc"
	orc.scene = preload("res://units/orc.tscn")   # optional until there's art
	register_unit("Orc", orc)                      # key = the Java *name*, not "e1"

	var reckless := MoveData.new()
	reckless.display_name = "Reckless Swing"
	reckless.description = "Big hit, but you take half of it yourself."
	reckless.animation_key = &"heavy_swing"
	register_move("reckless", reckless)            # key = the Java move id
```

You can also make `.tres` resources of `UnitData` / `MoveData` in the editor and
`load()` them here instead of building them in code.

Keys must match the server exactly:

| Godot key | comes from Java |
|---|---|
| `register_unit("Orc", ...)` | 2nd argument of `new Combatant(id, "Orc", ...)` |
| `register_move("reckless", ...)` | 1st argument of `new Move("reckless", ...)` |

A missing row is not a crash: `get_unit`/`get_move` return `null` and
Presentation prints `(no Content row for ...)`.

### 3.6 Testing Godot without the server

Simulation doesn't care where the JSON comes from. Feed it a saved response:

```gdscript
var sim: Simulation = $Simulation
presentation.listen_to(sim)
sim.load_battle(JSON.parse_string(FileAccess.get_file_as_string("res://dev/fixtures/demo_win.json")))
sim.step()          # one event
sim.skip_to_end()   # all of it
```

That is exactly what `dev/smoke_presentation.gd` does. The fixtures in
`dev/fixtures/` are real server responses. To make one for new content, save
the server's output:

```bash
cd server && curl -s --data-binary @examples/<case>/Submission.java \
  "http://localhost:8080/compile?level=example&student=alice" > ../client/dev/fixtures/example_win.json
```

Headless checks, from the repo root:

```bash
godot --headless --path client res://dev/smoke_simulation.tscn
godot --headless --path client res://dev/smoke_presentation.tscn
godot --headless --path client res://dev/smoke_content.tscn
godot --headless --path client res://dev/smoke_flow.tscn      # needs server
```

To try a different level from the editor, change `default_level` in
`config/server_config.tres`.

---

## 4. Checklists

**New move (existing effects only)**
1. `server/harness/Moves.java`: factory.
2. Give it to someone in `Heroes.java` / `Monsters.java`.
3. `client/autoload/content.gd`: `register_move("<id>", ...)`.
4. Optional: `move_hooks` entry in `presentation.gd`.
5. Example submissions + `tests/e2e.sh`, run it.

**New move with a new mechanic**
Same as above, plus a new `server/harness/<Name>Effect.java`. If it can't be
built from `dealDamage`/`heal`/`block`, it needs a new `Battle` primitive and a
new event type, which means a `server/docs/protocol.md` update and a
`type_hooks` entry in `presentation.gd`.

**New enemy / hero**
1. `server/harness/Monsters.java` or `Heroes.java`: factory.
2. Put it in a level's `setup`.
3. `client/autoload/content.gd`: `register_unit("<Name>", ...)`.

**New level**
1. `server/harness/<Name>Level.java`, a `Level` subclass.
2. One line in `Levels.get`.
3. A winning and a losing `examples/<case>/Submission.java`, asserted in
   `tests/e2e.sh`.
4. Client: set `default_level`, or add a level picker to Flow.

**Nothing in this list touches** `Main.java`, `Battle.java`, `Server.java`,
`simulation.gd`, `battle_controller.gd` or `flow.gd`. If you find you need to,
stop and rethink, or it's a genuinely new primitive.
