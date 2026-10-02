# Runner protocol

The contract between the Godot client and the compile service once the game
lives in Godot. The service knows nothing about the game: it compiles a
`Submission.java`, and then, one call at a time, hands the student's `decide`
whatever state the client sends and returns whatever it answers. Units, moves,
sides, turns and win/loss are all the client's business.

This runs next to the old `/compile` service (`docs/protocol.md`) until the
old harness is deleted.

## The student's side

```java
public interface Strategy {
    String decide(Map<String, Object> state);
}
```

`decide` returns a **command**: the move's id, then the id of each target,
separated by spaces. `"attack e1"`, `"cleave e1 e2"`, `"heal cleric"`,
`"block"`, `"pass"`. Every move reads the same way; a move aimed at its own
user takes no id. The service sends the String back untouched; splitting it
and checking it against the battle is the client's business.

`Submission` is public, in the default package, with a public no-arg
constructor. One `Submission` is made per battle, so its fields last from one
call to the next within a battle and never into the next battle.

The state is JSON-like data: a `Map` has `String` keys, and
every value is a `Map`, a `List`, a `String`, a `Number`, a `Boolean` or
`null`. A whole number arrives as an `Integer` (a `Long` if it does not fit),
any other number as a `Double`. Maps keep the order their keys arrived in.

Reading a key the state does not have throws `NoSuchElementException`, naming
the key and listing the ones that are there. A key present with a null value
reads as null. `containsKey` and `getOrDefault` are the way to look for a key
that may be missing.

## Requests

Every endpoint takes `POST` with a plain-text body, so a browser build sends no
CORS preflight, and always answers HTTP 200 with a JSON object that has
`status` and `message`. `status` is `ok` whenever the call worked; the
student's code misbehaving is still `ok`, with `error` set.

| endpoint | body | answer |
|---|---|---|
| `/build` | `Submission.java`, at most 50,000 bytes | `build` |
| `/start?build=<id>&timeout_ms=<n>` | none | `instance`, `console`, `error` |
| `/decide?instance=<id>` | the state, as a JSON object, at most 1,000,000 bytes | `console`, `action`, `error` |
| `/close?build=<id>` | none | nothing more |

**`/build`** compiles the submission against `runner/` and keeps it. A failed
compile is `status: compile_error` with javac's or TeaVM's output in `message`
(`Submission.java:6: error: ...`) and `build: null`. A `package` line is
rejected the same way before javac runs.

**`/start`** begins a battle: a fresh node process and a fresh `Submission`.
It stops the build's previous battle, if any, so a build never has more than one
running. `timeout_ms` is how long each call of this battle may take, including
the constructor: 1 to 10,000, default 1,000. The client chooses it.

**`/decide`** hands one state to `decide` and returns its `action`.

**`/close`** stops the build's battle and deletes the build. A build nobody
has used for 60 seconds is closed anyway, so a client that crashes mid-battle
leaves nothing running for long.

| status | when |
|---|---|
| `ok` | the call worked; look at `error` |
| `compile_error` | `/build` only |
| `unknown_build` | no such build: closed, expired or never made |
| `unknown_instance` | no such battle: it ended after a `timeout`, `crashed` or `output_limit`, was replaced by a later `/start`, or its build was closed |
| `bad_request` | the request was wrong, not the student's code: a bad `timeout_ms`, a body too large, a state that is not a JSON object. The battle carries on. |
| `runtime_error` | the service itself failed |

## Errors

`error` is `null`, or an object with `kind` and `message`:

| kind | when | extra fields | afterwards |
|---|---|---|---|
| `threw` | the constructor or `decide` threw | `exception` (the class name; empty for errors that started in JavaScript, such as a stack overflow), `in` (`constructor` or `decide`) | the battle can carry on |
| `returned_null` | `decide` returned null | | the battle can carry on |
| `timeout` | the call took longer than `timeout_ms` | | the process is killed |
| `output_limit` | the student printed more than 2,000,000 characters in this battle | | the process is gone |
| `crashed` | the node process died | | the process is gone |

The service only reports these; whether one ends the battle is up to the
client. After the last three, `/decide` answers `unknown_instance`, and only a
new `/start` goes on.

## Console

`console` is what the student printed during that call, `System.out` and
`System.err` together, cut at 4,000 characters. The client puts the calls'
consoles together.

## Samples

`next/state.json` is a full state. Trimmed:

```json
{"turn": 1,
 "self":    {"id":"knight","name":"Knight","hp":34,"maxHp":34,"strength":6,"magic":0,"speed":4,"guard":0,"intent":null,
             "moves":[{"id":"attack","name":"Attack","description":"Hit one enemy for 100% of your strength.","target":"enemy","targets":1}, ...]},
 "allies":  [ ... ],
 "enemies": [{"id":"e3","name":"Wraith","hp":11,"maxHp":11,"strength":2,"magic":3,"speed":7,
              "guard":0,"intent":"drain cleric","moves":[ ... ]}, ...]}
```

Every list is fastest first, the order units act in. An intent is a command
too, the one that unit is about to send. A move's
`target` is who it may hit (`enemy`, `ally` or `self`) and `targets` how many
ids it takes at most: 0 for a `self` move. `guard` is damage the unit will
absorb before its next action. The service checks none of this: those keys are
the client's.

```
$ curl -s --data-binary @next/examples/first_enemy/Submission.java localhost:8080/build
{"status":"ok","message":"","build":"b5546b223c46545fc495c4bf5"}
$ curl -s -X POST "localhost:8080/start?build=b5546b223c46545fc495c4bf5"
{"status":"ok","message":"","instance":"id7af3cc7b75c0d454bf50e56","console":"","error":null}
$ curl -s --data-binary @next/state.json "localhost:8080/decide?instance=id7af3cc7b75c0d454bf50e56"
{"status":"ok","message":"","console":"","action":"attack e1","error":null}
```

## How it runs

`/build` compiles `Submission.java` with `next/api/` and `runner/` (flat,
default package, the TeaVM subset) and cross-compiles to `classes.js` with
`Runner` as the main class.

`/start` runs `node --max-old-space-size=256 runner/host.js classes.js`.
The host loads the program once and calls its `main` once per request, which
is why the static `Submission` in `Runner` outlives a single call. Everything
the student prints goes through TeaVM's stdout hooks into a buffer, so nothing
they print reaches the host's own stdout. `Runner` prints its reply after a
nonce that is fresh for every call and never reaches student code, and the
host picks the reply out by it, so printing a fake reply does nothing.

Measured on one machine: starting a battle costs about 190 ms, almost all of it
node starting up; each `/decide` after that about 1.3 ms inside the service
and about 2 ms end to end from Godot, if the client polls `HTTPClient` in a
loop. Godot's `HTTPRequest` node only finishes on a later frame, about 35 ms
a call.

## Not solved yet

- Student code runs in node with full access to the machine; the only fence
  is what TeaVM's class library offers. A battle's process now lives for the
  whole battle (under a second of simulation, or 60 idle seconds if the client
  vanishes), and a student thread could keep running between calls, where the
  per-call timeout does not see it.
- The rules live in the client, so a result the client reports proves nothing:
  anyone can edit the Godot project or forge the requests.
