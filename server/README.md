# server

Compiles a student's `Submission.java` and runs its `decide` for the Godot
client. Knows nothing about the game. Contract: `docs/runner.md`.

Needs JDK 17 and `node`. Run everything from this directory.

```
./gradlew run             # serve on :8080
tests/e2e.sh              # the test suite (starts its own server)
scripts/build-api-jar.sh  # dsagame-api.jar, what students compile against
```

| directory | what it is |
|---|---|
| `src/main/java/compileservice` | the HTTP service |
| `runner` | runs inside TeaVM next to the student's code; flat, default package |
| `api/dsagame/api` | `Strategy`, what students implement; the only named package |
| `examples` | one `Submission.java` per test case |
| `tests` | `e2e.sh` and the sample `state.json` it sends |
