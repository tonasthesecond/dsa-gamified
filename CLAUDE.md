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
godot --headless --path client res://tests/smoke_game.tscn     # whole client, needs server
godot --headless --path client res://tests/smoke_submit.tscn -- --record   # re-record fixtures
```
Other checks: `smoke_replay`, `smoke_battle_display`, `smoke_progress` (no server),
`smoke_submit` (server).

## Architecture
- **One battle**: zone in `main.tscn` → `BattleScreen.open(level)` → Submit in
  `CodePanel` → `BattleRunner` (`/build`, then `Battle.run()` on a worker
  thread, `/decide` per student unit per turn) → envelope → `ReplaySystem` →
  `BattleDisplay`.
- `client/globals/`: autoloads `Config`, `BattleRunner`, `HoverUI`, `Progress`
  (save file: clears + drafts). `data/campaign.tres` locks the map's zones.
- `client/resources/`: Resource classes — `Stats`, `UnitDef`, `Move`,
  `Level`, `LevelSide`, `LevelUnit`, `LevelRule`, `Campaign`,
  `CampaignStage`, `effects/`, `controllers/`,
  `bodies/`, `problems/`.
- `client/systems/`: `battle/` (Battle, BattleLog, Combatant...),
  `student_code/` (`StudentCode` on the server or scripted for tests),
  `ReplaySystem`.
- `client/ui/`: `BattleScreen` (wires a battle together), `CodePanel` (editor,
  buttons), `BattleDisplay` (ColorRect stage).
- `client/data/`: `moves/`, `units/`, `levels/`, `problems/` .tres,
  `campaign.tres`, `server_config.tres`.
- `server/`: `src/` the service, `runner/` runs inside TeaVM, `api/` the
  `Strategy` interface, `examples/` one case each for `e2e.sh`.
- References: `ARCHITECTURE.md` (full product: built vs planned, deployment,
  security), `docs/runner.md` (HTTP + student state), `docs/events.md` (log),
  `DEVELOPMENT.md` (recipes).
- Planned (see `ARCHITECTURE.md`; don't build unasked): `Codex`,
  `BodyView`s, `LookCatalog`; on the server
  `Sandbox` (bwrap + cgroup), compile slots, `busy`, `/health`; deploy as
  Caddy + a systemd unit (no Docker: it blocks bwrap).

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
- **Questions**: a unit's `body` (a data structure) and `crit` (a `Problem`),
  and a level's `rules`, are answered after `|` in the command. Godot judges
  them in `Battle.use`; a wrong answer only misses its reward, never an error.

## Common Tasks
- New move: `data/moves/<id>.tres` with effects, add to a UnitDef's `moves`.
- New mechanic: an `Effect` subclass in `resources/effects/`; a new primitive
  on `Battle` only if damage/heal/block/guard can't express it.
- New unit: `data/units/<name>.tres` with a `Stats`.
- New level: `data/levels/<id>.tres` (a Level, with `title`, `briefing` and
  `starter_code` = `data/starters/<id>.java`) + an Area2D zone in `main.tscn` with `level`
  metadata + a `CampaignStage` in `data/campaign.tres` + a winning and losing
  student in `tests/smoke_battle.gd`
  (`_campaign` for the campaign levels). Step by step: skill `new-level`.
- Hover popup: a `HoverComponent` child on a Control or Area2D, `scene` set
  to a Control scene with an optional `setup(data)`; `HoverUI` shows it.
- New AI: a `Controller` subclass in `resources/controllers/`.
- New monster: a UnitDef with `body` + `crit`; new question or structure: a
  `Problem` or `Body` subclass (DEVELOPMENT.md 2.11). Ideas: `IDEAS.md`.

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
- Web export: one origin (client + `/api`), Thread Support + COOP/COEP;
  blocking `HTTPClient` from a worker on web is unverified (ARCHITECTURE 3.7).
- Tests that touch the save file call `Progress.use_file("user://<test>.json")`
  first, or they overwrite the player's drafts.
- Student code is untrusted: never relax a server limit, never log source.
  javac must not see the server's classpath (`teavm-jso` = raw JS in node).
- Each `/decide` is a network round trip in production: keep a winning run
  under ~30 calls and `max_turns` × student units ≤ 100.
