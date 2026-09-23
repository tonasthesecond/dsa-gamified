import dsagame.api.TargetKind;

/**
 * Where a move's id, name, numbers and effects live. Heroes and monsters are
 * built from these, so two combatants with the same move still get their own
 * instance.
 */
final class Moves {
    private Moves() {
    }

    /** The basic attack: damage equal to the user's attack. Every combatant has it. */
    static Move attack() {
        return new Move("attack", "Attack", "Hit one enemy for your attack.",
                TargetKind.ENEMY, 0, new DamageEffect(0));
    }

    /**
     * Do nothing. Every combatant gets one, so passing needs no special case
     * anywhere in the battle loop.
     */
    static Move pass() {
        return new Move("pass", "Pass", "Do nothing this turn.", TargetKind.SELF, 0);
    }

    static Move smite() {
        int power = 4;
        return new Move("smite", "Smite", "Hit one enemy for your attack plus " + power + ".",
                TargetKind.ENEMY, power, new DamageEffect(power));
    }

    static Move heal() {
        int power = 8;
        return new Move("heal", "Heal", "Heal one ally, or yourself, by " + power + ".",
                TargetKind.ALLY, power, HealEffect.target(power));
    }

    /** Hurts one enemy and heals the user by as much as it actually took off. */
    static Move drain() {
        int power = 1;
        return new Move("drain", "Drain",
                "Hit one enemy for your attack plus " + power + ", and heal yourself by what landed.",
                TargetKind.ENEMY, power, new DamageEffect(power), HealEffect.userFromState(MoveState.DAMAGE));
    }
}
