# Events

The battle log `Battle` writes and `Simulation` replays, inside the envelope
`SubmitClient` emits:

```json
{"status": "ok", "message": "", "console": "...",
 "result": {"won": true, "reason": "All enemies defeated", "error": "", "events": [...]}}
```

`status` is `ok`, `compile_error`, `bad_request` or `runtime_error`; `result`
is null unless `ok`. When `error` is set, `reason` repeats it.

Every event has `turn` (0 for spawns) and `type`. `unit` and `target` are
unit ids from `spawn`. `move` names the move an event came from.

| type | fields | Simulation signal |
|---|---|---|
| `spawn` | `unit`, `name`, `team`, `hp`, `maxHp` | `spawned` |
| `intent` | `unit`, `action`, `target?`, `targets?`, `move` | `intent` |
| `action` | `unit`, `action`, `target?`, `targets?`, `move` | `action` |
| `damage` | `unit`, `amount`, `hp`, `absorbed?`, `move` | `effect_applied` |
| `heal` | `unit`, `amount`, `hp`, `move` | `effect_applied` |
| `guard` | `unit`, `amount`, `move` | `effect_applied` |
| `blocked` | `unit`, `reason`, `move` | `effect_applied` |
| `death` | `unit` | `died` |
| `end` | `won`, `reason` | `ended` |
| new type with `move` | | `effect_applied` |
| new type without `move` | | `unknown_event` |

- `action` = `move` = the move id. A `self` move has no `target`; a
  multi-target move has `target` = the first and `targets` = all, in order.
- `hp` is after the change. `amount` on `damage` is what got past the guard,
  `absorbed` what the guard took (only when > 0).
- Fields are only ever added, never renamed or removed.
