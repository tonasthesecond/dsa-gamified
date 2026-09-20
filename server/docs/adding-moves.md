# Adding moves, monsters, heroes and levels

Everything in `harness/` is one flat directory in the default package, because
the student's `Submission` is in the default package and the compile service
copies `harness/` in as-is. Do not add subfolders.

## How a move works

A `Move` is an object a combatant owns. It holds no battle state, so it is safe
from turn to turn, and every combatant gets its own instances.

```java
abstract class Move {
    final String id;            // stable; what Action.use sends back
    final String name;          // shown to the player
    final TargetKind targetKind;// ENEMY, ALLY or SELF
    final int power;            // meaning is up to the move

    String blockReason(Battle battle, Combatant user, Combatant target);  // null = it goes through
    abstract void resolve(Battle battle, Combatant user, Combatant target);
}
```

A move changes the battle only through the primitives on `Battle`:

| primitive | what it does |
|---|---|
| `battle.dealDamage(target, amount)` | takes health off, logs `damage`, logs `death` at 0 |
| `battle.heal(target, amount)` | puts health back, never past the maximum, logs `heal` |

Those primitives log their own events, so **a move never builds an event**. If a
move needs something the primitives cannot express, add a primitive to `Battle`
— that is the one reason to touch `Battle`.

By the time `resolve` runs, the target is known to exist, to be alive and to
match `targetKind`; `Battle.useError` has already checked. `resolve` never has
to validate.

Damage moves deal `user.attack + power`, so the basic attack is a `DamageMove`
with power 0.

## Worked example: adding `drain`

`drain` hurts an enemy and heals its user by however much it actually took off.
Adding it and putting it into the `demo` level touched four files, all of them
additive:

| file | change |
|---|---|
| `harness/DrainMove.java` | new, 14 lines: the move itself |
| `harness/Moves.java` | +1 factory: where its id, name and power live |
| `harness/Monsters.java` | +1 factory: a Wraith that knows it |
| `harness/DemoLevel.java` | one line: the level puts a Wraith in the fight |

No change to `Main`, `Battle`, `EventLog`, `Server` or `dsagame.api`. If adding
a move ever does need one of those, the design is wrong — say so rather than
working around it.

The move itself:

```java
/** Hurts one enemy and heals the user by as much as it actually took off. */
class DrainMove extends Move {
    DrainMove(String id, String name, int power) {
        super(id, name, TargetKind.ENEMY, power);
    }

    void resolve(Battle battle, Combatant user, Combatant target) {
        int before = target.hp;
        battle.dealDamage(target, user.attack + power);
        battle.heal(user, before - target.hp);
    }
}
```

Note that it heals for the damage that landed, not the damage it tried to do, by
reading `target.hp` on either side of the primitive.

Then one line in `Moves`, which is the only place a move's numbers live:

```java
static Move drain() {
    return new DrainMove("drain", "Drain", 1);
}
```

If a move is a plain hit or a plain heal, skip the new class entirely: it is
already a `DamageMove` or a `HealMove` with different numbers, so it is one line
in `Moves`.

## Adding a monster or a hero

One factory in `Monsters.java` or `Heroes.java`. Each call returns a fresh
combatant with fresh moves.

```java
static Combatant wraith(String id, int maxHp) {
    return new Combatant(id, "Wraith", maxHp, 2, true, Moves.drain(), Moves.attack());
}
```

The last argument is the move list, in the combatant's own order. `pass` is
added for you, so every combatant can always do nothing.

Order matters for enemies: the default `Level.chooseIntent` uses the enemy's
**first** move on the first living hero. An enemy whose first move is a heal
needs the level to override `chooseIntent`, or it will aim at a hero and the
move will be skipped as an illegal target.

## Adding a level

Subclass `Level`, build the party and the enemies from the factories, register
one line in `Levels.get`. See "How to add a level" in `docs/protocol.md`.

```java
class ExampleLevel extends Level {
    String id() { return "example"; }

    List<Combatant> setup(long seed) {
        Random random = new Random(seed);
        List<Combatant> units = new ArrayList<Combatant>();
        units.add(Heroes.knight("knight"));
        units.add(Monsters.goblin("e1", 12 + random.nextInt(5)));
        return units;
    }
}
```

Heroes first, then enemies. Everything random comes from the seed, or from
`battle.random` later on, so the same submission always replays identically.

To make a level special, override one of the seams rather than adding a rule
to the battle loop:

| seam | for |
|---|---|
| `chooseIntent(enemy, battle)` | what the monsters do; returns an `Intent`, one move and one target |
| `blockReason(target, battle)` | a rule about a target that applies to every move, such as a shield |
| `Move.blockReason(...)` | a rule belonging to one move |
| `maxTurns`, `scenarioCount` | the shape of the exercise |

## What the student sees

| harness | student |
|---|---|
| `Combatant` | `Unit` — immutable snapshot |
| `Move` | `MoveInfo` — id, name, target kind, power |
| the battle | `GameState` — turn, self, allies, enemies |

`decide` is called once per living hero, in party order, with `getSelf()` set to
that hero. A submission picks a move from `state.getSelf().getMoves()` and sends
it back as `Action.use(move, target)`. `Action.attack(target)` is sugar for the
move with id `attack`, and `Action.pass()` for `pass`.

Using a move the hero does not know, or on a target the move cannot hit, ends
the scenario with an error naming both:

```
Knight tried to use "heal", which it does not know.
Cleric tried to use Heal on Goblin, which is not an ally.
```

## Before you commit

- `tests/e2e.sh` — the whole suite, through real TeaVM.
- New content needs a test: a submission that wins it and one that does not,
  under `examples/`, asserted in `tests/e2e.sh`.
- Stay inside the TeaVM subset (see the bottom of `docs/protocol.md`).
