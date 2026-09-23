import java.util.List;

/**
 * The seam every level plugs into. The defaults are a plain fight, so a level
 * overrides only what makes it special.
 *
 * <p>To add a level: subclass this, register it in {@link Levels}, and add a
 * reference solution and a deliberately wrong one to the tests.
 */
abstract class Level {
    abstract String id();

    /** The party first, then the enemies. Must be deterministic for a given seed. */
    abstract List<Combatant> setup(long seed);

    int scenarioCount() {
        return 3;
    }

    int maxTurns() {
        return 20;
    }

    /**
     * What this enemy telegraphs for the coming turn. Default: its first move on
     * the first living hero. The move and target must be legal for the enemy.
     */
    Intent chooseIntent(Combatant enemy, Battle battle) {
        return new Intent(enemy.moves.get(0), battle.firstLivingHero());
    }

    /**
     * Whether any move aimed at this target bounces, whoever is using it.
     * A move can also refuse on its own with a {@link BlockEffect}.
     *
     * @return a reason shown to the player, or null if the hit lands
     */
    String blockReason(Combatant target, Battle battle) {
        return null;
    }
}
