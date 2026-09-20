# DSA Game server

Compiles a student's `Submission.java`, runs it through a turn-based battle, and
returns the battle as a JSON event log. See `docs/protocol.md` for the contract.

Needs a JDK 17+ and `node` on the PATH.

```
./gradlew run             # serve on :8080, from this directory
tests/e2e.sh              # the whole test suite (starts its own server)
tests/harness-test.sh     # just the harness determinism checks
scripts/build-api-jar.sh  # dsagame-api.jar, for students to compile against
```

The service reads `api/` and `harness/` from its working directory, so run it
from here.

| directory | what it is |
|---|---|
| `src/main/java/compileservice` | the HTTP service |
| `api/dsagame/api` | the student-facing API; the only named package |
| `harness` | the battle loop and the level seam; default package |
| `starter` | the skeleton students start from |
| `examples` | one submission per test case |

The harness and `Submission` share the default package on purpose: Java cannot
reference the default package from a named one, so a packaged harness could not
instantiate `Submission`.
