# CLAUDE.md

## Project
- A coding game for a data structures course: students write Java that picks
  each unit's move, Godot plays the battle and replays it.
- **Client** (`client/`): Godot 4.7, GDScript. Owns every rule.
- **Server** (`server/`): Java 17 + TeaVM + node. Compiles and runs student
  code only; knows nothing about the game.
- Machine: JDK at `~/.local/jdk-17` (`export JAVA_HOME=~/.local/jdk-17
  PATH=~/.local/jdk-17/bin:$PATH`), Godot at `~/applications/godot/godot`.

## Commands
```bash
cd server && ./gradlew run                     # serve on :8080
cd server && tests/e2e.sh                      # Java suite (own server on :8080)
godot --headless --path client res://tests/smoke_battle.tscn   # rules, no server
godot --headless --path client res://tests/smoke_flow.tscn     # whole client, needs server
godot --headless --path client res://tests/smoke_submit.tscn -- --record   # re-record fixtures
```
Other checks: `smoke_simulation`, `smoke_presentation`, `smoke_submit`.

## Architecture
- **Flow**: zone in `main.tscn` → `BattleController.open(level)` → Submit →
  `SubmitClient` (`/build`, then `Battle.run()` on a worker thread, `/decide`
  per student unit per turn) → envelope → `Simulation` → `Presentation`.
- `client/globals/`: autoloads `Config`, `SubmitClient`.
- `client/resources/`: Resource classes — `Stats`, `UnitDef`, `Move`,
  `Encounter`, `SideSpec`, `UnitSlot`, `effects/`, `controllers/`.
- `client/systems/`: `battle/` (Battle, BattleLog, Combatant...), `strategy/`
  (HTTP and scripted student clients), `Simulation`, `BattleController`.
- `client/ui/`: `Flow` (editor, buttons), `Presentation` (ColorRect stage).
- `client/data/`: `moves/`, `units/`, `levels/` .tres, `server_config.tres`.
- `server/`: `src/` the service, `runner/` runs inside TeaVM, `api/` the
  `Strategy` interface, `examples/` one case each for `e2e.sh`.
- References: `docs/runner.md` (HTTP + student state), `docs/events.md` (log).

## Coding Style
- snake_case files, `class_name` on every custom type, PascalCase classes.
- One `##` line per class and public function; `# --- Section ---` dividers.
- Folders by role, flat until a group grows.

## Key Patterns
- **Moves are data**: a `Move` is a list of `Effect`s; effects scale off a
  user `Stats` stat by `percent` and change the battle only through `Battle`'s
  primitives (`deal_damage`, `heal`, `block`, `guard`), which log the events.
- **Controllers** decide for a side: `TelegraphController` (AI),
  `StudentController` (parses the command string). No `if enemy` anywhere.
- **Commands**: students return `"move id id"`; `Battle.use_error` is the one
  legality check, `Battle.turn_order` (speed) the one turn order.
- Student mistakes are a lost battle with `error` set, never a server error.

## Common Tasks
- New move: `data/moves/<id>.tres` with effects, add to a UnitDef's `moves`.
- New mechanic: an `Effect` subclass in `resources/effects/`; a new primitive
  on `Battle` only if damage/heal/block/guard can't express it.
- New unit: `data/units/<name>.tres` with a `Stats`.
- New level: `data/levels/<id>.tres` (Encounter) + an Area2D zone in
  `main.tscn` with `level` metadata + a winning and losing student in
  `tests/smoke_battle.gd`.
- New AI: a `Controller` subclass in `resources/controllers/`.

## Gotchas
- Never change a Resource mid-battle; per-fight state is on `Combatant`.
- Randomness only from `battle.rng`; same code + level = same battle.
- No nodes or `await` in `systems/battle/`: it runs on a worker thread.
- `server/runner/` stays flat in the default package and inside the TeaVM
  subset (no reflection, `String.format`, streams, records). A JVM accepts code
  TeaVM rejects: only `e2e.sh` counts.
- Re-record `tests/fixtures/*.json` when a rule or number changes on purpose.
- The event log and student state only gain fields; renames break the client
  or submissions.
