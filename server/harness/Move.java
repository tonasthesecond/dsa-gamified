import dsagame.api.MoveInfo;
import dsagame.api.TargetKind;

/**
 * Something a combatant can do on its turn. Heroes and monsters use the same
 * moves; the basic attack is a move like any other.
 *
 * <p>A move holds no battle state, so an instance belongs to exactly one
 * combatant and is safe to reuse from turn to turn. Moves change the battle
 * only through the primitives on {@link Battle}, which log their own events; a
 * move never builds an event itself.
 */
abstract class Move {
    final String id;
    final String name;
    final TargetKind targetKind;
    /** How strong the move is. What that means is up to the move. */
    final int power;

    Move(String id, String name, TargetKind targetKind, int power) {
        this.id = id;
        this.name = name;
        this.targetKind = targetKind;
        this.power = power;
    }

    /**
     * Whether this move bounces off this target.
     *
     * @return a reason shown to the player, or null if the move goes through
     */
    String blockReason(Battle battle, Combatant user, Combatant target) {
        return null;
    }

    /** Carries the move out. The target is already known to be legal. */
    abstract void resolve(Battle battle, Combatant user, Combatant target);

    MoveInfo snapshot() {
        return new MoveInfo(id, name, targetKind, power);
    }
}
