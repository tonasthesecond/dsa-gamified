/**
 * Where a move's id, name and power live. Heroes and monsters are built from
 * these, so two combatants with the same move still get their own instance.
 */
final class Moves {
    private Moves() {
    }

    /** The basic attack: damage equal to the user's attack. Every combatant has it. */
    static Move attack() {
        return new DamageMove("attack", "Attack", 0);
    }

    static Move smite() {
        return new DamageMove("smite", "Smite", 4);
    }

    static Move heal() {
        return new HealMove("heal", "Heal", 8);
    }

    static Move drain() {
        return new DrainMove("drain", "Drain", 1);
    }
}
