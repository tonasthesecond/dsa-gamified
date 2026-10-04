# Development guide

How the whole thing fits together, what each piece is called and where it
lives, and step-by-step recipes for adding moves, units, levels and AIs, and
for dropping the battle into some other kind of game.

The detailed references are:

- `docs/runner.md`: the HTTP contract between Godot and Java, and the
  state and command the student's code sees.
- `docs/events.md`: the envelope and every event in the battle log.
- `CLAUDE.md`: the short version of this file.

This file is the map. Start here.

---

## 1. The big picture

```
 ┌──────────────────────── Godot client (client/) ───────────────────────┐          ┌─── Java server (server/) ───┐
 │                                                                       │          │                             │
 │  CodePanel (UI) ──submit_pressed──► BattleRunner                      │          │                             │
 │                                  │  1. POST /build (source) ──────────┼──────────┼─► javac + TeaVM             │
 │                                  │                                    │          │                             │
 │                                  ▼  on a worker thread                │          │                             │
 │                            Battle.run()  ── every rule lives here     │          │                             │
 │                                  │  2. POST /start ───────────────────┼──────────┼─► node, new Submission()    │
 │                                  │  3. POST /decide (state) ──────────┼──────────┼─► decide(state) → action    │
 │                                  │     ... once per student unit      │          │                             │
 │                                  │         per turn ...               │          │                             │
 │                                  │  4. POST /close ───────────────────┼──────────┼─► process and build gone    │
 │                                  ▼                                    │          │                             │
 │  ReplaySystem ◄──result_ready(envelope)── the finished event log      │          └─────────────────────────────┘
 │     │  one signal per event, on Step                                  │
 │     ▼                                                                 │
 │  BattleDisplay  (draws it: today, print calls)                        │
 └───────────────────────────────────────────────────────────────────────┘
```

The important idea: **Godot plays the whole battle first, then replays it.**
Every rule (units, moves, damage, turn order, enemy AI, win/loss, the seed)
is in Godot. When one of the student's units has to act, Godot sends the
current state to Java, Java runs the student's `decide`, and the action comes
back. Nothing is shown until the battle is over; then the finished log goes to
ReplaySystem and BattleDisplay, which replay it one event at a time.

Java knows nothing about the game. It compiles `Submission.java`, and then
passes a Map in and a Map out. The test for that: Java could host a completely
different game without a code change.

So:

- A new **rule, move, unit, level or AI** is Godot work, and usually just data.
- A new **visual** is Godot work in BattleDisplay.
- Java changes only if the way student code is compiled or run changes.

### 1.1 One battle, start to finish

1. Player clicks **Submit**. `BattleRunner` POSTs the source to `/build`. A
   compile error comes back as `status: compile_error` and never becomes a
   battle.
2. `BattleRunner` loads the level (a `Level`), builds a `Battle` from it
   and runs it on a worker thread.
3. The battle calls `/start` once (a fresh `Submission`), then `/decide` once
   per student unit per turn, until someone wins or the turn limit hits.
4. Anything the student's code does wrong (throws, returns null, times out,
   returns something that is not an action, makes an illegal move) ends the
   battle as a **loss with `error` set**. It is part of playing, not a failure
   of the game, so `status` stays `ok`.
5. `/close`, then the envelope is emitted on the main thread and replayed.

### 1.2 Where things live

Folders are by role: what a file *is*, not which feature it belongs to.

```
client/
  globals/           autoloads: Config, BattleRunner
  resources/         Resource classes: Stats, UnitDef, Move, Level, LevelSide, LevelUnit, ServerConfig
    effects/         Effect and its subclasses, MoveContext
    controllers/     Controller, TelegraphAI, StudentController
  systems/
    battle/          the battle: Battle, BattleLog, BattleSide, BattleResult, Combatant; no nodes, no network
    student_code/    StudentCode: how StudentController reaches student code, on the server or in GDScript for tests
    replay_system.gd ReplaySystem: steps through a finished battle log
  ui/                BattleScreen (wires a battle together), CodePanel (editor, buttons),
                     BattleDisplay (draws the stage)
  data/              .tres: moves/, units/, levels/, server_config.tres
  tests/             headless checks and fixtures/
  main.gd, main.tscn the overworld rig
server/
  src/main/java/compileservice/   the HTTP service
  runner/            what runs inside TeaVM next to the student's code
  api/               the Strategy interface students implement
  examples/          one Submission.java per test case
  tests/             e2e.sh, the Java suite, and the state.json it sends
docs/                runner.md, events.md
```

### 1.3 The envelope

What `BattleRunner.result_ready` hands to `ReplaySystem.load_battle` (the full
field list is `docs/events.md`):

```json
{"status": "ok", "message": "", "console": "what the student printed",
 "result": {"won": true, "reason": "All enemies defeated", "error": "",
            "events": [{"turn": 0, "type": "spawn", "unit": "hero", ...}, ...]}}
```

`status` is `ok`, or `compile_error`, `bad_request`, `runtime_error`, in
which case `result` is `null` and `message` says why. `console` is cut at
4,000 characters. Events and the envelope only ever gain fields.

---

## 2. The battle (`client/systems/battle/`, `client/resources/`)

### 2.1 The pieces

Rules that are data (moves, units, levels, AIs) are Resources in
`resources/`; the fight itself is plain objects in `systems/battle/`.

| piece | file | what it is |
|---|---|---|
| **Effect** | `resources/effects/effect.gd` + `DamageEffect`, `HealEffect`, `ImmunityEffect`, `GuardEffect` | One step of a move. A Resource with one method, `apply(battle, user, target, move_context)`. |
| **MoveContext** | `resources/effects/move_context.gd` | Notepad shared by the effects of one move use, so a later effect can read what an earlier one did (drain heals by the damage that landed). |
| **Move** | `resources/move.gd` | A Resource: `id`, `name`, `description`, `target` (`ENEMY`, `ALLY` or `SELF`, relative to the user's side), `max_targets`, and a **list of effects** run in order. No numbers of its own: its effects scale off the user's stats. |
| **Stats** | `resources/stats.gd` | A Resource: `hp`, `strength`, `magic`, `speed`. `scaled(stat, percent)` is how every effect turns a stat into a number. |
| **UnitDef** | `resources/unit_def.gd` | A Resource: what a kind of unit is. `name`, `stats`, `moves`. Nothing about sides or who controls it. |
| **Controller** | `resources/controllers/controller.gd` | Picks the actions of one side's units. The battle assigns it to a side. |
| **TelegraphAI** | `resources/controllers/telegraph_ai.gd` | The plain AI: telegraphs its first move at the first living opponent, then does it. |
| **StudentController** | `resources/controllers/student_controller.gd` | Asks the student's code, through the `StudentCode` in the battle's context. Turns every runner error into a message for the player. |
| **Combatant** | `systems/battle/combatant.gd` | One unit in one battle: id, side, its own copy of the stats, hp, guard, moves, this turn's intent. The only thing that changes during a fight. Its `unit` is the shared UnitDef. |
| **BattleSide** | `systems/battle/battle_side.gd` | A side: a `team` label for the log, a controller, its combatants. |
| **Battle** | `systems/battle/battle.gd` | One fight. Holds the turn loop (`run`), turn order (`turn_order`), the one legality check (`use_error`), `use` (runs a move), the **primitives** (`deal_damage`, `heal`, `block`, `guard`), and `state_for`, the state the student sees. |
| **BattleLog** | `systems/battle/battle_log.gd` | Builds the events. Only `Battle` writes to it. |
| **BattleResult** | `systems/battle/battle_result.gd` | `won`, `reason`, `error`, `events`; `abort` if the battle could not finish at all. |
| **Level** | `resources/level.gd` + `LevelSide`, `LevelUnit` | A battle written down as data: sides, their controllers and units, `rng_seed`, `max_turns`, `player_side`, `shared_moves`. `create_battle(context)` turns it into a Battle. |

### 2.2 What happens in `Battle.run`

1. A `spawn` event for every combatant, side by side.
2. Every side's controller `begin`s once. For the student that is `/start`;
   a constructor that throws ends the battle on turn 1.
3. Each turn:
   1. Every living unit's controller may `plan` an intent. The
      TelegraphAI does; the student's does not. Intents are logged and
      every later state shows them.
   2. Everyone acts in `turn_order()`: the living, **fastest first**; equal
      speed goes by side order, then position on the side. Anyone who died
      earlier in the turn is skipped.
      Its guard from last turn drops first. The controller's `act` returns an
      action, `{"move": id, "targets": [ids]}`; for the student that is their
      command `"attack e1"` split on spaces.
   3. `use_error` checks it: the move is known, the target exists, is alive and
      is the right kind. If not, the controller's `refuse` decides: the student
      loses with that message; the AI's move fizzles (its target died first)
      and the battle goes on.
   4. `use` runs the move's effects. The effects call the primitives, and the
      primitives log the events.
   5. After every action: if every other side is wiped out the player's side
      won; if the player's side is, it lost.
4. Out of turns is a loss: "Turn limit reached".

### 2.3 Rules you must not break

- **Never change a Resource during a battle.** Godot shares loaded Resources,
  so a Move or UnitDef changed in one fight is changed in every fight. Anything
  that changes lives on `Combatant` (or the Battle).
- **No branch on what kind of unit it is.** If you are about to write
  `if enemy`, the behaviour belongs on a Controller (who decides and what
  happens when they get it wrong) or on data (a Move, a UnitDef). Win and loss
  are relative to `player_side`, not to a team name.
- **An effect never builds an event.** It calls `battle.deal_damage`,
  `battle.heal`, `battle.block` or `battle.guard`, which log for it and name the move.
- **Randomness only from `battle.rng`** (seeded from the Level), never
  `randi()` or `randf()`. The same code against the same level must give the
  same battle; `tests/smoke_battle` checks it.
- **No nodes, no scene tree, no `await` in `systems/battle/`.** It runs on a worker
  thread and blocks while the student's code thinks.
- **New content should not touch `battle.gd`.** The one exception is a
  genuinely new primitive (2.9).

### 2.4 Adding a move

A move is a `.tres` in `client/data/moves/`. In the editor: FileSystem →
right-click `data/moves/` → New → Resource → **Move**, then fill it in the Inspector.

**(a) A plain hit or heal with different numbers.** Just data:

| field | value |
|---|---|
| `id` | `fireball` |
| `name` | `Fireball` |
| `description` | `Hit one enemy for 150% of your magic.` |
| `target` | `Enemy` |
| `effects` | one `DamageEffect` with `stat` Magic, `percent` 150 |

The `id` is the first word of the student's command (`"fireball e1"`), and the
`move` field on every event the move causes, which BattleDisplay can key off.
Pick it once and don't rename it.

**A move never holds a raw number.** Every effect names a **stat of the user**
(`Hp`, `Strength`, `Magic`, `Speed`) and a **`percent`** of it, rounded down:
the basic `attack` is 100% of strength, `smite` 170%, `cleave` 70% per target,
`heal` 100% of magic. So the same move hits harder in a stronger unit's hands,
and balancing is done on units' stats. The description is the only place the
student reads what a move does, so say the percentage there.

**(b) It combines existing effects.** Still just data. Effects run in order and
share one MoveContext. The real `drain` is a `DamageEffect` (Magic, 100%), then
a `HealEffect` with `on_user` on and `from_context` = `damage`: with
`from_context` set, `percent` is taken of that number instead of a stat.

**(c) It needs a new mechanic.** Write a new Effect subclass, then use it in a
move. Example, a reckless hit whose user takes half the damage as recoil:

`client/resources/effects/recoil_effect.gd`:

```gdscript
class_name RecoilEffect
extends Effect
## Hurts the user by a fraction of the damage an earlier effect of this move landed.

@export var divisor: int = 2


func apply(battle: Battle, user: Combatant, _target: Combatant, move_context: MoveContext) -> void:
	battle.deal_damage(user, move_context.get_value(MoveContext.DAMAGE) / divisor)
```

`data/moves/reckless.tres`: target `Enemy`, effects `DamageEffect` (Strength, 200%), then
`RecoilEffect` (divisor 2). In the log that is an `action`, then two `damage`
events with `"move": "reckless"`, one on the target and one on the user. No
client change is needed for it to replay.

`max_targets` (default 1) is how many ids the command may name: `cleave`
has 2, so `"cleave e1 e2"` and `"cleave e1"` are both legal, and the effects
run once per target in that order. A `Self` move takes no id at all.

`block` (`GuardEffect`, Strength, 100%) is not `ImmunityEffect`. `block` the
move gives its user a **guard**: damage up to its strength, taken before its
next action, is absorbed. `ImmunityEffect` is an immunity check that makes a move bounce off a
target, logged as `blocked`.

For a move that should *refuse* under some condition ("can't hit a flying
unit"), subclass `ImmunityEffect`, override `reason(battle, user, target)` to
return a message or `""`, and put it **first** in the effects. If it returns a
reason it logs a `blocked` event and the rest of the move is skipped.

**Giving the move to someone:** add it to a UnitDef's `moves`. A move nobody
has does nothing. Moves every unit gets (today, `pass` and `block`) are the
Level's `shared_moves`, added after the unit's own.

### 2.5 Adding a kind of unit

A `.tres` in `client/data/units/`: New → Resource → **UnitDef**. `name`
(shown to the student and in every `spawn` event, so treat it as an id),
`stats` (New → **Stats**: `hp`, `strength`, `magic`, `speed`), `moves` in
order. Stats live inside the unit file; for several units sharing one stat
line, save the Stats as its own `.tres` and point them at it. A battle copies
them per combatant, so a future buff can change `combatant.stats` freely.

There is no hero or monster: the same UnitDef can be on the party's side in one
level and the enemy's in the next (`data/levels/swapped.tres` does exactly that).
Order matters only to an AI that cares: the TelegraphAI always uses the
**first** move.

### 2.6 Adding a level

A `.tres` in `client/data/levels/`: New → Resource → **Level**.

| field | meaning |
|---|---|
| `rng_seed` | everything random in this level comes from it |
| `max_turns` | turn limit before it's a loss (default 20) |
| `player_side` | the index of the side whose win or loss is reported (default 0) |
| `shared_moves` | moves every unit gets; put `data/moves/pass.tres` and `block.tres` here |
| `sides` | in side order, which breaks speed ties. Each a **LevelSide**: `team` (a label for the log, `hero` or `enemy`), `controller` (New StudentController, New TelegraphAI, or your own), `units` |
| `units` | each a **LevelUnit**: `id` (unique in the battle, like `e1`), `unit` (a UnitDef), `bonus_max_hp` (up to this much extra max hp, rolled from the seed) |

The level's id is its file name: `BattleRunner.submit(source, "example")` plays
`res://data/levels/example.tres`. To play it in the game, add a zone for it
(3.1); `default_level` in `data/server_config.tres` is what a BattleScreen
opens before any zone sets one.

### 2.7 Adding an AI

Subclass `Controller`, or `TelegraphAI` to keep "telegraph, then do
it", and override what differs. Example, an AI that goes for the weakest
opponent:

```gdscript
class_name WeakestFirstAI
extends TelegraphAI
## Telegraphs its first move at the living opponent with the least hp.


func plan(battle: Battle, unit: Combatant) -> Dictionary:
	var weakest: Combatant = null
	for other in battle.turn_order():
		if other.side != unit.side and (weakest == null or other.hp < weakest.hp):
			weakest = other
	return {"move": unit.moves[0], "targets": [weakest] as Array[Combatant]}
```

Then pick it as a side's `controller` in a level. The four methods, all
optional:

| method | when | returns |
|---|---|---|
| `begin(battle)` | once, before turn 1 | `{}`, `{"error": msg}` to end the battle as a loss, `{"abort": ...}` |
| `plan(battle, unit)` | start of each turn | `{"move": Move, "targets": Array[Combatant]}` to telegraph, `{}` for nothing |
| `act(battle, unit)` | the unit's turn | `{"action": {"move": id, "targets": [ids]}}`, `{"error": msg}`, `{"abort": ...}` |
| `refuse(battle, unit, problem)` | its action was illegal | the error that ends the battle, or `""` to let it fizzle |

Use `battle.rng` for anything random. Controllers hold no state (they are
shared Resources); anything an AI needs to remember goes on the Combatant or in
`battle.context`.

### 2.8 Using the battle somewhere else

A Level is only one way to start a battle. `Battle` takes plain sides, so a
roguelike carrying hp between floors, or an overworld starting a fight on
contact, builds them itself:

```gdscript
var shared: Array[Move] = [preload("res://data/moves/pass.tres"), preload("res://data/moves/block.tres")]
var party: Array[Combatant] = []
for member in run_state.party:              # whatever your game keeps
	var unit := Combatant.new(member.id, member.unit_def, 0, member.max_hp, shared)
	unit.hp = member.hp                     # carried over from the last fight
	party.append(unit)
var foes: Array[Combatant] = [Combatant.new("e1", preload("res://data/units/goblin.tres"), 1, 14, shared)]

var rng := RandomNumberGenerator.new()
rng.seed = run_state.seed + run_state.floor
var battle := Battle.new(
	[BattleSide.new("hero", StudentController.new(), party),
	 BattleSide.new("enemy", TelegraphAI.new(), foes)] as Array[BattleSide],
	0, 20, rng, {StudentController.CONTEXT_KEY: client})
var result := battle.run()
# result.won, result.events; read hp back off `party` for the next fight.
```

A combatant's `side` (third argument) must be the index of the BattleSide it
is in. The events go to `ReplaySystem.load_battle` wrapped in an envelope (1.3),
or anywhere else.

With the student's code in the loop, `run` blocks on HTTP, so call it off the
main thread and create the client the way `BattleRunner._build_and_run` does:
`/build` once, a `ServerStudentCode` per battle, `/close` at the end. One
build can play any number of battles; each `/start` is a fresh `Submission`.
For a fight with no student at all, give every side an AI and `run` needs no
network.

### 2.9 When you really do need to touch `Battle`

Only for a mechanic that can't be expressed as damage, heal, block or guard:
status effects over turns (poison, stun), buffs to a stat. Those need state
on `Combatant`, a new primitive on `Battle` that changes it, and a new event
from `BattleLog`. `guard` is the worked example: `Combatant.guard`,
`Battle.guard`, `deal_damage` reading it, `BattleLog.guard`, and `GuardEffect`. Give the event a `move` field (the primitive
gets it from `_resolving`) and the client's `effect_applied` signal picks it
up with no change to ReplaySystem. Add it to the event table in
`docs/events.md`, and teach BattleDisplay's `_on_effect_applied` what it looks like.

### 2.10 What the student sees

`Battle.state_for(unit)` builds it, in the shape of `docs/runner.md`:

```json
{"turn": 1,
 "self":    {"id": "knight", "name": "Knight", "hp": 34, "maxHp": 34,
             "strength": 6, "magic": 0, "speed": 4, "guard": 0, "intent": null,
             "moves": [{"id": "attack", "name": "Attack", "description": "...", "target": "enemy", "targets": 1}, ...]},
 "allies":  [ ...the living on its side, itself included, fastest first... ],
 "enemies": [ ...the living on every other side, fastest first, each with its "intent"... ]}
```

The student answers with a **command**, a String: the move id, then up to
`targets` ids, separated by spaces. `"smite e1"`, `"cleave e1 e2"`, `"block"`.
An intent in the state is the same kind of String: `"attack knight"`.
`StudentController.parse` splits it; `Battle.use_error` checks it. A new field is one more key
in `_view` or `state_for` plus a line in `docs/runner.md`; students read it
with `get`. Removing or renaming one breaks every submission that reads it.

---

## 3. The rest of the Godot client

Open `client/project.godot` in Godot 4.7, start the server, press F5.

### 3.1 The pieces

`main.tscn` is the running game, a test rig: a top-down overworld, and the
battle screen on a layer above it.

```
Main                 (main.gd)  ← player movement, zones open the battle
├── Overworld
│   ├── Player       CharacterBody2D, arrows or WASD
│   ├── DemoZone     Area2D with metadata `level` = "demo"; walking in opens it
│   └── SmokeZone    same, "smoke"
└── BattleLayer      CanvasLayer, hidden until a zone opens it
    └── BattleScreen       (ui/battle_screen.gd)  ← wires everything together
        ├── ReplaySystem   (systems/replay_system.gd)
        ├── BattleDisplay  (ui/battle_display.gd), drawing into Stage
        ├── Stage          %HeroColumn | %EnemyColumn, %Banner
        └── CodePanel      (ui/code_panel.tscn)
```

A new zone is one more Area2D under Overworld with a `level` metadata entry,
the level's file name (`"demo"` for `data/levels/demo.tres`).
`BattleScreen.open(level)` shows an empty screen for it; once a battle
loads it plays itself one event every `step_seconds`, and CodePanel's Leave emits
`closed` to go back.

Plus two **autoloads** (Project Settings → Autoload), in `globals/`: `Config`
and `BattleRunner`.

| system | file | in plain words |
|---|---|---|
| **CodePanel** | `ui/code_panel.gd`, `ui/code_panel.tscn` | **The code panel**: code editor, Submit, spinner, error label, and the replay buttons (Step, Skip, Reset) and Leave. A small state machine: `IDLE → SUBMITTING → REPLAYING` or `ERROR`. It knows nothing about battles; it reports clicks through signals and shows what it's told. |
| **BattleRunner** | `globals/battle_runner.gd` | **Build, play, hand over.** `submit(source, level_id)` compiles the source, runs the level's battle on a worker thread, and emits `result_ready(envelope)`, or `submit_failed(reason)` if the server couldn't be reached. |
| **Config** | `globals/config.gd`, `data/server_config.tres` | **Settings** (a `ServerConfig`): `server_url`, `timeout_sec` (the compile step), `default_level`, `decide_timeout_ms` (per call to the student's code, 1 to 10,000). Edit the `.tres`. |
| **ReplaySystem** | `systems/replay_system.gd` | **The replay engine.** Steps through the finished log one event at a time, like a tape player. Keeps each unit's hp and alive/dead, and emits **one signal per event**. No animation, no timers. |
| **BattleDisplay** | `ui/battle_display.gd` | **What the player sees.** Listens to ReplaySystem, prints each signal, and with a `stage` draws each unit as a ColorRect with a `name hp/max [guard n]` label: the first team to spawn on the left, the rest on the right, the unit acting in yellow, the dead in grey. **This is the file you rebuild with sprites, tweens and health bars.** |
| **BattleScreen** | `ui/battle_screen.gd` | **The switchboard.** Every cross-system connection is in its `_ready()`, plus the autoplay timer. |

### 3.2 ReplaySystem signals (what BattleDisplay listens to)

Every event signal carries the raw event `Dictionary` (see `docs/events.md`).
Numbers are already `int`.

| signal | fires for | useful fields | typical visual |
|---|---|---|---|
| `battle_loaded()` | a good envelope arrived | | clear the stage |
| `battle_reset()` | Reset, and right after loading | | remove all unit nodes, start over |
| `submission_failed(message, line)` | compile error etc. | | (CodePanel handles it) |
| `spawned(event)` | `spawn` | `unit` (id like `"e1"`), `name` (`"Goblin"`), `team`, `hp`, `maxHp` | create the unit's sprite, chosen by `name` |
| `intent(event)` | `intent` | `unit`, `move`, `target`, `targets` | an icon over the unit of what it will do |
| `action(event)` | `action` | `unit`, `move`, `target`, `targets` (no target for a `self` move) | the user's attack/cast animation, chosen by `move` |
| `effect_applied(event)` | **everything a move did**: `damage`, `heal`, `guard`, `blocked`, any future effect | `type`, `unit` (who was affected), `move`, and `amount`, `hp`, `absorbed` or `reason` | hit flash, damage number, health bar tween |
| `died(event)` | `death` | `unit` | death animation |
| `ended(won, reason)` | `end` | | victory/defeat banner |
| `unknown_event(event)` | a new structural event without `move` | | ignore; replay continues |

Typical sequence for one knight hit that kills a goblin:

```
action          {unit: "knight", move: "smite", target: "e1"}
effect_applied  {type: "damage", unit: "e1", amount: 10, hp: 0, move: "smite"}
died            {unit: "e1"}
```

**Why `effect_applied` is one signal:** every event a move causes carries
`move`, so a new effect (recoil, a future `poison` event) arrives with **no
change to ReplaySystem**. BattleDisplay decides what it looks like.

At any time: `replay.unit_ids()`, `replay.unit_state("e1")` →
`{name, team, hp, max_hp, alive}`, `replay.turn`.

### 3.3 Giving a move or unit its look

There is no art yet and no display catalogue: BattleDisplay draws every unit
the same way and only prints moves. When art arrives, key it off what the
events already carry: a unit's look off `spawn.name` (the UnitDef's `name`,
not its id `"e1"`), a move's off `action.move` and `effect_applied.move` (the
Move's `id`). A move or unit with no art should still replay, so fall back to
the plain box rather than crash.

The recoil from `reckless` is a `damage` event and already plays as damage.
A new event type needs a branch in `_on_effect_applied`; without one it is
printed and the replay carries on.

---

## 4. Java (`server/`)

Needs JDK 17 (`JAVA_HOME` pointing at it) and `node` on the PATH. Run
everything from `server/`: the service reads `runner/` and `api/` from its
working directory.

```bash
./gradlew run      # serve on :8080
tests/e2e.sh       # the Java test suite: builds, starts its own server
scripts/build-api-jar.sh   # dsagame-api.jar, what students compile against
```

### 4.1 The pieces

| piece | file(s) | what it does |
|---|---|---|
| **Server** | `src/main/java/compileservice/Server.java` | The endpoints: `/build` (javac + TeaVM, keeps the build), `/start`, `/decide`, `/close`. Always HTTP 200 with a `status`. |
| **Builds** | `Builds.java` | Compiled submissions by id, each with at most one running battle. Closes builds idle for 60 s. |
| **Instance** | `Instance.java` | One node process for one battle. Sends a request, waits for the reply with the per-call timeout, kills the process on a timeout. |
| **Strategy** | `api/dsagame/api/Strategy.java` | What students implement: `String decide(Map<String, Object> state)`, returning a command such as `"attack e1"`. The only named package. |
| **Runner** | `runner/Runner.java` | The TeaVM main class. Makes the `Submission`, turns the state JSON into Maps, calls `decide`, turns the answer back into JSON, and reports anything that went wrong as an error `kind`. |
| **Json, StrictMap** | `runner/Json.java`, `runner/StrictMap.java` | Hand-rolled JSON to Map/List and back. Every JSON object becomes a StrictMap, whose `get` throws, naming the key, for a key that isn't there. |
| **host.js** | `runner/host.js` | The node side: loads the compiled program once, calls `main` once per request, captures everything the student prints. |

### 4.2 Rules you must not break

- **Java knows nothing about the game.** No unit, move, hp or side anywhere in
  `server/`. A key the client adds to the state needs no Java change.
- **`runner/` stays flat, in the default package.** Java can't reference the
  default package from a named one, so a packaged runner could not create
  `Submission`; and `copySources` keeps directories, so a subfolder would
  become a package.
- **TeaVM subset** for everything in `runner/`: `StringBuilder`, `ArrayList`,
  `LinkedHashMap`, `Math`, index loops. No reflection, `String.format`,
  streams, records, `java.time`, files, threads. JSON is built by hand for
  this reason.
- **A JVM accepts code TeaVM gets wrong**, so only `tests/e2e.sh` counts. Two
  that bit us: TeaVM's `java.util.Random` ignores its seed, and its
  `LinkedHashMap` calls `get` from its own methods, so overriding `get` in a
  subclass recursed forever (hence StrictMap wraps one instead).
- **Student misbehaviour is not a server error.** Throws, nulls, bad shapes,
  timeouts, crashes and too much output come back as `status: ok` with
  `error` set, and the client decides what that means for the battle.

### 4.3 Testing Java changes

Each `examples/<case>/Submission.java` is one case, driven through
`/build`, `/start` and `/decide` with `tests/state.json` and asserted in
`tests/e2e.sh`. They cover compile errors, the package line, fields lasting a
battle, and every error kind.

By hand, against a running server:

```bash
curl -s --data-binary @examples/first_enemy/Submission.java localhost:8080/build
curl -s -X POST "localhost:8080/start?build=<build>&timeout_ms=1000"
curl -s --data-binary @tests/state.json "localhost:8080/decide?instance=<instance>"
curl -s -X POST "localhost:8080/close?build=<build>"
```

---

## 5. Testing

Headless checks, from the repo root (`godot` is your Godot 4.7 binary):

```bash
godot --headless --path client res://tests/smoke_battle.tscn        # the rules; no server; exits 1 on failure
godot --headless --path client res://tests/smoke_replay.tscn    # ReplaySystem, from fixtures
godot --headless --path client res://tests/smoke_battle_display.tscn  # BattleDisplay, from a fixture
godot --headless --path client res://tests/smoke_submit.tscn        # real pipeline (needs server)
godot --headless --path client res://tests/smoke_game.tscn          # whole client (needs server)
cd server && tests/e2e.sh                                           # Java
```

**`tests/smoke_battle`** plays battles with students written in GDScript
(`ScriptedStudentCode`), so the rules are tested with no server. It checks:

- the battles recorded through the real pipeline (`smoke.json`, `demo.json`),
  event for event, so nothing is lost on the way to Java and back;
- every rule that ends a battle early, with its exact message;
- every malformed or illegal command;
- turn order by speed, and damage as a percent of a stat;
- every student error kind, and the service going away mid-battle;
- the same code giving the same battle, and another seed giving another;
- the swapped level.

To test new content, add a GDScript student to it that wins and one that
doesn't, as the `_demo_win` and `_demo_lose` there do.

**Fixtures** in `tests/fixtures/` are real envelopes. `smoke.json` and
`demo.json` are recorded from `Submission.java` and `demo_win.java` by:

```bash
godot --headless --path client res://tests/smoke_submit.tscn -- --record
```

Re-record them when a rule or a level's numbers change on purpose, then run
`smoke_battle`: it tells you whether the offline battles still agree.

---

## 6. Checklists

**New move (existing effects)**
1. `client/data/moves/<id>.tres`: a Move.
2. Add it to a UnitDef's `moves`.
3. Optional: its look in `ui/battle_display.gd`.

**New move with a new mechanic**
Same, plus `client/resources/effects/<name>_effect.gd`. If it can't be built
from `deal_damage` / `heal` / `block` / `guard`, it needs a new primitive and
event (2.9), a row in `docs/events.md`, and a branch in BattleDisplay.

**New kind of unit**
1. `client/data/units/<name>.tres`: a UnitDef.
2. Put it in a level's side.

**New level**
1. `client/data/levels/<id>.tres`: a Level.
2. An Area2D zone in `main.tscn` with `level` metadata `<id>`.
3. A winning and a losing GDScript student in `tests/smoke_battle.gd`.

**New AI**
1. `client/resources/controllers/<name>_ai.gd`: a Controller subclass.
2. Pick it as a side's controller in a level.

**Nothing in these lists touches** `battle.gd`, `replay_system.gd`,
`battle_screen.gd`, `code_panel.gd` or anything in `server/`. If you find you
need to, stop and rethink, or it's a genuinely new primitive.
