# Runner

The HTTP contract between the Godot client and the Java service, and what the
student's code sees. The service knows nothing about the game.

## Student code

```java
public interface Strategy {
    String decide(Map<String, Object> state);
}
```

- `Submission` is public, in the default package, with a no-arg constructor.
  One is made per battle, so fields last for that battle only.
- `decide` returns a **command**: the move id, then each target id, space
  separated. `"attack e1"`, `"cleave e1 e2"`, `"heal cleric"`, `"block"`.
  The service returns it untouched; the client splits and checks it.
- The state is Maps, Lists, Strings, Numbers (whole → `Integer`/`Long`,
  else `Double`), Booleans and null, keys in the order sent. Reading a missing
  key throws, naming it; use `containsKey` for optional keys.

State sample (`server/tests/state.json` is a full one):

```json
{"turn": 1,
 "self":    {"id":"knight","name":"Knight","hp":34,"maxHp":34,"strength":6,"magic":0,"speed":4,"guard":0,"intent":null,
             "moves":[{"id":"attack","name":"Attack","description":"Hit one enemy for 100% of your strength.","target":"enemy","targets":1}, ...],
             "body":null,"crit":null},
 "allies":  [ ... ],
 "enemies": [{"id":"e3","name":"Wraith","hp":11,"maxHp":11,"strength":2,"magic":3,"speed":7,
              "guard":0,"intent":"drain cleric","moves":[ ... ],"body":null,"crit":null}, ...],
 "rules":   []}
```

Lists are fastest first. `intent` is the command that unit will send.
`target` is who a move may hit (`enemy`, `ally`, `self`), `targets` how many
ids it takes at most (0 for `self`). `guard` is damage absorbed before hp.

## Bodies, crits and rules

Some kinds of unit carry a data structure, their `body`, and a `crit`
question about it; every unit of that kind asks the same question. Units
without one have `"body": null, "crit": null`.

```json
"body": {"kind": "linked_list", "head": "n2",
         "nodes": {"n1": {"value": 7, "next": null},
                   "n2": {"value": 4, "next": "n3"},
                   "n3": {"value": 9, "next": "n1"}}},
"crit": {"id": "middle", "description": "The value of the middle node, ..."}
```

| `kind` | fields |
|---|---|
| `array` | `values`: distinct whole numbers |
| `linked_list` | `head` (a node id), `nodes`: id → `{value, next}`, `next` null at the tail; table order is not list order |

| crit `id` | answer |
|---|---|
| `middle` | the middle node's value; with an even length, the second of the two middles |
| `min_index` | the index of the smallest value, from 0 |

`rules` lists the level's own questions: `{"id", "description", "answer"}`,
where `answer` is false for a rule judged from the move alone (such as "hit the
enemy with the least hp").

**Answers** go after the command, each in a section after a `|`: its label,
then the answer, read as JSON, else as plain text. The label is `crit` for the
target's crit, or a rule's `id`:

```
attack e1 | crit 4
attack e1 | crit 4 | median 5.5
attack e1 | crit [1, 3, 4]
```

A right crit answer on a move aimed at an enemy runs the move's crit (for
`attack`, 50% more of your strength), and the target's body is generated anew.
A rule can bounce the move when its answer is wrong, or add to it when right;
its `description` says which. A wrong, missing or unreadable answer only misses
its reward: it is never an error.

## Endpoints

All `POST` with a plain-text body; always HTTP 200 with `status` and `message`.

| endpoint | body | answer |
|---|---|---|
| `/build` | `Submission.java`, ≤ 50,000 bytes | `build` |
| `/start?build=<id>&timeout_ms=<n>` | | `instance`, `console`, `error` |
| `/decide?instance=<id>` | state JSON, ≤ 1,000,000 bytes | `console`, `action`, `error` |
| `/close?build=<id>` | | |

- `/build` compiles against `api/` and `runner/`, javac then TeaVM. A failure,
  or a `package` line, is `compile_error` with `Submission.java:N: error: ...`.
- `/start` starts a node process and a fresh `Submission`, replacing the
  build's previous one. `timeout_ms` is per call, 1–10,000, default 1,000.
- `/close` deletes the build. Builds idle for 60 s are closed anyway.

| status | when |
|---|---|
| `ok` | the call worked; check `error` |
| `compile_error` | `/build` failed |
| `unknown_build` / `unknown_instance` | closed, expired, replaced, or never made |
| `bad_request` | bad `timeout_ms`, body too large, state not a JSON object |
| `runtime_error` | the service itself failed |

## Errors

The student's mistakes are `status: ok` with `error` = `{kind, message}`:

| kind | when | afterwards |
|---|---|---|
| `threw` | constructor or `decide` threw; adds `exception`, `in` | battle can go on |
| `returned_null` | `decide` returned null | battle can go on |
| `timeout` | took longer than `timeout_ms` | process killed |
| `output_limit` | printed over 2,000,000 chars this battle | process gone |
| `crashed` | node died | process gone |

`console` is what was printed during the call, cut at 4,000 chars.

## Notes

- node loads the program once per battle and calls `main` per request, so the
  static `Submission` in `Runner` lives for the battle. Replies are prefixed
  with a per-call nonce the student never sees, so printing a fake one does
  nothing.
- ~190 ms to start a battle, ~2 ms per `/decide` from Godot.
- Not solved: student code runs in node with full machine access, and the
  client is trusted with the result.
