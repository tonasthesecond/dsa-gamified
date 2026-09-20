import dsagame.api.Action;
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

    /** Hero first, then the enemies. Must be deterministic for a given seed. */
    abstract List<Combatant> setup(long seed);

    int scenarioCount() {
        return 3;
    }

    int maxTurns() {
        return 20;
    }

    /** What this enemy telegraphs for the coming turn. Default: attack the hero. */
    Action chooseIntent(Combatant enemy, Battle battle) {
        return Action.attack(battle.hero.snapshot());
    }

    /**
     * Whether the student's attack on this target bounces.
     *
     * @return a reason shown to the player, or null if the hit lands
     */
    String blockReason(Combatant target, Battle battle) {
        return null;
    }
}
