# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

A Zachtronics-style coding game for a data structures course. Students write a
Java `Submission` whose `decide(state)` picks one unit's action; a Godot game
plays a turn-based battle with it and then replays the battle on screen.

`DEVELOPMENT.md` is the map: architecture, every piece by name, and recipes for
adding moves, units, levels and AIs. Read the relevant section before changing
anything. `server/docs/runner.md` is the HTTP contract and the shape of the
state the student sees; `server/docs/protocol.md` is the battle-log event
vocabulary. `feasibility-report.md` is the project plan.

## Architecture in one paragraph

**Godot owns every rule; Java only runs student code.** `SubmitClient` POSTs the
source to `/build` (javac + TeaVM), then runs `Battle.run()` on a worker thread.
Each time a student unit acts, `StudentController` calls `/decide` with the
state from `Battle.state_for`, and Java's `runner/Runner.java` hands it to the
student's `decide` inside a node process and returns the action. `/start` makes a
fresh `Submission` per battle; `/close` ends it. When the battle is over, the
finished event log goes to `Simulation` (one signal per event) and
`Presentation` (draws it). Java could host a different game without a change.

## Commands

The machine has only a JRE 25. Java work needs
`export JAVA_HOME=~/.local/jdk-17 PATH=~/.local/jdk-17/bin:$PATH` first, and
`node` on the PATH. Godot 4.7 is `~/applications/godot/godot` (not on PATH).

```bash
# Java, from server/ (the service reads runner/ and next/api/ from its cwd)
./gradlew run             # serve on :8080
tests/e2e.sh              # Java suite: builds, starts its own server, runs every case

# Godot, from the repo root; each exits 1 on failure
godot --headless --path client res://dev/smoke_battle.tscn        # the rules, no server
godot --headless --path client res://dev/smoke_simulation.tscn    # replay, from fixtures
godot --headless --path client res://dev/smoke_presentation.tscn
godot --headless --path client res://dev/smoke_content.tscn
godot --headless --path client res://dev/smoke_submit.tscn        # real pipeline, needs server
godot --headless --path client res://dev/smoke_flow.tscn          # whole client, needs server
godot --headless --path client res://dev/smoke_submit.tscn -- --record   # re-record fixtures
```

There is no test framework. `smoke_battle` runs battles against GDScript
students (`ScriptedStrategyClient`), so rule changes are tested without a
server. One Java case by hand is the curl sequence in `DEVELOPMENT.md` 4.3.

## In transition

`server/harness/`, `server/api/`, `server/examples/`, `server/starter/`, the
`/compile` endpoint, `tests/harness-test.sh`, `scripts/build-api-jar.sh` and the
fixtures `smoke_win.json` / `demo_win.json` are the old Java-side game. They are
waiting to be deleted: don't build on them or extend them. `next/api` and
`next/examples` move into `api/` and `examples/` when they go.

## Rules that are load-bearing

### Godot battle (`client/battle/`)

- **Never mutate a Resource during a battle.** Moves, UnitDefs, Encounters and
  Controllers are shared; per-fight state lives on `Combatant` or `Battle`.
- **No branch on unit kind or team name.** Behaviour belongs on a Controller or
  in data; win/loss is relative to `player_side`.
- **An effect never builds an event.** Effects call the primitives
  (`deal_damage`, `heal`, `block`), which log and name the move.
- **Randomness only from `battle.rng`.** Same code + same level = same battle;
  `smoke_battle` checks it.
- **No nodes, scene tree or `await` in `battle/`** — it runs on a worker thread
  and blocks on HTTP.
- **New content must not touch `battle.gd`, `simulation.gd`,
  `battle_controller.gd`, `flow.gd` or `server/`.** A new move is a `.tres`
  (plus an `Effect` subclass for a new mechanic), likewise units, levels and
  AIs. The one exception is a genuinely new primitive on `Battle`
  (`DEVELOPMENT.md` 2.9). If content forces another edit, that's a design flaw:
  say so rather than working around it.
- New content needs a GDScript student that wins it and one that doesn't in
  `dev/smoke_battle.gd`.

### Java (`server/`)

- **Java knows nothing about the game.** No unit, move, hp or side in `server/`.
- **`runner/` is flat and in the default package**, because Java can't reference
  the default package from a named one, and `Server.copySources` keeps
  directories. Only `dsagame.api` is named.
- **TeaVM subset** in `runner/`, the API and student code: `StringBuilder`,
  `ArrayList`, `LinkedHashMap`, `Math`, index loops. No reflection,
  `String.format`, streams, records, `java.time`, files, threads. JSON is built
  by hand.
- **A JVM accepts code TeaVM gets wrong; only `tests/e2e.sh` counts.** Known
  traps: TeaVM's `java.util.Random` ignores its seed; its `LinkedHashMap` calls
  `get` internally, so `StrictMap` wraps one instead of overriding `get`.
- **Student misbehaviour is not a server error.** Throws, nulls, bad shapes,
  timeouts, crashes and output floods are `status: ok` with `error` set; the
  client turns them into a loss. Every endpoint answers HTTP 200 with `status`.

### Contracts

- **Additive only**: the event vocabulary (`protocol.md`), the state shape
  (`runner.md`) and the `Strategy` API. New events and fields are fine; renames
  and removals break the client or old submissions. Document every change there
  and in `client/README.md`'s event table.
- Move ids and UnitDef names are keys for students, the log and `Content`. Don't
  rename them.
- Fixtures in `client/dev/fixtures/` are real recorded envelopes. Re-record them
  only when a rule or level's numbers change on purpose, then run `smoke_battle`.
