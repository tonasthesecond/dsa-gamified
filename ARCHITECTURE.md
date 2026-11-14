# Architecture

DSA RPG is a browser game for a data structures course. Students write Java
that picks each unit's move in a turn-based battle. The game plays the whole
battle against that code, then replays it as an animation. Each level is built
so that one data-structure idea is the way to win.

This file describes the **full product**: what is built now and what still has
to be built. Every component has a status:

- **built**: in the repo and covered by a test
- **partial**: exists, but the product needs more
- **planned**: designed here, not written yet

Detailed contracts: `docs/runner.md` (HTTP + student state), `docs/events.md`
(battle log). How-to recipes: `DEVELOPMENT.md`. Agent rules: `CLAUDE.md`.

---

## 1. Goals and non-goals

**Goals**
- A student needs only a browser: no JDK, no install, no account.
- Every rule is in one place (the Godot client), so content is mostly data.
- The same code on the same level always gives the same battle.
- Mistakes in student code are part of playing (a lost battle with an
  explanation), never a crash.
- One developer can run the server for one course (~100 students, ~30 at once).

**Non-goals (for this product)**
- Accounts, grading, leaderboards. The client is trusted with its own result.
  Section 8 shows how grading could be added later without a redesign.
- Multiplayer, or student code fighting other students' code.
- Languages other than Java.

---

## 2. System overview

**Style:** client–server. The client is split into layers and treats content as
data. A battle is played in full first, then replayed.

```
 Student's browser                                  One host (VPS), one origin: https://<host>/
┌──────────────────────────────────────┐          ┌────────────────────────────────────────────────┐
│ Godot web export (client/)           │          │ Caddy (TLS, static files, rate limit)          │
│                                      │  GET /   │   /       → client web export (COOP/COEP)      │
│  Screens      Title, WorldMap,       │◄─────────┤   /api/*  → compile service on 127.0.0.1:8080  │
│               BattleScreen, Codex    │          │                                                │
│  Coordination BattleRunner,          │ POST     │ Compile service (server/, systemd unit)        │
│               Progress, Campaign,    │ /api/... │   Server ─ Builds ─ Instance ─ Sandbox         │
│               Config                 ├─────────►│   javac + TeaVM 0.13 → JS program per build    │
│  Game logic   Battle, ReplaySystem,  │ state →  │                                                │
│               StudentCode            │ ← command│ Sandbox (bubblewrap + cgroup, per battle)      │
│  Content      data/*.tres            │          │   node host.js + student program               │
│                                      │          │   no network, read-only fs, mem/pid limits     │
│  Save: user:// (IndexedDB on web)    │          │                                                │
└──────────────────────────────────────┘          └────────────────────────────────────────────────┘
```

The client and server share no code and no game knowledge. The only things
they agree on are the HTTP contract (`docs/runner.md`) and the fact that state
and commands are plain JSON and strings. Test for this: the server could host a
different game without changing.

### 2.1 One submission, end to end

1. The student presses **Submit** in `CodePanel`. `BattleRunner` POSTs the
   source to `/build`. A compile error comes back as `compile_error` with line
   numbers and is shown in the editor. It never becomes a battle.
2. `BattleRunner` loads the `Level`, builds a `Battle` and runs it on a worker
   thread.
3. `Battle.run()` calls `/start` once (a fresh `Submission`), then `/decide`
   once per student unit per turn. Enemies follow their `Controller`.
4. Each command (`"attack e1 | crit 4"`) is parsed by `StudentController`,
   checked by `Battle.use_error`, and run by `Battle.use`. Effects change the
   battle only through `Battle`'s primitives, and the primitives write the log.
5. The battle ends with a win, a loss, the turn limit, or a student error.
   `/close` is called and the envelope (`docs/events.md`) goes back to the main
   thread.
6. `ReplaySystem` steps through the log. `BattleDisplay` animates it.
   `Progress` records the result and the code.

**Timing.** Measured on localhost: ~190 ms to start a battle, ~2 ms per
`/decide`. Over the internet every `/decide` also pays one round trip on a kept
connection (30–80 ms). The recorded winning runs of the five campaign levels
make **8–16 calls**, so they take about 0.5–1.5 s. The slow case is a losing
run that hits the turn limit: 50 turns × 2 units = 100 calls, or **3–8 s**,
with nothing on screen until it ends. So:
- host the server near the students (a Singapore region for Vietnam),
- `BattleRunner` emits `progress(turn, max_turns)` from the worker thread
  (`call_deferred`), and `CodePanel` shows "Playing turn 7 / 50…",
- size a level by its calls, not its turns: a winning run should stay under
  ~30 calls, and `max_turns` × student units should stay ≤ 100.

---

## 3. Client (`client/`, Godot 4.7, GDScript)

Four layers. Each layer uses only the layers below it. The battle rules can be
tested with no screen and no server, and screens can change without touching
the rules.

### 3.1 Screens (`ui/`, `main.tscn`)

| component | status | role |
|---|---|---|
| `TitleScreen` | planned | Continue / New game / Settings. Shows whether the server is reachable (`GET /health`). |
| `WorldMap` (`main.tscn`, `main.gd`) | partial | Overworld with one zone per level. Built: zones open a battle, a cleared zone turns green for the session. Needed: locked zones and saved clears from `Progress` and `Campaign`, and a layout by chapter. |
| `BattleScreen` | built | The switchboard. It wires `CodePanel`, `BattleRunner`, `ReplaySystem` and `BattleDisplay` together, autoplays the replay, and shows the briefing. |
| `CodePanel` | partial | Editor, Submit, replay controls, errors. Needed: Java syntax highlighting, starter code per level, saving the draft as it is edited, jumping to a compile error's line, the progress line (2.1), and the decision console (3.6). |
| `BattleDisplay` | partial | Built: ColorRect units with labels. Needed: sprites and tweens chosen by `LookCatalog`, health bars, damage numbers, intent icons, and a `BodyView` per body (3.5). |
| `Codex` | planned | A reference that can be opened from any screen. It covers the `Strategy` API, the state shape, every move, what Java works under TeaVM, and a page per monster met (its body, its crit, a worked example). Meeting a monster for the first time opens its page. |
| `HoverUI` + `HoverComponent` | built | Hover popups on any Control or Area2D. |

### 3.2 Coordination (`globals/`, autoloads)

| component | status | role |
|---|---|---|
| `BattleRunner` | built | `submit(source, level_id)`: build, play on a worker thread, emit `result_ready(envelope)` or `submit_failed(reason)`. Planned: the `progress` signal, and a retry with backoff when the server answers `busy`. |
| `Config` | built | `ServerConfig` resource: `server_url`, timeouts, `default_level`. On web, the page's own origin + `web_path` (`/api`). |
| `Progress` | planned | The save file `user://progress.json`: `{version, cleared: {level: {turns, at}}, drafts: {level: source}, met: [unit names], settings}`. It writes on change and migrates by `version`. On web, Godot keeps `user://` in IndexedDB. **Export code** and **Import code** download or upload a `.java` file as a backup, because browser storage can be cleared. |
| `Campaign` | planned | Reads `data/campaign.tres` (an ordered list of `CampaignStage`s). It answers "is this level unlocked" and "what comes next". |

### 3.3 Game logic (`systems/`)

| component | status | role |
|---|---|---|
| `Battle` | built | Turn loop, turn order (speed), the one legality check `use_error`, `use`, the primitives (`deal_damage`, `heal`, `block`, `guard`), and `state_for` (what the student sees). No nodes, no `await`. Runs on a worker thread. |
| `BattleLog`, `BattleResult`, `BattleSide`, `Combatant` | built | The log writer, the result, a side, and per-fight unit state. `Combatant` is the only thing that changes during a fight. |
| `StudentCode` | built | How `StudentController` reaches student code: `ServerStudentCode` (blocking HTTP through `ServerConnection`) or `ScriptedStudentCode` (GDScript, for tests). |
| `ReplaySystem` | built | A tape player over a finished log. It emits one signal per event, has no timers and no drawing. |

### 3.4 Content (`resources/` classes, `data/` instances)

Everything a designer changes is a `.tres`. Code is written only for a new
*kind* of thing.

| resource | status | what it is |
|---|---|---|
| `Move` + `Effect`s | built | A list of effects that scale off a user stat by `percent`. `crit_effects` run on a right crit answer. |
| `UnitDef` + `Stats` | built | A kind of unit: name, stats, moves, and optionally a `body` (`Body`) and a `crit` (`Problem`). |
| `Level`, `LevelSide`, `LevelUnit`, `LevelRule` | partial | A battle as data: sides, controllers, seed, turn limit, rules, `title`, `briefing`. Needed: `starter_code`, the path of a `.java` file in `data/starters/`. |
| `Controller`s | built | `TelegraphController` (AI) and `StudentController`. New AIs are subclasses. |
| `Body`s | partial | Built: `ArrayBody`, `LinkedListBody`. Planned for the campaign: `CyclicListBody`, `SortedArrayBody`, `BracketStringBody`, `TreeBody` (node table), `GraphBody` (adjacency), `GridBody`. |
| `Problem`s | partial | Built: `MiddleValueProblem`, `MinIndexProblem`, `MedianOfAllProblem`, `LowestHpTargetProblem`. Planned: one per campaign idea (`IDEAS.md`). |
| `CampaignStage`, `Campaign` | planned | `level`, `chapter`, `requires` (the levels to clear first), and `introduces` (the UnitDefs whose Codex page opens on first meeting). |
| `UnitLook`, `MoveLook`, `LookCatalog` | planned | Art keyed by `UnitDef.name` and `Move.id`, the same keys the events carry. A missing look falls back to the plain box and never stops a replay. |

### 3.5 Showing data structures

The point of the game is the data structures, so the replay draws them. This
needs two **additive** log changes (`docs/events.md` only ever gains fields):

- `spawn` gains `body` (the unit's body, the same JSON the student saw).
- A new `body` event, `{unit, body, move}`, is logged when a crit re-rolls a
  body. It has a `move`, so it arrives through `effect_applied` with no change
  to `ReplaySystem`.

`BodyView` (planned, `ui/body_views/`) is one small scene per `Body.kind`:
`array` → a row of cells, `linked_list` → nodes and arrows in list order,
`tree` → a laid-out tree, `graph` → a force layout. On a crit it highlights
the answer (for example, the middle node).

### 3.6 Debugging student code

Students need to see why their code did what it did. The envelope gains
`decisions`: one entry per `/decide`, `{turn, unit, command, console}`.
`CodePanel` shows the entry for the action being replayed. Today the console
is one block for the whole battle. The full state is not logged, because a
student can print it.

### 3.7 Web export

- The worker thread needs the web export's **Thread Support** option, and a
  threaded web build only runs when the page is cross-origin isolated. Caddy
  serves the page with `Cross-Origin-Opener-Policy: same-origin` and
  `Cross-Origin-Embedder-Policy: require-corp`. Serving the client and `/api`
  from **one origin** also means there is no CORS to configure.
- **Open risk (check this first):** `ServerConnection` busy-polls
  `HTTPClient` from a worker thread. On web, `HTTPClient` is built on `fetch`.
  Whether that works off the main thread has to be tested in a real exported
  build before anything else is deployed.
  Fallback: run `Battle` on the main thread as a step machine (`Battle.step()`
  per action) that waits on an async `HTTPRequest` between steps. The rules,
  the log and the tests stay the same; only `BattleRunner` and the loop driver
  change. The cost is ~35 ms more per call (measured).
- Built: the `Web` preset in `client/export_presets.cfg` (thread support on,
  output `client/build/web/`), and `scripts/serve_web.py`, which serves it the
  way Caddy will (COOP/COEP, `/api` proxied) for local testing.
- The desktop export stays as the fallback for a lab session.

---

## 4. Compile service (`server/`, Java 17 + TeaVM 0.13 + node)

Knows nothing about the game. It compiles one Java file and runs `decide`.

| component | status | role |
|---|---|---|
| `Server` | built | `/build`, `/start`, `/decide`, `/close`. Always HTTP 200 with a `status`. Planned: `GET /health` (`{status, builds, instances}`). |
| Compile step (`Server.javac`, `Server.teavm`) | partial | Built: javac then TeaVM, in-process, with the source in a temp directory. Needed: see 4.1. |
| `Builds` | partial | Builds by id, one running instance each, closed after 60 s idle. Planned: a cap on running instances (`MAX_INSTANCES`, sized from memory in 4.3). Over the cap, `/start` answers a new status `busy`. Also planned: a compile cache keyed by the SHA-256 of the source. |
| `Instance` | partial | One node process per battle, with a per-call timeout and an output cap. Planned: started through `Sandbox`. |
| `Sandbox` | planned | Starts node with `bwrap --unshare-all --die-with-parent`: no network, read-only binds of node and the build's directory only, a fresh `tmpfs` `/tmp`. Each instance gets its own cgroup (`memory.max` 320 MB, `pids.max` 16), which the service can create because its systemd unit has `Delegate=yes`. No `RLIMIT_AS`: V8 reserves far more address space than it uses, so an address-space limit breaks node. |
| `runner/` (`Runner`, `Json`, `StrictMap`, `host.js`) | built | Inside TeaVM, next to the student's code. Flat, default package, TeaVM subset only. |
| `api/` (`Strategy`) | built | What students implement. `dsagame-api.jar` is for students who want to code in their own IDE. |

### 4.1 Compiling untrusted source

The compile step had three gaps. The first is fixed:

| gap | why it matters | fix |
|---|---|---|
| **Fixed:** javac ran with no `-classpath` | In-process javac used the server's own classpath, which includes `teavm-jso`. A student could write `@JSBody(script = "...")` and run any JavaScript in node (shown: it returned node's version). | javac now gets `-classpath <build dir>` and `-proc:none`, so `org.teavm` doesn't resolve. `examples/js_interop` checks it in `e2e.sh`. |
| No limit on compiles at once | javac + TeaVM take hundreds of MB each, so 30 submits at once can exhaust the JVM. | A semaphore of 2 compile slots. Up to 20 requests wait; more get `busy`. |
| No compile time limit | Source written to make javac slow ties up a slot. | 20 s per compile. If an in-process compile turns out not to stop when cancelled, move the compile step into a child JVM that can be killed. |

### 4.2 Security model

Student code is untrusted. The defences, from outside in:

1. **Caddy:** TLS and request-size limits. Per-IP rate limits on `/api/build`
   (about 10 a minute) and `/api/start` come from the `caddy-ratelimit`
   module, so Caddy is built with `xcaddy`.
2. **systemd unit:** the service runs as its own user with
   `ProtectSystem=strict`, `ProtectHome=yes`, `PrivateTmp=yes`,
   `NoNewPrivileges=yes`, `MemoryMax=3G`, `TasksMax=512`. Nothing else
   runs on the host, and it holds no secrets.
3. **Contract limits** (built): source ≤ 50 KB, state ≤ 1 MB, call timeout
   1–10,000 ms, output ≤ 2,000,000 chars a battle, node heap 256 MB.
4. **Compile isolation** (4.1): no JS interop (built), limited compile slots and time (planned).
5. **Sandbox** (planned): no network, nothing writable except `/tmp`, memory
   and process count limited per battle, killed with the service.

Not defended: a student editing the client to report a win. That is
acceptable while there is no grading (section 1).

### 4.3 Deployment

- One small VPS (2–4 vCPU, 4 GB, near the students), Ubuntu LTS.
- **No containers.** bubblewrap needs unprivileged user namespaces, which
  Docker's default seccomp profile blocks. Running bwrap in Docker would mean
  weakening the container. Instead: Caddy as a system service, and the compile
  service as a hardened systemd unit (4.2). Deployment check:
  `bwrap --unshare-all true` must succeed as the service user. Recent Ubuntu
  releases allow this through an AppArmor profile for bwrap.
- `scripts/deploy.sh` (planned): export the Godot web build, run
  `./gradlew installDist`, rsync both to the host, restart the unit, then run
  `tests/e2e.sh` and one `smoke_submit` against the live URL.
- Logs: one JSON line per request (endpoint, status, ms, error kind, never
  source code) to the journal. An uptime check polls `GET /health`.
- **Capacity:** a running battle is one node process, about 60 MB in normal
  use and at most 320 MB (its cgroup). With ~2.5 GB for instances,
  `MAX_INSTANCES` = 8 covers the worst case. A battle holds its instance for a
  few seconds, so 30 students submitting in the same minute wait briefly on
  `busy` retries instead of failing. The load test (section 7) checks these
  numbers before the student trial.

---

## 5. Data contracts

| contract | file | rule |
|---|---|---|
| HTTP + student state + command | `docs/runner.md` | Fields and statuses are only added. A rename breaks submissions. |
| Battle log + envelope | `docs/events.md` | Fields and event types are only added. Any new event caused by a move carries `move`. |
| Save file | `Progress` (planned) | Has a `version` and migrates forward. A broken file is renamed to `.bak` and a fresh one is started. |

Planned additions, all additive: `spawn.body`, the `body` event,
`envelope.decisions`, the `busy` status, `GET /health`.

---

## 6. Content plan (the campaign)

Each chapter introduces one idea, and its levels are built so that the idea
wins, or wins clearly faster. **Built** campaign levels: 1 Goblin Camp
(commands), 2 Worm Burrow (linked-list middle, fast/slow pointers), 3 Swarm
Nest (array min index), 4 Pecking Order (lowest hp first), 5 Gatehouse
(median of all values). `demo`, `smoke`, `swapped` and the `*_test` levels
are for tests only and are not on the map.

| chapter | idea | monsters / rules (from `IDEAS.md`) |
|---|---|---|
| 1 Basics | reading state, commands | goblins, slimes, wraiths |
| 2 Lists | pointers, cycles | Worm, Ouroboros, Centipede |
| 3 Arrays | scan, sort, binary search | Swarm, Mimic Row, Serpent |
| 4 Hashing | maps and sets | Twin Imps, Doppelganger, "seen this body before" rule |
| 5 Stacks and queues | matching, order | Bracket Golem, Ghost Conga |
| 6 Trees and heaps | recursion, priority | Treant, Hydra, Hive Queen, running-median rule |
| 7 Graphs | BFS, topological order | Spider, Labyrinth Golem, Lich Ritual |
| 8 Finale | mixed | a boss with several bodies and rules |

Every level ships with: a `.tres`, a starter `.java`, a briefing, a zone on
the map, a `CampaignStage`, and scripted students in `tests/smoke_battle.gd`
that show the idea wins and the naive approach loses or is slower
(`.claude/skills/new-level/SKILL.md` walks through it).

---

## 7. Testing

| check | needs | covers |
|---|---|---|
| `smoke_battle` | nothing | every rule, every student error, determinism, every campaign level with and without its idea |
| `smoke_replay`, `smoke_battle_display` | nothing | replay and display from recorded fixtures |
| `smoke_submit` | server | the real pipeline. `--record` re-records `tests/fixtures/*.json`. |
| `smoke_game` | server | the whole client |
| `server/tests/e2e.sh` | JDK, node | every endpoint and error kind under real TeaVM |
| `smoke_progress` (planned) | nothing | save, load, migration, a corrupt file |
| `e2e.sh` hardening cases | bwrap | Built: `@JSBody` is a compile error. Planned: network, file write and fork attempts fail as student errors. `busy` appears over the cap. |
| `scripts/load_test.sh` (planned) | server | N parallel battles. It reports p95 `/decide` latency and when `busy` appears. |
| Web build check (planned) | browser | the exported page plays one battle against the live server (3.7) |

---

## 8. Extension points

- **Grading.** Same code + same level = same battle, so a `Verifier` (headless
  Godot next to the compile service) could re-run a submission and sign the
  result. Only `Server` and a new `/verify` route change. The rules are
  reused as they are.
- **Status effects** (poison, stun, buffs): state on `Combatant`, a new
  primitive on `Battle`, a new event with `move` (`DEVELOPMENT.md` 2.9).
- **Other games.** `Battle` takes plain sides, so a roguelike or an overworld
  encounter can build battles without a `Level` (`DEVELOPMENT.md` 2.8).

---

## 9. Decisions and their reasons

| decision | why | cost |
|---|---|---|
| Godot owns every rule, the server none | Content and rules change in one place. The server stays a small, auditable sandbox. | One HTTP round trip per student move (2.1). |
| TeaVM + node rather than a JVM per battle | It starts fast (~190 ms) and runs in a small process. An earlier WebAssembly attempt failed. | A subset of the Java library. `e2e.sh` is the only judge. |
| Play first, then replay | Rules are separate from animation. Replays can step, skip and reset. Results are deterministic. | Nothing is shown until the battle ends, so a progress line is needed. |
| Commands are strings, answers after `\|` | Students write one line. The server passes it through without knowing questions exist. | Parsing errors have to be explained well. |
| A wrong answer only misses its reward | Students experiment without being punished. | A wrong answer and no answer look the same. |
| Progress in the browser, not on the server | No accounts, no personal data, no database. | Clearing browser data loses progress. Export/Import code is the mitigation. |
| One origin behind Caddy | No CORS. Cross-origin isolation for threads. TLS in one place. | One host. That is enough for one course. |
| systemd + bwrap, not Docker | bwrap works without weakening a container, and one process manager is enough. | The host is set up by a script, not an image. |

---

## 10. Risks

| risk | mitigation |
|---|---|
| Blocking HTTP from a worker thread fails on web (3.7) | Test it first. Fallback: a step-machine battle on the main thread. |
| Network latency makes battles slow (2.1) | A host near the students, a progress line, a call budget per level. Measure from campus. |
| Untrusted code escapes | The classpath fix (4.1, done), then the sandbox, the hardened unit, and no secrets on the host. |
| Too many battles or compiles at once | Compile slots, `MAX_INSTANCES`, `busy` + retry. Load test before the student trial. |
| TeaVM rejects code a JVM accepts | The Codex lists what works. Compile errors are shown clearly. Common cases go in `e2e.sh`. |
| Level design takes longer than planned | Levels are data. Chapters 1–3 come first. Later chapters can ship with fewer levels. |
