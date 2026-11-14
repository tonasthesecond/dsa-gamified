---
name: new-level
description: Add a campaign level (and any new monster, body, crit question or level rule it needs) to the DSA RPG Godot client, with tests and fixtures. Use when asked to add, design or build a level, a monster, a crit question, a data structure body, or a level rule.
---

# New level

A level teaches **one** data-structure idea: the student should be able to
clear it only by using that idea. Ideas live in `IDEAS.md`; the campaign plan
is `ARCHITECTURE.md` section 6. Everything here is client work; never touch
`server/`, `battle.gd`, `replay_system.gd`, `battle_screen.gd` or
`code_panel.gd`.

## 1. Decide the idea and the win condition

Write down, before any file:
- the idea (e.g. "fast/slow pointers"),
- what a naive student does: it either **loses** (turn limit, a rule that
  bounces moves, as in `gatehouse`) or wins **in clearly more turns** (as in
  `burrow`, `nest`, `pecking_order`),
- what the idea-using student does and why it wins, or wins faster.

If you can't state both, the level doesn't teach anything yet.

## 2. New structure or question? (skip if reusing)

- Body: `client/resources/bodies/<kind>_body.gd`, `class_name <Kind>Body`,
  extends `Body`; `generate(rng)` returns JSON-like data and draws **only**
  from the `rng` given; `values(body)` lists what it holds. Add a row to the
  `kind` table in `docs/runner.md`.
- Question: `client/resources/problems/<id>_problem.gd`, extends `Problem`;
  implement `expected(battle, user, target)` (or `is_correct` with
  `takes_answer() == false` when judged from the move alone). Save a `.tres`
  in `client/data/problems/` with `id` and a `description` precise enough to
  answer from (ties, empty cases, 0- or 1-based). Add a row to the crit table
  in `docs/runner.md`.
- One `##` line per class and public function. No nodes, no `await`, no
  `randi()`.

## 3. Monster (if new)

`client/data/units/<name>.tres`: a `UnitDef` with `name`, `stats`, `moves`
(the AI uses the first), and `body` + `crit` for a question monster.
Balance by stats, never by raw numbers in moves.

## 4. The level

`client/data/levels/<id>.tres`, a `Level`:
- `title` "N. Name" and a `briefing`: the goal, what is new, an example
  command with its answer (`"attack e1 | crit 4"`).
- `starter_code` = `res://data/starters/<id>.java`: the Goblin Camp code plus
  this level's wiring, with the idea left as **one TODO function** whose
  placeholder returns a wrong-but-legal answer. It must compile and play as
  given (`smoke_submit` checks), and filling only the TODO must win, or win
  faster.
- `rng_seed`, `max_turns`, `shared_moves` = `pass.tres`, `block.tres`.
  Budget the student's calls (one per student unit per turn): a winning run
  under ~30, and `max_turns` × student units ≤ 100 (each is a network round
  trip in production).
- `sides`: side 0 the student's (`StudentController`), then enemies
  (`TelegraphController` or a custom one).
- `rules`: `LevelRule`s; a gate uses `BounceEffect` in `when_wrong`, a bonus
  a `DamageEffect` in `when_right`.

Then an Area2D zone in `client/main.tscn` under `Overworld`, copied from an
existing zone, with `metadata/level = "<id>"` and its own position, and a
`CampaignStage` in `client/data/campaign.tres` (`level`, and the levels it
`requires`). `smoke_progress` fails if a zone has no stage or a stage no zone.

## 5. Tests

In `client/tests/smoke_battle.gd`:
- extend `_campaign_student` so `"lowest"` (every idea) answers this level,
  then in `_campaign` either add the id to the "wins in fewer turns" loop, or
  add explicit checks like gatehouse's: `"naive"` → `won == false`,
  `"lowest"` → `won == true`.
- for a new question: a right, a wrong and a missing answer in `_crits` (or
  `_level_rules`); a wrong answer must never be an error.

Run:

```bash
G=~/applications/godot/godot
$G --headless --path client res://tests/smoke_battle.tscn
$G --headless --path client res://tests/smoke_progress.tscn
```

If the level should play through the real pipeline, add its winning Java to
`client/tests/fixtures/campaign.java`, start the server and re-record:

```bash
export JAVA_HOME=~/.local/jdk-17 PATH=~/.local/jdk-17/bin:$PATH
(cd server && ./gradlew run) &
$G --headless --path client res://tests/smoke_submit.tscn -- --record
$G --headless --path client res://tests/smoke_battle.tscn
$G --headless --path client res://tests/smoke_game.tscn
```

`smoke_battle` must pass after re-recording: it proves the offline battle
equals the recorded one.

## 6. Done means

- [ ] naive loses or is clearly slower, idea wins, checked in `smoke_battle`
- [ ] same seed gives the same battle (no randomness outside `battle.rng`)
- [ ] winning run under ~30 student calls; `max_turns` × student units ≤ 100
- [ ] briefing names the idea and shows one example command
- [ ] starter compiles and plays; filling only its TODO wins or wins faster
- [ ] `docs/runner.md` rows for any new body kind or crit id
- [ ] zone in `main.tscn` and stage in `campaign.tres`; fixtures re-recorded if the pipeline covers it
- [ ] all smoke tests green; report any that you could not run
